# AWS Three-Tier Infrastructure Foundation with Terraform

> A security-focused AWS infrastructure project built with reusable Terraform modules, private networking, Systems Manager administration, and least-privilege IAM.

## Architecture

<!-- Add the final Draw.io export here:
![AWS Three-Tier Infrastructure](docs/terraform-3tier-architecture.png)
-->

> **Current implementation:** one public subnet, two private subnets across two Availability Zones, one private EC2 application instance, and one private Amazon RDS MySQL instance. The RDS subnet group spans both private subnets. No public application endpoint is currently deployed.

## Project Overview

This project provisions a modular AWS infrastructure foundation using Terraform. The root module composes separate modules for networking, compute, database, and security.

The design focuses on:

- Private EC2 and RDS resources
- Controlled outbound connectivity through a NAT Gateway
- Systems Manager Session Manager instead of inbound SSH
- Runtime retrieval of database parameters from Systems Manager Parameter Store
- Least-privilege IAM permissions
- Reusable Terraform module boundaries
- Version-constrained providers and consistent resource tagging

This repository is intentionally positioned as a **production-inspired development architecture**, not a complete production web platform. An Application Load Balancer, Auto Scaling Group, separate tier-specific security groups, Multi-AZ RDS, and remote state are documented as future improvements.

## Current Architecture

| Component | Current implementation |
|---|---|
| AWS Region | `us-east-1` by default |
| VPC | `10.0.0.0/16` |
| Public subnets | One public subnet: `10.0.1.0/24` in `us-east-1a` |
| Private subnets | `10.0.2.0/24` in `us-east-1a` and `10.0.3.0/24` in `us-east-1b` |
| Public routing | Internet Gateway and public route table |
| Private outbound access | NAT Gateway with Elastic IP |
| Application tier | One EC2 instance in the first private subnet |
| Database tier | One RDS MySQL instance using a DB subnet group across both private subnets |
| Administrative access | AWS Systems Manager Session Manager |
| Credentials | Systems Manager Parameter Store |
| Security groups | One shared development security group |
| State | Local Terraform state in the current version |

## Traffic and Management Flows

### Private outbound connectivity

```text
Private EC2 instance
        |
Private route table
        |
NAT Gateway
        |
Internet Gateway
        |
Internet
```

The NAT Gateway provides outbound connectivity for private resources. It does not create a public inbound path to the EC2 instance.

### Administrative access

```text
Authorized AWS identity
        |
Systems Manager Session Manager
        |
Private EC2 instance
```

The EC2 instance does not require a public IP address, SSH key pair, or inbound port 22 rule.

### Parameter retrieval

```text
EC2 IAM role
        |
ssm:GetParameter / ssm:GetParameters
        |
/project2/db_username
/project2/db_password
```

The EC2 role is scoped to the two Parameter Store values required by the bootstrap process.

## Security Design

- EC2 is deployed with `associate_public_ip_address = false`
- RDS is configured with `publicly_accessible = false`
- Inbound SSH access is removed
- Systems Manager managed-node permissions are attached to the EC2 role
- Parameter Store access is limited to two database parameter ARNs
- Bootstrap logs do not print credential values
- Provider-level tags identify the project, environment, and Terraform ownership
- Terraform and AWS provider versions are constrained and locked

### Sensitive state note

The database username and password are read by Terraform and passed to the RDS resource. Sensitive values may still exist in Terraform state even when CLI output is redacted. State must therefore remain excluded from source control and protected appropriately.

## Architecture Decisions

### Why Terraform modules?

Networking, compute, database, and security are separated into child modules. This reduces duplication, keeps the root module focused on composition, and makes each infrastructure domain easier to review and update.

### Why private subnets?

The EC2 application instance and RDS database do not require direct inbound internet access. Private placement reduces the public attack surface while allowing controlled outbound access through the NAT Gateway.

### Why Systems Manager instead of SSH?

Session Manager removes the need for inbound port 22, public IP addresses, and long-lived SSH key pairs. Access is controlled through AWS identity permissions.

### Why Parameter Store?

Database credentials remain outside the repository and are retrieved through authenticated AWS API calls. The EC2 role is restricted to only the required parameter paths.

### Why one NAT Gateway?

This development environment uses one NAT Gateway to control cost and complexity. A stronger production design would evaluate one NAT Gateway per Availability Zone or VPC endpoints for critical AWS services.

