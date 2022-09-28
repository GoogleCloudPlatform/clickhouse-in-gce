#!/usr/bin/env python3
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

# usage: $0 clustername clustersize username password
# clustername: the basename of cluster machines
# clustersize: number of nodes in the cluster
# username: the username to connect to each nodes
# passsword: the password of that user
# zk: basename of zookeeper nodes

# scheme of replication: replicate to the node on the left
#    node: 1 2 3 4
#          | | | |
#          v v v v
# replica: 4 1 2 3
import os
import sys
import xml.etree.ElementTree as ET

def main():
    cluster = sys.argv[1]
    size = int(sys.argv[2])
    username = sys.argv[3]
    password = sys.argv[4]
    zk = sys.argv[5]

    if size < 2:
        raise Exception("cluster must have at least 2 nodes")

    cfgtree = ET.parse("/etc/clickhouse-server/config.xml")

    cfgtree.getroot().append(ET.fromstring("<listen_host>0.0.0.0</listen_host>"))

    remote_servers = [x for x in cfgtree.getroot() if x.tag == "remote_servers"][0]
    remote_servers.clear()

    cluster_element = ET.Element("default_cluster")
    for idx in range(0, size):
        mirror_idx = (size + idx - 1) % size
        shard_element = ET.fromstring(
            """<shard>
          <replica>
            <default_database>shard</default_database>
            <host>{hostname}-{idx}</host>
            <port>9000</port>
            <user>{user}</user>
            <password>{password}</password>
          </replica>
          <replica>
            <default_database>replica</default_database>
            <host>{hostname}-{mirror_idx}</host>
            <port>9000</port>
            <user>{user}</user>
            <password>{password}</password>
          </replica>
        </shard>""".format(
                hostname=cluster,
                idx=idx,
                mirror_idx=mirror_idx,
                user=username,
                password=password,
            )
        )
        cluster_element.append(shard_element)

    remote_servers.append(cluster_element)

    zookeepers = [x for x in cfgtree.getroot() if x.tag == "zookeeper"]

    if len(zookeepers) > 0:
        zk_element = zookeepers[0]
        zk_element.clear()
    else:
        zk_element = ET.Element("zookeeper")
        cfgtree.getroot().append(zk_element)

    for idx in range(0, 3):
        zk_node_element = ET.fromstring(
            """<node>
            <host>{zk}-{idx}</host>
            <port>2181</port>
        </node>""".format(
                zk=zk, idx=idx
            )
        )
        zk_element.append(zk_node_element)

    os.rename("/etc/clickhouse-server/config.xml", "/etc/clickhouse-server/config.xml.bak")
    cfgtree.write("/etc/clickhouse-server/config.xml")

if __name__ == "__main__":
    main()
