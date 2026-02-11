locals {
  enable_build_env = var.enable_build_env
  enable_gcs       = var.enable_gcs
  enable_cloud_sql = var.enable_cloud_sql
  enable_redis     = var.enable_redis
  enable_filestore = var.enable_filestore
  enable_apps      = var.enable_apps

  enable_private_networking = var.enable_private_networking
  
  # Strictly use app_name for resource naming (Convention over Configuration)
  network_name             = "${var.app_name}-vpc"
  subnet_name              = "${var.app_name}-subnet"
  artifact_registry_repo   = var.artifact_registry_repo != "" ? var.artifact_registry_repo : "${var.app_name}-repo"
  gcs_bucket               = "${var.app_name}-storage"
  cloud_sql_instance_name  = var.cloud_sql_instance_name != "" ? var.cloud_sql_instance_name : "${var.app_name}-db"
  redis_instance_name      = var.redis_instance_name != "" ? var.redis_instance_name : "${var.app_name}-redis"
  filestore_instance_name  = var.filestore_instance_name != "" ? var.filestore_instance_name : "${var.app_name}-fs"
  app_service_name         = "${var.app_name}-backend"
  ui_service_name          = "${var.app_name}-ui"
  orion_service_name       = "${var.app_name}-orion"
  campsite_service_name    = "${var.app_name}-campsite"
  vpc_connector_name       = "${var.app_name}-cr-conn"

  enable_lb = var.enable_lb

  lb_routing_plan = {
    domain = var.base_domain
    default_backend = "ui"
    backends = {
      backend = {
        cloud_run_service = local.app_service_name
        region            = var.region
      }
      ui = {
        cloud_run_service = local.ui_service_name
        region            = var.region
      }
      orion = {
        cloud_run_service = local.orion_service_name
        region            = var.region
      }
      campsite = {
        cloud_run_service = local.campsite_service_name
        region            = var.region
      }
    }
    path_routes = [
      for p in var.lb_api_path_prefixes : {
        path_prefix = p
        backend     = "backend"
      }
    ]
  }
}

# Artifact Registry module
module "artifact_registry" {
  count  = local.enable_build_env ? 1 : 0
  source = "../../../modules/gcp/artifact_registry"

  location  = var.artifact_registry_location
  repo_name = local.artifact_registry_repo
}

# Network module
module "network" {
  count  = local.enable_private_networking ? 1 : 0
  source = "../../../modules/gcp/network"

  app_name                 = var.app_name
  region                   = var.region
  network_name             = local.network_name
  subnet_name              = local.subnet_name
  subnet_cidr              = var.subnet_cidr
  pods_secondary_range     = var.pods_secondary_range
  services_secondary_range = var.services_secondary_range
}

# IAM module
module "iam" {
  source = "../../../modules/gcp/iam"

  project_id       = var.project_id
  app_name         = coalesce(var.app_suffix, var.app_name)
  service_accounts = var.iam_service_accounts
}

# Monitoring module
module "monitoring" {
  source = "../../../modules/gcp/monitoring"

  project_id                  = var.project_id
  app_name                    = var.app_name
  enable_logging              = var.enable_logging
  enable_monitoring           = var.enable_monitoring
  enable_alerts               = var.enable_alerts
  alert_notification_channels  = var.alert_notification_channels
  log_sink_name               = var.log_sink_name
  log_sink_destination        = var.log_sink_destination
}

# GCS module
module "gcs" {
  count  = local.enable_gcs ? 1 : 0
  source = "../../../modules/gcp/gcs"

  name                     = local.gcs_bucket
  location                 = var.region
  force_destroy            = var.gcs_force_destroy
  uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
}

# Cloud SQL module
module "cloud_sql" {
  count  = local.enable_cloud_sql ? 1 : 0
  source = "../../../modules/gcp/cloud_sql"

