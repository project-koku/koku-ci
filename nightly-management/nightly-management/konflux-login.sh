#!/usr/bin/env bash

# Konflux Login Helper
# Script to simplify login to Konflux cluster and project selection
# Repository: koku-ci
# Author: Cost Management Team

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

# Load .env file if it exists
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

# Default values (can be overridden by .env)
DEFAULT_ENV="${DEFAULT_ENV:-konflux}"
DEFAULT_PROJECT="${DEFAULT_PROJECT:-cost-mgmt-dev-tenant}"
KONFLUX_URL="${KONFLUX_URL:-https://YOUR-KONFLUX-CLUSTER:6443/}"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show help
show_help() {
    cat << EOF
Konflux Login Helper

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV    Environment to connect to (default: konflux)
    -p, --project PROJECT    Project/namespace to switch to (default: cost-mgmt-dev-tenant)
    -h, --help              Show this help message

ENVIRONMENTS:
    konflux                 Konflux production cluster (default)
    ephemeral               Ephemeral environment
    stage                   Stage environment  
    prod                    Production environment

EXAMPLES:
    $0                                    # Login to Konflux, switch to cost-mgmt-dev-tenant
    $0 -p koku-dev-tenant                 # Login to Konflux, switch to koku-dev-tenant
    $0 -e stage -p my-project             # Login to stage, switch to my-project
    $0 --environment prod --project prod-tenant

DEFAULT BEHAVIOR:
    - Environment: $DEFAULT_ENV
    - Project: $DEFAULT_PROJECT
    - URL: $KONFLUX_URL

REPOSITORY: koku-ci
TEAM: Cost Management

EOF
}

# Parse command line arguments
parse_args() {
    local env="$DEFAULT_ENV"
    local project="$DEFAULT_PROJECT"
    
    # Handle help first
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                env="$2"
                shift 2
                ;;
            -p|--project)
                project="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "$env|$project"
}

# Get URL for environment
get_url() {
    local env="$1"
    case $env in
        ephemeral) echo "${EPHEMERAL_URL:-https://YOUR-EPHEMERAL-CLUSTER:6443}" ;;
        stage) echo "${STAGE_URL:-https://YOUR-STAGE-CLUSTER:6443}" ;;
        prod) echo "${PROD_URL:-https://YOUR-PROD-CLUSTER:6443}" ;;
        konflux) echo "$KONFLUX_URL" ;;
        *)
            log_error "Invalid environment: $env"
            log_info "Valid environments: ephemeral, stage, prod, konflux"
            exit 1
            ;;
    esac
}

# Set KUBECONFIG for environment
set_kubeconfig() {
    local env="$1"
    case $env in
        konflux)
            export KUBECONFIG="${KONFLUX_KUBECONFIG:-/Users/lucasbacciotti/development/konflux/konflux-cost-mgmt-dev.yaml}"
            ;;
        *)
            export KUBECONFIG=~/.kube/$env.yml
            ;;
    esac
    log_info "KUBECONFIG set to: $KUBECONFIG"
}

# Check if oc is available
check_oc() {
    if ! command -v oc &> /dev/null; then
        log_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
}

# Login to cluster
login_to_cluster() {
    local url="$1"
    
    log_info "Checking authentication status..."
    
    if oc whoami > /dev/null 2>&1; then
        local current_user
        current_user=$(oc whoami)
        log_success "Already authenticated as: $current_user"
    else
        log_info "Not authenticated. Starting web login..."
        log_info "URL: $url"
        
        if oc login --web --server="$url"; then
            log_success "Successfully logged in!"
        else
            log_error "Login failed"
            exit 1
        fi
    fi
}

# Switch to project
switch_to_project() {
    local project="$1"
    
    log_info "Switching to project: $project"
    
    if oc project "$project" > /dev/null 2>&1; then
        log_success "Switched to project: $project"
    else
        log_warning "Failed to switch to project: $project"
        log_info "Available projects:"
        oc projects --short | head -10
        log_info "You can manually switch with: oc project <project-name>"
    fi
}

# Show current status
show_status() {
    log_info "=== Current Status ==="
    echo "User: $(oc whoami 2>/dev/null || echo 'Not logged in')"
    echo "Project: $(oc project --short 2>/dev/null || echo 'No project selected')"
    echo "Server: $(oc whoami --show-server 2>/dev/null || echo 'Not connected')"
    echo "KUBECONFIG: $KUBECONFIG"
}

# Main function
main() {
    # Handle help first
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    check_oc
    
    # Parse arguments
    local args
    args=$(parse_args "$@")
    local env="${args%%|*}"
    local project="${args##*|}"
    
    log_info "=== Konflux Login Helper ==="
    log_info "Environment: $env"
    log_info "Project: $project"
    echo
    
    # Get URL and set KUBECONFIG
    local url
    url=$(get_url "$env")
    set_kubeconfig "$env"
    
    # Login to cluster
    login_to_cluster "$url"
    
    # Switch to project
    switch_to_project "$project"
    
    echo
    show_status
    
    log_success "Ready to use Konflux cluster!"
    log_info "You can now run nightly build commands:"
    log_info "  make status"
    log_info "  make trigger"
    log_info "  make logs"
}

# Run main function with all arguments
main "$@"
