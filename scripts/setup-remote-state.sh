#!/bin/bash

# =============================================================================
# Azure Terraform Remote State Setup Script
# =============================================================================
# This script creates the Azure resources needed for Terraform remote state:
# - Resource Group
# - Storage Account
# - Blob Container
# - Outputs the configuration needed for backend.tf

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values (can be overridden with environment variables)
RESOURCE_GROUP_NAME="${TERRAFORM_STATE_RG:-rg-aks-terraform-state}"
STORAGE_ACCOUNT_NAME="${TERRAFORM_STATE_SA:-tfstate$(date +%s | tail -c 6)}" # Add random suffix
CONTAINER_NAME="${TERRAFORM_STATE_CONTAINER:-tfstate}"
LOCATION="${TERRAFORM_STATE_LOCATION:-italynorth}"
SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID}"
TAGS="${TERRAFORM_STATE_TAGS:-Environment=shared Purpose=terraform-state ManagedBy=script}"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo
    print_message $BLUE "================================================================================"
    print_message $BLUE "$1"
    print_message $BLUE "================================================================================"
    echo
}

print_success() {
    print_message $GREEN "✓ $1"
}

print_warning() {
    print_message $YELLOW "⚠ $1"
}

print_error() {
    print_message $RED "✗ $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Azure CLI login
check_azure_login() {
    if ! az account show >/dev/null 2>&1; then
        print_error "Not logged in to Azure CLI"
        print_message $YELLOW "Please run: az login"
        exit 1
    fi
}

# Function to set subscription
set_subscription() {
    if [ -n "$SUBSCRIPTION_ID" ]; then
        print_message $BLUE "Setting subscription to: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
        print_success "Subscription set"
    else
        CURRENT_SUB=$(az account show --query "id" -o tsv)
        print_message $YELLOW "Using current subscription: $CURRENT_SUB"
        SUBSCRIPTION_ID=$CURRENT_SUB
    fi
}

# Function to parse tags
parse_tags() {
    # Convert "key=value key2=value2" to JSON format for Azure CLI
    if [ -n "$TAGS" ]; then
        # Convert space-separated key=value pairs to JSON
        echo "$TAGS" | sed 's/ /","/g; s/=/":""/g; s/^/{""/; s/$/"}/' | sed 's/"""/"/g'
    else
        echo "{}"
    fi
}

# Function to create resource group
create_resource_group() {
    print_message $BLUE "Creating resource group: $RESOURCE_GROUP_NAME"
    
    # Check if resource group exists
    if az group show --name "$RESOURCE_GROUP_NAME" >/dev/null 2>&1; then
        print_warning "Resource group $RESOURCE_GROUP_NAME already exists"
    else
        local tags_json=$(parse_tags)
        az group create \
            --name "$RESOURCE_GROUP_NAME" \
            --location "$LOCATION" \
            --tags "$tags_json" \
            --output table
        print_success "Resource group created: $RESOURCE_GROUP_NAME"
    fi
}

# Function to create storage account
create_storage_account() {
    print_message $BLUE "Creating storage account: $STORAGE_ACCOUNT_NAME"
    
    # Check if storage account exists
    if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" >/dev/null 2>&1; then
        print_warning "Storage account $STORAGE_ACCOUNT_NAME already exists"
    else
        local tags_json=$(parse_tags)
        az storage account create \
            --name "$STORAGE_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --location "$LOCATION" \
            --sku Standard_LRS \
            --encryption-services blob \
            --https-only true \
            --min-tls-version TLS1_2 \
            --allow-blob-public-access false \
            --tags "$tags_json" \
            --output table
        print_success "Storage account created: $STORAGE_ACCOUNT_NAME"
    fi
    
    # Enable versioning and soft delete for better state management
    print_message $BLUE "Configuring storage account security features..."
    az storage account blob-service-properties update \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --enable-versioning true \
        --enable-delete-retention true \
        --delete-retention-days 7 >/dev/null
    print_success "Storage account security configured"
}

# Function to create blob container
create_blob_container() {
    print_message $BLUE "Creating blob container: $CONTAINER_NAME"
    
    # Get storage account key
    local storage_key=$(az storage account keys list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --query '[0].value' -o tsv)
    
    # Check if container exists
    if az storage container show \
        --name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --account-key "$storage_key" >/dev/null 2>&1; then
        print_warning "Container $CONTAINER_NAME already exists"
    else
        az storage container create \
            --name "$CONTAINER_NAME" \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --account-key "$storage_key" \
            --public-access off \
            --output table
        print_success "Blob container created: $CONTAINER_NAME"
    fi
}

# Function to output backend configuration
output_backend_config() {
    print_header "TERRAFORM BACKEND CONFIGURATION"
    
    cat << EOF
Add this configuration to your backend.tf file:

terraform {
  backend "azurerm" {
    resource_group_name   = "$RESOURCE_GROUP_NAME"
    storage_account_name  = "$STORAGE_ACCOUNT_NAME"
    container_name        = "$CONTAINER_NAME"
    key                   = "terraform.tfstate"
  }
}

EOF

    print_header "ENVIRONMENT VARIABLES"
    cat << EOF
You can also set these environment variables instead of specifying in backend.tf:

export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"

EOF

    print_header "TERRAFORM INITIALIZATION"
    cat << EOF
To initialize Terraform with the remote backend:

terraform init -backend-config="resource_group_name=$RESOURCE_GROUP_NAME" \\
               -backend-config="storage_account_name=$STORAGE_ACCOUNT_NAME" \\
               -backend-config="container_name=$CONTAINER_NAME" \\
               -backend-config="key=terraform.tfstate"

Or simply run: terraform init (if using backend.tf)

EOF
}

# Function to create backend.tf file
create_backend_file() {
    local backend_file="backend.tf"
    
    if [ -f "$backend_file" ]; then
        print_warning "backend.tf already exists, creating backend.tf.example instead"
        backend_file="backend.tf.example"
    fi
    
    cat > "$backend_file" << EOF
# Terraform Backend Configuration for Azure Storage
# This file configures Terraform to store state remotely in Azure Blob Storage
# 
# Prerequisites:
# 1. Run scripts/setup-remote-state.sh to create the required Azure resources
# 2. Ensure you're logged in to Azure CLI: az login
# 3. Set the correct subscription: az account set --subscription <subscription-id>

terraform {
  backend "azurerm" {
    resource_group_name   = "$RESOURCE_GROUP_NAME"
    storage_account_name  = "$STORAGE_ACCOUNT_NAME" 
    container_name        = "$CONTAINER_NAME"
    key                   = "terraform.tfstate"
    
    # Optional: Uncomment these if not using environment variables
    # subscription_id       = "your-subscription-id"
    # tenant_id            = "your-tenant-id"
  }
}
EOF
    
    print_success "Backend configuration file created: $backend_file"
}

# Function to display usage
usage() {
    cat << EOF
Azure Terraform Remote State Setup Script

This script creates the Azure resources needed for Terraform remote state storage.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help                  Show this help message
    -g, --resource-group NAME   Resource group name (default: rg-terraform-state)
    -s, --storage-account NAME  Storage account name (default: tfstate + random suffix)
    -c, --container NAME        Container name (default: tfstate)
    -l, --location LOCATION     Azure region (default: italynorth)
    --subscription-id ID        Azure subscription ID
    --tags "key=value ..."      Resource tags (default: Environment=shared Purpose=terraform-state ManagedBy=script)
    --create-backend            Create backend.tf file automatically

ENVIRONMENT VARIABLES:
    TERRAFORM_STATE_RG          Override resource group name
    TERRAFORM_STATE_SA          Override storage account name
    TERRAFORM_STATE_CONTAINER   Override container name
    TERRAFORM_STATE_LOCATION    Override location
    TERRAFORM_STATE_TAGS        Override tags
    ARM_SUBSCRIPTION_ID         Azure subscription ID

EXAMPLES:
    # Use defaults
    $0

    # Custom names and location
    $0 -g "rg-tfstate-prod" -s "tfstateprod123" -l "westeurope"
    
    # With environment variables
    export TERRAFORM_STATE_RG="rg-mycompany-tfstate"
    export TERRAFORM_STATE_SA="tfstatemycompany"
    $0

    # Create backend.tf automatically
    $0 --create-backend

EOF
}

# Main function
main() {
    local create_backend=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -g|--resource-group)
                RESOURCE_GROUP_NAME="$2"
                shift 2
                ;;
            -s|--storage-account)
                STORAGE_ACCOUNT_NAME="$2"
                shift 2
                ;;
            -c|--container)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            -l|--location)
                LOCATION="$2"
                shift 2
                ;;
            --subscription-id)
                SUBSCRIPTION_ID="$2"
                shift 2
                ;;
            --tags)
                TAGS="$2"
                shift 2
                ;;
            --create-backend)
                create_backend=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    print_header "AZURE TERRAFORM REMOTE STATE SETUP"
    
    # Pre-flight checks
    print_message $BLUE "Performing pre-flight checks..."
    
    if ! command_exists az; then
        print_error "Azure CLI is not installed"
        print_message $YELLOW "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    print_success "Azure CLI is installed"
    
    check_azure_login
    print_success "Azure CLI is authenticated"
    
    set_subscription
    
    # Display configuration
    print_header "CONFIGURATION"
    echo "Resource Group:    $RESOURCE_GROUP_NAME"
    echo "Storage Account:   $STORAGE_ACCOUNT_NAME"
    echo "Container:         $CONTAINER_NAME"
    echo "Location:          $LOCATION"
    echo "Subscription:      $SUBSCRIPTION_ID"
    echo "Tags:              $TAGS"
    echo
    
    # Confirm before proceeding
    read -p "Do you want to continue with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message $YELLOW "Aborted by user"
        exit 0
    fi
    
    # Create resources
    create_resource_group
    create_storage_account
    create_blob_container
    
    # Create backend.tf if requested
    if [ "$create_backend" = true ]; then
        create_backend_file
    fi
    
    # Output configuration
    output_backend_config
    
    print_header "SETUP COMPLETE"
    print_success "Remote state backend is ready!"
    print_message $YELLOW "Next steps:"
    print_message $YELLOW "1. Add the backend configuration to your terraform block"
    print_message $YELLOW "2. Run 'terraform init' to initialize the backend"
    print_message $YELLOW "3. Your state will be stored remotely in Azure Blob Storage"
}

# Run main function
main "$@"