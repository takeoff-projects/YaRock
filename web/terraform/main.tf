terraform {
  required_version = ">= 0.14"

  required_providers {
    google = ">= 3.3"
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

locals {
  location = "us_central"

  service_name   = "pets"

  deployment_name = "YaRock-pets"
  service-account  = "serviceAccount:${google_service_account.service-account-2.email}"
}

# Enables the Identity and Access Management (IAM) API
resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

# Create a service account
resource "google_service_account" "service-account-2" {
  account_id   = "service-account-2"
  display_name = "YaRock-pets Service Account"
}

# Create new SA key
resource "google_service_account_key" "sa_key" {
  service_account_id = google_service_account.service-account-2.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Set permissions
resource "google_project_iam_binding" "service_permissions" {
  for_each = toset([
    "run.invoker", "datastore.owner","appengine.appAdmin"
  ])

  role       = "roles/${each.key}"
  members    = [local.service-account]
  depends_on = [google_service_account.service-account-2]
}

# Enables the Datastore
resource "google_project_service" "datastore" {
  service = "datastore.googleapis.com"
  disable_on_destroy = false
}

# resource "google_project_service" "enable_firestore" {
#   provider = google
#   project = var.project
#   service = "firestore.googleapis.com"

#   disable_on_destroy = false
# }

# resource "google_datastore_index" "pets-db-1" {
#   kind = "pets-db-1"
#   properties {
#     name = "added"
#     direction = "ASCENDING"
#   }

#   properties {
#     name = "caption"
#     direction = "ASCENDING"
#   }
#   depends_on = [google_project_service.enable_firestore]
# }

# # configure Datastore
# resource "google_app_engine_application" "pets-db-1" {
#   provider      = google
#   location_id   = "us-central"
#   database_type = "CLOUD_DATASTORE_COMPATIBILITY"
# }

# Enables the Cloud Build
resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Enables the Cloud Run
resource "google_project_service" "run" {
  service = "run.googleapis.com"
  disable_on_destroy = false
}

# Enables the Cloud Run API
resource "google_project_service" "run_api" {
  service = "run.googleapis.com"

  disable_on_destroy = false
}

data "google_container_registry_image" "image" {
  name = local.service_name
  tag = var._version
}

# The Cloud Run service
resource "google_cloud_run_service" "service" {
  name                       = local.service_name
  location                   = var.region

  template {
    spec {
      service_account_name = google_service_account.service-account-2.email

      containers {
        image = data.google_container_registry_image.image.image_url
        env {
          name = "GOOGLE_CLOUD_PROJECT"
          value = var.project
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.run]
}

# No auth
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

# Set no auth policy
resource "google_cloud_run_service_iam_policy" "noauth_policy" {
  location    = google_cloud_run_service.service.location
  project     = google_cloud_run_service.service.project
  service     = google_cloud_run_service.service.name

  policy_data = data.google_iam_policy.noauth.policy_data
  depends_on  = [google_cloud_run_service.service]
}
