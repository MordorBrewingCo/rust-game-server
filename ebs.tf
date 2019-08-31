resource "aws_ebs_volume" "rust_persistent" {
  volume_type = "gp2"
  delete_on_termination = false
  availability_zone = var.availability_zone
  size              = 10
}

resource "aws_volume_attachment" "rust_ec2" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.rust_persistent.id
  instance_id = aws_instance.rust.id
}
