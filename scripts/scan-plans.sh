#!/usr/bin/env bash
#
# Scans the plans written by `terragrunt run --all plan --json-out-dir <plans-dir>` with
# Trivy and writes one SARIF report, which CI uploads to Security > Code scanning.
#
# Trivy reports plan findings against a generated main.tf, so each unit's plan is scanned
# on its own and its findings are pointed at that unit's terragrunt.hcl.
#
# Usage:   ./scripts/scan-plans.sh <env> <plans-dir> <output.sarif>
# Example: ./scripts/scan-plans.sh dev /tmp/plans trivy.sarif

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <env> <plans-dir> <output.sarif>   (e.g. $0 dev /tmp/plans trivy.sarif)" >&2
  exit 1
fi

ENV="$1"
PLANS_DIR="$2"
OUTPUT="$3"
WORK_DIR="$(mktemp -d)"

for plan_dir in "$PLANS_DIR"/*/; do
  unit="$(basename "$plan_dir")"

  trivy config --quiet --format sarif --output "${WORK_DIR}/${unit}.raw" "$plan_dir"

  jq --arg uri "live/${ENV}/${unit}/terragrunt.hcl" '
    .runs[0].results[].locations[].physicalLocation |= { artifactLocation: { uri: $uri }, region: { startLine: 1 } }
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
