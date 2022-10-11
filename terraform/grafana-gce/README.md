# Run grafana in Compute Engine

This module deploy a grafana in Compute Engine.

## What is deployed

1. A Virtual Machine running grafana
1. An external https load-balancer with identity-aware proxy enabled

The certificate of the https load-balancer is GCP-managed. 

# Some variables explained

## `grafana_role_config`

A map of user and role settting to grant users grafana roles: "Admin", "Editor", "Viewer". 

Example 1, grant someuser@example.com the "Admin" role of grafana:

```
grafana_role_config = {
    rolebindings = {
        "someuser@example.com"  = "Admin"
    }
}
```

Example 2, also grants someotheruser@example.com the "Editor" role:

```
grafana_role_config = {
    rolebindings = {
        "someuser@example.com"  = "Admin",
        "someotheruser@example.com" = "Editor"
    }
}
```

## `grafana-datasource-install` 

A script used to provision datasources for grafana. See `../grafana-example/main.tf` for a real world example. 


## `domain_name`

The domain name you wanto to expose your grafana dashboard. It must be pointing to the external address of the load-balencer. 

If unspecified, a name `grafana-xx.xx.xx.xx.nip.io` will be used, xx.xx.xx.xx is the external address of the load-balencer.
