# Changelog

## [Unreleased]

## nuwa-app 0.21.0

### Added
- `networkPolicy.egress`: `none` lets the app's pods open no connections at all (not even DNS), for an app that only
  answers - the nuwa-static template's sites. Default `allow`; apps that don't set it render byte-for-byte as in 0.20.0.

## nuwa-app 0.20.0

### Added
- `glitchtip.dsn`: the app's GlitchTip DSN (D125), written by Shikigami at onboarding. Set, the pod gets `SENTRY_DSN`
  for the Sentry SDK. Apps that don't set it render byte-for-byte as in 0.19.0.

## nuwa-app 0.19.0

### Added
- `certificate.keyEncoding`: `PKCS8` writes the certificate's private key in PKCS#8, for a server that only reads that format
  (granian, which serves GlitchTip). Apps that don't set it render byte-for-byte as in 0.18.0.

## nuwa-app 0.18.0

### Added
- `heartbeat.host`: the Host header the probes send. For an app that refuses requests to other hosts, like GlitchTip
  (Django's `ALLOWED_HOSTS`), whose probes would otherwise get 400 for the pod's IP. Apps that don't set it render
  byte-for-byte as in 0.17.0.

## nuwa-app 0.17.0

### Added
- `reloadsSecrets`: for an app that picks up new secret files itself, so a rotated Secret doesn't restart it.

## nuwa-app 0.16.0

### Added
- `externalSecrets.<name>.mountPath`: the Secret as read-only files, for an app that can't read secrets from the environment.
- `externalSecrets.<name>.files`: the Secret's keys as templates, so a config file stays in git with only its secret in
  OpenBao. For Warpgate, whose config file is its only way to get the OIDC client secret.

## nuwa-app 0.15.0

### Added
- `extraPorts`: ports that aren't HTTP, published on the node (`name`, `port`, `nodePort`). Any entry makes the Service a
  NodePort. For Warpgate's SSH, which Caddy can't forward.
- `heartbeat.scheme`: `HTTPS` for an app that only serves TLS. Apps that set neither render byte-for-byte as in 0.14.0.

## nuwa-app 0.14.0

### Added
- `job`: a scheduled app instead of a long-running one (D107). `job.schedule` set (cron, `timeZone` default
  Europe/Lisbon) renders a CronJob in place of the Deployment and the Service: one pod per run, never overlapping
  (`concurrencyPolicy: Forbid`), `backoffLimit` retries, stopped after `activeDeadlineSeconds`, finished runs kept a
  week. The pod spec is the Deployment's (now shared, `nuwa-app.podSpec`) minus port and probes - Kyverno's probe
  rule covers long-running workloads only. Zabbix watches the CronJob's `status.lastSuccessfulTime`. Not with
  `autoscaling` (the chart fails). Deployments render byte-for-byte as in 0.13.0.

## nuwa-app 0.13.0

### Added
- `authentikLogin`: the app's own Authentik login without an app password (D104). Mounts a service-account token meant
  for Authentik only (audience `authentik`, 1 hour, renewed by the kubelet) read-only at `mountPath`; the app sends it
  as its client_credentials assertion. It opens only what a protected Authentik blueprint grants the app's
  `<namespace>/<service account>`. Off by default.

## nuwa-app 0.10.0

### Added
- `kubernetesApi`: the app's own Kubernetes API token, for an app that reads the cluster itself (Shikigami reads Argo
  CD Applications, D85). Mounts a service-account token for the API server (10 minutes, renewed by the kubelet) and
  the cluster CA (`kube-root-ca.crt`) read-only at `mountPath`; `automountServiceAccountToken` stays false. It can do
  only what RBAC grants the app's service account (Meru/meru `rbac/`). Off by default.

## nuwa-app 0.9.0

### Added
- `enabled` (default true): false = the app is retired (D84) - the Deployment, migration Job and ScaledObject stop
  rendering, so the pods go on the next sync; Service, volumes, secrets etc. stay until Charon purges the namespace.
  Shikigami sets it in the app's last commit before archiving the repo. The same gate as the placeholder digest.

### Changed
- The pod template's labels are the selector pair + the CMDB labels rule 7 asks of pods (`part-of`, `owner`) - no
  `helm.sh/chart` / `managed-by`. A chart bump alone no longer changes the pod template, so it no longer restarts
  every app (seen on Echo's 0.7.0 -> 0.8.0). Moving to 0.9.0 itself restarts each app once (the labels change).

## nuwa-app 0.8.0

### Changed
- Until CI's first build - the digest still the template's all-zero placeholder - the Deployment, the migration Job
  and the ScaledObject aren't rendered; the rest of the app (Service, volumes, secrets, ...) is. Before, Kyverno
  refused the unsigned placeholder pod and Argo CD kept retrying that revision (up to ~1 h of backoff) before it took
  the build's digest commit - hit on Echo's first template-built deploy. A real digest renders as before.

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
