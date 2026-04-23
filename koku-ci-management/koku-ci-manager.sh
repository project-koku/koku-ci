#!/usr/bin/env bash

# Koku CI Management
# Script to simplify management of Koku CI scheduled test jobs
# Repository: koku-ci

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
NAMESPACE="cost-mgmt-dev-tenant"
KONFLUX_KUBECONFIG="$SCRIPT_DIR/konflux-cost-mgmt-dev.yaml"

# Job definitions: name -> "cronjob_name:scenario_name:description"
declare -A JOB_CRONJOB
declare -A JOB_SCENARIO
declare -A JOB_DESC

JOB_CRONJOB["standard"]="koku-scheduled-integration-test"
JOB_SCENARIO["standard"]="koku-scheduled-test-job"
JOB_DESC["standard"]="Standard daily smoke tests (2 AM UTC)"

JOB_CRONJOB["onprem"]="koku-onprem-scheduled-integration-test"
JOB_SCENARIO["onprem"]="koku-scheduled-onprem-test-job"
JOB_DESC["onprem"]="ONPREM=True daily validation (3 AM UTC, -m cost_ocp_on_prem)"

ALL_JOBS=("standard" "onprem")

# Set KUBECONFIG to use Konflux credentials
if [[ -f "$KONFLUX_KUBECONFIG" ]]; then
    export KUBECONFIG="$KONFLUX_KUBECONFIG"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_section() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# Resolve job key, accepting "standard", "onprem", or "all"
resolve_job() {
    local job="${1:-standard}"
    case "$job" in
        standard|onprem|all) echo "$job" ;;
        *)
            log_error "Unknown job: '$job'. Valid values: standard, onprem, all"
            exit 1
            ;;
    esac
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

# Check CronJob health for a single job key
check_cronjob_health_single() {
    local job="$1"
    local cronjob_name="${JOB_CRONJOB[$job]}"
    local desc="${JOB_DESC[$job]}"

    log_section "$job ($desc)"

    local last_schedule
    local last_success
    last_schedule=$(kubectl get cronjob "$cronjob_name" -n "$NAMESPACE" -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null || echo "")
    last_success=$(kubectl get cronjob "$cronjob_name" -n "$NAMESPACE" -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null || echo "")

    if [[ -z "$last_schedule" ]]; then
        log_warning "CronJob has never been executed"
        return 1
    fi

    if [[ -z "$last_success" ]]; then
        log_error "CronJob has been scheduled but NEVER succeeded!"
        log_info "Last scheduled: $last_schedule"
        return 1
    fi

    if [[ "$last_schedule" != "$last_success" ]]; then
        log_error "FAILURE DETECTED! Last scheduled job did not complete successfully"
        log_info "Last scheduled: $last_schedule"
        log_info "Last successful: $last_success"
        echo

        log_warning "Checking for recent failures..."
        local recent_events
        recent_events=$(kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | \
                       grep -E "(FailedCreatePodSandBox|Failed|Error|CrashLoopBackOff|ImagePullBackOff)" | \
                       grep "$cronjob_name" | tail -5 || true)

        if [[ -n "$recent_events" ]]; then
            echo "$recent_events"
        else
            log_info "No recent error events found (job may have been deleted)"
        fi

        return 1
    else
        log_success "Health: OK (last execution was successful)"
        log_info "Last scheduled:  $last_schedule"
        log_info "Last successful: $last_success"
        return 0
    fi
}

# Check health for one or all jobs
check_cronjob_health() {
    local job="${1:-all}"
    local exit_code=0

    if [[ "$job" == "all" ]]; then
        for j in "${ALL_JOBS[@]}"; do
            check_cronjob_health_single "$j" || exit_code=1
            echo
        done
    else
        check_cronjob_health_single "$job" || exit_code=1
    fi

    return $exit_code
}

