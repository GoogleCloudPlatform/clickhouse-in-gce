variable "project_id" {
  type        = string
  description = "the Google Cloud project id to use"
}

variable "cluster_size" {
  type        = number
  description = "number of nodes in clickhouse cluster"
  default     = 4
}

variable "region" {
  type        = string
  description = "the Google Cloud region to provision resources in"
  default     = "us-central1"
}

variable "cluster_network" {
  type        = string
  description = "the network to attach resources to"
  default     = "default"
}

variable "cluster_subnetwork" {
  type        = string
  description = "the subnetwork to attach resources to"
  default     = "default"
}

variable "zone" {
  type        = string
  description = "the Google Cloud zone to provision zonal resources in"
  default     = "us-central1-a"
}

variable "data_disktype" {
  type        = string
  description = "the data disk used in clickhouse cluster"
  default     = "pd-ssd"
}

variable "data_disksize" {
  type        = number
  description = "size of the data disk, in GB"
  default     = 2500
}

variable "cluster_machine_type" {
  type        = string
  description = "the machine type in clickhouse cluster"
  default     = "n2-standard-16"
}


