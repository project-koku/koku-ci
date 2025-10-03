# Koku Nightly Build Management

This directory contains tools to manage Koku nightly smoke tests (integration tests) that run automatically every Saturday at 2 AM UTC.

## Login to Konflux

**First step: Always login to Konflux cluster before using any commands.**

### Using Make (Recommended)
```bash
# Navigate to the nightly-management directory
cd nightly-management

# Login to Konflux cluster
make login
```

### Using Script Directly
```bash
# Login to Konflux with default project (cost-mgmt-dev-tenant)
./koku-nightly-manager.sh login

# Or use the dedicated login helper
./konflux-login.sh
```

### Login Helper Options
```bash
# Login to Konflux with default project
./konflux-login.sh

# Login to Konflux with specific project
./konflux-login.sh -p koku-dev-tenant

# Login to different environment
./konflux-login.sh -e stage -p my-project

# Show help
./konflux-login.sh --help
```

## Quick Start

After logging in, you can use these commands:

### Using Make (Recommended)
```bash
# Show current status
make status

# Trigger manual nightly build
make trigger

# Show recent jobs
make jobs

# Show logs for most recent job
make logs

# Watch jobs in real-time
make watch
```

### Using Script Directly
```bash
# Show help
./koku-nightly-manager.sh help

# Show current status
./koku-nightly-manager.sh status

# Trigger manual build
./koku-nightly-manager.sh trigger

# Show last 5 jobs
./koku-nightly-manager.sh jobs 5

# Show logs for specific job
./koku-nightly-manager.sh logs koku-manual-run-20250127-1430
```

## What It Does

The nightly build system:

1. **Automatically runs** every Saturday at 2 AM UTC via CronJob
2. **Finds the latest released snapshot** of the Koku component
3. **Triggers integration tests** against that snapshot
4. **Validates** that the system is working correctly

## Manual Operations

### Login to Konflux
```bash
# Using make (recommended)
make login

# Using script directly
./koku-nightly-manager.sh login

# Using login helper
./konflux-login.sh
```

### Trigger Manual Build
```bash
make trigger
# or
./koku-nightly-manager.sh trigger
```

### Monitor Execution
```bash
# Watch jobs in real-time
make watch

# Check status
make status

# View logs
make logs
```

### Cleanup Old Jobs
```bash
# Clean up jobs older than 7 days
make cleanup

# Clean up jobs older than 14 days
./koku-nightly-manager.sh cleanup 14
```

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
2. **ServiceAccount Missing**: If jobs fail with "serviceaccount not found", the `koku-pull` ServiceAccount might be missing
3. **No Snapshots**: If no valid snapshots are found, check if the Koku component has been built and released recently
4. **Permission Issues**: Ensure you're logged in with proper permissions using `make login`

## Configuration

The nightly build configuration is managed in the `konflux-release-data` repository:

- **CronJob**: `koku-scheduled-integration-test`
- **ServiceAccount**: `koku-pull`
- **Test Scenario**: `koku-scheduled-test-job`
- **Namespace**: `cost-mgmt-dev-tenant`

## Schedule

- **Frequency**: Weekly
- **Day**: Saturdays
- **Time**: 2:00 AM UTC
- **Cron Expression**: `0 2 * * 6`

## Related Documentation

- [Konflux Integration Testing](https://konflux-ci.dev/docs/testing/integration/rerunning/)
- [Koku CI Repository](../README.md)
- [Konflux Release Data](https://github.com/redhat-appstudio/konflux-release-data)

## Team Information

- **Repository**: koku-ci
- **Team**: Cost Management
- **Maintainers**: Cost Management Team
