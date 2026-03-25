# Environment-specific Variables

This directory contains environment-specific variable files for Terraform configurations.

## Available Environments

- `dev.tfvars`: Development environment configuration
- `staging.tfvars`: Staging environment configuration
- `prod.tfvars`: Production environment configuration

## Usage

To apply a specific environment configuration, use the following command:

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

## Security Note

The .tfvars files contain sensitive information like database passwords. In a production environment:
1. Do not commit these files to version control
2. Use a secrets management solution
3. Consider using environment variables for sensitive values 