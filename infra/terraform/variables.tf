variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the regional GKE cluster."
  type        = string
  default     = "europe-southwest1"
}

variable "node_zones" {
  description = "Zones for the initial GKE node pool."
  type        = list(string)
  default = [
    "europe-southwest1-a",
    "europe-southwest1-b"
  ]
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  default     = "odoo-final-gke"
}

variable "uptime_hosts" {
  description = "Hosts públicos que se comprobarán desde Cloud Monitoring."
  type        = map(string)
  default = {
    cliente_a = "cliente-a.34.8.217.186.nip.io"
    cliente_b = "cliente-b.34.8.217.186.nip.io"
  }
}

variable "alert_notification_channel_ids" {
  description = "Canales de notificación de Cloud Monitoring, por ejemplo un email validado."
  type        = list(string)
  default     = []
}
