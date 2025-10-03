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

Runs `bonfile deploy` to create the application for testing.


#### run-iqe-cji ####

Runs `bonfire deploy-iqe-cji` with filter and marker based on the labels applied to the pull request.


#### teardown ####

Uploads artifacts to S3 and release namespace.

### Nightly Build Management ###

The `nightly-management/` directory contains tools to manage Koku nightly smoke tests that run automatically every Saturday at 2 AM UTC.

#### Quick Start ####

```bash
cd nightly-management

# Configure your cluster URLs (first time only)
cp config.example .env
nano .env  # Edit with your cluster URLs

# Login to Konflux cluster
make login

# Show current status
make status

# Trigger manual nightly build
make trigger

# Show recent jobs
make jobs

# Show logs for most recent job
make logs
```

For more information, see the [nightly-management README](nightly-management/README.md).


[Tekton pipelines and tasks]: https://tekton.dev/docs/pipelines/
[koku]: https://github.com/project-koku/koku
[koku-test-container]: https://github.com/project-koku/koku-test-container
[fuzzy date]: https://pypi.org/project/fuzzy-date/
