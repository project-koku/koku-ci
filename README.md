# Koku CI #

[Tekton pipelines and tasks] for running builds and integration tests in Konflux.

The integration tests tasks are run inside [koku-test-container] which contains the programs referenced in each task.

### Pipelines ###

#### pipeline-build ####

It's the main build pipeline for some of the repositories in Konflux. The repositories that reference this file are: `koku`, `koku-daily`, `koku-report-emailer`, `nise-populator` 

#### basic_no_iqe ####

Only runs `bonfire deploy`.

##### Parameters #####

`URL` - Git repository containing the pipelines and tasks<br/>
`REVISION` - Branch of the repository<br/>
`BONFIRE_IMAGE` - Container image used for running tatks<br/>

`APP_NAME` - Name of the app-sre application folder<br/>
`BONFIRE_COMPONENT_NAME` - Name of the app-sre component <br/>
`COMPONENT_NAME` - Name of the app-sre ResourceTemplate for this component<br/>
`COMPONENTS_W_RESOURCES` - Components that should not have their resource request removed<br/>
`COMPONENTS` - Space separated list of components to deploy<br/>
`DEPLOY_FRONTENDS` - `true` or `false`<br/>
`DEPLOY_TIMEOUT` - [fuzzy date] value to wait before killing the deployment<br/>
`EXTRA_DEPLOY_ARGS`<br/>
`SNAPSHOT`<br/>

#### basic ####

- Runs `bonfire deploy` then runs IQE tests
- The IQE filter and marker are determined by the labels set on the PR
- If the `ok-to-skip-smokes` label is set on a PR, IQE tests will **not** run

##### Parameters #####

`URL` - Git repository containing the pipelines and tasks<br/>
`REVISION` - Branch of the repository<br/>
`BONFIRE_IMAGE` - Container image used for running tatks<br/>

`APP_NAME` - Name of the app-sre application folder<br/>
`BONFIRE_COMPONENT_NAME` - Name of the app-sre component <br/>
`COMPONENT_NAME` - Name of the app-sre ResourceTemplate for this component<br/>
`COMPONENTS_W_RESOURCES` - Components that should not have their resource request removed<br/>
`COMPONENTS` - Space separated list of components to deploy<br/>
`DEPLOY_FRONTENDS` - `true` or `false`<br/>
`DEPLOY_TIMEOUT` - Time in seconds to wait before killing the deployment<br/>
`EXTRA_DEPLOY_ARGS`<br/>
`IQE_CJI_TIMEOUT` - [fuzzy date] value to wait before killing the deployment<br/>
`IQE_ENV`<br/>
`IQE_FILTER_EXPRESSION`<br/>
`IQE_IBUTSU_SOURCE`<br/>
`IQE_MARKER_EXPRESSION`<br/>
`IQE_PARALLEL_ENABLED`<br/>
`IQE_PARALLEL_WORKER_COUNT`<br/>
`IQE_PLUGINS`<br/>
`IQE_REQUIREMENTS_PRIORITY`<br/>
`IQE_REQUIREMENTS`<br/>
`IQE_RP_ARGS`<br/>
`IQE_SELENIUM`<br/>
`IQE_TEST_IMPORTANCE`<br/>
`REF_ENV`<br/>
`SNAPSHOT`<br/>

### Tasks ###

#### reserve-namespace ####

Reserves a namespace in the ephemeral environment for testing.


#### deploy-application ####

Runs `bonfire deploy` to create the application for testing.

Fetches PR labels from the GitHub API (via `deploy.py` in
[koku-test-container]). Authenticated requests need the `github-api-token`
secret (see below); without it the shared unauthenticated quota (60/h/IP)
can return HTTP 403 from the ephemeral cluster.


#### run-iqe-cji ####

Runs `bonfire deploy-iqe-cji` with filter and marker based on the labels applied to the pull request.


#### teardown ####

Uploads artifacts to S3 and release namespace.

### GitHub API token (PR label lookups) ###

Several tasks call the GitHub REST API to read PR labels
(`init-pipeline-context`, `midnight-hold`, `deploy`, `run-iqe-cji`).

Create a classic PAT with **no scopes** (public repos only need auth for the
higher rate limit) and store it in the tenant namespace:

```bash
# After: cd koku-ci-management && make login && eval $(make env)
oc create secret generic github-api-token \
  --from-literal=token='ghp_...' \
  -n cost-mgmt-dev-tenant
```

Tasks reference this secret with `optional: true`, so pipelines still start if
the secret is missing — but then they fall back to unauthenticated calls and
can hit rate limits again.

Override the secret name with pipeline/task param `GITHUB_TOKEN_SECRET` if needed.


### Koku CI Management ###

The `koku-ci-management/` directory contains tools to manage Koku CI, including the Scheduled Test Job that runs automatically.

#### Quick Start ####

```bash
cd koku-ci-management

# Login to Konflux cluster
make login

# Show current status
make status

# Trigger manual test job
make trigger
```

For more information, see the [koku-ci-management README](koku-ci-management/README.md).


[Tekton pipelines and tasks]: https://tekton.dev/docs/pipelines/
[koku]: https://github.com/project-koku/koku
[koku-test-container]: https://github.com/project-koku/koku-test-container
[fuzzy date]: https://pypi.org/project/fuzzy-date/
