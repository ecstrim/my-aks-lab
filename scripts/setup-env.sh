#!/bin/bash

# =============================================================================
# Environment Setup Script for Azure Terraform Deployment
# =============================================================================
# This script helps set up environment variables for Terraform Azure deployments
# using Service Principal authentication.
#
# USAGE:
#   # Load from secrets.tfvars file
#   source ./scripts/setup-env.sh
#   
#   # Load from custom file
#   source ./scripts/setup-env.sh path/to/custom.tfvars
#
#   # Load from environment-specific file
#   source ./scripts/setup-env.sh secrets.prod.tfvars

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Default secrets file
SECRETS_FILE="${1:-secrets.tfvars}"

# Function to parse tfvars file and set environment variables
parse_and_set_vars() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        print_error "Secrets file not found: $file"
        print_message $YELLOW "Expected file locations:"
        print_message $YELLOW "  - secrets.tfvars (default)"
        print_message $YELLOW "  - secrets.prod.tfvars (production)"
        print_message $YELLOW "  - secrets.dev.tfvars (development)"
        print_message $YELLOW ""
        print_message $YELLOW "Create from template:"
        print_message $YELLOW "  cp secrets.tfvars.example secrets.tfvars"
        return 1
    fi
    
    print_message $BLUE "Loading environment variables from: $file"
    
    # Parse the tfvars file and extract key-value pairs
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        
        # Extract variable assignments
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*\"(.*)\"[[:space:]]*$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"
            
            case "$var_name" in
                "client_id")
                    export ARM_CLIENT_ID="$var_value"
                    print_success "Set ARM_CLIENT_ID"
                    ;;
                "client_secret")
                    export ARM_CLIENT_SECRET="$var_value"
                    print_success "Set ARM_CLIENT_SECRET (hidden)"
                    ;;
                "tenant_id")
                    export ARM_TENANT_ID="$var_value"
                    print_success "Set ARM_TENANT_ID"
                    ;;
                "subscription_id")
                    export ARM_SUBSCRIPTION_ID="$var_value"
                    print_success "Set ARM_SUBSCRIPTION_ID"
                    ;;
                *)
                    # Set as regular environment variable for use in Terraform
                    export "TF_VAR_$var_name"="$var_value"
                    print_success "Set TF_VAR_$var_name"
                    ;;
            esac
        # Handle array values (for admin_group_object_ids, api_server_authorized_ip_ranges)
        elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*\[(.*)\][[:space:]]*$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"
            
            # Convert array to JSON format for Terraform
            var_value=$(echo "$var_value" | sed 's/[[:space:]]*//g; s/,$//; s/"/\\"/g')
            export "TF_VAR_$var_name"="[$var_value]"
            print_success "Set TF_VAR_$var_name (array)"
        fi
    done < "$file"
}

# Function to validate required environment variables
validate_env_vars() {
    local missing_vars=()
    
    # Check required Azure authentication variables
    [[ -z "$ARM_CLIENT_ID" ]] && missing_vars+=("ARM_CLIENT_ID")
    [[ -z "$ARM_CLIENT_SECRET" ]] && missing_vars+=("ARM_CLIENT_SECRET")
    [[ -z "$ARM_TENANT_ID" ]] && missing_vars+=("ARM_TENANT_ID")
    [[ -z "$ARM_SUBSCRIPTION_ID" ]] && missing_vars+=("ARM_SUBSCRIPTION_ID")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing required environment variables:"
        printf '%s\n' "${missing_vars[@]}" | sed 's/^/  - /'
        return 1
    fi
    
    print_success "All required environment variables are set"
    return 0
}

# Function to display current environment status
show_env_status() {
    print_message $BLUE "Current Environment Configuration:"
    echo "  ARM_CLIENT_ID:       ${ARM_CLIENT_ID:-<not set>}"
    echo "  ARM_CLIENT_SECRET:   ${ARM_CLIENT_SECRET:+<set (hidden)>}${ARM_CLIENT_SECRET:-<not set>}"
    echo "  ARM_TENANT_ID:       ${ARM_TENANT_ID:-<not set>}"
    echo "  ARM_SUBSCRIPTION_ID: ${ARM_SUBSCRIPTION_ID:-<not set>}"
    echo
    
    # Show additional Terraform variables if set
    if [[ -n "${TF_VAR_admin_group_object_ids:-}" ]]; then
        echo "  TF_VAR_admin_group_object_ids: ${TF_VAR_admin_group_object_ids}"
    fi
    if [[ -n "${TF_VAR_api_server_authorized_ip_ranges:-}" ]]; then
        echo "  TF_VAR_api_server_authorized_ip_ranges: ${TF_VAR_api_server_authorized_ip_ranges}"
    fi
}

