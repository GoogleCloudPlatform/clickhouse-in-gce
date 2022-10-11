# quick start

Create a `terraform.tfvars` file with the following contents:

```
project_id = "your-project-id"
grafana_role_config = {rolebindings = {
                                       "youremail@example.com"  = "Admin"}}
oauth_support_email = "youremail@example.com"

```

run `terraform apply`.
