variable "project_id" {
  type        = string
  description = "the Google Cloud project id to use"
}

variable "service_account" {
  type = string
  description = "the service account email used to create the machine"
}

variable "clickhouse_lb_ip" {
  type = string
  description = "the loadbalancer ip serving the clickhouse cluster"
}


variable "oauth_support_email" {
  type = string
  description = "the support email used in creating oauth branding"
}


variable "grafana_role_config" {
  type = any
  description = "the role config"
  validation {
    condition = can(var.grafana_role_config.rolebindings) || can(var.grafana_role_config.accesslevel-policy)
    error_message = "The grafana_role_config must be a map and contains either rolebinding or accesslevel-policy"
  }
}
variable "region" {
  type        = string
  description = "the Google Cloud region to provision resources in"
  default     = "us-central1"
}

variable "network" {
  type        = string
  description = "the network to attach resources to"
  default     = "default"
}

variable "subnetwork" {
  type        = string
  description = "the subnetwork to attach resources to"
  default     = "default"
}

variable "zone" {
  type        = string
  description = "the Google Cloud zone to provision zonal resources in"
  default     = "us-central1-a"
}
