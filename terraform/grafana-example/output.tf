output "grafana_url" {
  description = "url to access grafana"
  value = module.grafana_clickhouse.grafana_url
}
