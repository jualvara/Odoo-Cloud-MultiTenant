resource "google_compute_global_address" "cloudsql_private_range" {
  name          = "odoo-cloudsql-private-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.odoo.id
}

resource "google_service_networking_connection" "cloudsql" {
  network = google_compute_network.odoo.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_global_address.cloudsql_private_range.name
  ]

  depends_on = [
    google_project_service.required["servicenetworking.googleapis.com"]
  ]
}

resource "google_sql_database_instance" "odoo" {
  name             = "odoo-postgres"
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_16"

  deletion_protection = false

  settings {
    edition           = "ENTERPRISE"
    tier              = "db-f1-micro"
    availability_type = "ZONAL"

    disk_type       = "PD_SSD"
    disk_size       = 10
    disk_autoresize = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      start_time                     = "10:00"

      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.odoo.id
    }
  }

  depends_on = [
    google_service_networking_connection.cloudsql,
    google_project_service.required["sqladmin.googleapis.com"]
  ]
}