  name                     = local.cloud_sql_instance_name
  database_version         = var.cloud_sql_database_version
  region                   = var.region
  tier                     = var.cloud_sql_tier
  disk_size                = var.cloud_sql_disk_size
  disk_type                = var.cloud_sql_disk_type
  availability_type        = var.cloud_sql_availability_type
  private_network          = local.enable_private_networking ? module.network[0].network_self_link : ""
  private_ip_prefix_length = var.cloud_sql_private_ip_prefix_length
  enable_private_service_connection = var.cloud_sql_enable_private_service_connection
  enable_public_ip         = var.cloud_sql_enable_public_ip
  db_name                  = var.cloud_sql_db_name
  db_username              = var.db_username
  db_password              = var.db_password
  backup_enabled           = var.cloud_sql_backup_enabled
  deletion_protection      = var.cloud_sql_deletion_protection
}

# Redis module
module "redis" {
  count  = local.enable_redis ? 1 : 0
  source = "../../../modules/gcp/redis"

  name                    = local.redis_instance_name
  region                  = var.region
  tier                    = var.redis_tier
  memory_size_gb          = var.redis_memory_size_gb
  network                 = local.enable_private_networking ? module.network[0].network_self_link : ""
  transit_encryption_mode = var.redis_transit_encryption_mode
}

# Filestore module
module "filestore" {
  count  = local.enable_filestore ? 1 : 0
  source = "../../../modules/gcp/filestore"

  name           = local.filestore_instance_name
  location       = var.zone != "" ? var.zone : "${var.region}-b"
  network        = local.enable_private_networking ? module.network[0].network_id : ""
  tier           = var.filestore_tier
  capacity_gb    = var.filestore_capacity_gb
  file_share_name = var.filestore_file_share_name
  reserved_ip_range = var.filestore_reserved_ip_range
}

# Serverless VPC Access Connector
module "vpc_connector" {
  count  = local.enable_private_networking ? 1 : 0
  source = "../../../modules/gcp/vpc_connector"

  name          = local.vpc_connector_name
  region        = var.region
  network       = module.network[0].network_self_link
  ip_cidr_range = var.vpc_connector_cidr
}

# Cloud Run: Backend
module "app_cloud_run" {
  count        = local.enable_apps ? 1 : 0
  source       = "../../../modules/gcp/cloud_run"

  project_id   = var.project_id
  region       = var.region
  service_name = local.app_service_name
  image        = var.app_image
  env_vars     = var.app_env

  cpu            = var.app_cpu
  memory         = var.app_memory
  min_instances  = var.app_min_instances
  max_instances  = var.app_max_instances
  allow_unauth   = var.app_allow_unauth
  container_port = 8000

  vpc_connector = local.enable_private_networking ? module.vpc_connector[0].name : null
  vpc_egress     = var.cloud_run_vpc_egress
}

# Cloud Run: UI
module "ui_cloud_run" {
  count        = local.enable_apps ? 1 : 0
  source       = "../../../modules/gcp/cloud_run"

  project_id   = var.project_id
  region       = var.region
  service_name = local.ui_service_name
  image        = var.ui_image
  env_vars     = var.ui_env_vars

  cpu            = var.ui_cpu
  memory         = var.ui_memory
  min_instances  = var.ui_min_instances
  max_instances  = var.ui_max_instances
  allow_unauth   = var.ui_allow_unauth
  container_port = 3000

  vpc_connector = local.enable_private_networking ? module.vpc_connector[0].name : null
  vpc_egress     = var.cloud_run_vpc_egress
}

# Cloud Run: Orion Server
module "orion_cloud_run" {
  count        = local.enable_apps && var.orion_image != "" ? 1 : 0
  source       = "../../../modules/gcp/cloud_run"

  project_id   = var.project_id
  region       = var.region
  service_name = local.orion_service_name
  image        = var.orion_image
  env_vars     = var.orion_env_vars

  cpu            = "1"
  memory         = "512Mi"
  min_instances  = 0
  max_instances  = 10
  allow_unauth   = true
  container_port = 8000

  vpc_connector = local.enable_private_networking ? module.vpc_connector[0].name : null
  vpc_egress     = var.cloud_run_vpc_egress
}

# Cloud Run: Campsite
module "campsite_cloud_run" {
  count        = local.enable_apps && var.campsite_image != "" ? 1 : 0
  source       = "../../../modules/gcp/cloud_run"

  project_id   = var.project_id
  region       = var.region
  service_name = local.campsite_service_name
  image        = var.campsite_image
  env_vars     = var.campsite_env_vars

