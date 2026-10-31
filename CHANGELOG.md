# Changelog

## [Unreleased]

## nuwa-app 0.7.0

### Added
- `openbaoLogin`: the app's own OpenBao login, for an app that writes to OpenBao itself (Shikigami, D79). Mounts a
  service-account token meant for OpenBao only (audience `openbao`, 10 minutes, renewed by the kubelet) and OpenBao's
  CA (`<name>-openbao-ca` ConfigMap) read-only at `mountPath`. The token opens nothing until OpenBao's admin binds a
  role to the app's service account. Off by default; everyone else keeps reading through `externalSecrets`.

## nuwa-app 0.6.0

### Added
- `clusterIP`: a fixed Service address from the static band (10.43.0.2-10.43.0.255), for callers outside the
  cluster that can't resolve its DNS name - first user: Gitea's webhook to Shikigami. Empty (default) = Kubernetes
  picks, as before.

## nuwa-app 0.5.0

### Added
- `autoscaling`: KEDA scales the app on its own backlog (D75). A `ScaledObject` polls `GET <path>` on the app's
  Service from inside the cluster (KEDA's metrics-api trigger, no credentials) and keeps one replica per
  `targetValue` waiting items between `minReplicas` and `maxReplicas`. While it's on, the Deployment leaves
  `replicas` out so Argo CD and KEDA's HPA don't fight over it. Off by default; stateless apps only.

## nuwa-app 0.4.0

### Added
- `certificate`: a TLS certificate for the app's in-cluster names (`<name>.<namespace>.svc` and
  `.svc.cluster.local`), issued by OpenBao's `pki_meru` through cert-manager and renewed before it expires (24h,
  renewed 8h before by default). Mounted read-only at `/var/run/meru/tls` (`tls.crt`, `tls.key`, `ca.crt`), for
  mTLS as server and client. With it come the `certs` ServiceAccount, the permission for cert-manager to request
  its token, and the `openbao` Issuer (role `meru-certs`).

### Changed
- ESO logs in through the shared role `meru-eso` instead of `meru-<namespace>-eso`: OpenBao fills in the namespace
  from the login, so a new app needs no OpenBao setup of its own.
- The `eso` ServiceAccount and the SecretStore moved to sync-wave -2, a wave before the ExternalSecrets: in the same
  wave the store wasn't ready for the first try.

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
