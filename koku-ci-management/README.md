# Koku CI Management

This directory contains tools to manage Koku CI scheduled test jobs that run automatically every day.

## Scheduled Jobs

| Job | CronJob | Schedule | Description |
|-----|---------|----------|-------------|
| `standard` | `koku-scheduled-integration-test` | 2 AM UTC daily | Standard daily smoke tests |
| `onprem` | `koku-onprem-scheduled-integration-test` | 3 AM UTC daily | ONPREM=True validation (`-m cost_ocp_on_prem`) |

## Configuration

**No configuration needed!** Everything is pre-configured and ready to use.

- **Namespace**: `cost-mgmt-dev-tenant`
- **Kubeconfig**: `konflux-cost-mgmt-dev.yaml` (included in repository)

> **Note**: The `konflux-cost-mgmt-dev.yaml` file is tracked in git but ignored for local changes. This prevents accidentally committing sensitive tokens that are added during authentication. The file will be modified locally when you login, but these changes won't be staged for commit.

## Login to Konflux

**Always login to Konflux cluster before using any commands.**
A browser window will open to complete the login process.

**Why does `oc project` still show another cluster (e.g. hccm-prod)?**  
`make login` runs in a subprocess. Your **current terminal** still uses the default kubeconfig (e.g. production). After login, run **one** of the following in the **same terminal** so `oc`/`kubectl` point to Konflux:

```bash
# Option 1: from koku-ci-management/
eval $(make env)

# Option 2: copy the export line printed at the end of 'make login'
export KUBECONFIG="/path/to/koku-ci-management/konflux-cost-mgmt-dev.yaml"
```

Then `oc project` will show `cost-mgmt-dev-tenant` on the Konflux server.

```bash
cd koku-ci-management
make login
eval $(make env)
```

## Available Commands

### Status & Health

```bash
# Show status for both scheduled jobs + recent pipeline runs
make status

# Check health of both jobs (last execution success/failure)
make health

# Check health of the ONPREM job only
make health JOB=onprem

# Check health of the standard job only
make health JOB=standard
```

### Trigger Manual Runs

```bash
# Trigger the standard job manually (default)
make trigger

# Trigger the ONPREM job manually
make trigger JOB=onprem
```

### Suspend / Resume

```bash
# Suspend the standard job (default)
make suspend

# Suspend the ONPREM job
make suspend JOB=onprem

# Suspend BOTH jobs (e.g., before holidays)
make suspend JOB=all

# Resume the standard job (default)
make resume

# Resume the ONPREM job
make resume JOB=onprem

# Resume BOTH jobs
make resume JOB=all
```

### Pipelines & Jobs

```bash
# Show recent pipeline runs
make pipelines

# Show recent jobs
make jobs

# Show logs for most recent job
make logs

# Watch jobs in real-time
make watch

# Clean up jobs older than 7 days
make cleanup
```

### Using the Script Directly

```bash
# Show help with all options
./koku-ci-manager.sh help

# Show status
./koku-ci-manager.sh status

# Trigger ONPREM job
./koku-ci-manager.sh trigger onprem

# Check health of all jobs
./koku-ci-manager.sh health all

# Suspend both jobs
./koku-ci-manager.sh suspend all

# Show last 5 pipeline runs
./koku-ci-manager.sh pipelines 5

# Show logs for specific job
./koku-ci-manager.sh logs koku-onprem-manual-run-20250421-1430
```

## How It Works

Each scheduled job:

1. **Runs automatically** via a Kubernetes CronJob at the configured schedule
2. **Finds the latest released snapshot** of the Koku component (push event + AutoReleased)
3. **Labels the snapshot** to trigger the associated `IntegrationTestScenario`
4. **Provisions an ephemeral environment**, runs the tests, then tears it down

The `onprem` job additionally deploys with `ONPREM=True` and uses the `cost_ocp_on_prem` pytest marker.

## Troubleshooting

### Check CronJobs

```bash
kubectl get cronjob -n cost-mgmt-dev-tenant | grep scheduled
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

1. **Not Logged In**: Run `make login` then `eval $(make env)`
2. **No Snapshots Found**: Check if the Koku component has been built and released recently
3. **Permission Issues**: Ensure you're logged in with proper permissions using `make login`
4. **CronJob Suspended**: Run `make status` to check, then `make resume JOB=all` to re-enable

## Related Documentation

- [Konflux Integration Testing](https://konflux-ci.dev/docs/testing/integration/rerunning/)
- [Koku CI Repository](../README.md)
- [Konflux Release Data](https://github.com/redhat-appstudio/konflux-release-data)
