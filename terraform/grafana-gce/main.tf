resource "google_compute_instance" "grafana" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = var.boot_disk_size
    }
  }
  tags = ["grafana"]
  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = var.service_account
    scopes = ["cloud-platform"]
  }
  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
  }
  metadata = {
    grafana-datasource-install = var.grafana-datasource-install
    grafana-envoy-config       = file("${path.module}/envoy/config-orig.yaml")
    grafana-envoy-lua-script   = file("${path.module}/envoy/rolesetting.lua")
    grafana-envoy-install      = file("${path.module}/envoy/install-envoy.sh")
    grafana-envoy-update-py    = file("${path.module}/envoy/update-envoy-config.py")
    grafana-role-config        = jsonencode(var.grafana_role_config)
  }
  metadata_startup_script = <<-EOT
  #!/bin/bash
  if [ -e /root/grafana_initialized ]
  then
    exit 0
  fi 
  apt-get update
  apt-get install -y apt-transport-https
  apt-get install -y software-properties-common wget
  wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
  echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
  apt-get update
  apt-get install -y grafana
  /bin/systemctl daemon-reload
  /bin/systemctl enable grafana-server
  /bin/systemctl start grafana-server

  cat <<EOF > /etc/grafana/grafana.ini
  [server]
  http_addr = 127.0.0.1
  domain = x-x-x-x.nip.io
  root_url = https://\$(domain)s/
  [security]
  disable_initial_admin_creation = true
  [auth]
  disable_login_form = true
  disable_signout_menu = true
  [auth.proxy]
  enabled = true
  header_name = X-User-Email
  header_property = email
  auto_sign_up = true
  headers = Email:X-User-Email, Role:X-User-Role
  EOF
  
  curl -o /root/grafana-datasource-install.sh "http://metadata.google.internal/computeMetadata/v1/instance/attributes/grafana-datasource-install" -H "Metadata-Flavor: Google"
  curl -o /root/envoy-lua-script "http://metadata.google.internal/computeMetadata/v1/instance/attributes/grafana-envoy-lua-script" -H "Metadata-Flavor: Google"
  curl -o /root/grafana-envoy-install.sh "http://metadata.google.internal/computeMetadata/v1/instance/attributes/grafana-envoy-install" -H "Metadata-Flavor: Google"
  curl -o /root/grafana-update-envoy-config.py "http://metadata.google.internal/computeMetadata/v1/instance/attributes/grafana-envoy-update-py" -H "Metadata-Flavor: Google"
  bash /root/grafana-datasource-install.sh
  bash /root/grafana-envoy-install.sh
  touch /root/grafana_initialized
  EOT

}

resource "google_compute_instance_group" "grafana" {
  project   = var.project_id
  name      = "grafana-instance-group"
  zone      = var.zone
  instances = [google_compute_instance.grafana.self_link]

  named_port {
    name = "http"
    port = "8080"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_global_address" "grafana_ext_address" {
  count = var.ext_address == null ? 1 : 0
  name = "grafana-ext-address"
}

module "http-lb" {
  source      = "GoogleCloudPlatform/lb-http/google"
  version     = "> 4.20"
  project     = var.project_id
  name        = "grafana-http-lb"
  target_tags = ["grafana"]
  address     = var.ext_address == null ? google_compute_global_address.grafana_ext_address[0].address : var.ext_address
  create_address = false
  ssl                             = true
  managed_ssl_certificate_domains = [var.domain_name == null ? "grafana-${google_compute_global_address.grafana_ext_address[0].address}.nip.io" : var.domain_name]

  backends = {
    default = {
      description                     = null
      protocol                        = "HTTP"
      port                            = "8080"
      port_name                       = "http"
      timeout_sec                     = 10
      enable_cdn                      = false
      custom_request_headers          = null
      custom_response_headers         = null
      security_policy                 = null

      connection_draining_timeout_sec = null
      session_affinity                = null
      affinity_cookie_ttl_sec         = null      
      health_check = {
        request_path        = "/healthz"
	port                = 8080
	check_interval_sec  = 3
        timeout_sec         = 1
        healthy_threshold   = 3
        unhealthy_threshold = 5
        host                = ""
        logging             = null
      }

      log_config = {
        enable = true
        sample_rate = 1.0
      }

      groups = [
        {
	  group                        = google_compute_instance_group.grafana.self_link
	  balancing_mode               = null
          capacity_scaler              = null
          description                  = null
          max_connections              = null
          max_connections_per_instance = null
          max_connections_per_endpoint = null
          max_rate                     = null
          max_rate_per_instance        = null
          max_rate_per_endpoint        = null
          max_utilization              = null
        },
      ]

      iap_config = {
        enable               = true
        oauth2_client_id     = google_iap_client.project_client.client_id
        oauth2_client_secret = google_iap_client.project_client.secret
      }
    }
  }

}

data "google_project" "project" {
  project_id = var.project_id
}

module "setup_oauth_branding" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 2.0"

  platform = "linux"
  additional_components = ["kubectl", "beta"]

  create_cmd_entrypoint  = "/bin/sh"
  create_cmd_body        = join(" ", [ "-c",<<-EOT
  "#!/bin/sh
  gcloud --project=${var.project_id} iap oauth-brands create --application_title='${var.oauth_title}' --support_email='${var.oauth_support_email}'"
  true
  EOT
  ]
    )

}

resource "google_iap_client" "project_client" {
  display_name = "LB Client"
  brand        = "projects/${data.google_project.project.number}/brands/${data.google_project.project.number}"
  depends_on = [module.setup_oauth_branding]
}



module "pass_backend_id" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 2.0"

  platform = "linux"
  additional_components = ["kubectl", "beta"]

  create_cmd_entrypoint  = "/bin/sh"
  create_cmd_body        = join(" ", [ "-c",<<-EOT
  "#!/bin/sh
  gcloud --project=${var.project_id} compute backend-services describe ${module.http-lb.backend_services.default.id} --format='value(id)' | gcloud --project=${var.project_id} compute instances add-metadata ${var.name} --zone ${var.zone} --metadata-from-file=backend-numeric-id=/dev/stdin"
  EOT
  ]
    )
  module_depends_on = [module.http-lb.backend_services.default]
}

resource "google_iap_web_backend_service_iam_member" "member" {
  for_each = can(var.grafana_role_config.rolebindings) ? var.grafana_role_config.rolebindings : {}
  project = var.project_id
  web_backend_service = module.http-lb.backend_services.default.name
  role = "roles/iap.httpsResourceAccessor"
  member = "user:${each.key}"
}
