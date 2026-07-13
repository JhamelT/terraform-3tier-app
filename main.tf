provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

module "rds" {
  source              = "./modules/rds"
  instance_class      = "db.t3.micro"
  db_name             = "appdb"
  db_username         = data.aws_ssm_parameter.db_username.value
  db_password         = data.aws_ssm_parameter.db_password.value
  rds_sg_id           = module.security_group.sg_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  project             = var.project
  publicly_accessible = false
}

module "ec2" {
  source        = "./modules/ec2"
  ami_id        = var.ami_id
  instance_type = var.instance_type
  subnet_id     = module.vpc.private_subnet_ids[0]
  sg_id         = module.security_group.sg_id
  project       = var.project

  depends_on = [
    module.vpc
  ]
}

module "security_group" {
  source           = "./modules/security_group"
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  project          = var.project
  ec2_subnet_cidrs = var.private_subnet_cidrs
}

module "vpc" {
  source               = "./modules/vpc"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  project              = var.project
}

data "aws_ssm_parameter" "db_username" {
  name = "/project2/db_username"
}
data "aws_ssm_parameter" "db_password" {
  name = "/project2/db_password"
}
