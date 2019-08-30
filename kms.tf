resource "aws_kms_key" "rust_server" {
  description             = "Rust KMS Key"
  deletion_window_in_days = 10
}
