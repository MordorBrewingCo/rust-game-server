resource "aws_ebs_volume" "rust_ebs" {
  availability_zone = var.availability_zone
  size              = 10
}

resource "aws_volume_attachment" "rust_ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.rust_ebs.id
  instance_id = aws_instance.rust.id
}