  cpu            = "1"
  memory         = "512Mi"
  min_instances  = 0
  max_instances  = 10
  allow_unauth   = true
  container_port = 8000

  vpc_connector = local.enable_private_networking ? module.vpc_connector[0].name : null
  vpc_egress     = var.cloud_run_vpc_egress
}

# Load Balancer module
module "lb_backends" {
  count  = var.enable_lb ? 1 : 0
  source = "../../../modules/gcp/load_balancer"

  project_id            = var.project_id
  region                = var.region
  app_name              = var.app_name
  backend_service_name   = local.app_service_name
  ui_service_name        = local.ui_service_name
  lb_domain              = var.base_domain
  api_path_prefixes      = var.lb_api_path_prefixes
}

# Outputs
output "artifact_registry_repo" {
  value = local.enable_build_env ? module.artifact_registry[0].repository : null
}

output "gcs_bucket_name" {
  value = local.enable_gcs ? module.gcs[0].bucket_name : null
}

output "cloud_sql_db_endpoint" {
  value = local.enable_cloud_sql ? module.cloud_sql[0].db_endpoint : null
}

output "cloud_sql_connection_name" {
  value = local.enable_cloud_sql ? module.cloud_sql[0].connection_name : null
}

output "redis_host" {
  value = local.enable_redis ? module.redis[0].host : null
}

output "redis_port" {
  value = local.enable_redis ? module.redis[0].port : null
}

output "filestore_instance_name" {
  value = local.enable_filestore ? module.filestore[0].instance_name : null
}

output "filestore_file_share_name" {
  value = local.enable_filestore ? module.filestore[0].file_share_name : null
}

output "filestore_ip_address" {
  value = local.enable_filestore ? module.filestore[0].ip_address : null
}

output "app_cloud_run_url" {
  value = local.enable_apps ? module.app_cloud_run[0].url : null
}

output "ui_cloud_run_url" {
  value = local.enable_apps ? module.ui_cloud_run[0].url : null
}

output "orion_cloud_run_url" {
  value = local.enable_apps && var.orion_image != "" ? module.orion_cloud_run[0].url : null
}

output "campsite_cloud_run_url" {
  value = local.enable_apps && var.campsite_image != "" ? module.campsite_cloud_run[0].url : null
}

output "lb_backend_backend_service" {
  description = "Backend service self_link for backend (mono) in the external HTTPS LB"
  value       = var.enable_lb ? module.lb_backends[0].backend_backend_service_self_link : null
}

output "lb_ui_backend_service" {
  description = "Backend service self_link for UI (Next.js) in the external HTTPS LB"
  value       = var.enable_lb ? module.lb_backends[0].ui_backend_service_self_link : null
}

output "iam_service_accounts" {
  description = "Created service accounts with emails and names"
  value       = module.iam.service_accounts
}

output "iam_workload_identity_bindings" {
  description = "Workload Identity bindings (K8s SA -> GCP SA)"
  value       = module.iam.workload_identity_bindings
}

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "monitoring_logging_api_enabled" {
  description = "Whether Logging/Monitoring APIs are enabled"
  value       = module.monitoring.logging_api_enabled && module.monitoring.monitoring_api_enabled
}

# HTTPS Load Balancer & Routing Strategy (Milestone A)
output "lb_domain" {
  description = "The FQDN for the load balancer"
  value       = var.enable_lb ? local.lb_routing_plan.domain : null
}

output "lb_ip" {
  description = "The public Anycast IP address of the load balancer"
  value       = var.enable_lb ? module.lb_backends[0].lb_ip : null
}

output "dns_authorization_record_name" {
  description = "DNS CNAME record name for cert verification"
  value       = var.enable_lb ? module.lb_backends[0].dns_authorization_record_name : null
}

output "dns_authorization_record_value" {
  description = "DNS CNAME record value for cert verification"
  value       = var.enable_lb ? module.lb_backends[0].dns_authorization_record_value : null
}

output "lb_routing_plan" {
  description = "Detailed routing strategy for the load balancer"
  value       = var.enable_lb ? local.lb_routing_plan : null
}
