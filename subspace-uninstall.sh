#!/bin/bash

SUBSPACEPORT=30333
echo By default, Subspace node listens on port $SUBSPACEPORT.
echo If you installed with a custom port. please provide that port.
echo
read -n1 -r -p "Press any key to use the default port, or press P to enter a custom port number? (P/any) " YESNO
if [[ "${YESNO}" = "p" || ${YESNO} = "P" ]] ; then
    echo
    read -p "Enter a port number between 1025-65534? " SUBSPACEPORT
    echo
    if [[ "${SUBSPACEPORT}" < 1025 || ${SUBSPACEPORT} > 65534 ]] ; then
        echo "Invalid port number provided; ending script."
        exit
    fi
fi

read -n1 -r -p "Do you want to change UFW firewall to deny inbound on $SUBSPACEPORT? " YESNO
echo
if [[ "${YESNO}" = "y" || ${YESNO} = "Y" ]] ; then
    sudo ufw deny $SUBSPACEPORT/tcp
    sudo ufw enable
fi

read -n1 -r -p "Do you want to remove Prometheus and node_exporter? (y/n) " YESNO
if [[ "${YESNO}" = "y" || ${YESNO} = "Y" ]] ; then
    systemctl --user stop prometheus.service
    systemctl --user stop prom-node_exporter.service
    systemctl --user disable prometheus.service
    systemctl --user disable prom-node_exporter.service
    sudo rm -rf $(dirname $(readlink /usr/local/bin/prometheus))
    sudo rm -rf $(dirname $(readlink /usr/local/bin/node_exporter))
    sudo rm /usr/local/bin/node_exporter
    sudo rm /usr/local/bin/prometheus
    sudo rm /etc/prometheus/prometheus-subspace.yml
    sudo rm -rf /etc/prometheus/consoles
    sudo rm -rf /etc/prometheus/console_libraries
    sudo rm /etc/systemd/user/prometheus.service
    sudo rm /etc/systemd/user/prom-node_exporter.service
fi

read -n1 -r -p "Do you want to remove subspace node and farmer? (y/n) " YESNO
if [[ "${YESNO}" = "y" || ${YESNO} = "Y" ]] ; then
    systemctl --user stop subspace-farmer.service
    systemctl --user stop subspace-node.service
    systemctl --user disable subspace-farmer.service
    systemctl --user disable subspace-node.service
    sudo rm -rf $(dirname $(readlink /usr/local/bin/subspace-node))
    sudo rm -rf $(dirname $(readlink /usr/local/bin/subspace-farmer))
    sudo rm /usr/local/bin/subspace-node
    sudo rm /usr/local/bin/subspace-farmer
    sudo rm /etc/systemd/user/subspace-node.service
    sudo rm /etc/systemd/user/subspace-farmer.service
fi
echo
echo "If you used custom directories, you may need to clear them directly."
