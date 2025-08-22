#!/bin/bash

# =============================================================================
# Terraform Deployment Script with Secrets Management
# =============================================================================
# This script simplifies Terraform deployments by automatically loading
# secrets and providing common deployment operations.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
ENVIRONMENT="dev"
ACTION="plan"
SECRETS_FILE=""
CONFIG_FILE=""
AUTO_APPROVE=false
DESTROY=false

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

# Function to show usage
show_usage() {
    cat << EOF
Terraform Deployment Script with Secrets Management

USAGE:
    $0 [ENVIRONMENT] [ACTION] [OPTIONS]

ENVIRONMENTS:
    dev         Development environment (default)
    staging     Staging environment
    prod        Production environment
    custom      Custom environment

ACTIONS:
    plan        Show Terraform plan (default)
    apply       Apply Terraform changes
    destroy     Destroy all resources
    init        Initialize Terraform
    validate    Validate Terraform configuration
    output      Show Terraform outputs

OPTIONS:
    -s, --secrets FILE      Secrets file (default: secrets.[env].tfvars)
    -c, --config FILE       Configuration file (default: terraform.tfvars)
    -y, --auto-approve      Auto approve changes (for apply/destroy)
    -h, --help             Show this help

EXAMPLES:
    # Plan development deployment
    $0 dev plan

    # Apply production deployment
    $0 prod apply

    # Destroy staging environment with auto-approve
    $0 staging destroy --auto-approve

    # Custom secrets and config files
    $0 dev apply --secrets secrets.custom.tfvars --config terraform.prod.tfvars

    # Initialize backend for production
    $0 prod init

EOF
}

# Function to determine file paths
determine_files() {
    local env="$1"
    
    # Determine secrets file
    if [[ -z "$SECRETS_FILE" ]]; then
        if [[ -f "secrets.${env}.tfvars" ]]; then
            SECRETS_FILE="secrets.${env}.tfvars"
        elif [[ -f "secrets.tfvars" ]]; then
            SECRETS_FILE="secrets.tfvars"
        else
            print_error "No secrets file found!"
            print_message $YELLOW "Expected locations:"
            print_message $YELLOW "  - secrets.${env}.tfvars"
            print_message $YELLOW "  - secrets.tfvars"
            print_message $YELLOW ""
            print_message $YELLOW "Create from template:"
            print_message $YELLOW "  cp secrets.tfvars.example secrets.tfvars"
            exit 1
        fi
    fi
    
    # Determine config file
    if [[ -z "$CONFIG_FILE" ]]; then
        if [[ -f "terraform.${env}.tfvars" ]]; then
            CONFIG_FILE="terraform.${env}.tfvars"
        elif [[ -f "terraform.tfvars" ]]; then
            CONFIG_FILE="terraform.tfvars"
        else
            print_warning "No configuration file found, using default values"
            CONFIG_FILE=""
        fi
    fi
    
    print_message $BLUE "Using files:"
    print_message $BLUE "  Secrets: $SECRETS_FILE"
    print_message $BLUE "  Config:  ${CONFIG_FILE:-<default values>}"
}

# Function to load environment variables
load_environment() {
    local secrets_file="$1"
    
    print_message $BLUE "Loading environment variables from: $secrets_file"
    
    # Source the setup-env script to load variables
    if [[ -f "scripts/setup-env.sh" ]]; then
        # Temporarily disable exit on error for sourcing
        set +e
        source scripts/setup-env.sh "$secrets_file" > /dev/null 2>&1
        local source_result=$?
        set -e
        
        if [[ $source_result -eq 0 ]]; then
            print_success "Environment variables loaded"
        else
            print_error "Failed to load environment variables"
            exit 1
        fi
    else
        print_error "setup-env.sh script not found"
        exit 1
    fi
}

# Function to build Terraform command arguments
build_tf_args() {
    local args=""
    
    # Add secrets file if it exists
    if [[ -n "$SECRETS_FILE" && -f "$SECRETS_FILE" ]]; then
        args="$args -var-file=\"$SECRETS_FILE\""
    fi
    
    # Add config file if it exists
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        args="$args -var-file=\"$CONFIG_FILE\""
    fi
    
    echo "$args"
}

