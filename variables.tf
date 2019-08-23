variable "availability_zone" {
    type = "string"
    default = "us-west-2a"
}

variable "tf_state_key" {
    type = "string"
    default = "rust-server.tfstate"
}

variable "backend_bucket_name" {
    type = "string"
    default = "rust-fragtopia-us-west-2-389684724582-terraform"
}

variable "backend_table_name" {
    type = "string"
    default = "rust-fragtopia-locktable"
}
