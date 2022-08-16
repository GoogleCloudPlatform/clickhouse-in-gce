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


resource "google_service_account" "default" {
  account_id = "clickhouse-compute-cluster-sa"
}
resource "google_secret_manager_secret" "cluster_password" {
  ## this secret name is hard coded in the scripts, don't change
  secret_id = "ch-default-pass-fb6fa0fb3c91"
  replication {
    automatic = true
  }

}

module "gen_secret" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 2.0"

  platform = "linux"
  additional_components = ["kubectl", "beta"]

  create_cmd_entrypoint  = "/bin/sh"
  create_cmd_body        = join(" ", [ "-c",<<-EOT
  dd if=/dev/urandom count=1|shasum|cut -c 1-12|gcloud --project ${var.project_id} secrets versions add ${google_secret_manager_secret.cluster_password.secret_id} --data-file=-
  EOT
  ]
  )
}

resource "google_secret_manager_secret_iam_binding" "binding" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.cluster_password.secret_id
  role      = "roles/secretmanager.secretAccessor"

  members = [
    "serviceAccount:${google_service_account.default.email}"
  ]
  depends_on = [module.gen_secret]
}


resource "google_compute_disk" "clickhouse" {
  count                     = var.cluster_size
  name                      = "clickhouse-${count.index}-data"
  type                      = var.data_disktype
  zone                      = var.zone
  size                      = var.data_disksize
  physical_block_size_bytes = 4096
}

resource "google_compute_instance" "clickhouse" {
  count        = var.cluster_size
  name         = "clickhouse-${count.index}"
  machine_type = var.cluster_machine_type
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 200
    }
  }

  attached_disk {
    source      = google_compute_disk.clickhouse[count.index].self_link
    device_name = "disk-1"
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
  network_interface {
    network    = var.cluster_network
    subnetwork = var.cluster_subnetwork
  }
  metadata = {
    clickhouse-startup-script = file("../scripts/clickhouse-start-up-script.sh")
    clickhouse-config-cluster = file("../scripts/clickhouse-config-cluster.py")
    clickhouse-createtable    = file("../scripts/createtable.py")
    clickhouse-cluster-size   = "${var.cluster_size}"
  }
  metadata_startup_script = <<-EOT
  #!/bin/bash
  if [ -e /root/clickhouse-start-up-script.sh ]
  then
    exit 0
  fi
  curl -o /root/clickhouse-start-up-script.sh "http://metadata.google.internal/computeMetadata/v1/instance/attributes/clickhouse-startup-script" -H "Metadata-Flavor: Google"
  curl -o /root/clickhouse-config-cluster.py "http://metadata.google.internal/computeMetadata/v1/instance/attributes/clickhouse-config-cluster" -H "Metadata-Flavor: Google"
  curl -o /root/createtable.py "http://metadata.google.internal/computeMetadata/v1/instance/attributes/clickhouse-createtable" -H "Metadata-Flavor: Google"
  curl -o /root/cluster_size.txt "http://metadata.google.internal/computeMetadata/v1/instance/attributes/clickhouse-cluster-size" -H "Metadata-Flavor: Google"
  bash /root/clickhouse-start-up-script.sh /root/cluster_size.txt
  EOT

  depends_on = [google_secret_manager_secret.cluster_password, google_secret_manager_secret_iam_binding.binding, google_compute_instance.zookeeper]
}

resource "google_compute_instance" "zookeeper" {
  count        = 3
  name         = "zook-${count.index}"
  machine_type = "e2-standard-4"
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 200
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
  network_interface {
    network    = var.cluster_network
    subnetwork = var.cluster_subnetwork
  }
  metadata = {
    zookeeper-startup-script = file("../scripts/zk-install.sh")
    zookeeper-index          = "${count.index}"
  }
  metadata_startup_script = <<-EOT
  #!/bin/bash
  if [ -e /root/zk-install.sh ]
  then
    exit 0
  fi
  curl -o /root/zk-install.sh "http://metadata.google.internal/computeMetadata/v1/instance/attributes/zookeeper-startup-script" -H "Metadata-Flavor: Google"
  curl -o /root/zk-idx.txt "http://metadata.google.internal/computeMetadata/v1/instance/attributes/zookeeper-index" -H "Metadata-Flavor: Google"
  bash /root/zk-install.sh /root/zk-idx.txt
  EOT

}

resource "google_compute_instance_group" "clickhouse-cluster" {
  project   = var.project_id
  name      = "clickhouse-cluster-instance-group"
  zone      = var.zone
  instances = google_compute_instance.clickhouse[*].self_link

  lifecycle {
    create_before_destroy = true
  }
}

module "ilb" {
  source      = "GoogleCloudPlatform/lb-internal/google"
  version     = "~> 4.0"
  project     = var.project_id
  network     = var.cluster_network
  subnetwork  = var.cluster_subnetwork
  region      = var.region
  name        = "clickhouse-cluster"
  target_tags = ["clickhouse-cluster"]
  source_tags = ["clickhouse-cluster"]

  ports = ["9000"]
  backends = [
    {
      description = "Instance group for clickhouse cluster"
      group       = google_compute_instance_group.clickhouse-cluster.self_link
    },
  ]
  health_check = {
    type                = "tcp"
    check_interval_sec  = 1
    healthy_threshold   = 3
    timeout_sec         = 1
    unhealthy_threshold = 5
    proxy_header        = "NONE"
    port                = 9000
    port_name           = "health-check-port"
    enable_log          = false
    host                = ""
    request             = ""
    request_path        = ""
    response            = ""
  }
}

resource "google_compute_instance" "grafana" {
  name         = "clickhouse-grafana"
  machine_type = "e2-standard-4"
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 200
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
  network_interface {
    network    = var.cluster_network
    subnetwork = var.cluster_subnetwork
  }
  metadata = {
    grafana-startup-script = file("../scripts/grafana-install.sh")
    grafana-clickhouse-ilb = "${module.ilb.ip_address}"
  }
  metadata_startup_script = <<-EOT
  #!/bin/bash
  if [ -e /root/grafana-install.sh ]
  then
    exit 0
  fi
  curl -o /root/grafana-install.sh "http://metadata.google.internal/computeMetadata/v1/instance/attributes/grafana-startup-script" -H "Metadata-Flavor: Google"
  curl -o /root/ilb-address.txt "http://metadata.google.internal/computeMetadata/v1/instance/attributes/grafana-clickhouse-ilb" -H "Metadata-Flavor: Google"
  bash /root/grafana-install.sh /root/ilb-address.txt
  EOT

}
