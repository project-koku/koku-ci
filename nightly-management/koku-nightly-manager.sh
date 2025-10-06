#!/usr/bin/env bash

# Koku Nightly Build Manager
# Script to simplify management of Koku nightly smoke tests
# Repository: koku-ci

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
NAMESPACE="cost-mgmt-dev-tenant"
CRONJOB_NAME="koku-scheduled-integration-test"
TEST_SCENARIO_NAME="koku-scheduled-test-job"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if kubectl is available and user is logged in
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi

    if ! kubectl auth can-i get pods -n "$NAMESPACE" &> /dev/null; then
        log_error "You don't have access to namespace $NAMESPACE or you're not logged in"
        log_info "Please run one of the following:"
        log_info "  ./konflux-login.sh                    # Login to Konflux with default project"
        log_info "  ./konflux-login.sh -p $NAMESPACE      # Login to Konflux with specific project"
        log_info "  oc login --web                        # Manual login"
        exit 1
    fi
}

# Show current status
show_status() {
    log_info "=== Koku Nightly Build Status ==="
    echo
    
    # CronJob schedule
    local schedule
    schedule=$(kubectl get cronjob "$CRONJOB_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.schedule}' 2>/dev/null || echo "Not found")
    log_info "Schedule: $schedule"
    
    # Last execution
    local last_schedule
    last_schedule=$(kubectl get cronjob "$CRONJOB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null || echo "Never")
    log_info "Last execution: $last_schedule"
    
    # Active jobs
    local active_jobs
    active_jobs=$(kubectl get cronjob "$CRONJOB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.active}' 2>/dev/null || echo "0")
    log_info "Active jobs: $active_jobs"
    
    echo
    log_info "=== Recent Jobs ==="
    kubectl get jobs -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | tail -5
    
    echo
    log_info "=== Recent PipelineRuns ==="
    kubectl get pipelineruns -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | tail -5
    
    echo
    log_info "=== Running Pipelines ==="
    local running_pipelines
    running_pipelines=$(kubectl get pipelineruns -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[-1].reason}{"\n"}{end}' 2>/dev/null | grep -E '\tRunning$' | wc -l)
    if [[ "$running_pipelines" -gt 0 ]]; then
        log_info "Currently running: $running_pipelines pipeline(s)"
        kubectl get pipelineruns -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[-1].reason}{"\t"}{.status.startTime}{"\n"}{end}' 2>/dev/null | grep -E '\tRunning\t' | sort
    else
        log_info "No pipelines currently running"
    fi
}

# Trigger manual nightly build
trigger_manual() {
    local job_name="koku-manual-run-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Triggering manual nightly build: $job_name"
    
    # Use the complex command from documentation
    kubectl get cronjob "$CRONJOB_NAME" -n "$NAMESPACE" -o json | \
    jq 'del(
        .metadata.ownerReferences,
        .metadata.uid,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.managedFields,
        .metadata.annotations,
        .metadata.labels,
        .status
      ) |
      .kind = "Job" |
      .apiVersion = "batch/v1" |
      .metadata.name = "'"$job_name"'" |
      .spec = .spec.jobTemplate.spec' | \
    kubectl create -f -
    
    log_success "Manual nightly build triggered: $job_name"
    log_info "You can monitor it with: kubectl get jobs -n $NAMESPACE --sort-by=.metadata.creationTimestamp"
}

# Show recent jobs
show_jobs() {
    local count=${1:-10}
    log_info "=== Last $count Jobs ==="
    kubectl get jobs -n "$NAMESPACE" -o=custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,CREATED:.metadata.creationTimestamp --sort-by=.metadata.creationTimestamp | tail -"$count"
}

# Show recent pipelines
show_pipelines() {
    local count=${1:-10}
    log_info "=== Last $count PipelineRuns ==="
    kubectl get pipelineruns -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | tail -"$count"
    
    echo
    log_info "=== Running Pipelines ==="
    local running_pipelines
    running_pipelines=$(kubectl get pipelineruns -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[-1].reason}{"\n"}{end}' 2>/dev/null | grep -E '\tRunning$' | wc -l)
    if [[ "$running_pipelines" -gt 0 ]]; then
        log_info "Currently running: $running_pipelines pipeline(s)"
        kubectl get pipelineruns -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[-1].reason}{"\t"}{.status.startTime}{"\n"}{end}' 2>/dev/null | grep -E '\tRunning\t' | sort
    else
        log_info "No pipelines currently running"
    fi
}

