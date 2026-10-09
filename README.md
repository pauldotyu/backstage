# Backstage developer portal

Companion code used in an upcoming blog series on building an internal developer portal with [Backstage](https://backstage.io). The series is not published yet; a link will be added here when it is available.

Backstage brings software catalogs, ownership, documentation, and software templates into one place. This repository contains the application code and configuration used to explore those capabilities, starting from the Backstage scaffold and building it out step by step.

**Work in progress:** The application and this README will evolve as the series progresses. This is a learning project, not a production-ready deployment.

## Current state

- Backstage frontend and backend based on the standard application scaffold.
- Microsoft Entra sign-in wired into the frontend and backend, with tenant configuration still required.
- Microsoft Graph catalog module registered for importing Entra users and groups.
- Plugins for the software catalog, software templates, TechDocs, search, and Kubernetes.

Having a plugin installed does not mean its integration is configured. The checked-in configuration has no authentication providers, catalog sources, or Kubernetes cluster connections configured. Follow the local setup below to enable sign-in and import users and groups.

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

The default local database is in-memory SQLite, so its data is lost when the backend restarts. Configured providers reimport their data, but manually registered catalog entries must be added again.

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

## Repository layout

- `packages/app/`: Backstage frontend, navigation, and sign-in page.
- `packages/backend/`: Backend service and plugin registrations.
- `plugins/`: Workspace for custom plugins as the project grows.
- `app-config.yaml`: Shared configuration and local development defaults.
- `app-config.local.yaml`: Git-ignored local configuration generated by `backstage-azure`.
- `app-config.production.yaml`: Production-oriented configuration scaffold, including PostgreSQL settings. It is not a complete production deployment.

The backend currently registers an allow-all permission policy. Microsoft Entra sign-in does not turn that into a production authorization policy. Review access controls, secret management, persistent storage, and deployment configuration before using this outside a local learning environment.