# Function to test Azure authentication
test_azure_auth() {
    print_message $BLUE "Testing Azure authentication..."
    
    if command -v az >/dev/null 2>&1; then
        # Test with Azure CLI using environment variables
        if az account show --only-show-errors >/dev/null 2>&1; then
            local current_sub=$(az account show --query id -o tsv 2>/dev/null)
            local current_tenant=$(az account show --query tenantId -o tsv 2>/dev/null)
            
            if [[ "$current_sub" == "$ARM_SUBSCRIPTION_ID" ]] && [[ "$current_tenant" == "$ARM_TENANT_ID" ]]; then
                print_success "Azure CLI authentication matches environment variables"
            else
                print_warning "Azure CLI authentication differs from environment variables"
                print_message $YELLOW "  CLI Subscription: $current_sub"
                print_message $YELLOW "  ENV Subscription: $ARM_SUBSCRIPTION_ID"
            fi
        else
            print_warning "Azure CLI authentication failed or not logged in"
        fi
    else
        print_warning "Azure CLI not found - unable to test authentication"
    fi
}

# Function to create environment-specific secrets file
create_env_secrets() {
    local env="$1"
    local target_file="secrets.${env}.tfvars"
    
    if [[ -f "$target_file" ]]; then
        print_warning "File $target_file already exists"
        return 0
    fi
    
    print_message $BLUE "Creating environment-specific secrets file: $target_file"
    
    cat > "$target_file" << EOF
# =============================================================================
# ${env^^} ENVIRONMENT SECRETS - DO NOT COMMIT TO VERSION CONTROL
# =============================================================================

# =============================================================================
# AZURE AUTHENTICATION (Service Principal)
# =============================================================================

# Service Principal Authentication for ${env^^}
client_id       = "<YOUR CLIENT ID>"
client_secret   = "<YOUR CLIENT SECRET>"
tenant_id       = "<YOUR TENANT ID>"
subscription_id = "<your SUBSCRIPTION ID>"

# =============================================================================
# ${env^^} ENVIRONMENT CONFIGURATION
# =============================================================================

# Azure AD Group Object IDs for ${env^^} AKS Admin Access
admin_group_object_ids = [
  # "00000000-0000-0000-0000-000000000000",  # ${env^^} AKS Admins Group ID
]

# API Server Authorized IP Ranges for ${env^^}
api_server_authorized_ip_ranges = [
  # "YOUR_IP/32",        # Your current IP
  # "YOUR_VPN_RANGE/24", # Your VPN range
]
EOF
    
    print_success "Created $target_file"
    print_message $YELLOW "Remember to customize the values in $target_file"
}

# Function to show usage
show_usage() {
    cat << EOF
Environment Setup Script for Azure Terraform Deployment

USAGE:
    source ./scripts/setup-env.sh [SECRETS_FILE]

EXAMPLES:
    # Load default secrets file
    source ./scripts/setup-env.sh

    # Load production secrets
    source ./scripts/setup-env.sh secrets.prod.tfvars

    # Load development secrets  
    source ./scripts/setup-env.sh secrets.dev.tfvars

COMMANDS:
    # Create environment-specific secrets files
    ./scripts/setup-env.sh create-env dev
    ./scripts/setup-env.sh create-env prod
    ./scripts/setup-env.sh create-env staging

    # Show current environment status
    ./scripts/setup-env.sh status

    # Test authentication
    ./scripts/setup-env.sh test-auth

    # Show help
    ./scripts/setup-env.sh help

ENVIRONMENT VARIABLES SET:
    ARM_CLIENT_ID          - Service Principal Client ID
    ARM_CLIENT_SECRET      - Service Principal Client Secret
    ARM_TENANT_ID          - Azure AD Tenant ID
    ARM_SUBSCRIPTION_ID    - Azure Subscription ID
    TF_VAR_*              - Additional Terraform variables

NOTES:
    - This script should be sourced, not executed directly
    - Environment variables persist in your current shell session
    - Always keep secrets files secure and never commit them to Git

EOF
}

# Main execution
main() {
    # Handle special commands
    case "${1:-}" in
        "help"|"-h"|"--help")
            show_usage
            return 0
            ;;
        "status")
            show_env_status
            return 0
            ;;
        "test-auth")
            test_azure_auth
            return 0
            ;;
        "create-env")
            if [[ -z "${2:-}" ]]; then
                print_error "Environment name required"
                print_message $YELLOW "Usage: ./scripts/setup-env.sh create-env <env-name>"
                return 1
            fi
            create_env_secrets "$2"
            return 0
            ;;
    esac
    
    # Normal environment setup
    print_message $BLUE "================================================================================"
    print_message $BLUE "AZURE TERRAFORM ENVIRONMENT SETUP"
    print_message $BLUE "================================================================================"
    echo
    
    # Parse and set environment variables
    if parse_and_set_vars "$SECRETS_FILE"; then
        echo
        validate_env_vars
        echo
        show_env_status
        echo
        test_azure_auth
        echo
        print_message $GREEN "================================================================================"
        print_message $GREEN "ENVIRONMENT SETUP COMPLETE!"
        print_message $GREEN "================================================================================"
        echo
        print_message $YELLOW "Next steps:"
        print_message $YELLOW "1. Verify your secrets file contains correct values"
        print_message $YELLOW "2. Run: terraform init"
        print_message $YELLOW "3. Run: terraform plan -var-file=\"terraform.tfvars\" -var-file=\"$SECRETS_FILE\""
        print_message $YELLOW "4. Run: terraform apply -var-file=\"terraform.tfvars\" -var-file=\"$SECRETS_FILE\""
    else
        return 1
    fi
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
else
    # Script is being sourced
    main "$@"
fi