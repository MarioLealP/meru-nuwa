# Changelog

## [Unreleased]

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
