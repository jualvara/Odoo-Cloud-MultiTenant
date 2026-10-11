resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "odoo-gke-nodes"
  display_name = "Odoo GKE node service account"
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_cluster" "odoo" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  network    = google_compute_network.odoo.id
  subnetwork = google_compute_subnetwork.gke.id

  networking_mode = "VPC_NATIVE"
  node_locations  = var.node_zones

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false
  enable_shielded_nodes    = true

  release_channel {
    channel = "REGULAR"
  }

  addons_config {
    # Controlador gestionado para volúmenes NFS ReadWriteMany de Filestore.
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Permite que los pods lean secretos de Secret Manager sin copiarlos
  # a manifiestos ni variables de entorno de Kubernetes.
  secret_manager_config {
    enabled = true
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  depends_on = [
    google_project_service.required["container.googleapis.com"]
  ]
}

resource "google_container_node_pool" "odoo" {
  name           = "odoo-primary-pool"
  project        = var.project_id
  location       = var.region
  cluster        = google_container_cluster.odoo.name
  node_locations = var.node_zones

  # Una máquina en cada zona: dos nodos iniciales.
  node_count = 1

  autoscaling {
    min_node_count = 1
    # Hasta tres nodos por zona para que el HPA pueda alojar cuatro réplicas
    # de Odoo sin quedar bloqueado por falta de capacidad.
    max_node_count = 3
  }

  # El autoscaler ajusta este valor en tiempo real; Terraform solo define sus
  # límites y no debe intentar devolver los nodos al valor inicial.
  lifecycle {
    ignore_changes = [node_count]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = "e2-medium"
    disk_type       = "pd-balanced"
    disk_size_gb    = 50
    service_account = google_service_account.gke_nodes.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      workload = "odoo"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [
    google_project_iam_member.gke_nodes
  ]
}
