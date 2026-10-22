# Backstage Demo

Companion code used in an upcoming blog series on building an internal developer portal with [Backstage](https://backstage.io). The series is not published yet; a link will be added here when it is available.

Backstage brings software catalogs, ownership, documentation, and software templates into one place. This repository contains the application code and configuration used to explore those capabilities, starting from the Backstage scaffold and building it out step by step.

**Work in progress:** The application and this README will evolve as the series progresses. This is a learning project, not a production-ready deployment.

## Current state

- Backstage frontend and backend based on the standard application scaffold.
- Microsoft Entra sign-in wired into the frontend and backend, with tenant configuration still required.
- Microsoft Graph catalog module registered for importing Entra users and groups.
- Plugins for the software catalog, software templates, TechDocs, search, and Kubernetes.

Having a plugin installed does not mean its integration is configured. The checked-in configuration includes discovery for agent environment catalog descriptors, but has no authentication providers or Kubernetes cluster connections configured. Follow the local setup below to enable sign-in and import users and groups.

## Run locally

### Prerequisites

- Git and Node.js 22 or 24, as required by `package.json`.
- Yarn 4.13.0, pinned and included in this repository. Use Corepack to enable the `yarn` command.
- A Microsoft Entra tenant and access to provision the identity resources using [pauldotyu/backstage-azure](https://github.com/pauldotyu/backstage-azure). That setup requires the Azure CLI and OpenTofu or Terraform, plus sufficient directory permissions. You may need a tenant administrator.
- Python and native build tools if dependency installation needs to compile `better-sqlite3`. On Linux, this typically means Python 3, `make`, and a C/C++ compiler.
- Docker, with its daemon running, only if you want to generate TechDocs with the default configuration. It is not required just to start the portal.

### 1. Clone the repository and install dependencies

```sh
git clone https://github.com/pauldotyu/backstage.git
cd backstage
corepack enable
yarn --version
yarn install
```

`yarn --version` should report `4.13.0`. If Corepack is unavailable, you can use the bundled Yarn directly: replace `yarn` in these instructions with `node .yarn/releases/yarn-4.13.0.cjs`.

Run this README's commands from the repository root. The companion Entra setup runs from its own directory, as described below.

### 2. Prepare Microsoft Entra

The sign-in screen uses Microsoft Entra, not guest access. Identity provisioning lives in the companion repository, [pauldotyu/backstage-azure](https://github.com/pauldotyu/backstage-azure), rather than in this application.

Clone it alongside this repository so the default output path points to this application:

```sh
git clone https://github.com/pauldotyu/backstage-azure.git ../backstage-azure
```

Your directories should look like this:

```text
workspace/
  backstage/        # This application
  backstage-azure/  # Entra provisioning and configuration generation
```

Follow the companion repository's [getting started instructions](https://github.com/pauldotyu/backstage-azure#getting-started) from its directory, then return here. That setup provisions the app registration, service principal, client secret, and `backstage-users` group, and writes `app-config.local.yaml` into this repository. Use interactive user authentication as described there so your user is added to the group.

**Back up any existing `app-config.local.yaml` before applying the companion configuration.** It replaces the whole file, not just the Entra settings. The generated file contains a plaintext client secret. This repository ignores `*.local.yaml`, but you should still restrict access and never commit the file.

Backstage loads `app-config.local.yaml` alongside `app-config.yaml` during local development. The generated file contains the Entra credentials directly, so you do not need to export `AZURE_*` variables for this setup. The frontend and backend provider modules are already enabled here; no additional plugin installation is needed.

The generated catalog configuration imports `backstage-users` and its direct user members. Its sign-in resolver matches your authenticated email to the imported user's `microsoft.com/email` annotation. Your account must be imported before sign-in can succeed. The group filters limit catalog ingestion, not the application's Microsoft Graph permissions or Entra application assignment.

### 3. Configure GitHub access

The shared `app-config.yaml` references `GITHUB_TOKEN`; the Entra setup does not supply it. To use GitHub catalog locations or software template actions, export a token with access to the repositories and operations you need in the terminal where you will run `yarn start`. This Bash example prompts without echoing the token or putting its value in shell history:

```bash
read -rsp 'GitHub token: ' GITHUB_TOKEN; echo
export GITHUB_TOKEN
```

If you are not using GitHub yet, add this top-level override to `app-config.local.yaml` instead:

```yaml
integrations:
  github: []
catalog:
  locations: []
```

Reapplying the companion configuration replaces local edits, including this override. Preserve any custom settings before applying and restore them afterward. Creating a `.env` file alone does not export `GITHUB_TOKEN` into your shell.

### 4. Start and sign in

From this repository's root:

```sh
yarn start
```

Open [http://localhost:3000](http://localhost:3000) and choose **Microsoft Entra**. The backend runs at [http://localhost:7007](http://localhost:7007). Allow the first Microsoft Graph ingestion and catalog processing to finish before signing in; check the backend terminal output for ingestion errors if sign-in fails.

After signing in, open the catalog and select the **User** or **Group** kind to see the imported directory entities. Application components, software templates, TechDocs content, and Kubernetes resources still need their own catalog entries and integration configuration.

Stop the app with `Ctrl+C`. Restart it after changing local configuration or credentials.

The default local database is in-memory SQLite, so its data is lost when the backend restarts. Configured providers and locations reimport their data, but manually registered catalog entries must be added again.

## Agent environment inventory

The catalog defaults to the **Resource** kind through the `catalog-filter:catalog/kind` extension in [app-config.yaml](app-config.yaml). Other kinds remain selectable, and an explicit kind filter in the URL overrides this default.

The [create template](templates/create-agent-environment/template.yaml) renders two files into the same PR in `pauldotyu/platform`:

```text
requests/agent-environments/<team>/<project>/<environment>/environment.yaml
catalog/agent-environments/<team>/<project>/<environment>/catalog-info.yaml
```

The request remains an `XAgentEnvironment` manifest. The separate catalog descriptor is a Backstage `Resource` of type `agent-environment`, with team, project, environment, and region labels and a link to the request. Keeping these files separate prevents the Backstage descriptor from being applied as a Kubernetes manifest.

Both files live in one [skeleton tree](templates/create-agent-environment/skeleton), with templated team, project, and environment directory names. A single `fetch:template` step renders that tree into `./output` in the task workspace. The publish step uses `sourcePath: ./output`, so only its contents are committed, without an extra `output` directory in the platform repository.

Ownership comes from the signed-in user's `${{ user.ref }}`, not the free-text team field or the Entra object ID. The requester must resolve to an imported Backstage `User`. Groups are not required for environment ownership, and catalog ownership does not grant infrastructure permissions.

The shared [app configuration](app-config.yaml) registers the [environment discovery location](catalog/agent-environments.yaml). Backstage's built-in GitHub URL reader finds matching descriptors on the target repository's `main` branch during catalog processing. No extra discovery plugin or per-environment registration is required. The optional target supports an empty inventory, including after the last descriptor is deleted.

To enable this flow:

1. Push the updated templates and discovery location to `main` in this repository so Backstage can read them.
2. Ensure `GITHUB_TOKEN` can read both repositories and create PRs in `pauldotyu/platform`.
3. Restart Backstage to load the catalog configuration, and refresh the registered templates. If a local or deployment override sets `catalog.locations`, include the environment discovery location there too: configuration arrays are replaced, not appended.
4. Submit a new environment request and merge its PR after review.
5. Allow catalog processing to discover the descriptor, then open the catalog, select **Resource**, and use the **Owned** filter. Catalog processing is asynchronous; visibility is not immediate after merge.

The [delete template](templates/delete-agent-environment/template.yaml) removes both the request and its matching catalog descriptor in one PR. It still supports older requests without a descriptor. After merge and catalog processing, Backstage removes the inventory entry using its default orphan-deletion behavior. If you override `catalog.orphanStrategy` to `keep`, removed entries remain as orphans instead.

Generated Resources include a **Request deletion** link on their entity page. It opens the registered `delete-agent-environment` template with team, project, and environment prefilled through the URL's `formData` parameter. Both confirmation checkboxes remain unchecked; opening the link does not submit the task or delete infrastructure. The template must be registered in the `default` catalog namespace.

The link uses the existing `app.baseUrl` setting, exposed as the `backstageBaseUrl` scaffolder global by a [backend module](packages/backend/src/scaffolderTemplateGlobals.ts). No domain is hardcoded in the skeleton, and requesters do not need to enter a portal URL. Local development and deployed environments use their own configured base URL; trailing slashes are removed before constructing the link. Deploy the backend module and refresh the create template before generating new requests.

Backstage catalog link validation requires an absolute URL, so generated links store the base URL in effect when the request is created. Changing `app.baseUrl` does not rewrite existing descriptors: update those in the platform repository if the portal moves. If the scaffolder route changes, also update the [catalog skeleton](templates/create-agent-environment/skeleton/catalog/agent-environments). Existing descriptors without the link need it added in Git once and are refreshed through catalog processing.

A visible catalog entry records an accepted request, not successful provisioning. A removed entry does not confirm teardown completed. Existing environments are not backfilled automatically: add descriptors for their existing requests to the same catalog directory if they should appear.

### Live deployment details

The existing Backstage **Kubernetes** plugin displays the live `XAgentEnvironment` outputs. Open the environment's **Resource** page, select **Kubernetes**, expand the cluster, and expand the `XAgentEnvironment`. Its built-in status table shows the application namespace, service account, client ID, model and telemetry endpoints, resource group ID, and conditions. Clicking the resource name opens the full object, including a YAML view. No custom frontend or additional plugin is required.

The deployment settings in [values-entra.yaml](charts/backstage/examples/values-entra.yaml) configure the cluster connection and register `platform.example.org/v1alpha1/xagentenvironments` under `appConfig.kubernetes.customResources`. Customize that one file for your deployment. If you already maintain a customized deployment values file, incorporate these settings there instead.

For existing descriptors, add the same annotations in the platform repository. For `t1-p1-dev`:

```yaml
metadata:
  annotations:
    backstage.io/kubernetes-namespace: agent-environments
    backstage.io/kubernetes-label-selector: crossplane.io/composite=t1-p1-dev
```

New descriptors include these annotations automatically. Existing descriptors need them added in Git and refreshed through catalog processing. `agent-environments` is the namespace containing the request, not the application namespace in `status.namespace`.

The example assumes Backstage and the environments share a cluster. It uses the pod's service account credentials, with no token stored in Git. `objectTypes: []` and `skipMetricsLookup: true` limit fetching to custom resources, excluding unrelated workloads and Secrets. For other clusters or local development, configure the connection using the [Kubernetes documentation](https://backstage.io/docs/features/kubernetes/configuration/); the in-cluster settings do not authenticate `yarn start`.

`agentEnvironments.enabled` creates only a Role and RoleBinding granting `get` and `list` access to `xagentenvironments` in the configured namespace, which must already exist. The installer needs permission to create both there. Cluster configuration remains explicit under `appConfig.kubernetes`. If you change the namespace, update the catalog annotations too.

Read `status.conditions` to determine provisioning readiness. The plugin's generic pod-health indicators do not establish Crossplane readiness, and populated outputs do not imply `Ready=True`. The plugin handles fetching and refresh; outputs are not copied into Git or the catalog database.

Catalog ownership is not authorization. The current allow-all permission policy lets authenticated portal users access these resources, not just the requester. Configure backend authorization before relying on requester-only visibility. The standard resource viewer exposes the entire custom resource; do not put secrets in its spec or status. Removing the catalog descriptor removes the page even if infrastructure teardown is still running.

## Scaffold an Agent Framework application

The [application template](templates/create-maf-app/template.yaml) creates a new GitHub repository from [pauldotyu/agent-framework-with-local-llms](https://github.com/pauldotyu/agent-framework-with-local-llms), then registers the application as a requester-owned Backstage `Component`.

Only the workflow lives in this repository:

```text
templates/
  create-maf-app/
    template.yaml
```

There is no local application skeleton. The workflow:

1. Copies the starter repository's current `main` contents into `./output` using `fetch:plain`. Application files are not processed as templates.
2. Uses `catalog:write` to add a root `catalog-info.yaml` containing the chosen component name, description, GitHub project annotation, and `${{ user.ref }}` as owner.
3. Publishes `./output` to a new repository using `publish:github`. The requester chooses the repository location and public or private visibility; private is the default.
4. Registers the new repository's catalog descriptor immediately using `catalog:register`. Unlike the infrastructure request flow, there is no unmerged PR to wait for.

After pushing this template to `main`, register this URL once through Backstage's catalog import page so it appears under **Create**:

```text
https://github.com/pauldotyu/backstage/blob/main/templates/create-maf-app/template.yaml
```

If you already discover template files automatically, let that discovery ingest it instead. No new hardcoded `catalog.locations` entry is added for this template or for the repositories it creates. With an in-memory catalog database, runtime registrations are lost on restart; use the deployed persistent database or configure discovery for durable re-ingestion.

The configured GitHub credentials must be able to create repositories under the selected owner, push their contents, and read the resulting descriptors, including private repositories. Catalog ownership does not grant repository access. The requester must resolve to an imported Backstage `User`.

The starter is a Python application, not Node.js. Its current `pyproject.toml` requires Python 3.14 or later, despite its README listing Python 3.12 or later. After creation, clone the new repository and follow its setup instructions for `uv`, a local model server, and optional observability services. The workflow does not run the application, install dependencies, or provision infrastructure.

Starter files, Python project metadata, and the lockfile are copied unchanged; the component name identifies the catalog entry, while the repository name is selected separately. Later starter changes are not automatically applied to previously created repositories.

## Troubleshooting

- **Microsoft provider is missing or not configured:** Check that the companion setup generated `app-config.local.yaml` in this repository's root and that `auth.environment` is `development`. Restart Backstage after generating or changing the file.
- **Redirect URI mismatch:** The default **Web** redirect URI is `http://localhost:7007/api/auth/microsoft/handler/frame`. If you change the local URLs, update both the companion configuration and the Backstage settings.
- **Sign-in succeeds at Microsoft but Backstage cannot resolve your identity:** Check the backend logs for Microsoft Graph ingestion errors. Confirm your account is a direct member of `backstage-users` and its imported `microsoft.com/email` annotation matches your sign-in email. The generated configuration schedules catalog sync every 30 minutes. Do not bypass the catalog-user check to work around a failed import.
- **Microsoft Graph returns an authorization error:** Verify that the app registration has its requested application permissions granted by an authorized tenant administrator. Delegated sign-in permissions alone do not authorize background ingestion.
- **Configuration reports a missing `GITHUB_TOKEN`:** Export the token or disable the integration using the local override in step 3.
- **Dependency installation fails during a native build:** Confirm your Node.js version is supported and Python and native build tools are installed.
- **TechDocs cannot start Docker:** Start the Docker daemon and ensure your user can access it.

## Development commands

Run these from the repository root after installing dependencies:

```sh
yarn tsc        # Type-check the workspaces
yarn test       # Run unit tests
yarn lint:all   # Lint all workspaces
yarn build:all  # Build all workspaces
```

## Deploy to AKS with Helm

The `Container image and Helm chart` workflow builds the root `Dockerfile` and pushes `ghcr.io/<owner>/backstage` on every push to `main` (`latest` and `sha-<commit>` tags) and on `v*` tags. Pull requests build and lint without pushing.

After the image is pushed, the workflow packages `charts/backstage` and pushes it as an OCI artifact to `oci://ghcr.io/<owner>/charts/backstage`. Each chart version pins `appVersion`, and therefore the default image tag, to the image built from the same commit:

- Push to `main`: chart `<Chart.yaml version>-sha-<commit>` with image `sha-<commit>`. Helm treats this as a pre-release, so pass `--version` explicitly (or `--devel`).
- Tag `v1.2.3`: chart `1.2.3` with image `1.2.3`.

The first push creates private GHCR packages for the image and chart. Make them public, or run `helm registry login ghcr.io` before installing and add an `imagePullSecrets` entry for the image.

To build locally: `docker build -t backstage .`

The chart in `charts/backstage` runs the backend and, by default, a single-replica PostgreSQL StatefulSet for demos. `appConfig` in values is mounted as `app-config.k8s.yaml` and loaded after `app-config.yaml` and `app-config.production.yaml`, so it overrides both. Keep secrets out of values by referencing `${ENV_VAR}` placeholders and supplying them through `existingSecret`.

Ingress uses the Kubernetes Gateway API. The defaults target the AKS application routing add-on's Istio implementation (`gatewayClassName: approuting-istio`) with the managed Gateway API CRDs installed. With `gateway.tls.enabled`, the chart creates:

- A Gateway with an HTTP listener and an HTTPS listener that terminates TLS.
- An HTTPRoute to Backstage on the HTTPS listener.
- An HTTP-to-HTTPS redirect route.
- A cert-manager `Certificate` for the HTTPS listener's Secret.

The `Certificate` is created directly, so cert-manager's Gateway API integration doesn't need to be enabled. To attach to a shared Gateway instead, set `gateway.create=false` with `gateway.name` and `gateway.namespace`.

### TLS prerequisites

The chart assumes cert-manager is installed and a ClusterIssuer already exists. Set its name in `gateway.tls.certManager.issuerRef.name`. To find it:

```sh
kubectl get clusterissuers
```

If cert-manager isn't installed, follow [Deploy cert-manager on Azure Kubernetes Service (AKS) and use Let's Encrypt to sign a certificate for an HTTPS website](https://cert-manager.io/docs/tutorials/getting-started-aks-letsencrypt/). It covers the install, the workload identity setup for Azure DNS, and creating a ClusterIssuer.

If cert-manager is installed but there's no ClusterIssuer, create one. `charts/backstage/examples/cluster-issuer-azure-dns.yaml` is a Let's Encrypt ClusterIssuer that solves DNS01 challenges against Azure DNS with workload identity. It requires cert-manager's service account to be federated to a managed identity with DNS Zone Contributor on the zone. Fill in the placeholders, then apply it:

```sh
kubectl apply -f charts/backstage/examples/cluster-issuer-azure-dns.yaml
kubectl get clusterissuer letsencrypt   # READY should be True
```

### Install

```sh
kubectl create namespace backstage
kubectl -n backstage create secret generic backstage-secrets \
  --from-literal=AUTH_MICROSOFT_CLIENT_SECRET='<client-secret>' \
  --from-literal=GITHUB_TOKEN='<github-pat>'

cp charts/backstage/examples/values-entra.yaml values-entra.local.yaml
# Fill in tenant, client, group IDs, and host in values-entra.local.yaml

helm upgrade --install backstage oci://ghcr.io/<owner>/charts/backstage -n backstage \
  --version <chart-version> \
  -f values-entra.local.yaml

# Or install from this checkout. Chart.yaml appVersion is `latest`, so pin the image:
# helm upgrade --install backstage ./charts/backstage -n backstage \
#   -f values-entra.local.yaml --set image.tag=sha-<commit>

# Point a DNS A record for the host at the Gateway address
kubectl -n backstage get gateway backstage -o jsonpath='{.status.addresses[0].value}'
```

In the deployed config, `auth.environment` is `production`, so the Microsoft provider settings sit under `providers.microsoft.production`. Add `https://<host>/api/auth/microsoft/handler/frame` as a **Web** redirect URI on the app registration. To test without the Gateway, set the base URLs to `http://localhost:7007` and run `kubectl -n backstage port-forward svc/backstage 7007:80`.

For production, set `postgresql.enabled=false` and point `externalDatabase` at Azure Database for PostgreSQL. TechDocs is configured to generate docs with Docker, which is not available in the pod.

## Repository layout

- `packages/app/`: Backstage frontend, navigation, and sign-in page.
- `packages/backend/`: Backend service and plugin registrations.
- `plugins/`: Workspace for custom plugins as the project grows.
- `app-config.yaml`: Shared configuration and local development defaults.
- `app-config.local.yaml`: Git-ignored local configuration generated by `backstage-azure`.
- `app-config.production.yaml`: Production-oriented configuration scaffold, including PostgreSQL settings. It is not a complete production deployment.
- `Dockerfile`: Multi-stage image build for the backend, which also serves the frontend.
- `charts/backstage/`: Helm chart for AKS. See `examples/` for Entra values and a cert-manager ClusterIssuer.
- `.github/workflows/container-image.yaml`: Builds and pushes the image to GHCR.

The backend currently registers an allow-all permission policy. Microsoft Entra sign-in does not turn that into a production authorization policy. Review access controls, secret management, persistent storage, and deployment configuration before using this outside a local learning environment.
