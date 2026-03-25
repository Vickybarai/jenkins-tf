# Three-Tier Infrastructure

This repository contains Terraform configurations for a three-tier infrastructure on AWS, including:
- RDS MySQL database
- EKS Kubernetes cluster
- S3 bucket for static website hosting

## Directory Structure

```
.
├── main.tf              # Main Terraform configuration
├── variables.tf         # Variable definitions
├── modules/            # Terraform modules
│   ├── rds/           # RDS module
│   ├── eks/           # EKS module
│   └── s3/            # S3 module
└── vars/              # Environment-specific variables
    ├── dev.tfvars     # Development environment
    ├── staging.tfvars # Staging environment
    └── prod.tfvars    # Production environment
```

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Choose an environment and apply the configuration:
   ```bash
   # For development
   terraform plan -var-file="vars/dev.tfvars"
   terraform apply -var-file="vars/dev.tfvars"

   # For staging
   terraform plan -var-file="vars/staging.tfvars"
   terraform apply -var-file="vars/staging.tfvars"

   # For production
   terraform plan -var-file="vars/prod.tfvars"
   terraform apply -var-file="vars/prod.tfvars"
   ```

## Security Considerations

- The .tfvars files contain sensitive information and should not be committed to version control
- Use a secrets management solution for production environments
- Consider using environment variables for sensitive values
- Review and adjust security group rules before deploying to production
