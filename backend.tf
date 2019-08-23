### BACKEND ###

/*terraform {
  backend "s3" {
    bucket         = "rust-fragtopia-us-west-2-389684724582-terraform"
    encrypt        = true
    key            = "rust-server.tfstate"
    region         = "us-west-2"
    dynamodb_table = "rust-fragtopia-locktable"
  }
}*/

terraform {
  backend "s3" {
    bucket         = "${var.backend_bucket_name}"
    key            = "${var.tf_state_key}"
    region         = "${var.availability_zone}"
    dynamodb_table = "${var.backend_table_name}"
  }
}