### Why one shared security group?

The current version uses one shared development security group to keep the implementation focused on module composition and private networking. A production iteration should separate application and database security groups and use source security-group references.

## Refactor Highlights

This repository was revisited and refactored as an infrastructure code review exercise.

Key changes included:

- Removed duplicate root-level networking resources
- Consolidated networking into one VPC module
- Added the missing public route table and association to the VPC module
- Changed EC2 to use no public IP
- Changed RDS to private accessibility
- Removed the hard-coded administrative IP and SSH ingress
- Removed an unnecessary EC2 module self-reference
- Added Systems Manager managed-node permissions
- Added least-privilege Parameter Store access
- Removed credential values from bootstrap logs
- Added Terraform and AWS provider constraints
- Committed the dependency lock file
- Added consistent project and environment tags

## Repository Structure

```text
terraform-3tier-app/
├── docs/
│   └── terraform-3tier-architecture.png
├── modules/
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── user_data.sh
│   │   └── variables.tf
│   ├── rds/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── security_group/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── vpc/
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── .gitignore
├── .terraform.lock.hcl
├── main.tf
├── README.md
├── variables.tf
└── versions.tf
```

## Prerequisites

- Terraform `1.12` or later
- AWS CLI configured with an authenticated AWS identity
- Permissions to create VPC, EC2, IAM, RDS, SSM, NAT Gateway, and related resources
- Existing Parameter Store entries:
  - `/project2/db_username`
  - `/project2/db_password`
- A valid AMI ID for the selected AWS Region

Verify AWS authentication:

```bash
aws sts get-caller-identity
```

## Deployment

### 1. Clone the repository

```bash
git clone https://github.com/JhamelT/terraform-3tier-app.git
cd terraform-3tier-app
```

### 2. Create `terraform.tfvars`

```hcl
ami_id        = "ami-REPLACE_WITH_VALID_AMI"
instance_type = "t3.micro"
environment   = "dev"
region        = "us-east-1"
```

`terraform.tfvars` is excluded from version control.

### 3. Initialize and validate

```bash
terraform init
terraform fmt -check -recursive
terraform validate
```

### 4. Review a saved plan

```bash
terraform plan -out=tfplan
terraform show tfplan
```

Review all IAM, RDS, NAT Gateway, security group, and networking changes before applying.

### 5. Apply the reviewed plan

```bash
terraform apply tfplan
```

### 6. Inspect managed resources

```bash
terraform state list
```

## State Management

This version does not configure a remote backend. Terraform therefore uses local state.

For team usage, the state should be migrated to a protected remote backend such as HCP Terraform or Amazon S3 with locking, encryption, versioning, and restricted access.

## Current Limitations

- One EC2 instance
- Single-AZ RDS configuration
- One NAT Gateway
- One shared development security group
- No Application Load Balancer
- No public application endpoint
- No Auto Scaling Group
- No HTTPS listener or ACM certificate
- No CloudWatch alarms or centralized application logging
- No remote Terraform backend
- AMI ID supplied manually

## Future Improvements

- Add an Application Load Balancer and HTTPS listener
- Deploy the application through an Auto Scaling Group
- Separate application and database security groups
- Replace CIDR-based database access with source security-group references
- Enable RDS Multi-AZ, backups, and deletion protection
- Add CloudWatch logs, metrics, dashboards, and alarms
- Add VPC endpoints for Systems Manager services
- Replace the manually supplied AMI with an Amazon Linux data lookup
- Move state to HCP Terraform or encrypted S3 with locking
- Add GitHub Actions checks for formatting, validation, and security scanning
- Introduce environment-specific development, staging, and production configuration

## What This Project Reinforced

- A successful Terraform deployment does not guarantee maintainable architecture
- Root modules should compose infrastructure rather than duplicate child-module resources
- Terraform plans and dependency graphs are valuable review tools
- Multi-AZ subnet design is a foundation for availability, not availability by itself
- Systems Manager access and Parameter Store access require different IAM permissions
- Sensitive CLI output and secure state management are separate concerns
- Infrastructure documentation should state current limitations as clearly as implemented capabilities

## Cleanup

Destroy the environment when testing is complete:

```bash
terraform plan -destroy
terraform destroy
```

Review the destroy plan carefully before confirming.