# Show status for a single job
show_status_single() {
    local job="$1"
    local cronjob_name="${JOB_CRONJOB[$job]}"
    local desc="${JOB_DESC[$job]}"

    log_section "$job — $desc"

    local suspended
    suspended=$(kubectl get cronjob "$cronjob_name" -n "$NAMESPACE" -o jsonpath='{.spec.suspend}' 2>/dev/null || echo "false")
    if [[ "$suspended" == "true" ]]; then
        log_warning "⚠️  STATUS: SUSPENDED"
    else
        log_success "STATUS: ACTIVE"
    fi

    local schedule
    schedule=$(kubectl get cronjob "$cronjob_name" -n "$NAMESPACE" -o jsonpath='{.spec.schedule}' 2>/dev/null || echo "Not found")
    log_info "Schedule:        $schedule"

    local last_schedule
    last_schedule=$(kubectl get cronjob "$cronjob_name" -n "$NAMESPACE" -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null || echo "Never")
    log_info "Last execution:  $last_schedule"

    local last_success
    last_success=$(kubectl get cronjob "$cronjob_name" -n "$NAMESPACE" -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null || echo "Never")
    log_info "Last successful: $last_success"
}

# Show current status
show_status() {
    log_section "Koku CI Management Status"
    echo

    for j in "${ALL_JOBS[@]}"; do
        show_status_single "$j"
        echo
    done

    log_section "Recent Jobs"
    kubectl get jobs -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | tail -5

    echo
    log_section "Recent PipelineRuns"
    kubectl get pipelineruns -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | tail -5

    echo
    log_section "Running Pipelines"
    local running_pipelines
    running_pipelines=$(kubectl get pipelineruns -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[-1].reason}{"\n"}{end}' 2>/dev/null | grep -E '\tRunning$' | wc -l)
    if [[ "$running_pipelines" -gt 0 ]]; then
        log_info "Currently running: $running_pipelines pipeline(s)"
        kubectl get pipelineruns -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[-1].reason}{"\t"}{.status.startTime}{"\n"}{end}' 2>/dev/null | grep -E '\tRunning\t' | sort
    else
        log_info "No pipelines currently running"
    fi
}

# Trigger manual scheduled test job
trigger_manual() {
    local job
    job=$(resolve_job "${1:-standard}")

    local cronjob_name="${JOB_CRONJOB[$job]}"
    local desc="${JOB_DESC[$job]}"
    local run_name="koku-${job}-manual-run-$(date +%Y%m%d-%H%M%S)"

    log_info "Triggering manual job for: $job ($desc)"
    log_info "Job name: $run_name"

    kubectl get cronjob "$cronjob_name" -n "$NAMESPACE" -o json | \
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
      .metadata.name = "'"$run_name"'" |
      .spec = .spec.jobTemplate.spec' | \
    kubectl create -f -

    log_success "Manual job triggered: $run_name"
    log_info "Monitor with: kubectl get jobs -n $NAMESPACE --sort-by=.metadata.creationTimestamp"
}

# Show recent jobs
show_jobs() {
    local count=${1:-10}
    log_section "Last $count Jobs"
    kubectl get jobs -n "$NAMESPACE" -o=custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,CREATED:.metadata.creationTimestamp --sort-by=.metadata.creationTimestamp | tail -"$count"
}

