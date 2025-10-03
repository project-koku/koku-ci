# Koku Nightly Build Management
# Makefile to simplify nightly build operations
# Repository: koku-ci

.PHONY: help login status trigger jobs logs watch pods cleanup

# Default target
help:
	@echo "Koku Nightly Build Management"
	@echo "============================="
	@echo ""
	@echo "Available targets:"
	@echo "  login      - Login to Konflux cluster and switch to correct project"
	@echo "  status     - Show current CronJob status and recent jobs"
	@echo "  trigger    - Trigger a manual nightly build"
	@echo "  jobs       - Show recent jobs (last 10)"
	@echo "  logs       - Show logs for the most recent job"
	@echo "  watch      - Watch jobs in real-time"
	@echo "  pods       - Show pods for the most recent job"
	@echo "  cleanup    - Clean up old jobs (older than 7 days)"
	@echo ""
	@echo "Examples:"
	@echo "  make login"
	@echo "  make status"
	@echo "  make trigger"
	@echo "  make logs"
	@echo ""
	@echo "Repository: koku-ci"
	@echo "Team: Cost Management"

# Login to Konflux cluster
login:
	@./koku-nightly-manager.sh login

# Show current status
status:
	@./koku-nightly-manager.sh status

# Trigger manual nightly build
trigger:
	@./koku-nightly-manager.sh trigger

# Show recent jobs
jobs:
	@./koku-nightly-manager.sh jobs

# Show logs for most recent job
logs:
	@./koku-nightly-manager.sh logs $$(kubectl get jobs -n cost-mgmt-dev-tenant --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "")

# Watch jobs in real-time
watch:
	@./koku-nightly-manager.sh watch

# Show pods for most recent job
pods:
	@./koku-nightly-manager.sh pods $$(kubectl get jobs -n cost-mgmt-dev-tenant --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "")

# Clean up old jobs
cleanup:
	@./koku-nightly-manager.sh cleanup
