# subspace-utils
Utilities to manage and operate subspace network nodes

 # Installing Subspace
 From your linux node, simply run:

 ```bash
 wget -q https://raw.githubusercontent.com/jrwashburn/subspace-utils/main/subspace-install.sh && bash subspace-install.sh && rm subspace-install.sh
```

# Removing Subspace
If you change your minda and want to remove subpace, this will cleanup and delete the files installed.

```bash
wget -q https://raw.githubusercontent.com/jrwashburn/subspace-utils/main/subspace-uninstall.sh && bash subspace-uninstall.sh && rm subspace-uninstall.sh
```
# Setting up grafana cloud dashboard
To use the grafana dashboard from https://github.com/counterpointsoftware, but in grafana cloud:

```bash
wget -q https://github.com/jrwashburn/subspace-monitoring/raw/main/grafana/provisioning/dashboards/subspace-dashboard-counterpoint.json
sed -i "s^PBFA97CFB590B2093^grafanacloud-prom^g" subspace-dashboard-counterpoint.json
sed -i "s^9.1.1^9.1.3-e1f2f3c^g" subspace-dashboard-counterpoint.json
```

Then login to grafana cloud and upload the modified "subspace-dashboard-counterpoint.json" to your instance.
From grafana, choose dashboard, import, then upload the file.

# subspace-install.sh

This shell script will provision a new subspace node, including the following options:

- create a new user
  If you opt to create a new user, the user will be created, after which you shoudl logout and log back in as the new user and run the script again.

- install and configure ufw firewall to block all except subspace and ssh
  The script will configure ufw to allow traffic to the ssh port and subspace port.
  Note if ufw is already installed, existing ufw rules will remain in place.
  Defaults will be set to deny incoming and allow outgoing.
  If you do not want to use those defaults, you can choose to not run the ufw config.

- install and configure node_exporter and prometheus
  The script will install the latest versions of node_exporter and prometheus to gather metrics.
  Metrics will be pushed to Grafana Cloud with remote_write.
  Grafana prom push endpoint, user, and API key must be provided.

- install and configure subspace
  The latest versions of subspace node and farmer will be installed.
  You may choose a custom port for subspace p2p networking (default 30333 will be used otherwise)

- systemd will be configured to automatically run the installed components
  Subspace node and farmer will be automatically run (and restarted in the event of a crash)
  If installed, node_exporter and prometheus will also be set to run automatically
