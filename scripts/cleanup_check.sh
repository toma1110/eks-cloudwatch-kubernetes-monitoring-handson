#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-1}"
CLUSTER_NAME="${CLUSTER_NAME:-eks-cw-handson}"
APP_NAMESPACE="${APP_NAMESPACE:-sample-observability}"

echo "== Kubernetes namespace check =="
if kubectl get namespace "$APP_NAMESPACE" >/dev/null 2>&1; then
  echo "FOUND: namespace $APP_NAMESPACE still exists"
  kubectl get all -n "$APP_NAMESPACE"
else
  echo "OK: namespace $APP_NAMESPACE not found"
fi

echo "== EKS cluster check =="
if aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1; then
  echo "FOUND: EKS cluster $CLUSTER_NAME still exists"
else
  echo "OK: EKS cluster $CLUSTER_NAME not found"
fi

echo "== Load balancer check =="
aws elbv2 describe-load-balancers \
  --region "$AWS_REGION" \
  --query "LoadBalancers[?contains(LoadBalancerName, '$CLUSTER_NAME') || contains(DNSName, '$CLUSTER_NAME')].[LoadBalancerName,DNSName,State.Code]" \
  --output table || true

echo "== CloudWatch log group check =="
aws logs describe-log-groups \
  --region "$AWS_REGION" \
  --log-group-name-prefix "/aws/containerinsights/$CLUSTER_NAME" \
  --query 'logGroups[].{name:logGroupName,retention:retentionInDays,storedBytes:storedBytes}' \
  --output table

echo "== CloudWatch alarm check =="
aws cloudwatch describe-alarms \
  --region "$AWS_REGION" \
  --alarm-name-prefix "$CLUSTER_NAME" \
  --query 'MetricAlarms[].{name:AlarmName,state:StateValue}' \
  --output table

echo "Cleanup check completed. Review any FOUND items before closing the hands-on."
