# Configure the Google Cloud provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable Cloud Run API
resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# Enable Eventarc API
resource "google_project_service" "eventarc" {
  service            = "eventarc.googleapis.com"
  disable_on_destroy = false
}

# Enable Pub/Sub API
resource "google_project_service" "pubsub" {
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

# --- Cloud Storage Bucket ---

resource "random_id" "bucket_name_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "default" {
  name                        = "${var.bucket_name}-${random_id.bucket_name_suffix.hex}"
  location                    = var.region
  force_destroy               = true  # Allows deletion even if non-empty
  uniform_bucket_level_access = true # Enforce uniform bucket-level access
  project                     = var.project_id

}

# --- Cloud Service Account ---

resource "google_service_account" "default" {
  account_id   = var.service_account_name
  display_name = "Service Account for Cloud Run and Spanner Access"
  project      = var.project_id
}

# Grant Spanner Database User role to the service account
resource "google_spanner_database_iam_member" "spanner_user" {
  project    = var.project_id
  instance   = google_spanner_instance.default.name
  database   = google_spanner_database.default.name
  role       = "roles/spanner.databaseUser"
  member     = "serviceAccount:${google_service_account.default.email}"
}

resource "google_spanner_database_iam_member" "spanner_reader" {
  project    = var.project_id
  instance   = google_spanner_instance.default.name
  database   = google_spanner_database.default.name
  role    = "roles/spanner.databaseReader"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "storage_reader" {
  project    = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "metric_writer" {
  project    = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.default.email}"
}
# --- Spanner Instance and Database ---

resource "google_spanner_instance" "default" {
  config       = "regional-${var.region}"
  display_name = var.spanner_instance_name
  name         = var.spanner_instance_name
  project      = var.project_id
  num_nodes = 1
}

resource "google_spanner_database" "default" {
  instance = google_spanner_instance.default.name
  name     = var.spanner_database_name
  project  = var.project_id

  ddl = [
    <<-EOT
    CREATE TABLE Products (
      Id     STRING(MAX) NOT NULL,
      Name   STRING(MAX),
      Quantity INT64,
    ) PRIMARY KEY(Id)
    EOT
  ]
  deletion_protection=false
}

# --- Cloud Run Service ---
resource "google_cloud_run_v2_service" "default" {
  name     = var.cloud_run_service_name
  location = var.region
  project  = var.project_id

  template {
    containers {
      name = "app"
      image = var.cloud_run_image_name
      # Add environment variables if needed for your application.
       env {
         name  = "DB_INSTANCE"
         value = google_spanner_instance.default.name
       }
       env {
        name = "DB_NAME"
        value = google_spanner_database.default.name
       }
       env {
         name = "PROJECT_ID"
         value = var.project_id
       }

    }

    containers {
        name = "collector"
        depends_on = [ "app" ]
        image = "us-docker.pkg.dev/cloud-ops-agents-artifacts/cloud-run-gmp-sidecar/cloud-run-gmp-sidecar:1.2.0"
    }
    service_account = google_service_account.default.email
  }

   traffic {
    type = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST" # Always use latest revision
    percent = 100
  }
  deletion_protection=false
}

# # Allow unauthenticated invocations (for the trigger) - IMPORTANT: Consider security implications!
# resource "google_cloud_run_service_iam_member" "invoker" {
#   service  = google_cloud_run_v2_service.default.name
#   location = google_cloud_run_v2_service.default.location
#   role     = "roles/run.invoker"
#   member   = "allUsers"  #  Make the service publicly accessible via trigger.
#   project  = var.project_id
# }

# --- Cloud Storage Trigger (Eventarc) ---

# Used to retrieve project information later
data "google_project" "project" {}

# Create a dedicated service account
resource "google_service_account" "eventarc" {
  account_id   = "eventarc-trigger-sa"
  display_name = "Eventarc Trigger Service Account"
}

# Grant permission to receive Eventarc events
resource "google_project_iam_member" "eventreceiver" {
  project = data.google_project.project.id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.eventarc.email}"
}

# Grant permission to invoke Cloud Run services
resource "google_project_iam_member" "runinvoker" {
  project = data.google_project.project.id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.eventarc.email}"
}

data "google_storage_project_service_account" "gcs_account" {}
resource "google_project_iam_member" "pubsubpublisher" {
  project = data.google_project.project.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

resource "google_eventarc_trigger" "default" {
  name     = "cloud-storage-trigger"
  location = var.region #  Eventarc trigger must be in the same region as the Cloud Run service.
  project  = var.project_id

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.default.name
  }

  transport {
      pubsub {} # Required for eventarc triggers
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.default.name
      path    = "/"  #  Optional: Path to invoke on the Cloud Run service.
      region  = var.region
    }
  }

  service_account = google_service_account.eventarc.email
  depends_on = [
    google_project_service.eventarc,
    google_project_iam_member.pubsubpublisher
  ]

}


# --- Outputs ---

output "bucket_url" {
  value = "gs://${google_storage_bucket.default.name}"
}

output "cloud_run_service_url" {
  value = google_cloud_run_v2_service.default.uri
}

output "spanner_instance_id" {
 value = google_spanner_instance.default.id
}

output "spanner_database_id" {
    value = "${google_spanner_instance.default.id}/databases/${google_spanner_database.default.name}"
}
output "service_account_email" {
  value = google_service_account.default.email
}