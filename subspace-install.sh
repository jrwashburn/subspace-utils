#!/bin/bash
cat <<E-O-F
Installing Linux Subspace Node

A new user may be created to run subspace. Note the following:
** The user will be added to sudo group and systemd-journal groups. **
** The user will be granted the same ssh authorized_keys as the current user $USER **
If a new user has already been created, please run this script under that user, and press CTRL+C now to end this script.

E-O-F

read -n1 -r -p "Would you like to create a new user? (y/n) " YESNO
echo
if [ $YESNO = "y" ] || [ $YESNO = "Y" ] ; then
    echo Setting up new dedicated user to run subspace.
    echo You will be prompted to set a new password and other general user info.
    read -p "New username: " USERNAME
    echo
    sudo adduser $USERNAME
    if ! [ $? -eq 0 ]; then
        echo Failed adding user $USERNAME
        exit
    fi
    sudo usermod -aG sudo $USERNAME
    sudo usermod -aG systemd-journal $USERNAME
    sudo mkdir -p /home/$USERNAME/.ssh
    sudo chown $USERNAME:$USERNAME /home/$USERNAME/.ssh
    sudo cp ~/.ssh/authorized_keys /home/$USERNAME/.ssh/authorized_keys
    sudo chown $USERNAME:$USERNAME /home/$USERNAME/.ssh/authorized_keys
    sudo chmod 600 /home/$USERNAME/.ssh/authorized_keys
    sudo systemctl restart sshd
    echo
    echo Please logout and log back in as the new user and run the script again.
    exit
else
    if [ $EUID = 0 ]; then
        cat <<E-O-F

It is not recommended to run subspace as the root user.

Please login as the user you will run subspace under.
This script will not install as root.
E-O-F

        exit
    else
        echo Starting Subspace installation ....
    fi
fi
cat <<E-O-F


