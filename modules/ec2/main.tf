data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ec2_parameter_store" {
  name = "${var.project}-ec2-parameter-store"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_parameter_store.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_role_policy" "parameter_store_access" {
  name = "${var.project}-parameter-store-access"
  role = aws_iam_role.ec2_parameter_store.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadDatabaseParameters"
        Effect = "Allow"

        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]

        Resource = [
          "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/project2/db_username",
          "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/project2/db_password"
        ]
      }
    ]
  })
}


resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${var.project}-ssm-profile"
  role = aws_iam_role.ec2_parameter_store.name
}

resource "aws_instance" "my_instance" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id # Updated for better scalability
  vpc_security_group_ids      = [var.sg_id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm_profile.name
  user_data                   = file("${path.module}/user_data.sh")

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core,
    aws_iam_role_policy.parameter_store_access
  ]

  tags = {
    Name = "${var.project}-ec2"
  }
}
