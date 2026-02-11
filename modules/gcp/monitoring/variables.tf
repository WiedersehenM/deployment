variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "app_name" {
  type        = string
  description = "The name of the application, used as a prefix for all resources"
}

variable "enable_logging" {
  type        = bool
  default     = true
  description = "Enable Cloud Logging for GKE"
}

variable "enable_monitoring" {
  type        = bool
  default     = true
  description = "Enable Cloud Monitoring for GKE"
}

variable "enable_alerts" {
  type        = bool
  default     = false
  description = "Enable example alert policies"
}

variable "alert_notification_channels" {
  type        = list(string)
  default     = []
  description = "List of notification channel IDs for alerts"
}

variable "log_sink_name" {
  type        = string
  default     = ""
  description = "Optional log sink name for exporting logs"
}

variable "log_sink_destination" {
  type        = string
  default     = ""
  description = "Optional log sink destination (e.g., bigquery.googleapis.com/projects/PROJECT_ID/datasets/DATASET_ID)"
}