# Show recent pipelines
show_pipelines() {
    local count=${1:-10}
    log_section "Last $count PipelineRuns"
    kubectl get pipelineruns -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | tail -"$count"

    echo
    log_section "Running Pipelines"
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

# Check if a CronJob is suspended
is_cronjob_suspended() {
    local cronjob_name="$1"
    local suspended
    suspended=$(kubectl get cronjob "$cronjob_name" -n "$NAMESPACE" -o jsonpath='{.spec.suspend}' 2>/dev/null || echo "false")
    [[ "$suspended" == "true" ]]
}

# Suspend one or all CronJobs
suspend_cronjob() {
    local job
    job=$(resolve_job "${1:-standard}")

    local jobs_to_act=()
    if [[ "$job" == "all" ]]; then
        jobs_to_act=("${ALL_JOBS[@]}")
    else
        jobs_to_act=("$job")
    fi

    for j in "${jobs_to_act[@]}"; do
        local cronjob_name="${JOB_CRONJOB[$j]}"
        if is_cronjob_suspended "$cronjob_name"; then
            log_warning "[$j] CronJob '$cronjob_name' is already suspended"
        else
            kubectl patch cronjob "$cronjob_name" -n "$NAMESPACE" \
                --type='merge' -p='{"spec":{"suspend":true}}'
            log_success "[$j] CronJob '$cronjob_name' SUSPENDED"
        fi
    done
}

# Resume one or all CronJobs
resume_cronjob() {
    local job
    job=$(resolve_job "${1:-standard}")

    local jobs_to_act=()
    if [[ "$job" == "all" ]]; then
        jobs_to_act=("${ALL_JOBS[@]}")
    else
        jobs_to_act=("$job")
    fi

    for j in "${jobs_to_act[@]}"; do
        local cronjob_name="${JOB_CRONJOB[$j]}"
        if ! is_cronjob_suspended "$cronjob_name"; then
            log_warning "[$j] CronJob '$cronjob_name' is already active"
        else
            kubectl patch cronjob "$cronjob_name" -n "$NAMESPACE" \
                --type='merge' -p='{"spec":{"suspend":false}}'
            log_success "[$j] CronJob '$cronjob_name' RESUMED"
        fi
    done
}

# Login to Konflux cluster
login_to_konflux() {
    log_info "Starting Konflux login process..."

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
Koku CI Management

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    login                   Login to Konflux cluster and switch to correct project
    health [job]            Check CronJob health (job: standard|onprem|all, default: all)
    status                  Show status for all scheduled jobs, recent jobs and pipelines
    suspend [job]           Suspend CronJob(s) (job: standard|onprem|all, default: standard)
    resume [job]            Resume CronJob(s) (job: standard|onprem|all, default: standard)
    trigger [job]           Trigger a manual run (job: standard|onprem, default: standard)
    jobs [count]            Show recent jobs (default: 10)
    pipelines [count]       Show recent PipelineRuns (default: 10)
    logs <job-name>         Show logs for a specific job
    watch                   Watch jobs in real-time
    pods <job-name>         Show pods for a specific job
    cleanup [days]          Clean up old jobs (default: 7 days)
    help                    Show this help message

SCHEDULED JOBS:
    standard   CronJob: ${JOB_CRONJOB[standard]}
               Scenario: ${JOB_SCENARIO[standard]}
               ${JOB_DESC[standard]}

    onprem     CronJob: ${JOB_CRONJOB[onprem]}
               Scenario: ${JOB_SCENARIO[onprem]}
               ${JOB_DESC[onprem]}

EXAMPLES:
    $0 login                        # Login to Konflux cluster
    $0 status                       # Show status for both jobs
    $0 health                       # Check health of both jobs
    $0 health onprem                # Check health of the ONPREM job only
    $0 trigger                      # Trigger standard job manually
    $0 trigger onprem               # Trigger ONPREM job manually
    $0 suspend all                  # Suspend both jobs (e.g., for holidays)
    $0 resume all                   # Resume both jobs
    $0 suspend onprem               # Suspend only the ONPREM job
    $0 jobs 5                       # Show last 5 jobs
    $0 pipelines 5                  # Show last 5 PipelineRuns
    $0 logs koku-standard-manual-run-20250421-1430
    $0 watch                        # Watch jobs in real-time
    $0 cleanup 14                   # Clean up jobs older than 14 days

NAMESPACE: $NAMESPACE
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
        "health")
            check_prerequisites
            check_cronjob_health "${2:-all}"
            ;;
        "status")
            check_prerequisites
            show_status
            ;;
        "suspend")
            check_prerequisites
            suspend_cronjob "${2:-standard}"
            ;;
        "resume")
            check_prerequisites
            resume_cronjob "${2:-standard}"
            ;;
        "trigger")
            check_prerequisites
            trigger_manual "${2:-standard}"
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
            show_logs "${2:-}"
            ;;
        "watch")
            check_prerequisites
            watch_jobs
            ;;
        "pods")
            check_prerequisites
            show_pods "${2:-}"
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
