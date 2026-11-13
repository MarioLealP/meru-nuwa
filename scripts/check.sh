#!/bin/bash
# Lint and render the chart with every ci/*-values.yaml, validate the output against the Kubernetes schemas and,
# when a policies dir is given, against Meru's Kyverno rules.
# Usage: scripts/check.sh [path/to/clockmost-infra/k8s/kyverno-policies]
set -euo pipefail
cd "$(dirname "$0")/.."
chart=charts/nuwa-app
policies="${1:-}"
rm -rf out && mkdir -p out

for values in "$chart"/ci/*-values.yaml; do
  case_name="$(basename "$values" -values.yaml)"
  echo "== $case_name"
  helm lint --strict "$chart" -f "$values" --quiet
  helm template "$case_name" "$chart" -n test -f "$values" >"out/$case_name.yaml"
  kubeconform -strict -summary -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    "out/$case_name.yaml"
done

for case_name in placeholder retired; do
  echo "== $case_name renders nothing that runs the image"
  if grep -nE '^kind: (Deployment|Job|CronJob|ScaledObject)$' "out/$case_name.yaml"; then
    echo "$case_name rendered a workload" >&2
    exit 1
  fi
done
echo "== pods carry no chart version (a chart bump alone mustn't restart every app)"
# once on the Deployment's own labels, never in its pod template
count=$(helm template full "$chart" -n test -f "$chart/ci/full-values.yaml" --show-only templates/deployment.yaml \
  | grep -c 'helm.sh/chart' || true)
if [ "$count" != 1 ]; then
  echo "helm.sh/chart appears $count times in the Deployment, expected 1 (its own labels only)" >&2
  exit 1
fi

echo "== egress none: the static case's policy refuses every outgoing connection"
policy=$(helm template static "$chart" -n test -f "$chart/ci/static-values.yaml" --show-only templates/networkpolicy.yaml)
if ! grep -qx '  policyTypes: \[Ingress, Egress\]' <<<"$policy" || ! grep -qx '  egress: \[\]' <<<"$policy"; then
  echo "static case: expected policyTypes [Ingress, Egress] with egress []" >&2
  exit 1
fi

echo "== egress internet: DNS to CoreDNS, then public addresses only"
policy=$(helm template internet "$chart" -n test -f "$chart/ci/internet-values.yaml" --show-only templates/networkpolicy.yaml)
for want in '  policyTypes: \[Ingress, Egress\]' '              k8s-app: kube-dns' '            cidr: 0.0.0.0/0' \
  '            except: \[10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10, 169.254.0.0/16, 127.0.0.0/8\]'; do
  if ! grep -qx "$want" <<<"$policy"; then
    echo "internet case: missing line: $want" >&2
    exit 1
  fi
done

echo "== runtimeClassName: set only when asked"
gpu=$(helm template gpu "$chart" -n test -f "$chart/ci/gpu-values.yaml" --show-only templates/deployment.yaml)
if ! grep -qx '      runtimeClassName: nvidia' <<<"$gpu"; then
  echo "gpu case: missing runtimeClassName: nvidia" >&2
  exit 1
fi
if helm template minimal "$chart" -n test -f "$chart/ci/minimal-values.yaml" | grep -q runtimeClassName; then
  echo "minimal case: runtimeClassName rendered without being set" >&2
  exit 1
fi

echo "== toNamespaces: egress to the named apps + DNS, and nothing more"
to=$(helm template to "$chart" -n test -f "$chart/ci/to-namespaces-values.yaml" --show-only templates/networkpolicy.yaml)
grep -q 'values: \["felt-llm"\]' <<<"$to" || { echo "toNamespaces case: no rule to felt-llm" >&2; exit 1; }
grep -q 'k8s-app: kube-dns' <<<"$to" || { echo "toNamespaces case: no DNS rule" >&2; exit 1; }
echo "== heartbeat.port: probes on the health port, the Service still on the app's"
dep=$(helm template to "$chart" -n test -f "$chart/ci/to-namespaces-values.yaml" --show-only templates/deployment.yaml)
[ "$(grep -c 'port: health' <<<"$dep")" = 3 ] || { echo "heartbeat.port: not every probe uses the health port" >&2; exit 1; }
grep -q 'containerPort: 8001' <<<"$dep" || { echo "heartbeat.port: no health container port" >&2; exit 1; }
if helm template to "$chart" -n test -f "$chart/ci/to-namespaces-values.yaml" --show-only templates/service.yaml | grep -q '8001\|health'; then
  echo "heartbeat.port: the health port leaked into the Service" >&2; exit 1
fi
eg=$(sed -n '/^  egress:/,/^  ingress:/p' <<<"$to")
grep -q 'cidr: 192.168.10.110/32' <<<"$eg" || { echo "toAddresses case: no rule to the address" >&2; exit 1; }
grep -q '{ protocol: TCP, port: 443 }' <<<"$eg" || { echo "toAddresses case: the address rule has no port" >&2; exit 1; }
if grep 'cidr:' <<<"$eg" | grep -qv '192.168.10.110/32'; then echo "toNamespaces case (egress none): an ipBlock beyond toAddresses" >&2; exit 1; fi
none=$(helm template none "$chart" -n test -f "$chart/ci/static-values.yaml" --show-only templates/networkpolicy.yaml 2>/dev/null || true)
if [ -n "$none" ] && ! grep -q 'egress: \[\]' <<<"$none"; then
  echo "static case: egress none no longer renders egress: []" >&2
  exit 1
fi

echo "== nodePorts: only the -ports Service is a NodePort, UDP kept; TCP probes; grace period"
game=out/game.yaml
[ "$(grep -c '^  type: NodePort$' "$game")" = 1 ] || { echo "game: the app's own Service must stay ClusterIP" >&2; exit 1; }
grep -q '^  name: game-ports$' "$game" || { echo "game: no game-ports Service" >&2; exit 1; }
[ "$(grep -c 'protocol: UDP' "$game")" = 2 ] || { echo "game: UDP lost (Service port + container port)" >&2; exit 1; }
[ "$(grep -c 'tcpSocket:' "$game")" = 3 ] || { echo "game: scheme TCP must give three tcpSocket probes" >&2; exit 1; }
grep -q 'terminationGracePeriodSeconds: 120' "$game" || { echo "game: grace period missing" >&2; exit 1; }
if grep -q terminationGracePeriodSeconds out/full.yaml; then echo "full: grace period set without asking" >&2; exit 1; fi

echo "== sidecars: native (initContainers, restartPolicy Always), restricted like the app; supplementalGroups; EXEC probes"
side=$(sed -n '/^kind: Deployment$/,/^---$/p' out/sidecar.yaml)
init=$(sed -n '/^      initContainers:$/,/^      containers:$/p' <<<"$side")
[ "$(grep -c '^        - name: ' <<<"$init")" = 2 ] || { echo "sidecar: expected 2 init containers" >&2; exit 1; }
[ "$(grep -c '^          restartPolicy: Always$' <<<"$init")" = 2 ] || { echo "sidecar: a sidecar without restartPolicy Always" >&2; exit 1; }
for want in '            allowPrivilegeEscalation: false' '            readOnlyRootFilesystem: true' '              drop: \[ALL\]'; do
  [ "$(grep -cx "$want" <<<"$init")" = 2 ] || { echo "sidecar: not every sidecar has: $want" >&2; exit 1; }
done
grep -qx '          image: zot.clockmost.com/meru/printer@sha256:a\{64\}' <<<"$init" || { echo "sidecar: no default to the app image" >&2; exit 1; }
grep -qx '              clockmost.com/ender: 1' <<<"$init" || { echo "sidecar: the device's extended resource is lost" >&2; exit 1; }
grep -qx '        supplementalGroups: \[986\]' <<<"$side" || { echo "sidecar: supplementalGroups missing" >&2; exit 1; }
app=$(sed -n '/^      containers:$/,$p' <<<"$side")
[ "$(grep -c '^            exec:$' <<<"$app")" = 3 ] || { echo "sidecar: heartbeat EXEC must give three exec probes" >&2; exit 1; }
if grep -q 'httpGet:' <<<"$app"; then echo "sidecar: an httpGet probe beside EXEC" >&2; exit 1; fi
if grep -qE 'initContainers|supplementalGroups' out/full.yaml; then echo "full: sidecars/supplementalGroups set without asking" >&2; exit 1; fi

if [ -n "$policies" ]; then
  echo "== kyverno"
  # One case at a time: the cases share resource names, and the CLI's fake cluster refuses duplicates.
  for rendered in out/*.yaml; do
    kyverno apply "$policies"/require-*.yaml "$policies"/allowed-registries.yaml --resource "$rendered" --table
  done
fi
