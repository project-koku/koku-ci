#!/usr/bin/env bash

# Konflux Login Helper
# Script to simplify login to Konflux cluster
# Repository: koku-ci

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEFAULT_PROJECT="cost-mgmt-dev-tenant"
KONFLUX_KUBECONFIG="$SCRIPT_DIR/konflux-cost-mgmt-dev.yaml"

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
    -p, --project PROJECT    Project/namespace to switch to (default: cost-mgmt-dev-tenant)
    -h, --help              Show this help message

EXAMPLES:
    $0                                    # Login to Konflux, switch to cost-mgmt-dev-tenant
    $0 -p koku-dev-tenant                 # Login to Konflux, switch to koku-dev-tenant

DEFAULT BEHAVIOR:
    - Project: $DEFAULT_PROJECT
    - Kubeconfig: $KONFLUX_KUBECONFIG

REPOSITORY: koku-ci
TEAM: Cost Management

EOF
}

# Parse command line arguments
parse_args() {
    local project="$DEFAULT_PROJECT"
    
    # Handle help first
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
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
    
    echo "$project"
}

# Check if oc is available
check_oc() {
    if ! command -v oc &> /dev/null; then
        log_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
}

# Set KUBECONFIG for Konflux
set_kubeconfig() {
    if [[ ! -f "$KONFLUX_KUBECONFIG" ]]; then
        log_error "Kubeconfig file not found: $KONFLUX_KUBECONFIG"
        log_info "The kubeconfig file should be in the same directory as this script."
        exit 1
    fi
    
    export KUBECONFIG="$KONFLUX_KUBECONFIG"
    log_info "KUBECONFIG set to: $KUBECONFIG"
}

# Login to Konflux cluster
login_to_konflux() {
    log_info "Checking authentication status..."
    
    # Check if already authenticated
    if oc whoami >/dev/null 2>&1; then
        local current_user
        current_user=$(oc whoami)
        log_success "Already authenticated as: $current_user"
    else
        log_info "Not authenticated. Starting web login..."
        
        # Use oc login --web like the working oc-login function
        local server_url="https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443"
        log_info "Opening browser for authentication to: $server_url"
        
        if oc login --web --server="$server_url"; then
            log_success "Successfully logged in!"
        else
            log_error "Login failed. Please try again."
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
    local project
    project=$(parse_args "$@")
    
    log_info "=== Konflux Login Helper ==="
    log_info "Project: $project"
    echo
    
    # Set KUBECONFIG
    set_kubeconfig
    
    # Login to cluster
    login_to_konflux
    
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