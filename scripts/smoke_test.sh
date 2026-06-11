#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-1}"
CLUSTER_NAME="${CLUSTER_NAME:-eks-cw-handson}"
APP_NAMESPACE="${APP_NAMESPACE:-sample-observability}"

echo "== Kubernetes =="
kubectl get nodes
kubectl get pods -A
kubectl get pods -n "$APP_NAMESPACE"
kubectl get service -n "$APP_NAMESPACE"

echo "== EKS =="
aws eks describe-cluster \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME" \
  --query 'cluster.{name:name,status:status,endpoint:endpoint}' \
  --output table

echo "== CloudWatch metrics =="
aws cloudwatch list-metrics \
  --region "$AWS_REGION" \
  --namespace ContainerInsights \
  --dimensions "Name=ClusterName,Value=$CLUSTER_NAME" \
  --max-items 20 \
  --output table

echo "== CloudWatch logs =="
aws logs describe-log-groups \
  --region "$AWS_REGION" \
  --log-group-name-prefix "/aws/containerinsights/$CLUSTER_NAME" \
  --query 'logGroups[].{name:logGroupName,retention:retentionInDays,storedBytes:storedBytes}' \
  --output table

echo "Smoke test completed. This script only performed read operations."
