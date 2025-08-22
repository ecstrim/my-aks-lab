# Azure Kubernetes Service (AKS) Terraform Deployment

This repository contains a modular Terraform configuration for deploying an Azure Kubernetes Service (AKS) cluster with enterprise-grade features and remote state management.

## Features

- **Modular Architecture**: Organized into reusable modules for resource group, networking, and AKS
- **Node Pool Presets**: Three VM SKU presets (low/high/custom) for easy configuration
- **Flexible Resource Management**:
  - Use existing resource groups or create new ones
  - Use existing VNets/subnets or create new networking
  - Support for cross-resource group networking (hub-spoke)
  - Custom naming for AKS managed resource group
- **Security Features**:
  - API server IP filtering
  - Entra ID (Azure AD) authentication with Kubernetes RBAC
  - Network policies enabled by default
  - Local accounts disabled for enhanced security
- **Remote State Management**:
  - Azure Blob Storage backend with state locking
  - Multi-environment support (dev/staging/prod)
  - Automated setup scripts for backend resources
- **Networking Options**:
  - Azure CNI Overlay (default)
  - Azure CNI
  - Kubenet
- **Cost Optimization**:
  - B-series VMs for low-spec preset
  - Spot instance support for user node pools
  - Auto-scaling enabled by default
- **Microsoft CAF Naming Convention**: Resources follow Microsoft's Cloud Adoption Framework naming standards

## Directory Structure

```
.
├── main.tf                       # Root module orchestration
├── variables.tf                  # Input variable definitions
├── outputs.tf                    # Output definitions
├── backend.tf.example            # Backend configuration template
├── terraform.tfvars.example      # Example configuration
├── terraform.tfvars.scenarios.md # Configuration scenarios
├── secrets.tfvars.example        # Secrets template (safe to commit)
├── SECRETS-MANAGEMENT.md         # Detailed secrets guide
├── README.md                     # This file
├── scripts/
│   ├── setup-remote-state.sh     # Initialize Azure backend resources
│   ├── init-backend.sh           # Initialize Terraform backend
│   ├── setup-env.sh              # Environment variables setup
│   └── deploy.sh                 # Deployment script with secrets
└── modules/
    ├── resource_group/           # Resource group module
    ├── network/                  # Virtual network module
    └── aks/                      # AKS cluster module
```

## Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.3.0
- Azure CLI (for authentication and kubectl configuration)
- Bash shell (for setup scripts)
- An Azure AD group for AKS admin access (optional but recommended)

## Quick Start

### 1. Setup Secrets (Required)

First, configure your authentication secrets:

```bash
# Copy the secrets template
cp secrets.tfvars.example secrets.tfvars

# Edit with your actual Service Principal credentials
nano secrets.tfvars
```

Add your Service Principal credentials:
```hcl
client_id       = "your-service-principal-client-id"
client_secret   = "your-service-principal-client-secret"
tenant_id       = "your-azure-ad-tenant-id"
subscription_id = "your-azure-subscription-id"

admin_group_object_ids = ["your-azure-ad-group-id"]
api_server_authorized_ip_ranges = ["your-ip/32"]
```

> ⚠️ **Security Note**: The `secrets.tfvars` file is automatically excluded from Git. Never commit secrets to version control.

### 2. Setup Remote State (Recommended)

First, create the Azure resources needed for Terraform remote state:

```bash
# Run the setup script
./scripts/setup-remote-state.sh

# Or with custom configuration
./scripts/setup-remote-state.sh \
  --resource-group "rg-mycompany-tfstate" \
  --storage-account "tfstatemycompany" \
  --location "westeurope"
```

The script will create:
- Resource group for Terraform state
- Storage account with security features enabled
- Blob container for state files
- Output backend configuration

### 3. Configure Backend

```bash
# Copy and customize the backend configuration
cp backend.tf.example backend.tf

# Edit backend.tf with your storage account details
# OR use the init script for different environments

# Initialize for development
./scripts/init-backend.sh dev

# Initialize for production  
./scripts/init-backend.sh prod
```

### 4. Configure Variables

```bash
# Copy and customize the configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your specific values
```

