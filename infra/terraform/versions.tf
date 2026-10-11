terraform {
  required_version = ">= 1.16, < 2.0"

  # Bucket independiente y versionado. No se destruye junto al entorno para
  # conservar historial y permitir reconstruir la infraestructura después.
  backend "gcs" {
    bucket = "pec3-odoo-cloud-jca26-tfstate"
    prefix = "odoo-cloud"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.2"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
