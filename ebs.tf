resource "aws_ebs_volume" "rust_ebs" {
  availability_zone = "${var.availability_zone}"
  size              = 10
