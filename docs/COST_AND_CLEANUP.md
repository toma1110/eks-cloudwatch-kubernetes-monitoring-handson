# コストと削除確認

## 主な課金要素

- EKSクラスター
- EC2 worker node
- EBS volume
- Elastic Load Balancing
- CloudWatch Logs
- Container Insights
- CloudWatch Alarm
- CloudWatch Dashboard
- データ転送

料金はリージョン、利用時間、ログ量、メトリクス量で変わります。実行前にAWS公式料金ページを確認してください。

## 削除順序

1. Helm releaseを削除する
2. Kubernetes namespaceを削除する
3. LoadBalancerが消えたか確認する
4. CloudWatch Alarm / Dashboardが不要なら削除する
5. EKS add-onを確認する
6. EKSクラスターを削除する
7. CloudWatch Logsの保持設定と残存ロググループを確認する
8. Billing / Cost Explorerで想定外の継続課金がないか確認する

## コマンド例

```bash
helm uninstall sample-app -n sample-observability
kubectl delete namespace sample-observability
eksctl delete cluster --region ap-northeast-1 --name eks-cw-handson
bash scripts/cleanup_check.sh
```

Terraformルートの場合:

```bash
cd terraform
terraform destroy
```

CloudWatch Alarm、Dashboard、Container Insightsロググループ、EKS control planeロググループが不要な場合:

```bash
aws cloudwatch delete-alarms \
  --region ap-northeast-1 \
  --alarm-names eks-cw-handson-pod-restarts

aws cloudwatch delete-dashboards \
  --region ap-northeast-1 \
  --dashboard-names eks-cw-handson-dashboard

for log_group in \
  /aws/containerinsights/eks-cw-handson/application \
  /aws/containerinsights/eks-cw-handson/dataplane \
  /aws/containerinsights/eks-cw-handson/host \
  /aws/containerinsights/eks-cw-handson/performance \
  /aws/eks/eks-cw-handson/cluster; do
  aws logs delete-log-group \
    --region ap-northeast-1 \
    --log-group-name "$log_group" || true
done
```

## 注意

`cleanup_check.sh` は削除操作を行いません。残っているリソースを見つけるための読み取り確認です。