# Function to run terraform init
run_init() {
    local env="$1"
    
    print_message $BLUE "Initializing Terraform for environment: $env"
    
    # Use the init-backend script if available
    if [[ -f "scripts/init-backend.sh" ]]; then
        print_message $BLUE "Using init-backend script..."
        bash scripts/init-backend.sh "$env"
    else
        print_message $BLUE "Running standard terraform init..."
        terraform init
    fi
    
    print_success "Terraform initialized"
}

# Function to run terraform validate
run_validate() {
    print_message $BLUE "Validating Terraform configuration..."
    terraform validate
    print_success "Configuration is valid"
}

# Function to run terraform plan
run_plan() {
    local tf_args=$(build_tf_args)
    local cmd="terraform plan $tf_args"
    
    print_message $BLUE "Running Terraform plan..."
    print_message $BLUE "Command: $cmd"
    echo
    
    eval $cmd
}

# Function to run terraform apply
run_apply() {
    local tf_args=$(build_tf_args)
    local approve_flag=""
    
    if [[ "$AUTO_APPROVE" == true ]]; then
        approve_flag="-auto-approve"
    fi
    
    local cmd="terraform apply $tf_args $approve_flag"
    
    print_message $BLUE "Running Terraform apply..."
    print_message $BLUE "Command: $cmd"
    echo
    
    eval $cmd
    
    if [[ $? -eq 0 ]]; then
        print_success "Deployment completed successfully!"
        echo
        print_message $YELLOW "To get cluster credentials, run:"
        terraform output -raw kube_config_command 2>/dev/null || echo "az aks get-credentials --resource-group <rg-name> --name <aks-name>"
    fi
}

# Function to run terraform destroy
run_destroy() {
    local tf_args=$(build_tf_args)
    local approve_flag=""
    
    if [[ "$AUTO_APPROVE" == true ]]; then
        approve_flag="-auto-approve"
    fi
    
    print_warning "This will destroy all resources in the $ENVIRONMENT environment!"
    
    if [[ "$AUTO_APPROVE" != true ]]; then
        read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
        if [[ ! $REPLY == "yes" ]]; then
            print_message $YELLOW "Destroy cancelled"
            exit 0
        fi
    fi
    
    local cmd="terraform destroy $tf_args $approve_flag"
    
    print_message $BLUE "Running Terraform destroy..."
    print_message $BLUE "Command: $cmd"
    echo
    
    eval $cmd
    
    if [[ $? -eq 0 ]]; then
        print_success "Resources destroyed successfully!"
    fi
}

# Function to run terraform output
run_output() {
    print_message $BLUE "Terraform outputs:"
    terraform output
}

# Parse command line arguments
parse_args() {
    # First positional argument is environment (if not starting with -)
    if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        ENVIRONMENT="$1"
        shift
    fi
    
    # Second positional argument is action (if not starting with -)  
    if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        ACTION="$1"
        shift
    fi
    
    # Parse remaining options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--secrets)
                SECRETS_FILE="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -y|--auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    parse_args "$@"
    
    print_message $BLUE "================================================================================"
    print_message $BLUE "TERRAFORM DEPLOYMENT - $ENVIRONMENT - $ACTION"
    print_message $BLUE "================================================================================"
    echo
    
    # Determine file paths
    determine_files "$ENVIRONMENT"
    echo
    
    # Load environment variables for authentication
    load_environment "$SECRETS_FILE"
    echo
    
    # Execute requested action
    case $ACTION in
        "init")
            run_init "$ENVIRONMENT"
            ;;
        "validate")
            run_validate
            ;;
        "plan")
            run_plan
            ;;
        "apply")
            run_apply
            ;;
        "destroy")
            run_destroy
            ;;
        "output")
            run_output
            ;;
        *)
            print_error "Unknown action: $ACTION"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"