variable "project_id" {
  type        = string
  description = "The ID of the Google Cloud project"
}

variable "region" {
  type        = string
  description = "The region to deploy resources in"
}

variable "bucket_name" {
  type        = string
  description = "Name of the Cloud Storage bucket"
}

variable "service_account_name" {
  type        = string
  description = "Name of the Cloud Service Account"
}

variable "spanner_instance_name" {
  type        = string
  description = "Name of the Spanner instance"
}

variable "spanner_database_name" {
  type        = string
  description = "Name of the Spanner database"
}

variable "cloud_run_service_name" {
  type        = string
  description = "Name of the Cloud Run service"
}

variable "cloud_run_image_name" {
  type        = string
  description = "The URL to the container image for the Cloud Run App"
}
