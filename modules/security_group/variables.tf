variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}
variable "project" {
  description = "Project name used for resource naming"
  type        = string
}
variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}
variable "ec2_subnet_cidrs" {
  description = "Private subnet CIDRs permitted to reach the database"
  type        = list(string)
}
