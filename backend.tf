### BACKEND ###

terraform {
  backend "s3" {
    bucket         = "${var.backend_bucket_name}"
    key            = "rust-server.tfstate"
    region         = "${var.availability_zone}"
    dynamodb_table = "${var.backend_table_name}"
  }
}
