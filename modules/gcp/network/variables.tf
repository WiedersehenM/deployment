variable "app_name" {
  type = string
}

variable "region" {
  type = string
}

variable "network_name" {
  type = string
}

variable "subnet_name" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "pods_secondary_range" {
  type = string
}

variable "services_secondary_range" {
  type = string
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = []
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = []
}

variable "enable_private_google_access" {
  type    = bool
  default = true
}

variable "create_nat" {
  type    = bool
  default = true
}

variable "allow_ssh" {
  type    = bool
  default = false
}

variable "gke_node_tags" {
  type    = list(string)
  default = []
}

variable "health_check_source_ranges" {
  type    = list(string)
  default = ["130.211.0.0/22", "35.191.0.0/16"]
}

variable "health_check_ports" {
  type    = list(string)
  default = ["80", "443"]
}
