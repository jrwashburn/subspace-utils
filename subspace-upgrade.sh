#TODO add support for wipe / chain change

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
if lspci | grep 'VGA' | grep 'AMG' ; then
  AMD_BUILD=true
else
  AMD_BUILD=false
fi

echo Detected architecture $PLATFORM $CPULEVEL with AMD $AMD_BUILD

echo
echo
echo Upgrading Subspace Node and Farmer
echo Downloading latest build

LAST_BUILD_MONTH_DAY=$(curl https://api.github.com/repos/autonomys/subspace/releases | grep name | grep mainnet | grep $(date +%Y) | grep -v .exe | cut -d : -f2 | cut -d - -f8,9,10 | cut -d \" -f1 | sort -M | tail -n1)
echo Last build date: $LAST_BUILD_MONTH_DAY
if [[ $AMD_BUILD = true ]] ; then
  LATEST_NODE=$(curl https://api.github.com/repos/autonomys/subspace/releases | grep $(date +%Y-$LAST_BUILD_MONTH_DAY) | grep mainnet | grep browser_download_url | grep rocm-$PLATFORM-$CPULEVEL | grep node | cut -d : -f2,3 |  tr -d ' "')
  echo Latest Node: $LATEST_NODE
  LATEST_FARMER=$(curl https://api.github.com/repos/autonomys/subspace/releases | grep $(date +%Y-$LAST_BUILD_MONTH_DAY) | grep mainnet | grep browser_download_url | grep rocm-$PLATFORM-$CPULEVEL| grep farmer | cut -d : -f2,3 |  tr -d ' "')
  echo Latest Farmer: $LATEST_FARMER
else
  LATEST_NODE=$(curl https://api.github.com/repos/autonomys/subspace/releases | grep $(date +%Y-$LAST_BUILD_MONTH_DAY) | grep mainnet | grep browser_download_url | grep -v rocm | grep $PLATFORM-$CPULEVEL | grep node | cut -d : -f2,3 |  tr -d ' "')
  echo Latest Node: $LATEST_NODE
  LATEST_FARMER=$(curl https://api.github.com/repos/autonomys/subspace/releases | grep $(date +%Y-$LAST_BUILD_MONTH_DAY) | grep mainnet | grep browser_download_url | grep -v rocm | grep $PLATFORM-$CPULEVEL| grep farmer | cut -d : -f2,3 |  tr -d ' "')
  echo Latest Farmer: $LATEST_FARMER
fi
if [[ "${LATEST_NODE}" = "" || ${LATEST_FARMER} = "" ]] ; then
    echo Cannot find latest Subspace builds - perhaps due to year rollover and no builds yet this year?
    exit
else
    sudo wget -N $LATEST_NODE -P /opt/subspace/
    sudo wget -N $LATEST_FARMER -P /opt/subspace/
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
