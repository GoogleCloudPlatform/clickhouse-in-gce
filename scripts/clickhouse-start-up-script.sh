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

# $1: the file holds cluster_size

install_clickhouse() {
  apt-get update
  apt-get install -y apt-transport-https ca-certificates dirmngr
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8919F6BD2B48D754

  echo "deb https://packages.clickhouse.com/deb stable main" | tee /etc/apt/sources.list.d/clickhouse.list
  apt-get update -y

  apt-get install -y xfsprogs python3-sqlparse
  DEBIAN_FRONTEND=noninteractive apt-get install -qq -y clickhouse-server clickhouse-client
  passhash=$(gcloud secrets versions access --secret=ch-default-pass-fb6fa0fb3c91 latest|tr -d '\n'|sha256sum |cut -d ' ' -f 1)
  cat > /etc/clickhouse-server/users.d/default-password.xml  <<EOF
<clickhouse>
    <users>
        <default>
            <password remove='1' />
            <password_sha256_hex>$passhash</password_sha256_hex>
        </default>
    </users>
</clickhouse>
EOF
  touch /root/clickhouse-installed
}

init_database() {
  DATADISK="$(readlink -f /dev/disk/by-id/google-disk-1)"
  if ! blkid -o value -s LABEL "$DATADISK" |grep -q clickhouse
  then
    mkfs.xfs -L clickhouse "$DATADISK"
  fi
  if ! grep -q /data /etc/fstab
  then
    cat >> /etc/fstab <<EOF
LABEL=clickhouse /data xfs defaults 0 0
EOF
  fi
  mkdir -p /data
  mount /data
  if [ -e /data/clickhouse/initialized ]
  then
    return 0
  fi
  if ! mountpoint /data
  then
    echo ERROR
    exit 111
  fi
  mkdir -p /data/clickhouse/{format_schemas,access,user_files,tmp,log,clickhouse-data}
  chown -R clickhouse.clickhouse /data/clickhouse/
  chmod -R 750 /data/clickhouse
  rm -fr /var/log/clickhouse-server
  ln -s /data/clickhouse/log /var/log/clickhouse-server
  rm -fr /var/lib/clickhouse
  ln -s /data/clickhouse /var/lib/clickhouse
  touch /data/clickhouse/initialized
}

if [ -e /root/clickhouse-installed ]
then
  echo "clickhouse installed"
else
  install_clickhouse
fi
if [ -e /data/clickhouse/initialized ]
then
  echo "clickhouse data initialized "
else
  init_database
  SELFNAME="$(readlink -f "$0")"
  CLUSTER_SIZE="$(cat $1)"
  python3 "$(dirname "$SELFNAME")"/clickhouse-config-cluster.py clickhouse "$CLUSTER_SIZE" default "$(gcloud secrets versions access --secret=ch-default-pass-fb6fa0fb3c91 latest)" zook
  systemctl enable clickhouse-server
  systemctl start clickhouse-server
  clickhouse-client --multiquery --password "$(gcloud secrets versions access --secret=ch-default-pass-fb6fa0fb3c91 latest)" <<EOF
CREATE DATABASE shard;
CREATE DATABASE replica;
EOF
fi

