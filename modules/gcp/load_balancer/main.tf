variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "backend_service_name" {
  type        = string
  description = "Cloud Run service name for backend (mono)"
}

variable "ui_service_name" {
  type        = string
  description = "Cloud Run service name for UI (Next.js)"
  default     = ""
}

variable "lb_domain" {
  type        = string
  description = "Domain name for the load balancer"
}

variable "api_path_prefixes" {
  type        = list(string)
  description = "Path prefixes to route to backend"
  default     = ["/api/v1", "/info/lfs"]
}

resource "google_compute_region_network_endpoint_group" "backend" {
  project               = var.project_id
  region                = var.region
  name                  = "${var.name_prefix}-backend-neg"
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.backend_service_name
  }
}

resource "google_compute_region_network_endpoint_group" "ui" {
  count                 = var.ui_service_name != "" ? 1 : 0
  project               = var.project_id
  region                = var.region
  name                  = "${var.name_prefix}-ui-neg"
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.ui_service_name
  }
}

resource "google_compute_backend_service" "backend" {
  project               = var.project_id
  name                  = "${var.name_prefix}-backend-bs"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.backend.id
  }
}

resource "google_compute_backend_service" "ui" {
  count                 = var.ui_service_name != "" ? 1 : 0
  project               = var.project_id
  name                  = "${var.name_prefix}-ui-bs"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.ui[0].id
  }
}

resource "google_compute_url_map" "this" {
  project = var.project_id
  name    = "${var.name_prefix}-urlmap"

  default_service = var.ui_service_name != "" ? google_compute_backend_service.ui[0].self_link : google_compute_backend_service.backend.self_link

  host_rule {
    hosts        = [var.lb_domain]
    path_matcher = "pm-default"
  }

  path_matcher {
    name            = "pm-default"
    default_service = var.ui_service_name != "" ? google_compute_backend_service.ui[0].self_link : google_compute_backend_service.backend.self_link

    dynamic "path_rule" {
      for_each = var.api_path_prefixes
      content {
        paths   = ["${path_rule.value}/*"]
        service = google_compute_backend_service.backend.self_link
      }
    }
  }
}

resource "google_compute_global_address" "this" {
  project = var.project_id
  name    = "${var.name_prefix}-lb-ip"
}

resource "google_compute_target_https_proxy" "this" {
  project          = var.project_id
  name             = "${var.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.this.id
  certificate_map  = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.this.id}"
}

resource "google_compute_global_forwarding_rule" "https" {
  project               = var.project_id
  name                  = "${var.name_prefix}-https-fr"
  target                = google_compute_target_https_proxy.this.id
  port_range            = "443"
  ip_address            = google_compute_global_address.this.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_certificate_manager_dns_authorization" "this" {
  project     = var.project_id
  name        = "${var.name_prefix}-dns-auth"
  domain      = var.lb_domain
  description = "DNS authorization for ${var.lb_domain}"
}

resource "google_certificate_manager_certificate" "this" {
  project     = var.project_id
  name        = "${var.name_prefix}-cert"
  description = "Google-managed cert for ${var.lb_domain}"
  scope       = "DEFAULT"
  managed {
    domains = [var.lb_domain]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.this.id
    ]
  }
}

resource "google_certificate_manager_certificate_map" "this" {
  project     = var.project_id
  name        = "${var.name_prefix}-cert-map"
  description = "Certificate map for ${var.lb_domain}"
}

resource "google_certificate_manager_certificate_map_entry" "this" {
  project      = var.project_id
  name         = "${var.name_prefix}-cert-map-entry"
  map          = google_certificate_manager_certificate_map.this.name
  certificates = [google_certificate_manager_certificate.this.id]
  hostname     = var.lb_domain
}

# --- Outputs ---

output "lb_ip" {
  value = google_compute_global_address.this.address
}

output "dns_authorization_record_name" {
  description = "DNS CNAME record name for cert verification"
  value       = google_certificate_manager_dns_authorization.this.dns_resource_record[0].name
}

output "dns_authorization_record_value" {
  description = "DNS CNAME record value for cert verification"
  value       = google_certificate_manager_dns_authorization.this.dns_resource_record[0].data
}

output "dns_authorization_record_type" {
  description = "DNS record type for cert verification"
  value       = google_certificate_manager_dns_authorization.this.dns_resource_record[0].type
}

output "backend_backend_service_self_link" {
  value = google_compute_backend_service.backend.self_link
}

output "ui_backend_service_self_link" {
  value = var.ui_service_name != "" ? google_compute_backend_service.ui[0].self_link : null
}

output "url_map_self_link" {
  value = google_compute_url_map.this.self_link
}
