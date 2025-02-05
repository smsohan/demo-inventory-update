variable "project_id" {
  type        = string
  description = "The ID of the Google Cloud project"
  default = "sohansm-project"
}

variable "region" {
  type        = string
  description = "The region to deploy resources in"
  default     = "us-central1"
}

resource "random_id" "bucket_name_suffix" {
  byte_length = 4
}

variable "bucket_name" {
  type        = string
  description = "Name of the Cloud Storage bucket"
  default     = "posts_db"
}

variable "service_account_name" {
  type        = string
  description = "Name of the Cloud Service Account"
  default     = "inventory-update-sa"
}

variable "spanner_instance_name" {
  type        = string
  description = "Name of the Spanner instance"
  default     = "inventory-instance"
}

variable "spanner_database_name" {
  type        = string
  description = "Name of the Spanner database"
  default     = "inventory"
}

variable "cloud_run_service_name" {
  type        = string
  description = "Name of the Cloud Run service"
  default     = "inventory-update-app"
}

variable "cloud_run_image_name" {
  type        = string
  default = "us-central1-docker.pkg.dev/sohansm-project/cloud-run-source-deploy/nodejs-inventory-update@sha256:61c64a7dc02e0abe1f63cf168c9af1b9aee77a7942430a31b4f923dae6413423"
}