This script will setp a Subspace node with the following optional capabilities:
 - ufw firewall configuration
 - install prometheus and send metrics to Grafana Cloud \(see https://grafana.com/docs/grafana-cloud/data-configuration/metrics/metrics-prometheus/\)
 - install latest version of subspace node and farmer and setup systemd units to have them run on startup
 - customize subspace listener Port

Starting installation
Your subspace node name will be used to identify this node on subspace telemetry and grafana

E-O-F

read -r -p "Enter the node name to identify this node: " NODENAME
echo
NODE_BASE_PATH=""
FARMER_BASE_PATH=""
read -n1 -r -p "Do you want a custom file path for the node? " YESNO
echo
if [ $YESNO = "y" ] || [ $YESNO = "Y" ] ; then
    read -r -p "Enter the base path for NODE files to be stored (i.e. /path/to/directory/here : " NODE_BASE_PATH
    echo
    if ! [[ -d "$NODE_BASE_PATH" ]] ; then
        echo directory does not exist - creating $NODE_BASE_PATH
        read -n1 -r -p "Press any key to continue or CTRL+C to break." CONTINUE
        sudo mkdir -p $NODE_BASE_PATH
    fi
    NODE_BASE_PATH="--base-path=$NODE_BASE_PATH"
    read -r -p "Enter the base path for FARMER files to be stored (i.e. /path/to/directory/here : " FARMER_BASE_PATH
    echo
    if ! [[ -d "$FARMER_BASE_PATH" ]] ; then
        echo directory does not exist - creating $FARMER_BASE_PATH
        read -n1 -r -p "Press any key to continue or CTRL+C to break." CONTINUE
        sudo mkdir -p $FARMER_BASE_PATH
    fi
    FARMER_BASE_PATH="--base-path=$FARMER_BASE_PATH"
fi

SUBSPACEPORT=30333
echo By default, Subspace node will listen on port $SUBSPACEPORT.
echo
read -n1 -r -p "Press any key to use the default port, or press P (must use capital P) to enter a custom port number? (P/any) " YESNO
if [ $YESNO = "P" ] ; then
    echo
    read -p "Enter a port number between 1025-65534? " SUBSPACEPORT
    echo
    if [ $SUBSPACEPORT -lt 1025 ] || [ $SUBSPACEPORT -gt 65534 ] ; then
        echo Invalid port number provided - ending script.
        exit
    fi
fi

SUBSPACE_PROMETHEUS=9615
echo By default, Subspace node will provide prometheus metrics on port $SUBSPACE_PROMETHEUS.
echo
read -n1 -r -p "Press any key to use the default port, or press P to enter a custom port number? (P/any) " YESNO
if [ $YESNO = "P" ] ; then
    echo
    read -p "Enter a port number between 1025-65534? " SUBSPACE_PROMETHEUS
    echo
    if [ $SUBSPACE_PROMETHEUS -lt 1025 ] || [ $SUBSPACE_PROMETHEUS -gt 65534 ] ; then
        echo "Invalid port number provided; ending script."
        exit
    fi
fi


#UFW setup
#get current SSH port configuration
SSHPORT=$(grep Port /etc/ssh/sshd_config | tr -s ' ' '\t' | cut -f 2)
echo
echo
read -n1 -r -p "Do you want to setup UFW firewall to only allow subspace and ssh ($SSHPORT) ports inbound, and allow all outbound traffic? " YESNO
echo
if [ $YESNO = "y" ] || [ $YESNO = "Y" ] ; then
    sudo apt -y install ufw
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow $SSHPORT/tcp
    sudo ufw allow $SUBSPACEPORT/tcp
    sudo ufw enable
fi

#Install Prometheus
YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT="https://prometheus-prod-10-prod-us-central-0.grafana.net/api/prom"
cat <<E-O-F

Installing prometheus will download and install the current prometheus and node_exporter versions.
It will also setup systemd units to start them automatically, and configure prometheus to send data to a remote_write endpoing \(e.g. granfana cloud\)
You will need a Metrics Publisher API Key \(see: https://grafana.com/docs/grafana-cloud/reference/create-api-key/ \)
and your Grafana Metrics Instance ID \(see: https://grafana.com/auth/sign-in then under Manage Grafana Cloud Stack click Send Metrics under Prometheus to get the url and user \)
for example: $YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT

E-O-F

read -n1 -r -p "Do you want to install Prometheus and configure it to push metrics to a remote_write endpoint such as Grafana Cloud? (y/n)" YESNO
if [ $YESNO = "y" ] || [ $YESNO = "Y" ] ; then
    echo
    echo
    read -r -p "Enter the remote_write endpoint or enter to use default [$YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT]?" YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT
    YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT=${YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT:-"https://prometheus-prod-10-prod-us-central-0.grafana.net/api/prom/push"}
    echo
    echo
    read -r -p "Enter your Grafana Metrics Instance Id: " YOUR_GRAFANA_METRICS_INSTANCE_ID
    echo
    echo
    read -r -p "Enter your Grafana API Key: " YOUR_GRAFANA_API_KEY
    echo
    echo
    read -r -p "How often do you want to scrape metrics? (e.g. 5s, 10s, 15s, 60s): " YOUR_GRAFANA_SCRAPE_INTERVAL
    echo
    echo
    case $(arch) in
        i386)
            PLATFORM=linux-386
            ;;
        x86_64)
            PLATFORM=linux-amd64
            ;;
        arm64)
            PLATFORM=linux-arm64
            ;;
        *)
            echo Unknown architecture - not sure which Grafana version to install. Attempting linux-amd64
            PLATFORM=linux-amd64
            ;;
    esac

    sudo mkdir -p /opt/prometheus
    CURRENT_NODE_EXPORTER=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep browser_download_url | grep $PLATFORM | cut -d '"' -f 4)
    sudo wget -N $CURRENT_NODE_EXPORTER -P /opt/prometheus
    sudo tar xvfz /opt/prometheus/${CURRENT_NODE_EXPORTER##*/} -C /opt/prometheus
    sudo rm /opt/prometheus/${CURRENT_NODE_EXPORTER##*/}
    NODE_DIR=$(echo /opt/prometheus/${CURRENT_NODE_EXPORTER##*/} | sed 's/\.tar\.gz//g' )

    CURRENT_PROMETHEUS=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep browser_download_url | grep $PLATFORM | cut -d '"' -f 4)
    sudo wget -N $CURRENT_PROMETHEUS -P /opt/prometheus
    sudo tar xvfz /opt/prometheus/${CURRENT_PROMETHEUS##*/} -C /opt/prometheus
    sudo rm /opt/prometheus/${CURRENT_PROMETHEUS##*/}
    PROM_DIR=$(echo /opt/prometheus/${CURRENT_PROMETHEUS##*/} | sed 's/\.tar\.gz//g' )

    sudo ln -s -f $NODE_DIR/node_exporter /usr/local/bin/node_exporter
    sudo ln -s -f $PROM_DIR/prometheus /usr/local/bin/prometheus
    sudo mkdir -p /etc/prometheus
    sudo cp -r $PROM_DIR/consoles /etc/prometheus
    sudo cp -r $PROM_DIR/console_libraries /etc/prometheus

    sudo tee /etc/prometheus/prometheus-subspace.yml &>/dev/null << E-O-F
global:
    scrape_interval: $YOUR_GRAFANA_SCRAPE_INTERVAL
    external_labels:
        origin_prometheus: $NODENAME
scrape_configs:
    - job_name: "node-exporter"
      static_configs:
        - targets: ["localhost:9100"]
    - job_name: "prometheus"
      static_configs:
        - targets: ["localhost:9090"]
    - job_name: "subspace"
      static_configs:
        - targets: ["localhost:$SUBSPACE_PROMETHEUS"]
remote_write:
    - url: $YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT
      basic_auth:
        username: $YOUR_GRAFANA_METRICS_INSTANCE_ID
        password: $YOUR_GRAFANA_API_KEY
E-O-F

    sudo tee /etc/systemd/user/prometheus.service &>/dev/null << E-O-F
[Unit]
Description=prometheus
After=network-online.target

[Service]
Type=simple
Restart=always
RestartSec=15
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus-subspace.yml

[Install]
WantedBy=default.target
E-O-F

    sudo tee /etc/systemd/user/prom-node_exporter.service &>/dev/null << E-O-F
[Unit]
Description=prom-node-exporter
After=network-online.target

[Service]
Type=simple
Restart=always
RestartSec=15
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
E-O-F
    systemctl --user daemon-reload
    systemctl --user start prom-node_exporter
    systemctl --user start prometheus
    systemctl --user enable prom-node_exporter
    systemctl --user enable prometheus
fi

#INSTALL SUBSPACE

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
echo Detected architecture $PLATFORM $CPULEVEL

echo
echo
echo Installing Subspace Node and Farmer
echo
echo
read -r -p "Enter the subspace reward wallet address for farming rewards: " REWARD_ADDRESS
echo
echo
read -r -p "Enter the plot size (i.e. 10G, 100G, 1T): " PLOT_SIZE
echo
echo
read -r -p "Enter the chain name (i.e. gemini-2a, etc.): " CHAIN_NAME
echo
echo

LAST_BUILD_MONTH_DAY=$(curl https://api.github.com/repos/autonomys/subspace/releases | grep name | grep \"gemini- | cut -d : -f2 | cut -d - -f4,5 | cut -d \" -f1 | sort -M | tail -n1)
LATEST_NODE=$(curl https://api.github.com/repos/autonomys/subspace/releases | grep $(date +%Y-$LAST_BUILD_MONTH_DAY) | grep browser_download_url | grep $PLATFORM-$CPULEVEL |  grep node | cut -d : -f2,3 |  tr -d ' "')
LATEST_FARMER=$(curl https://api.github.com/repos/autonomys/subspace/releases | grep $(date +%Y-$LAST_BUILD_MONTH_DAY) | grep browser_download_url | grep $PLATFORM-$CPULEVEL | grep farmer | cut -d : -f2,3 |  tr -d ' "')

if [ $LATEST_NODE = "" ] || [ $LATEST_FARMER = "" ] ; then
    echo Cannot find latest Subspace builds; perhaps due to year rollover and no builds yet this year?
    exit
else
    sudo mkdir -p /opt/subspace
    sudo wget -N $LATEST_NODE -P /opt/subspace/
    sudo wget -N $LATEST_FARMER -P /opt/subspace/
    sudo chmod +x /opt/subspace/"${LATEST_NODE##*/}"
    sudo chmod +x /opt/subspace/"${LATEST_FARMER##*/}"
    sudo ln -s -f /opt/subspace/"${LATEST_NODE##*/}" /usr/local/bin/subspace-node
    sudo ln -s -f /opt/subspace/"${LATEST_FARMER##*/}" /usr/local/bin/subspace-farmer
fi

sudo tee /etc/systemd/user/subspace-node.service &>/dev/null << E-O-F
[Unit]
Description=Subspace Node
After=network.target
[Service]
Type=simple
Restart=always
RestartSec=15
ExecStart=/usr/local/bin/subspace-node \\
--chain=$CHAIN_NAME \\
$NODE_BASE_PATH \\
--execution="wasm" \\
--blocks-pruning archive \\
--state-pruning archive \\
--no-private-ipv4 \
--validator \\
--port=$SUBSPACEPORT \\
--prometheus-port $SUBSPACE_PROMETHEUS \\
--name=$NODENAME
[Install]
WantedBy=default.target
E-O-F

sudo tee /etc/systemd/user/subspace-farmer.service &>/dev/null << E-O-F
[Unit]
Description=Subspace Farmer
After=network.target
[Service]
Type=simple
Restart=always
RestartSec=15
ExecStart=/usr/local/bin/subspace-farmer \\
$FARMER_BASE_PATH \\
farm \\
--reward-address=$REWARD_ADDRESS \\
--plot-size=$PLOT_SIZE
[Install]
WantedBy=default.target
E-O-F

systemctl --user daemon-reload
systemctl --user start subspace-node
systemctl --user start subspace-farmer
systemctl --user enable subspace-node
systemctl --user enable subspace-farmer
sudo loginctl enable-linger $USER