# Show job logs
show_logs() {
    local job_name="$1"
    
    if [[ -z "$job_name" ]]; then
        log_error "Please provide a job name"
        log_info "Available jobs:"
        kubectl get jobs -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | tail -5
        exit 1
    fi
    
    log_info "Showing logs for job: $job_name"
    kubectl logs job/"$job_name" -n "$NAMESPACE" --tail=50
}

# Watch jobs
watch_jobs() {
    log_info "Watching jobs (press Ctrl+C to stop)..."
    kubectl get jobs -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp --watch
}

# Show pods for a specific job
show_pods() {
    local job_name="$1"
    
    if [[ -z "$job_name" ]]; then
        log_error "Please provide a job name"
        exit 1
    fi
    
    log_info "Pods for job: $job_name"
    kubectl get pods -n "$NAMESPACE" --selector=job-name="$job_name"
}

# Clean up old jobs
cleanup_jobs() {
    local days=${1:-7}
    log_info "Cleaning up jobs older than $days days..."
    
    # Get jobs older than specified days
    local old_jobs
    old_jobs=$(kubectl get jobs -n "$NAMESPACE" -o json | \
               jq -r --arg days "$days" '
                 .items[] | 
                 select(.metadata.creationTimestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime < (now - ($days | tonumber) * 86400)) |
                 .metadata.name')
    
    if [[ -z "$old_jobs" ]]; then
        log_info "No old jobs found to clean up"
        return
    fi
    
    echo "$old_jobs" | while read -r job; do
        if [[ -n "$job" ]]; then
            log_info "Deleting job: $job"
            kubectl delete job "$job" -n "$NAMESPACE" --ignore-not-found=true
        fi
    done
    
    log_success "Cleanup completed"
}

# Login to Konflux cluster
login_to_konflux() {
    log_info "Starting Konflux login process..."
    
    # Check if konflux-login.sh exists
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    local login_script="$script_dir/konflux-login.sh"
    
    if [[ -f "$login_script" ]]; then
        log_info "Using konflux-login.sh helper script..."
        "$login_script" -p "$NAMESPACE"
    else
        log_warning "konflux-login.sh not found, using manual login..."
        log_info "Please run: oc login --web"
        log_info "Then switch to project: oc project $NAMESPACE"
    fi
}

# Show help
show_help() {
    cat << EOF
Koku Nightly Build Manager

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    login               Login to Konflux cluster and switch to correct project
    status              Show current CronJob status, recent jobs and pipelines
    trigger             Trigger a manual nightly build
    jobs [count]        Show recent jobs (default: 10)
    pipelines [count]   Show recent PipelineRuns (default: 10)
    logs <job-name>     Show logs for a specific job
    watch               Watch jobs in real-time
    pods <job-name>     Show pods for a specific job
    cleanup [days]      Clean up old jobs (default: 7 days)
    help                Show this help message

EXAMPLES:
    $0 login                     # Login to Konflux cluster
    $0 status                    # Show current status
    $0 trigger                   # Trigger manual build
    $0 jobs 5                    # Show last 5 jobs
    $0 pipelines 5               # Show last 5 PipelineRuns
    $0 logs koku-manual-run-123  # Show logs for specific job
    $0 watch                     # Watch jobs in real-time
    $0 cleanup 14                # Clean up jobs older than 14 days

QUICK REFERENCE:
    Schedule: Weekly on Saturdays at 2 AM UTC
    CronJob: $CRONJOB_NAME
    Test Scenario: $TEST_SCENARIO_NAME
    Namespace: $NAMESPACE

REPOSITORY: koku-ci
TEAM: Cost Management

EOF
}

# Main function
main() {
    case "${1:-help}" in
        "login")
            login_to_konflux
            ;;
        "status")
            check_prerequisites
            show_status
            ;;
        "trigger")
            check_prerequisites
            trigger_manual
            ;;
        "jobs")
            check_prerequisites
            show_jobs "${2:-10}"
            ;;
        "pipelines")
            check_prerequisites
            show_pipelines "${2:-10}"
            ;;
        "logs")
            check_prerequisites
            show_logs "$2"
            ;;
        "watch")
            check_prerequisites
            watch_jobs
            ;;
        "pods")
            check_prerequisites
            show_pods "$2"
            ;;
        "cleanup")
            check_prerequisites
            cleanup_jobs "${2:-7}"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
