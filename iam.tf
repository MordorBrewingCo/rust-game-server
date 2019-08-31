resource "aws_iam_role" "ec2_describe_volumes_role" {
  name = "describe_volumes_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_describe_volumes_profile" {
  name  = "ec2_describe_volumes_profile"
  roles = ["${aws_iam_role.ec2_describe_volumes_role.name}"]
}

resource "aws_iam_role_policy" "ec2_describe_volumes_policy" {
  name = "ec2_describe_volumes_policy"
  role = "${aws_iam_role.ec2_describe_volumes_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeVolumes",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "ssm:DescribeParameters",
        "ssm:DescribeParameters"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
