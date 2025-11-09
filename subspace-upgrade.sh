#!/usr/bin/env bash

#TODO add support for wipe / chain change

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to parse GitHub release metadata. Please install jq (e.g. sudo apt install jq)."
  exit 1
fi

#check platforms to determine which version to install
case $(arch) in
    x86_64 )
        PLATFORM=ubuntu-x86_64
        ;;
    arm64 )
        PLATFORM=ubuntu-aarch64
        ;;
    *)
        echo Unknown architecture - not sure which Grafana version to install. Attempting linux-amd64
        PLATFORM=ubuntu-x86_64
        ;;
esac
#get architecture level (v2, v3, v4),
# credit to https://unix.stackexchange.com/a/631320
flags=$(grep '^flags\b' </proc/cpuinfo | head -n 1)
flags=" ${flags#*:} "
has_flags () {
  for flag; do
    case "$flags" in
      *" $flag "*) :;;
      *)
        return 1;;
    esac
  done
}
determine_level () {
  CPULEVEL=0
  has_flags lm cmov cx8 fpu fxsr mmx syscall sse2 || return 0
  CPULEVEL=1
  has_flags cx16 lahf_lm popcnt sse4_1 sse4_2 ssse3 || return 0
  CPULEVEL=2
  has_flags avx avx2 bmi1 bmi2 f16c fma abm movbe xsave || return 0
  CPULEVEL=3
  has_flags avx512f avx512bw avx512cd avx512dq avx512vl || return 0
  CPULEVEL=3 # no subspace v4 builds currently, use v3 build for v4 cpu.
}
determine_level
if [[ $CPULEVEL -le 2 ]] ; then
  CPULEVEL=v$CPULEVEL
else
  CPULEVEL=skylake
fi

if command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -i 'VGA' | grep -qi 'AMD'; then
  AMD_BUILD=true
else
  AMD_BUILD=false
fi

echo Detected architecture $PLATFORM $CPULEVEL with AMD $AMD_BUILD

echo
echo
echo Upgrading Subspace Node and Farmer
echo Downloading latest build

RELEASES_JSON=$(curl -fsSL https://api.github.com/repos/autonomys/subspace/releases) || {
  echo "Failed to fetch release metadata from GitHub."
  exit 1
}

latest_asset_url() {
  local asset_type=$1
  echo "$RELEASES_JSON" | jq -r \
    --arg type "$asset_type" \
    --arg platform "$PLATFORM" \
    --arg level "$CPULEVEL" \
    --arg want_rocm "$AMD_BUILD" '
      [ .[]
        | select((.draft | not) and (.prerelease | not) and (.name | test("mainnet")))
        | .assets[]
        | select(
            (.browser_download_url | contains("subspace-" + $type))
            and (.browser_download_url | contains($platform))
            and (.browser_download_url | contains($level))
            and (
              ($want_rocm == "true" and (.browser_download_url | contains("rocm")))
              or ($want_rocm != "true" and (.browser_download_url | contains("rocm") | not))
            )
          )
        | {published: .updated_at, url: .browser_download_url}
      ]
      | sort_by(.published)
      | reverse
      | (.[0].url // "")
    '
}

LATEST_NODE=$(latest_asset_url node)
LATEST_FARMER=$(latest_asset_url farmer)

LAST_BUILD_DATE=$(echo "$LATEST_NODE" | grep -oE 'mainnet-[0-9]{4}-[a-z]{3}-[0-9]{2}' | head -n1 | cut -d- -f2-4)
echo "Last build date: ${LAST_BUILD_DATE:-unknown}"

echo Latest Node: $LATEST_NODE
echo Latest Farmer: $LATEST_FARMER

if [[ "${LATEST_NODE}" = "" || ${LATEST_FARMER} = "" ]] ; then
    echo Cannot find latest Subspace builds - perhaps due to year rollover and no builds yet this year?
    exit
else
    sudo wget -N "$LATEST_NODE" -P /opt/subspace/
    sudo wget -N "$LATEST_FARMER" -P /opt/subspace/
    sudo chmod +x /opt/subspace/"${LATEST_NODE##*/}"
    sudo chmod +x /opt/subspace/"${LATEST_FARMER##*/}"
    echo
    echo Stopping Node and Farmer
    systemctl --user stop subspace-farmer
    systemctl --user stop subspace-node
    sudo ln -s -f /opt/subspace/"${LATEST_NODE##*/}" /usr/local/bin/subspace-node
    sudo ln -s -f /opt/subspace/"${LATEST_FARMER##*/}" /usr/local/bin/subspace-farmer
fi

echo
echo Starting Node and Farmer

systemctl --user start subspace-node
systemctl --user start subspace-farmer
