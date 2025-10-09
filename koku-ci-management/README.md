# Koku CI Management

This directory contains tools to manage Koku CI scheduled test jobs (integration tests) that run automatically every Saturday at 2 AM UTC.

## Configuration

**No configuration needed!** Everything is pre-configured and ready to use.

The scripts use the following default settings:
- **Namespace**: `cost-mgmt-dev-tenant`
- **CronJob**: `koku-scheduled-integration-test`
- **Test Scenario**: `koku-scheduled-test-job`
- **Kubeconfig**: `konflux-cost-mgmt-dev.yaml` (included in repository)

> **Note**: The `konflux-cost-mgmt-dev.yaml` file is tracked in git but ignored for local changes. This prevents accidentally committing sensitive tokens that are added during authentication. The file will be modified locally when you login, but these changes won't be staged for commit.

## Login to Konflux

**Always login to Konflux cluster before using any commands.**
A browser window will open to complete the login process.

### Using Make
```bash
# Navigate to the koku-ci-management directory
cd koku-ci-management

# Login to Konflux cluster
make login

# Login to Konflux with specific project
make login -p koku-dev-tenant
```


### Login Helper Options
```bash
# Login to Konflux with default project
./konflux-login.sh

# Show help
./konflux-login.sh --help
```

### Available Commands (Using Make)
```bash
# Show current status
make status

# Trigger manual scheduled test job
make trigger

# Show recent jobs
make jobs

# Show recent pipeline runs
make pipelines

# Show logs for most recent job
make logs

# Watch jobs in real-time
make watch

# Clean up jobs older than 7 days
make cleanup
```

### Using Script Directly
```bash
# Show help
./koku-ci-manager.sh help

# Show current status
./koku-ci-manager.sh status

# Trigger manual build
./koku-ci-manager.sh trigger

# Show last 5 jobs
./koku-ci-manager.sh jobs 5

# Show logs for specific job
./koku-ci-manager.sh logs koku-manual-run-20250127-1430
```

## What It Does

The scheduled test job system:

1. **Automatically runs** every Saturday at 2 AM UTC via CronJob
2. **Finds the latest released snapshot** of the Koku component
3. **Triggers integration tests** against that snapshot
4. **Validates** that the system is working correctly




## Troubleshooting

### Check if CronJob is Working
```bash
kubectl get cronjob koku-scheduled-integration-test -n cost-mgmt-dev-tenant
```

### View Recent Jobs
```bash
kubectl get jobs -n cost-mgmt-dev-tenant --sort-by=.metadata.creationTimestamp
```

### Check Job Logs
```bash
kubectl logs job/<job-name> -n cost-mgmt-dev-tenant
```

### Common Issues

1. **Not Logged In**: If you get authentication errors, run `make login` first
2. **Kubeconfig Missing**: If you get "kubeconfig file not found", create the kubeconfig file with OIDC configuration
4. **No Snapshots**: If no valid snapshots are found, check if the Koku component has been built and released recently
5. **Permission Issues**: Ensure you're logged in with proper permissions using `make login`



## Related Documentation

- [Konflux Integration Testing](https://konflux-ci.dev/docs/testing/integration/rerunning/)
- [Koku CI Repository](../README.md)
- [Konflux Release Data](https://github.com/redhat-appstudio/konflux-release-data)

