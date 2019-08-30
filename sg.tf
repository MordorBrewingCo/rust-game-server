resource "aws_security_group" "rust" {
  name = "rust"
  description = "Rust Server EC2 Security Group"
  ingress {
    from_port = 28015
    to_port = 28016
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 28015
    to_port = 28016
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["173.84.0.0/14"]
  }
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["173.84.0.0/14", "98.10.111.0/25", "206.251.217.0/24"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
