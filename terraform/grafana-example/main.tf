
module "grafana_clickhouse" {
  source = "../grafana-gce"
  project_id = var.project_id
  region     = var.region
  zone       = var.zone
  network    = var.network
  subnetwork = var.subnetwork
  oauth_support_email = var.oauth_support_email
  grafana_role_config = var.grafana_role_config
  service_account = var.service_account
  grafana-datasource-install = <<-EOT
  #!/bin/bash
  /usr/share/grafana/bin/grafana-cli plugins install grafana-clickhouse-datasource

  cat <<EOF |tee /etc/grafana/provisioning/datasources/clickhouse.yaml
  apiVersion: 1
  datasources:
    - name: ClickHouse
      type: grafana-clickhouse-datasource
      jsonData:
        defaultDatabase: default
        port: 9000
        server: ${var.clickhouse_lb_ip}
        username: default
        tlsSkipVerify: false
      secureJsonData:
        password: $(gcloud secrets versions access --secret=ch-default-pass-fb6fa0fb3c91 latest)
  EOF
  systemctl restart grafana-server  
  EOT
}
