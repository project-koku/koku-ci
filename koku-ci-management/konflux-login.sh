#!/usr/bin/env bash

# Konflux / OpenShift login helper for Koku CI Management.
# Uses direct cluster access (stone-prd-rh01), not the Konflux OIDC exec kubeconfig.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEFAULT_PROJECT="cost-mgmt-dev-tenant"
KONFLUX_KUBECONFIG="$SCRIPT_DIR/konflux-cost-mgmt-dev.yaml"
KONFLUX_SERVER="https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443"
AUTH_CHECK_TIMEOUT="${AUTH_CHECK_TIMEOUT:-10}"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
Konflux Login Helper

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -p, --project PROJECT    Namespace to switch to (default: cost-mgmt-dev-tenant)
    -h, --help               Show this help message

EXAMPLES:
    $0
    $0 -p cost-mgmt-dev-tenant

After login, in the same terminal:
    eval \$(make env)

REPOSITORY: koku-ci
EOF
}

parse_args() {
    local project="$DEFAULT_PROJECT"

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
                show_help
                exit 1
                ;;
        esac
    done

    echo "$project"
}

check_oc() {
    if ! command -v oc &> /dev/null; then
        log_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
}

# Run a command with a timeout (macOS-compatible: perl if GNU timeout is missing).
run_with_timeout() {
    local seconds="$1"
    shift

    if command -v timeout &> /dev/null; then
        timeout "$seconds" "$@"
        return $?
    fi

    if command -v gtimeout &> /dev/null; then
        gtimeout "$seconds" "$@"
        return $?
    fi

    perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
}

uses_oidc_exec_kubeconfig() {
    [[ -f "$KONFLUX_KUBECONFIG" ]] && grep -q 'oidc-login' "$KONFLUX_KUBECONFIG" 2>/dev/null
}

ensure_kubeconfig() {
    if uses_oidc_exec_kubeconfig; then
        log_warning "Detected legacy Konflux OIDC kubeconfig (kubectl oidc-login can hang)."
        log_info "Resetting to direct cluster kubeconfig template..."
        cp "$KONFLUX_KUBECONFIG" "${KONFLUX_KUBECONFIG}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi

    if [[ ! -f "$KONFLUX_KUBECONFIG" ]] || uses_oidc_exec_kubeconfig; then
        cat > "$KONFLUX_KUBECONFIG" << 'EOF'
apiVersion: v1
kind: Config
clusters:
  - name: stone-prd-rh01
    cluster:
      server: https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443
contexts:
  - name: cost-mgmt-dev-tenant
    context:
      cluster: stone-prd-rh01
      namespace: cost-mgmt-dev-tenant
      user: default
current-context: cost-mgmt-dev-tenant
users:
  - name: default
    user: {}
EOF
        log_success "Wrote kubeconfig template: $KONFLUX_KUBECONFIG"
    fi

    export KUBECONFIG="$KONFLUX_KUBECONFIG"
    log_info "KUBECONFIG set to: $KUBECONFIG"
}

auth_ok() {
    run_with_timeout "$AUTH_CHECK_TIMEOUT" oc whoami >/dev/null 2>&1
}

login_to_cluster() {
    log_info "Checking authentication status (timeout: ${AUTH_CHECK_TIMEOUT}s)..."

    if auth_ok; then
        log_success "Already authenticated as: $(oc whoami)"
        return 0
    fi

    log_info "Not authenticated. Starting web login to: $KONFLUX_SERVER"
    if oc login --web --server="$KONFLUX_SERVER"; then
        log_success "Successfully logged in!"
    else
        log_error "Login failed. Try manually:"
        log_info "  export KUBECONFIG=\"$KONFLUX_KUBECONFIG\""
        log_info "  oc login --web --server=$KONFLUX_SERVER"
        exit 1
    fi
}

switch_to_project() {
    local project="$1"

    log_info "Switching to project: $project"
    if oc project "$project" >/dev/null 2>&1; then
        log_success "Switched to project: $project"
    else
        log_warning "Failed to switch to project: $project"
        log_info "Available projects:"
        oc projects --short 2>/dev/null | head -15 || true
    fi
}

show_status() {
    log_info "=== Current Status ==="
    echo "User: $(oc whoami 2>/dev/null || echo 'Not logged in')"
    echo "Project: $(oc project --short 2>/dev/null || echo 'No project selected')"
    echo "Server: $(oc whoami --show-server 2>/dev/null || echo 'Not connected')"
    echo "KUBECONFIG: $KUBECONFIG"
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi

    check_oc
    local project
    project=$(parse_args "$@")

    log_info "=== Konflux Login Helper ==="
    log_info "Project: $project"
    echo

    ensure_kubeconfig
    login_to_cluster
    switch_to_project "$project"

    echo
    show_status

    log_success "Ready to use the cluster!"
    log_info "In this terminal, run:"
    echo
    printf '  eval $(make env)\n'
    echo
}

main "$@"
