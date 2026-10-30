# Changelog

## [Unreleased]

## nuwa-app 0.3.0

### Added
- `externalSecrets`: Secrets the External Secrets Operator fills from OpenBao (`apps/meru/<namespace>/eso/<name>`,
  every key), owned by their ExternalSecret. With it come the `eso` ServiceAccount (ESO's login, role
  `meru-<namespace>-eso`) and the `openbao` SecretStore, all in sync-wave -1 so the Deployment waits for them.
  `openbao.refreshInterval` (default 5m) is how often ESO re-reads.
- The chart refuses a `migrate.secretEnv` that names one of them: the PreSync migration runs before the Sync phase
  creates it, so a first install would wait forever.

## nuwa-app 0.2.1

### Fixed
- The migration Job no longer names the app's ServiceAccount: on a first install its PreSync hook ran before that
  account existed, and every pod was refused.

## nuwa-app 0.2.0

### Added
- `secretEnv` (and `migrate.secretEnv`): settings from Kubernetes Secrets, `{NAME: {secret, key}}`.
- `heartbeat.readyPath`: readiness on its own path (an app's "can serve" check); defaults to `heartbeat.path`.
- `migrate`: a Job from the app's image that Argo CD runs as a PreSync hook before every rollout - a failure stops
  the sync and the old version keeps serving. Its pod is labelled `<name>-migrate`, so the Service never selects it.

## nuwa-app 0.1.0

### Added
- `nuwa-app` 0.1.0: Deployment, Service, ServiceAccount and optional PersistentVolumeClaims for one web app,
  compliant with Meru's admission rules by construction; values schema; `scripts/check.sh`.
