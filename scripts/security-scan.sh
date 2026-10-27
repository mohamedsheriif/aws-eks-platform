#!/usr/bin/env bash
#
# Scans each unit of an environment with Trivy and writes one SARIF report per unit,
# which CI uploads to the repository's Security > Code scanning tab.
#
# Each module is scanned with its unit's inputs, rendered by Terragrunt with mocked
# dependency outputs. Without them, Trivy would see no resources.
#
# Usage:   ./scripts/security-scan.sh <env> <report-dir>
# Example: ./scripts/security-scan.sh dev /tmp/trivy

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <env> <report-dir>   (e.g. $0 dev /tmp/trivy)" >&2
  exit 1
fi

ENV="$1"
REPORT_DIR="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$REPORT_DIR"

for unit_dir in "${ROOT}/live/${ENV}"/*/; do
  unit="$(basename "$unit_dir")"
  report="${REPORT_DIR}/${unit}"

  # The unit's module path and inputs.
  config="$(cd "$unit_dir" && TG_MOCK=true terragrunt render --format json 2>/dev/null)"
  module_dir="$(jq -r '.terraform.source' <<<"$config")"
  jq '.inputs' <<<"$config" >"${report}.tfvars.json"

  trivy config --quiet --tf-vars "${report}.tfvars.json" \
    --format sarif --output "${report}.trivy.sarif" "$module_dir"

  # GitHub needs paths relative to the repository root, and one category per unit so
  # units that share a module don't replace each other's alerts.
  jq --arg path "${module_dir#"${ROOT}/"}" --arg category "trivy/${ENV}/${unit}" '
    .runs[0].automationDetails.id = $category
    | .runs[0].results[].locations[].physicalLocation.artifactLocation |= { uri: "\($path)/\(.uri)" }
  ' "${report}.trivy.sarif" >"${report}.sarif"
  rm "${report}.trivy.sarif"

  echo "${unit}: $(jq '.runs[0].results | length' "${report}.sarif") finding(s)"
done
