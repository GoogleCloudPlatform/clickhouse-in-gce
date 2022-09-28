output "project_id" {
  description = "the actual project id"
  value       = module.project-factory.project_id
}

output "service_account_email" {
  description = "the email of serviceAccount used to run the VMs"
  value       = module.clickhouse-cluster.service_account_email
}

output "load_balancer_ip_address" {
  description = "Internal IP address of the load balancer"
  value       = module.clickhouse-cluster.load_balancer_ip_address
}


output "grafana_url" {
  description = "url to access grafana"
  value = module.grafana-example.grafana_url
}
