#!/usr/bin/env python3
import yaml
import json
from urllib import request, error
import time
import sys

GCE_BASE = "http://metadata.google.internal/computeMetadata/v1"
ENVOY_CFG_URL = GCE_BASE + "/instance/attributes/grafana-envoy-config"
BACKEND_ID_URL = GCE_BASE + "/instance/attributes/backend-numeric-id"
ROLE_CFG_URL = GCE_BASE + "/instance/attributes/grafana-role-config"
PROJECT_NUM_ID_URL = GCE_BASE + "/project/numeric-project-id"
GCE_HEADERS = {"Metadata-Flavor": "Google"}

CONFIG_IN = "/etc/envoy/config-orig.yaml"
CONFIG_OUT = "/etc/envoy/config.yaml"

class kvpredicate:
    def __init__(self, k, v):
        self.k = k
        self.v = v
    def __call__(self, x):
        return x[self.k] == self.v
    def __str__(self):
        return f"predicate: {self.k} == {self.v}"

path_to_aud = ["static_resources",
               "listeners",
               kvpredicate("name", "listener_0"),
               "filter_chains",
               kvpredicate("name", "chain_0"),
               "filters",
               kvpredicate("name", "envoy.filters.network.http_connection_manager"),
               "typed_config",
               "http_filters",
               kvpredicate("name", "envoy.filters.http.jwt_authn"),
               "typed_config",
               "providers",
               "auth0",
               ]

path_to_rolecfg = ["static_resources",
                   "listeners",
                   kvpredicate("name", "listener_0"),
                   "filter_chains",
                   kvpredicate("name", "chain_0"),
                   "filters",
                   kvpredicate("name", "envoy.filters.network.http_connection_manager"),
                   "typed_config",
                   "route_config",
                   "virtual_hosts",
                   kvpredicate("name", "local_service"),
                   "routes",
                   kvpredicate("name", "default"),
                   "metadata",
                   "filter_metadata",
                   ]


def simple_json_set(j, path, v):
    s = j
    for p in path:
        try:
            if isinstance(p, str) or isinstance(p, int):
                s = s[p]
                continue
            if callable(p):
                s = [x for x in s if p(x)][0]
                continue
        except:
            print("got error at", s, "path item", p)
            raise
        raise(Exception(f"{p} is neither index nor predictor"))
    v(s)

def main():
    for i in range(1,10):
        try:
            backend_id = request.urlopen(request.Request(BACKEND_ID_URL, headers=GCE_HEADERS)).read().decode('utf8').strip()
            break
        except error.HTTPError as err:
            if err.code == 404 and i < 7:
                print(f"backend id not found, wait {2*i*i}s",file=sys.stderr)
                time.sleep(2*i*i)
                continue
            raise(err)
    project_num_id = request.urlopen(request.Request(PROJECT_NUM_ID_URL, headers=GCE_HEADERS)).read().decode('utf8').strip()
    try:
        rolecfg = yaml.safe_load(request.urlopen(request.Request(ROLE_CFG_URL, headers=GCE_HEADERS)))
    except:
        rolecfg = None
    aud = f"/projects/{project_num_id}/global/backendServices/{backend_id}"
    #print(aud, rolecfg)
    j = yaml.safe_load(request.urlopen(request.Request(ENVOY_CFG_URL, headers=GCE_HEADERS)))
    simple_json_set(j, path_to_aud, lambda x: x.update(audiences=[aud]))
    simple_json_set(j, path_to_rolecfg, lambda x:x.update({"envoy.filters.http.lua":rolecfg}))
    json.dump(j, open(CONFIG_OUT, "w"), indent=2)


if __name__ == "__main__":
    main()
