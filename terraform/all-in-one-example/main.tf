
module "project-factory" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 13.1"
  random_project_id       = true
  name                    = var.project_name
  org_id                  = var.organization_id
  billing_account         = var.billing_account
  default_service_account = "deprivilege"
  auto_create_network     = true
  activate_apis = ["compute.googleapis.com",
    "secretmanager.googleapis.com",
    "iap.googleapis.com"
  ]
}

module "cloud-nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  project_id = module.project-factory.project_id
  region     = var.region
  network = var.network
  create_router = true
  router     = "cloud-nat-router"
  depends_on = [module.project-factory]
}

module "clickhouse-cluster" {
  source = "../clickhouse"
  project_id = module.project-factory.project_id
  region = var.region
  cluster_machine_type = "n1-standard-1"
  data_disksize = 100

}

module "grafana-example" {
  source = "../grafana-example"
  project_id = module.project-factory.project_id
  region     = var.region
  zone       = var.zone
  network    = var.network
  subnetwork = var.subnetwork
  oauth_support_email = var.oauth_support_email
  grafana_role_config = var.grafana_role_config
  service_account = module.clickhouse-cluster.service_account_email
  clickhouse_lb_ip = module.clickhouse-cluster.load_balancer_ip_address

}
