# Koku CI Management
# Makefile to simplify Koku CI management operations
# Repository: koku-ci

.PHONY: help login status trigger jobs pipelines logs watch pods cleanup

# Default target
help:
	@echo "Koku CI Management"
	@echo "============================="
	@echo ""
	@echo "Available targets:"
	@echo "  login      - Login to Konflux cluster and switch to correct project"
	@echo "  status     - Show current CronJob status, recent jobs and pipelines"
	@echo "  trigger    - Trigger a manual scheduled test job"
	@echo "  jobs       - Show recent jobs (last 10)"
	@echo "  pipelines  - Show recent PipelineRuns (last 10)"
	@echo "  logs       - Show logs for the most recent job"
	@echo "  watch      - Watch jobs in real-time"
	@echo "  pods       - Show pods for the most recent job"
	@echo "  cleanup    - Clean up old jobs (older than 7 days)"
	@echo ""
	@echo "Examples:"
	@echo "  make login"
	@echo "  make status"
	@echo "  make trigger"
	@echo "  make pipelines"
	@echo "  make logs"
	@echo ""
	@echo "Repository: koku-ci"
	@echo "Team: Cost Management"

# Login to Konflux cluster
login:
	@./koku-ci-manager.sh login

# Show current status
status:
	@./koku-ci-manager.sh status

# Trigger manual scheduled test job
trigger:
	@./koku-ci-manager.sh trigger

# Show recent jobs
jobs:
	@./koku-ci-manager.sh jobs

# Show recent pipelines
pipelines:
	@./koku-ci-manager.sh pipelines

# Show logs for most recent job
logs:
	@./koku-ci-manager.sh logs $$(kubectl get jobs -n cost-mgmt-dev-tenant --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "")

# Watch jobs in real-time
watch:
	@./koku-ci-manager.sh watch

# Show pods for most recent job
pods:
	@./koku-ci-manager.sh pods $$(kubectl get jobs -n cost-mgmt-dev-tenant --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "")

# Clean up old jobs
cleanup:
	@./koku-ci-manager.sh cleanup
