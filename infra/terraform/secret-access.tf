# Identidad exclusiva para el trabajo puntual de inicialización de permisos.
# Solo puede leer la clave administrativa de Cloud SQL; no las claves de clientes.
resource "google_service_account" "db_bootstrap" {
  project      = var.project_id
  account_id   = "odoo-db-bootstrap"
  display_name = "Odoo Cloud SQL bootstrap"
}

resource "google_secret_manager_secret_iam_member" "db_bootstrap_admin_password" {
  project   = var.project_id
  secret_id = "odoo-postgres-admin-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.db_bootstrap.email}"

  depends_on = [
    google_project_service.required["secretmanager.googleapis.com"]
  ]
}

resource "google_service_account_iam_member" "db_bootstrap_workload_identity" {
  service_account_id = google_service_account.db_bootstrap.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[odoo-multitenant/db-bootstrap]"
}

# Cada entorno Odoo tiene una identidad distinta y únicamente puede leer
# sus dos secretos: la contraseña de su usuario PostgreSQL y su clave maestra.
locals {
  odoo_clients = {
    a = {
      account_id    = "odoo-cliente-a"
      display_name  = "Odoo Cliente A workload"
      ksa_name      = "odoo-cliente-a"
      db_secret     = "odoo-cliente-a-db-password"
      master_secret = "odoo-cliente-a-master-password"
    }
    b = {
      account_id    = "odoo-cliente-b"
      display_name  = "Odoo Cliente B workload"
      ksa_name      = "odoo-cliente-b"
      db_secret     = "odoo-cliente-b-db-password"
      master_secret = "odoo-cliente-b-master-password"
    }
  }
}

resource "google_service_account" "odoo_client" {
  for_each = local.odoo_clients

  project      = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
}

resource "google_secret_manager_secret_iam_member" "odoo_client_db_password" {
  for_each = local.odoo_clients

  project   = var.project_id
  secret_id = each.value.db_secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.odoo_client[each.key].email}"
}

resource "google_secret_manager_secret_iam_member" "odoo_client_master_password" {
  for_each = local.odoo_clients

  project   = var.project_id
  secret_id = each.value.master_secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.odoo_client[each.key].email}"
}

resource "google_service_account_iam_member" "odoo_client_workload_identity" {
  for_each = local.odoo_clients

  service_account_id = google_service_account.odoo_client[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[odoo-multitenant/${each.value.ksa_name}]"
}
