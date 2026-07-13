#!/bin/bash
set -euo pipefail

systemctl enable amazon-ssm-agent || true
systemctl start amazon-ssm-agent || true


AWS_REGION="us-east-1"
DB_USERNAME_PARAMETER="/project2/db_username"
DB_PASSWORD_PARAMETER="/project2/db_password"

DB_USER=$(aws ssm get-parameter \
  --name "$DB_USERNAME_PARAMETER" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query "Parameter.Value" \
  --output text)

DB_PASS=$(aws ssm get-parameter \
  --name "$DB_PASSWORD_PARAMETER" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query "Parameter.Value" \
  --output text)

if [[ -n "$DB_USER" && -n "$DB_PASS" ]]; then
  echo "Database credentials retrieved successfully from Parameter Store."
else
  echo "Failed to retrieve database credentials from Parameter Store."
  exit 1
fi
