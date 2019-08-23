terraform {
  required_version = ">= 0.10.3"
}

provider "aws" {
  region = var.region
}

