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

echo
echo
echo Upgrading Subspace Node and Farmer
echo
echo Stopping Node and Farmer
systemctl --user stop subspace-farmer
systemctl --user stop subspace-node

echo Downloading latest build

LAST_BUILD_MONTH_DAY=$(curl https://api.github.com/repos/subspace/subspace/tags | grep name | grep \"gemini- | cut -d : -f2 | cut -d - -f4,5 | cut -d \" -f1 | sort -M | tail -n1)
LATEST_NODE=$(curl https://api.github.com/repos/subspace/subspace/releases | grep $(date +%Y-$LAST_BUILD_MONTH_DAY) | grep browser_download_url | grep $PLATFORM | grep -v opencl | grep node | cut -d : -f2,3 |  tr -d ' "')
LATEST_FARMER=$(curl https://api.github.com/repos/subspace/subspace/releases | grep $(date +%Y-$LAST_BUILD_MONTH_DAY) | grep browser_download_url | grep $PLATFORM | grep -v opencl | grep farmer | cut -d : -f2,3 |  tr -d ' "')
if [[ "${LATEST_NODE}" = "" || ${LATEST_FARMER} = "" ]] ; then
    echo Cannot find latest Subspace builds; perhaps due to year rollover and no builds yet this year?
    exit
else
    sudo wget -N $LATEST_NODE -P /opt/subspace/
    sudo wget -N $LATEST_FARMER -P /opt/subspace/
    sudo chmod +x /opt/subspace/"${LATEST_NODE##*/}"
    sudo chmod +x /opt/subspace/"${LATEST_FARMER##*/}"
    sudo ln -s -f /opt/subspace/"${LATEST_NODE##*/}" /usr/local/bin/subspace-node
    sudo ln -s -f /opt/subspace/"${LATEST_FARMER##*/}" /usr/local/bin/subspace-farmer
fi

systemctl --user start subspace-node
systemctl --user start subspace-farmer
