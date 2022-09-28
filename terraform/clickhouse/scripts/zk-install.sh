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

# $1: the file name holding myid

apt-get update
apt-get install -y openjdk-17-jdk wget
useradd -U -m zookeeper
mkdir -p /data/zookeeper
cp "$1" /data/zookeeper/myid

chown -R zookeeper:zookeeper /data/zookeeper

cd /home/zookeeper
wget https://dlcdn.apache.org/zookeeper/zookeeper-3.7.1/apache-zookeeper-3.7.1-bin.tar.gz
tar xvzf apache-zookeeper-3.7.1-bin.tar.gz
cat <<EOF > /home/zookeeper/apache-zookeeper-3.7.1-bin/conf/zoo.cfg
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/data/zookeeper
clientPort=2181
server.0=zook-0:2888:3888
server.1=zook-1:2888:3888
server.2=zook-2:2888:3888
EOF
chown -R zookeeper.zookeeper apache-zookeeper-3.7.1-bin.tar.gz apache-zookeeper-3.7.1-bin
cd -
cat <<EOF |tee /etc/systemd/system/zookeeper.service
[Unit]
Description=Zookeeper
After=network.target

[Service]
ExecStart=/home/zookeeper/apache-zookeeper-3.7.1-bin/bin/zkServer.sh start-foreground /home/zookeeper/apache-zookeeper-3.7.1-bin/conf/zoo.cfg
ExecStop=/home/zookeeper/apache-zookeeper-3.7.1-bin/bin/zkServer.sh stop /home/zookeeper/apache-zookeeper-3.7.1-bin/conf/zoo.cfg
User=zookeeper
Group=zookeeper

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zookeeper.service
systemctl start zookeeper.service