### 5. Deploy Infrastructure

```bash
# Option 1: Use the deployment script (recommended)
./scripts/deploy.sh dev plan    # Review the plan
./scripts/deploy.sh dev apply   # Deploy the infrastructure

# Option 2: Manual deployment
source scripts/setup-env.sh secrets.tfvars  # Load authentication
terraform init
terraform plan -var-file="secrets.tfvars" -var-file="terraform.tfvars"
terraform apply -var-file="secrets.tfvars" -var-file="terraform.tfvars"

# Get cluster credentials
$(terraform output -raw kube_config_command)
```

## Configuration Options

### Resource Management Options

The deployment supports various resource management scenarios:

#### 1. Create Everything (Default)
```hcl
create_resource_group = true
create_vnet          = true
```

#### 2. Use Existing Resource Group
```hcl
create_resource_group        = false
existing_resource_group_name = "rg-existing-myapp-prod-itn-01"
```

#### 3. Use Existing VNet (Same RG)
```hcl
create_resource_group        = false
existing_resource_group_name = "rg-myapp-prod-itn-01"

create_vnet                        = false
existing_vnet_name                 = "vnet-myapp-prod-itn-01"
existing_vnet_resource_group_name  = "rg-myapp-prod-itn-01"
existing_subnet_name               = "snet-aks-myapp-prod-itn-01"
```

#### 4. Use Existing VNet (Different RG - Hub/Spoke)
```hcl
create_resource_group = true  # Create new RG for AKS

create_vnet                        = false  # Use hub VNet
existing_vnet_name                 = "vnet-hub-prod-itn-01"
existing_vnet_resource_group_name  = "rg-network-hub-prod-itn-01"
existing_subnet_name               = "snet-aks-spoke-myapp-prod-itn-01"
```

#### 5. Custom Resource Group Names
```hcl
resource_group_name      = "rg-mycompany-aks-prod-custom"
node_resource_group_name = "rg-mc-mycompany-aks-prod-custom"
```

See `terraform.tfvars.scenarios.md` for detailed configuration examples.

### Node Pool Presets

| Preset | System Pool | User Pool | Use Case |
|--------|------------|-----------|----------|
| `low` | Standard_B2ms | Standard_B2ms | Development, testing |
| `high` | Standard_D4s_v5 | Standard_D8s_v5 | Production workloads |
| `custom` | Configurable | Configurable | Custom requirements |

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `workload` | Name of the workload | Required |
| `environment` | Environment (dev/staging/prod) | Required |
| `location` | Azure region | italynorth |
| `kubernetes_version` | Kubernetes version | 1.30 |
| `node_pool_preset` | VM SKU preset | low |
| `api_server_authorized_ip_ranges` | Allowed IPs for API access | [] (public) |
| `network_plugin` | Network plugin type | azure |
| `network_plugin_mode` | Network plugin mode | overlay |

## Remote State Management

### Backend Setup

The repository includes scripts for automated backend setup:

```bash
# Setup Azure resources for remote state
./scripts/setup-remote-state.sh --help

# Initialize backend for different environments
./scripts/init-backend.sh dev
./scripts/init-backend.sh staging  
./scripts/init-backend.sh prod
```

### Multi-Environment State

Each environment uses a separate state file:
- Development: `aks-cluster/dev/terraform.tfstate`
- Staging: `aks-cluster/staging/terraform.tfstate`
- Production: `aks-cluster/prod/terraform.tfstate`

### State File Organization

```
Azure Storage Container: tfstate
├── aks-cluster/
│   ├── dev/terraform.tfstate
│   ├── staging/terraform.tfstate
│   └── prod/terraform.tfstate
└── other-projects/
    └── ...
```

## Security Considerations

1. **Secrets Management**: Use `secrets.tfvars` for sensitive data, never commit to Git
2. **Service Principal Authentication**: Dedicated service principal with least-privilege access
3. **API Server Access**: Always restrict API server access in production
4. **Azure RBAC**: Enabled by default for fine-grained access control
5. **Local Accounts**: Disabled by default for enhanced security
6. **Network Policies**: Azure network policies enabled by default
7. **Managed Identity**: System-assigned identity used for cluster operations
8. **State Security**: Remote state stored in encrypted Azure Storage with access controls

