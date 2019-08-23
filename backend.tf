### BACKEND ###

terraform {
  backend "s3" {
    bucket         = "$${var.backend_bucket_name}"
    key            = "$${var.tf_state_key}"
    region         = "$${var.region}"
    dynamodb_table = "$${var.backend_table_name}"
  }
}

