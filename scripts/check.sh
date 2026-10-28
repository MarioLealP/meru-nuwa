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
  kubeconform -strict -summary "out/$case_name.yaml"
done

if [ -n "$policies" ]; then
  echo "== kyverno"
  # One case at a time: the cases share resource names, and the CLI's fake cluster refuses duplicates.
  for rendered in out/*.yaml; do
    kyverno apply "$policies"/require-*.yaml "$policies"/allowed-registries.yaml --resource "$rendered" --table
  done
fi
