# Secrets Management Guide

This guide explains how to securely manage secrets and authentication for your AKS Terraform deployment using Azure Service Principal authentication.

## 🔐 Security Overview

### What's Protected
- **Service Principal Credentials**: Client ID, Client Secret, Tenant ID, Subscription ID
- **AKS Admin Groups**: Azure AD group IDs for cluster admin access
- **Network Security**: Authorized IP ranges for API server access
- **Environment-specific secrets**: Different credentials per environment

### Security Features
- ✅ **Git exclusion**: Secrets files are never committed to version control
- ✅ **Terraform sensitivity**: Variables marked as sensitive in Terraform
- ✅ **Environment separation**: Different secrets per environment (dev/staging/prod)
- ✅ **Multiple authentication methods**: File-based or environment variables

## 📁 Files Structure

```
.
├── secrets.tfvars.example      # Template file (safe to commit)
├── secrets.tfvars              # Your actual secrets (NEVER COMMIT)
├── secrets.dev.tfvars          # Development secrets (NEVER COMMIT)
├── secrets.prod.tfvars         # Production secrets (NEVER COMMIT)
├── scripts/
│   ├── setup-env.sh           # Environment setup script
│   └── deploy.sh              # Deployment script with secrets
└── .gitignore                 # Excludes all secrets files
```

## 🚀 Quick Setup

### 1. Create Your Secrets File

```bash
# Copy the template
cp secrets.tfvars.example secrets.tfvars

# Edit with your actual values
nano secrets.tfvars
```

Your `secrets.tfvars` file should contain:

```hcl
# Service Principal Authentication
client_id       = "<YOUR CLIENT ID>"
client_secret   = "<YOUR CLIENT SECRET>"
tenant_id       = "<YOUR TENANT ID>"
subscription_id = "<YOUT SUBSCRIPTION ID>"

# AKS Security Configuration
admin_group_object_ids = [
  "your-azure-ad-group-id-here"
]

api_server_authorized_ip_ranges = [
  "YOUR_IP/32"        # Your current IP
]
```

### 2. Load Environment and Deploy

```bash
# Option 1: Use the deployment script (recommended)
./scripts/deploy.sh dev plan
./scripts/deploy.sh dev apply

# Option 2: Manual approach
source scripts/setup-env.sh secrets.tfvars
terraform plan -var-file="secrets.tfvars" -var-file="terraform.tfvars"
terraform apply -var-file="secrets.tfvars" -var-file="terraform.tfvars"
```

## 🌍 Multi-Environment Setup

### Create Environment-Specific Secrets

```bash
# Create development secrets
./scripts/setup-env.sh create-env dev

# Create production secrets  
./scripts/setup-env.sh create-env prod

# Edit each file with environment-specific values
nano secrets.dev.tfvars
nano secrets.prod.tfvars
```

### Deploy to Different Environments

```bash
# Development deployment
./scripts/deploy.sh dev apply

# Production deployment
./scripts/deploy.sh prod apply

# With custom files
./scripts/deploy.sh prod apply --secrets secrets.custom.tfvars
```

## 🔧 Authentication Methods

### Method 1: Terraform Variables (Recommended)
Store secrets in `.tfvars` files and pass to Terraform:

```bash
terraform apply -var-file="secrets.tfvars" -var-file="terraform.tfvars"
```

**Pros:**
- ✅ Clear separation of secrets and configuration
- ✅ Environment-specific files
- ✅ Works with all Terraform commands

### Method 2: Environment Variables
Set Azure authentication variables:

```bash
export ARM_CLIENT_ID="<YOUR CLIENT ID>"
export ARM_CLIENT_SECRET="<YOUR CLIENT SECRET>"
export ARM_TENANT_ID="<YOUR TENANT ID>"
export ARM_SUBSCRIPTION_ID="<YOUR SUBSCRIPTION ID>"

terraform apply -var-file="terraform.tfvars"
```

**Pros:**
- ✅ No secrets in files
- ✅ Good for CI/CD pipelines
- ✅ Standard Azure practice

### Method 3: Hybrid Approach (Best of Both)
Use environment variables for authentication, files for AKS-specific secrets:

```bash
# Load authentication from secrets file
source scripts/setup-env.sh secrets.tfvars

# Deploy (authentication via env vars, AKS config via files)
terraform apply -var-file="terraform.tfvars"
```

## 🛠️ Helper Scripts

### Environment Setup Script
`scripts/setup-env.sh` - Loads secrets into environment variables

```bash
# Load default secrets
source scripts/setup-env.sh

# Load environment-specific secrets
source scripts/setup-env.sh secrets.prod.tfvars

# Check current environment status
./scripts/setup-env.sh status

# Test authentication
./scripts/setup-env.sh test-auth
```

### Deployment Script
`scripts/deploy.sh` - Automated deployment with secrets management

