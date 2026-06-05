#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_commands=(aws kubectl eksctl helm terraform jq)

echo "== Tool check =="
for cmd in "${required_commands[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "OK: %s\n" "$cmd"
  else
    printf "MISSING: %s\n" "$cmd"
    missing=1
  fi
done

if [[ "${missing:-0}" == "1" ]]; then
  echo "Install missing tools before starting the hands-on."
  exit 1
fi

echo "== File check =="
files=(
  "$ROOT_DIR/eksctl/cluster.yaml"
  "$ROOT_DIR/terraform/main.tf"
  "$ROOT_DIR/helm/sample-app/Chart.yaml"
  "$ROOT_DIR/helm/sample-app/values.yaml"
  "$ROOT_DIR/cloudwatch/alarm-pod-restarts.json"
  "$ROOT_DIR/cloudwatch/dashboard-container-insights.json"
)

for file in "${files[@]}"; do
  test -s "$file"
  printf "OK: %s\n" "${file#$ROOT_DIR/}"
done

echo "== JSON check =="
jq empty "$ROOT_DIR/cloudwatch/alarm-pod-restarts.json"
jq empty "$ROOT_DIR/cloudwatch/dashboard-container-insights.json"

echo "== AWS identity check =="
if [[ "${CHECK_AWS_IDENTITY:-0}" == "1" ]]; then
  aws sts get-caller-identity >/dev/null
  echo "OK: aws sts get-caller-identity"
else
  echo "SKIP: set CHECK_AWS_IDENTITY=1 to run aws sts get-caller-identity"
fi

echo "Validation completed. No AWS resources were created, updated, or deleted."
