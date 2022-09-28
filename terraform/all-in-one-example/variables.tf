variable "project_name" {
  description = "The project name for the associated services"
}

variable "organization_id" {
  description = "The organization id for the associated services"
}

variable "billing_account" {
  description = "The ID of the billing account to associate this project with"
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
