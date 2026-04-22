# Koku CI Management
# Makefile to simplify Koku CI management operations
# Repository: koku-ci

.PHONY: help login env health status suspend resume trigger jobs pipelines logs watch pods cleanup

# Job selector: standard | onprem | all (default: standard for mutating ops, all for read ops)
JOB ?= standard

# Default target
help:
	@./koku-ci-manager.sh help

# Login to Konflux cluster
login:
	@./koku-ci-manager.sh login

# Print KUBECONFIG export for current shell. After 'make login', run: eval $(make env)
# so oc/kubectl in this terminal use Konflux instead of the default kubeconfig.
env:
	@echo 'export KUBECONFIG="$(CURDIR)/konflux-cost-mgmt-dev.yaml"'

# Check CronJob health (both jobs by default)
# Usage: make health              # check both
#        make health JOB=onprem  # check onprem only
health:
	@./koku-ci-manager.sh health $(JOB)

# Show current status for all scheduled jobs
status:
	@./koku-ci-manager.sh status

# Suspend scheduled job(s)
# Usage: make suspend             # suspend standard job
#        make suspend JOB=onprem # suspend onprem job
#        make suspend JOB=all    # suspend both (e.g. for holidays)
suspend:
	@./koku-ci-manager.sh suspend $(JOB)

# Resume scheduled job(s)
# Usage: make resume             # resume standard job
#        make resume JOB=onprem # resume onprem job
#        make resume JOB=all    # resume both
resume:
	@./koku-ci-manager.sh resume $(JOB)

# Trigger a manual run
# Usage: make trigger             # trigger standard job
#        make trigger JOB=onprem # trigger onprem job
trigger:
	@./koku-ci-manager.sh trigger $(JOB)

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
