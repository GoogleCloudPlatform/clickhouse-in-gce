#!/bin/bash
# Copyright 2022 Google LLC
# Author: Jun Sheng
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# $1: the file holds ip address of ilb pointing to clickhouse cluster

apt-get update
apt-get install -y apt-transport-https
apt-get install -y software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y grafana
/bin/systemctl daemon-reload
/bin/systemctl enable grafana-server
/bin/systemctl start grafana-server
/usr/share/grafana/bin/grafana-cli plugins install grafana-clickhouse-datasource

cat <<EOF |tee /etc/grafana/provisioning/datasources/clickhouse.yaml
apiVersion: 1
datasources:
  - name: ClickHouse
    type: grafana-clickhouse-datasource
    jsonData:
      defaultDatabase: default
      port: 9000
      server: $(cat "$1")
      username: default
      tlsSkipVerify: false
    secureJsonData:
      password: $(gcloud secrets versions access --secret=ch-default-pass-fb6fa0fb3c91 latest)
EOF

/bin/systemctl restart grafana-server
