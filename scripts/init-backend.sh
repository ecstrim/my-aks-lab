#!/bin/bash

# =============================================================================
# Terraform Backend Initialization Script
# =============================================================================
# This script helps initialize Terraform with different backend configurations
# for various environments (dev, staging, prod) using the same storage account
# but different state file keys.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default backend configuration
RESOURCE_GROUP_NAME="${TERRAFORM_STATE_RG:-rg-terraform-state}"
STORAGE_ACCOUNT_NAME="${TERRAFORM_STATE_SA}"
CONTAINER_NAME="${TERRAFORM_STATE_CONTAINER:-tfstate}"
ENVIRONMENT="${1:-dev}"
PROJECT_NAME="${PROJECT_NAME:-aks-cluster}"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
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

# Function to display usage
usage() {
    cat << EOF
Terraform Backend Initialization Script

This script initializes Terraform with Azure Storage backend for different environments.

USAGE:
    $0 [ENVIRONMENT] [OPTIONS]

ENVIRONMENTS:
    dev         Development environment (default)
    staging     Staging environment  
    prod        Production environment
    custom      Custom environment (specify key with --key)

OPTIONS:
    -h, --help                  Show this help message
    -g, --resource-group NAME   Resource group name
    -s, --storage-account NAME  Storage account name  
    -c, --container NAME        Container name
    -p, --project NAME          Project name (default: aks-cluster)
    -k, --key PATH              Custom state file key/path
    --force                     Force re-initialization
    --reconfigure              Reconfigure backend (migrate existing state)

ENVIRONMENT VARIABLES:
    TERRAFORM_STATE_RG          Resource group name
    TERRAFORM_STATE_SA          Storage account name (required)
    TERRAFORM_STATE_CONTAINER   Container name
    PROJECT_NAME               Project name

EXAMPLES:
    # Initialize dev environment
    $0 dev

    # Initialize production with custom storage account
    $0 prod -s "tfstateprod123"
    
    # Custom state file path
    $0 custom -k "my-project/custom/terraform.tfstate"
    
    # Force re-initialization
    $0 prod --force

EOF
}

# Function to validate required parameters
validate_parameters() {
    if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
        print_error "Storage account name is required"
        print_message $YELLOW "Set TERRAFORM_STATE_SA environment variable or use -s option"
        exit 1
    fi
    
    if [ -z "$RESOURCE_GROUP_NAME" ]; then
        print_error "Resource group name is required"
        print_message $YELLOW "Set TERRAFORM_STATE_RG environment variable or use -g option"
        exit 1
    fi
}

# Function to generate state file key based on environment
generate_state_key() {
    local env=$1
    local project=$2
    
    case $env in
        dev|staging|prod)
            echo "${project}/${env}/terraform.tfstate"
            ;;
        custom)
            if [ -n "$CUSTOM_KEY" ]; then
                echo "$CUSTOM_KEY"
            else
                echo "${project}/custom/terraform.tfstate"
            fi
            ;;
        *)
            echo "${project}/${env}/terraform.tfstate"
            ;;
    esac
}

# Function to check if backend is already configured
check_existing_backend() {
    if [ -f ".terraform/terraform.tfstate" ]; then
        print_warning "Terraform backend already configured"
        if [ "$FORCE_INIT" != "true" ] && [ "$RECONFIGURE" != "true" ]; then
            print_message $YELLOW "Use --force to re-initialize or --reconfigure to migrate"
            exit 1
        fi
    fi
}

# Function to backup current state
backup_current_state() {
    if [ -f "terraform.tfstate" ]; then
        local backup_file="terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
        cp "terraform.tfstate" "$backup_file"
        print_success "Local state backed up to: $backup_file"
    fi
}

