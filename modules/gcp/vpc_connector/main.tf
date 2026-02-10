variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "network" {
  type = string
}

variable "ip_cidr_range" {
  type    = string
  default = null
}

resource "google_vpc_access_connector" "this" {
  name          = var.name
  region        = var.region
  network       = var.network
  ip_cidr_range = var.ip_cidr_range

  # Required by the API: throughput must be a multiple of 100 between 200 and 1000 Mbps.
  min_throughput = 200
  max_throughput = 300
}

output "id" {
  value = google_vpc_access_connector.this.id
}

output "name" {
  value = google_vpc_access_connector.this.name
}

