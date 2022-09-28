output "grafana_url" {
  description = "url to access grafana"
  value = var.domain_name == null ? "https://grafana-${google_compute_global_address.grafana_ext_address[0].address}.nip.io" : "https://${var.domain_name}"
}
