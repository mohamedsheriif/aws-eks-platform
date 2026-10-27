#!/usr/bin/env bash
#
# Scans each unit of an environment with Trivy and writes one SARIF report, which CI
# uploads to the repository's Security > Code scanning tab.
#
# Each module is scanned with its unit's inputs, rendered by Terragrunt with mocked
# dependency outputs. Without them, Trivy would see no resources.
#
# Usage:   ./scripts/security-scan.sh <env> <output.sarif>
# Example: ./scripts/security-scan.sh dev trivy.sarif

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <env> <output.sarif>   (e.g. $0 dev trivy.sarif)" >&2
  exit 1
fi

ENV="$1"
OUTPUT="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"

for unit_dir in "${ROOT}/live/${ENV}"/*/; do
  unit="$(basename "$unit_dir")"

  # The unit's module path and inputs.
  config="$(cd "$unit_dir" && TG_MOCK=true terragrunt render --format json 2>/dev/null)"
  module_dir="$(jq -r '.terraform.source' <<<"$config")"
  jq '.inputs' <<<"$config" >"${WORK_DIR}/${unit}.tfvars.json"

  trivy config --quiet --tf-vars "${WORK_DIR}/${unit}.tfvars.json" \
    --format sarif --output "${WORK_DIR}/${unit}.raw" "$module_dir"

  # GitHub needs paths relative to the repository root.
  jq --arg path "${module_dir#"${ROOT}/"}" '
    .runs[0].results[].locations[].physicalLocation.artifactLocation |= { uri: "\($path)/\(.uri)" }
  ' "${WORK_DIR}/${unit}.raw" >"${WORK_DIR}/${unit}.sarif"

  echo "${unit}: $(jq '.runs[0].results | length' "${WORK_DIR}/${unit}.sarif") finding(s)"
done

# Code scanning accepts at most 20 runs per upload, so all units go into one run.
jq -s --arg category "trivy/${ENV}" '
  (map(.runs[0].tool.driver.rules // []) | add | unique_by(.id)) as $rules
  | (map(.runs[0].results) | add | map(del(.ruleIndex))) as $results
  | .[0]
  | .runs[0].tool.driver.rules = $rules
  | .runs[0].results = $results
  | .runs[0].automationDetails.id = $category
' "${WORK_DIR}"/*.sarif >"$OUTPUT"

rm -rf "$WORK_DIR"
echo "Wrote ${OUTPUT}"