```bash
# Plan deployment
./scripts/deploy.sh dev plan

# Apply changes
./scripts/deploy.sh prod apply

# Destroy resources
./scripts/deploy.sh dev destroy --auto-approve

# Initialize backend
./scripts/deploy.sh prod init
```

## 🔍 Getting Required Values

### Azure AD Group IDs
```bash
# List all groups
az ad group list --query "[].{Name:displayName, ObjectId:id}" --output table

# Get specific group ID
az ad group show --group "AKS-Admins" --query id --output tsv
```

### Your Current IP Address
```bash
# Get your public IP
curl -s https://ipinfo.io/ip

# Add to secrets file
echo "api_server_authorized_ip_ranges = [\"$(curl -s https://ipinfo.io/ip)/32\"]"
```

### Service Principal Information
If you need to create a new service principal:

```bash
# Create service principal
az ad sp create-for-rbac --name "aks-terraform-sp" --role Contributor

# Output will show:
# {
#   "appId": "your-client-id",
#   "password": "your-client-secret",
#   "tenant": "your-tenant-id"
# }
```

## 🔒 Security Best Practices

### File Security
1. **Never commit secrets files** - They're in `.gitignore` but double-check
2. **Use restrictive permissions** - `chmod 600 secrets.tfvars`
3. **Separate environments** - Different service principals per environment
4. **Rotate secrets regularly** - Update client secrets periodically

### Network Security
1. **Restrict API server access** - Use specific IP ranges, not `0.0.0.0/0`
2. **Use VPN ranges** - Include your corporate VPN CIDR blocks
3. **Remove temporary IPs** - Clean up test IP addresses

### Service Principal Security
1. **Least privilege** - Only grant necessary permissions
2. **Environment separation** - Different SPs for dev/staging/prod
3. **Monitor usage** - Check Azure AD sign-in logs
4. **Disable unused SPs** - Clean up old service principals

## 🆘 Troubleshooting

### Common Issues

#### 1. Authentication Failed
```bash
# Check if variables are set
./scripts/setup-env.sh status

# Test authentication
./scripts/setup-env.sh test-auth

# Verify service principal
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
```

#### 2. Secrets File Not Found
```bash
# Check file existence
ls -la secrets*.tfvars

# Create from template
cp secrets.tfvars.example secrets.tfvars
```

#### 3. API Server Access Denied
```bash
# Check your current IP
curl -s https://ipinfo.io/ip

# Update authorized IP ranges in secrets.tfvars
api_server_authorized_ip_ranges = ["YOUR_NEW_IP/32"]
```

#### 4. Permission Denied
```bash
# Check service principal permissions
az role assignment list --assignee $ARM_CLIENT_ID --output table

# Grant Contributor role if needed
az role assignment create \
  --assignee $ARM_CLIENT_ID \
  --role Contributor \
  --scope "/subscriptions/$ARM_SUBSCRIPTION_ID"
```

### Debugging Commands

```bash
# Check Terraform variables
terraform console
> var.client_id

# Validate configuration
terraform validate

# Show plan with secrets
terraform plan -var-file="secrets.tfvars" -var-file="terraform.tfvars"

# Check provider authentication
terraform providers
```

## 🏭 Production Considerations

### For Production Deployments

1. **Use Azure Key Vault**:
   ```hcl
   data "azurerm_key_vault_secret" "client_secret" {
     name         = "aks-client-secret"
     key_vault_id = data.azurerm_key_vault.main.id
   }
   ```

2. **CI/CD Pipeline Integration**:
   - Store secrets in Azure DevOps Variable Groups
   - Use GitHub Secrets for GitHub Actions
   - Enable secret masking in logs

3. **Network Hardening**:
   - Use private endpoints for AKS API server
   - Implement network security groups
   - Use Azure Firewall for egress filtering

4. **Audit and Monitoring**:
   - Enable Azure AD audit logs
   - Monitor service principal usage
   - Set up alerts for unauthorized access attempts

### Alternative Authentication Methods

For production environments, consider these alternatives:

1. **Managed Identity** (for Azure VMs/Container Instances):
   ```hcl
   provider "azurerm" {
     use_msi = true
     features {}
   }
   ```

2. **Azure CLI Authentication** (for local development):
   ```bash
   az login
   terraform apply  # Uses Azure CLI credentials
   ```

3. **Workload Identity** (for Kubernetes workloads):
   - Configure OIDC integration
   - Use federated identity credentials
   - No long-lived secrets required

## 📚 References

- [Azure Service Principal Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Terraform Azure Provider Authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret)
- [AKS Security Best Practices](https://docs.microsoft.com/en-us/azure/aks/concepts-security)
- [Azure Key Vault Integration](https://docs.microsoft.com/en-us/azure/key-vault/)