> 📖 **Detailed Security Guide**: See [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md) for comprehensive secrets management instructions.

### API Server Access Control

For production environments, always configure `api_server_authorized_ip_ranges`:

```hcl
api_server_authorized_ip_ranges = [
  "203.0.113.0/32",    # Office IP
  "198.51.100.0/24"    # VPN range
]
```

### Using Spot Instances

To enable Spot instances for cost savings in non-production:

```hcl
user_node_pool_priority        = "Spot"
user_node_pool_eviction_policy = "Delete"
user_node_pool_spot_max_price  = -1  # Pay up to on-demand price
```

## Environment-Specific Deployments

### Development Environment
```bash
# Setup backend
./scripts/init-backend.sh dev

# Use dev-specific variables
cp terraform.tfvars.example terraform.tfvars.dev
# Edit terraform.tfvars.dev

# Deploy
terraform plan -var-file="terraform.tfvars.dev"
terraform apply -var-file="terraform.tfvars.dev"
```

### Production Environment
```bash
# Setup backend
./scripts/init-backend.sh prod

# Use production variables with existing resources
cat > terraform.tfvars.prod << EOF
workload    = "myapp"
environment = "prod"

# Use existing hub networking
create_vnet                        = false
existing_vnet_name                 = "vnet-hub-prod-itn-01"
existing_vnet_resource_group_name  = "rg-network-hub-prod-itn-01"
existing_subnet_name               = "snet-aks-myapp-prod-itn-01"

# Production settings
node_pool_preset = "high"
api_server_authorized_ip_ranges = ["10.0.0.0/8"]
admin_group_object_ids = ["your-aad-group-id"]
EOF

# Deploy
terraform plan -var-file="terraform.tfvars.prod"
terraform apply -var-file="terraform.tfvars.prod"
```

## Outputs

After deployment, the following outputs are available:

- `cluster_name`: Name of the AKS cluster
- `cluster_fqdn`: Fully qualified domain name
- `kube_config`: Raw kubeconfig (sensitive)
- `kube_config_command`: Azure CLI command to get credentials
- `resource_group_name`: Name of the resource group
- `node_resource_group`: Auto-created node resource group
- `deployment_info`: Summary of what was created vs. used existing

## Adding More Resources

This modular structure allows easy addition of new resources:

1. Create a new module in the `modules/` directory
2. Add the module call in `main.tf`
3. Define necessary variables in `variables.tf`
4. Add outputs in `outputs.tf`

Example modules you might add:
- Azure Container Registry (ACR)
- Azure Key Vault
- Azure Monitor/Log Analytics
- Application Gateway Ingress Controller

## Troubleshooting

### Common Issues

1. **Authentication errors**: Ensure you're logged in to Azure CLI:
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

2. **Backend initialization errors**:
   ```bash
   # Verify storage account exists
   az storage account show -n <storage-account> -g <resource-group>
   
   # Re-run backend setup
   ./scripts/setup-remote-state.sh
   ```

3. **Kubernetes version not available**: Check available versions:
   ```bash
   az aks get-versions --location italynorth --output table
   ```

4. **IP not authorized**: Add your current IP to `api_server_authorized_ip_ranges`

5. **Quota exceeded**: Check your subscription quotas for the selected VM SKUs

6. **State locking errors**: 
   ```bash
   # Force unlock if needed (use carefully)
   terraform force-unlock <lock-id>
   ```

### Backend Migration

To migrate from local to remote state:

```bash
# Backup local state
cp terraform.tfstate terraform.tfstate.backup

# Initialize with backend
./scripts/init-backend.sh <environment>

# Terraform will prompt to copy existing state
```

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

To clean up remote state resources:

```bash
# Delete the state storage (careful!)
az storage account delete \
  --name <storage-account-name> \
  --resource-group <resource-group-name>
```

## Contributing

1. Follow the existing code structure and naming conventions
2. Update documentation for any new features
3. Test with multiple environments
4. Ensure backend compatibility

## License

[Your License Here]
