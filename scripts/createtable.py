#!/usr/bin/python3
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


import argparse
import re

import sqlparse


def transform(c):
    def token_backmatch(tl, start, p):
        for pred in reversed(p):
            if start is None:
                return False
            if not pred(tl[start]):
                return False
            start, _ = tl.token_prev(start, True, True)
        return True
    state = 0  # 0 - start
    # 1 - table name process
    # 2 - table body finished
    # 3 - Engine process
    # 4 - finishing
    # 5 - end
    ret = []
    for idx, t in enumerate(c.tokens):
        if state == 0:
            if token_backmatch(
                c,
                idx,
                [
                    lambda x: x.is_keyword and x.normalized == "CREATE",
                    lambda x: x.is_keyword and x.normalized == "TABLE",
                    lambda x: isinstance(x, sqlparse.sql.Identifier)
                ]
            ):
                ret.append(("name", str(t)))
                state = 1
                continue
        if state == 1:
            if token_backmatch(
                c,
                idx,
                [
                    lambda x: x.is_keyword and x.normalized == "CREATE",
                    lambda x: x.is_keyword and x.normalized == "TABLE",
                    lambda x: isinstance(x, sqlparse.sql.Identifier),
                    lambda x: isinstance(x, sqlparse.sql.Parenthesis)
                ]
            ):
                ret.append((1, t))
                state = 2
                continue
        if state == 2:
            if token_backmatch(
                c,
                idx,
                [
                    lambda x: x.is_keyword and x.normalized == "CREATE",
                    lambda x: x.is_keyword and x.normalized == "TABLE",
                    lambda x: isinstance(x, sqlparse.sql.Identifier),
                    lambda x: isinstance(x, sqlparse.sql.Parenthesis),
                    lambda x: x.is_keyword and x.normalized == "ENGINE"
                ]
            ):
                state = 3
                continue
            if token_backmatch(
                c,
                idx,
                [lambda x: x.is_keyword or x.ttype is sqlparse.tokens.Punctuation]
            ):
                ret.append(("engine", "ENGINE"))
                state = 4
        if state == 3:
            if token_backmatch(
                c,
                idx,
                [
                    lambda x: x.is_keyword and x.normalized == "ENGINE",
                    lambda x: x.ttype is sqlparse.tokens.Comparison and x.normalized == "=",
                    lambda x: isinstance(x, sqlparse.sql.Identifier),
                    lambda x: isinstance(x, sqlparse.sql.Parenthesis)
                ]
            ):
                state = 2
            continue
        if state == 4:
            if token_backmatch(
                c,
                idx,
                [lambda x: x.ttype is sqlparse.tokens.Punctuation and x.value == ";"]
            ):
                state = 5
        ret.append((state, t))
    if state < 2:
        raise Exception("not a table DDL")
    return ret


def getddl(ddlseq, indb, dbid, clustername=None):
    tablename = ""
    finalddl = ""

    def checkdbid(indb):
        return indb in ("shard", "replica")

    def transtblname(raw, indb):
        cre = re.compile('([`"]?)([^.`"]*[.]?)([^.`"]*)([`"]?)')
        l, c1, c2, e = cre.match(raw).groups()
        if c2 == "":
            c2 = c1
        return f"{l}{indb}.{c2}{e}", c2

    def genengine(tablename, indb, dbid, cn=clustername):
        if not checkdbid(indb):
            return f"""ENGINE=Distributed('{cn}','',{tablename},rand())\n"""
        return f"""Engine=ReplicatedMergeTree('/clickhouse/tables/shard{dbid}/{tablename}', 'replica_{dbid}')\n"""

    if not checkdbid(indb) and clustername is None:
        raise Exception(f"clustername must be specified if dbid={indb}")
    for tag, sqlet in ddlseq:
        if tag == "name":
            t, tablename = transtblname(sqlet, indb)
            finalddl += t
            continue
        if tag == "engine":
            finalddl += genengine(tablename, indb, dbid)
            continue
        if tag == 4 and not checkdbid(indb):
            continue
        finalddl += str(sqlet)
    return finalddl


# example of layout
# layout = [(('shard', 0),('replica', 1),('default', 0)), # server 0
#           (('shard', 1),('replica', 2),('default', 0)), # server 1
#           (('shard', 2),('replica', 3),('default', 0)), # server 2
#           (('shard', 3),('replica', 0),('default', 0))] # server 3


def main():
    argp = argparse.ArgumentParser()
    argp.add_argument(
        "--clustername",
        help="the cluster name, default is 'default_cluster'",
        default="default_cluster"
    )
    argp.add_argument(
        "--hostbase",
        help="the base name of clickhouse host, default is 'clickhouse'",
        default="clickhouse"
    )
    argp.add_argument(
        "--clustersize",
        help="No. of nodes in cluster, default is '4'",
        default=4,
        type=int
    )
    argp.add_argument(
        "--user",
        help="the user to connect to clickhouse database, default is 'default'",
        default="default"
    )
    argp.add_argument(
        "--passsecret",
        help="""the gcp secret name holding the password to connect to clickhouse database,
        default is 'ch-default-pass-fb6fa0fb3c91'""",
        default="ch-default-pass-fb6fa0fb3c91"
    )
    argp.add_argument(
        "--sqlfile",
        help="the DDL sql to run in clickhouse cluster"
    )

    sqlexample = """CREATE TABLE replica.test
    (
       id Int64,
       event_time DateTime
    )
    Engine=ReplicatedMergeTree('/clickhouse/tables/shard1/test', 'replica_1')
    PARTITION BY toYYYYMMDD(event_time)
    ORDER BY id;
    """
    args = argp.parse_args()

    clustername = args.clustername
    hostbase    = args.hostbase
    clustersize = args.clustersize
    user        = args.user
    passsecret  = args.passsecret
    sqlfile     = args.sqlfile

    if sqlfile is not None:
        sql = sqlparse.parse(open(sqlfile))[0]
    else:
        sql = sqlparse.parse(sqlexample)[0]

    for srvidx in range(0, clustersize):
        for indb, dbid in [
            ("shard", srvidx),
            ("replica", (srvidx + 1) % clustersize),
            ("default", 0)
        ]:
            print(f"""clickhouse-client --host {hostbase}-{srvidx} --multiquery\\
            --user {user} --password "$(gcloud secrets versions access --secret={passsecret} latest)" <<EOF""")
            print(getddl(transform(sql), indb, dbid, clustername))
            print("""EOF""")
            print("""#######Finished host {hostbase}-{srvidx}, database {indb}-{dbid} #########################""")

if __name__ == "__main__":
    main()
