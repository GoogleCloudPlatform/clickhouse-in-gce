variable "project_id" {
  type        = string
  description = "the Google Cloud project id to use"
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

variable "service_account" {
  type        = string
  description = "the service account used to run the instance"
}

variable "machine_type" {
  type = string
  description = "the machine type"
  default = "e2-standard-4"
}

variable "boot_disk_size" {
  type = number
  description = "size of the book disk, in GB"
  default = 200
}

variable "oauth_title" {
  type = string
  description = "the titile used in creating oauth branding"
  default = "Used for IAP"
}

variable "ext_address" {
  type        = string
  description = "the external ip address for the load balancer"
  default     = null

}
variable "domain_name" {
  type        = string
  description = "the domain name used to access grafana, must point to the external address"
  default     = null
}

variable "name" {
  type        = string
  description  = "instance name"
  default     = "grafana"
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


variable "grafana-datasource-install" {
  type        = string
  description = "the script to be called during instance startup to install datasource for grafana"
  default     = <<-EOT
  #!/bin/bash
  exit 0
  EOT
}
