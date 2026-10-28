# Nüwa

The app templates of **Meru**, a small in-house container platform (CaaS) on k3s. Nüwa holds `nuwa-app`, the
Helm chart every Meru app is deployed with: an app repo carries only a `deploy/values.yaml`, and the chart turns it
into a workload that already passes every Meru compliance rule.

What the chart builds into every app:

- the image pinned by digest (the tag is only a label for people)
- Pod Security "restricted": non-root, read-only root filesystem, no capabilities, no privilege escalation,
  seccomp, no service account token
- CPU and memory requests plus a memory limit
- startup, liveness and readiness probes on the app's `/heartbeat` endpoint
- the CMDB labels: `app.kubernetes.io/name`, `app.kubernetes.io/part-of`, `meru.clockmost.com/owner`
- OpenTelemetry service naming, so traces land in OpenObserve under the app's name
- optional volumes on the `local` (SSD) or `hdd` storage class

## Usage

An app's `deploy/values.yaml`, the minimum:

```yaml
name: echo
owner: mario
image:
  repository: zot.clockmost.com/meru/echo
  digest: sha256:<digest of the image CI built>
```

Everything else has a default; `charts/nuwa-app/values.yaml` documents each option and
`charts/nuwa-app/values.schema.json` rejects unknown keys and missing fields. In Meru, Argo CD renders the chart
with the app repo's values; nothing runs `helm install`.

## Development

Prerequisites: `helm` 4, `kubeconform`, and optionally the Kyverno CLI with a checkout of Meru's policies.

```sh
scripts/check.sh                                    # lint + render every ci/*-values.yaml + schema-validate
scripts/check.sh ../clockmost-infra/k8s/kyverno-policies   # ... and run Meru's admission rules on the output
```

Each `charts/nuwa-app/ci/*-values.yaml` is a test case. Commits follow Conventional Commits; changes go in through
pull requests to `main`.

## License

MIT - see `LICENSE`.
