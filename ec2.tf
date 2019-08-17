provider "aws" {
  region = "us-west-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "user_data" {
  template = "${file("templates/user_data.tpl")}"

resource "aws_instance" "rust" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.medium"
  user_data = "${data.template_file.user_data.rendered}"
}
