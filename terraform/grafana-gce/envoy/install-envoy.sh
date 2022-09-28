#!/bin/bash

apt-get update
apt-get install -y python3-yaml debian-keyring debian-archive-keyring apt-transport-https curl lsb-release
curl -sL 'https://deb.dl.getenvoy.io/public/gpg.8115BA8E629CC074.key' | gpg --dearmor -o /usr/share/keyrings/getenvoy-keyring.gpg
echo a077cb587a1b622e03aa4bf2f3689de14658a9497a9af2c427bba5f4cc3c4723 /usr/share/keyrings/getenvoy-keyring.gpg | sha256sum --check || exit 1
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/getenvoy-keyring.gpg] https://deb.dl.getenvoy.io/public/deb/debian $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/getenvoy.list
apt-get update
apt-get install -y getenvoy-envoy

useradd -U -m envoy
mkdir /etc/envoy

cp /root/envoy-lua-script /etc/envoy/rolesetting.lua

chown -R envoy:envoy /etc/envoy

install -m 755 /root/grafana-update-envoy-config.py /usr/local/bin/grafana-update-envoy-config.py

cat <<EOF |tee /etc/systemd/system/envoy.service
[Unit]
Description=Envoy
After=network.target

[Service]
WorkingDirectory=/etc/envoy
ExecStartPre=/usr/local/bin/grafana-update-envoy-config.py
ExecStart=/usr/bin/envoy --config-path /etc/envoy/config.yaml --log-level warn
User=envoy
Group=envoy

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable envoy.service
systemctl start envoy.service
