resource "google_compute_network" "odoo" {
  name                    = "odoo-final-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false

  depends_on = [
    google_project_service.required["compute.googleapis.com"]
  ]
}

resource "google_compute_subnetwork" "gke" {
  name                     = "odoo-final-gke-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.odoo.id
  ip_cidr_range            = "10.10.0.0/20"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.30.0.0/20"
  }
}