# Function to initialize Terraform backend
init_backend() {
    local state_key=$(generate_state_key "$ENVIRONMENT" "$PROJECT_NAME")
    
    print_message $BLUE "Initializing Terraform backend with:"
    echo "  Environment:       $ENVIRONMENT"
    echo "  Resource Group:    $RESOURCE_GROUP_NAME"
    echo "  Storage Account:   $STORAGE_ACCOUNT_NAME"
    echo "  Container:         $CONTAINER_NAME"
    echo "  State Key:         $state_key"
    echo "  Project:           $PROJECT_NAME"
    echo
    
    # Build terraform init command
    local init_cmd="terraform init"
    
    init_cmd="$init_cmd -backend-config=\"resource_group_name=$RESOURCE_GROUP_NAME\""
    init_cmd="$init_cmd -backend-config=\"storage_account_name=$STORAGE_ACCOUNT_NAME\""
    init_cmd="$init_cmd -backend-config=\"container_name=$CONTAINER_NAME\""
    init_cmd="$init_cmd -backend-config=\"key=$state_key\""
    
    if [ "$FORCE_INIT" == "true" ]; then
        init_cmd="$init_cmd -force-copy"
    fi
    
    if [ "$RECONFIGURE" == "true" ]; then
        init_cmd="$init_cmd -reconfigure"
    fi
    
    # Execute terraform init
    print_message $BLUE "Executing: $init_cmd"
    eval $init_cmd
    
    print_success "Terraform backend initialized successfully!"
}

# Function to create workspace if needed
create_workspace() {
    local workspace_name="$ENVIRONMENT"
    
    # Skip for default workspace
    if [ "$workspace_name" == "default" ]; then
        return
    fi
    
    # Check if workspace exists
    if terraform workspace list | grep -q "\\b$workspace_name\\b"; then
        print_message $BLUE "Switching to existing workspace: $workspace_name"
        terraform workspace select "$workspace_name"
    else
        print_message $BLUE "Creating new workspace: $workspace_name"
        terraform workspace new "$workspace_name"
    fi
    
    print_success "Using Terraform workspace: $workspace_name"
}

# Function to verify backend configuration
verify_backend() {
    if terraform providers >/dev/null 2>&1; then
        print_success "Backend verification successful"
        
        # Show current backend config
        print_message $BLUE "Current backend configuration:"
        terraform init -backend=false >/dev/null 2>&1 || true
        if [ -f ".terraform/terraform.tfstate" ]; then
            grep -A 10 '"backend"' .terraform/terraform.tfstate 2>/dev/null | head -15 || true
        fi
    else
        print_error "Backend verification failed"
        exit 1
    fi
}

# Main function
main() {
    local FORCE_INIT=false
    local RECONFIGURE=false
    local CUSTOM_KEY=""
    
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
            -p|--project)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -k|--key)
                CUSTOM_KEY="$2"
                shift 2
                ;;
            --force)
                FORCE_INIT=true
                shift
                ;;
            --reconfigure)
                RECONFIGURE=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [ -z "$ENVIRONMENT" ] || [ "$ENVIRONMENT" == "dev" ]; then
                    ENVIRONMENT="$1"
                fi
                shift
                ;;
        esac
    done
    
    print_message $BLUE "================================================================================"
    print_message $BLUE "TERRAFORM BACKEND INITIALIZATION - $ENVIRONMENT"  
    print_message $BLUE "================================================================================"
    echo
    
    validate_parameters
    check_existing_backend
    backup_current_state
    init_backend
    create_workspace
    verify_backend
    
    echo
    print_message $GREEN "================================================================================"
    print_message $GREEN "INITIALIZATION COMPLETE!"
    print_message $GREEN "================================================================================"
    echo
    
    print_success "Environment: $ENVIRONMENT"
    print_success "Backend configured with Azure Storage"
    print_success "State will be stored remotely and locked automatically"
    
    print_message $YELLOW "Next steps:"
    print_message $YELLOW "1. Configure your terraform.tfvars file for $ENVIRONMENT"
    print_message $YELLOW "2. Run 'terraform plan' to see planned changes"
    print_message $YELLOW "3. Run 'terraform apply' to create resources"
}

# Handle case where environment is passed as first argument
if [ $# -gt 0 ] && [[ ! "$1" =~ ^- ]]; then
    ENVIRONMENT="$1"
    shift
fi

# Run main function
main "$@"