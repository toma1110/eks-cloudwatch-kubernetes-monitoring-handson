# EKS + CloudWatch Kubernetes監視ハンズオン

Amazon EKS上のKubernetesワークロードをCloudWatchで監視するための学習用ハンズオンです。

## 最初に必ず確認

このハンズオンはAWSリソースを作成します。EKSクラスター、EC2 worker node、EBS、LoadBalancer、CloudWatch Logs、Container Insights、CloudWatch Alarm、Dashboardなどで料金が発生する可能性があります。

作業前に、利用リージョン、削除手順、請求確認方法を確認してください。作業後は必ず `scripts/cleanup_check.sh` で残存確認を行います。

## このリポジトリの構成

```text
.
├── eksctl/                 # 学習用の最短EKS構築例
├── terraform/              # 実運用IaC寄りの最小構成例
├── helm/sample-app/        # EKSへ配置するサンプルアプリ
├── kubernetes/             # Kubernetes manifest読解用
├── cloudwatch/             # Alarm / Dashboardのサンプル
├── queries/                # Logs Insightsクエリ例
├── scripts/                # 事前確認・確認・削除漏れ確認
└── docs/                   # コストと削除、補足メモ
```

## 前提ツール

- AWS CLI
- kubectl
- eksctl
- Helm
- Terraform
- jq

## 推奨リージョンと名前

講座では以下の値を例にします。必要に応じて変更してください。

```bash
export AWS_REGION=ap-northeast-1
export CLUSTER_NAME=eks-cw-handson
export APP_NAMESPACE=sample-observability
```

## 事前チェック

AWSリソースを作る前に、ローカル環境と入力値だけを確認します。

```bash
bash scripts/validate.sh
```

このスクリプトは作成・更新・削除を行いません。

## ルート1: eksctlで学習用クラスターを作る

`eksctl` は学習用の最短ルートです。内部ではCloudFormation stackが作られるため、削除漏れ確認まで必ず行います。

```bash
eksctl create cluster -f eksctl/cluster.yaml
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl get nodes
kubectl get pods -A
```

CloudWatch Observability EKS add-onは、EKS Pod Identity Agentを入れてから、推奨Pod Identity設定を自動適用して有効化します。

```bash
eksctl create addon \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --name eks-pod-identity-agent

kubectl rollout status daemonset/eks-pod-identity-agent \
  -n kube-system \
  --timeout=180s

eksctl create addon \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --name amazon-cloudwatch-observability \
  --auto-apply-pod-identity-associations

aws eks describe-addon \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name amazon-cloudwatch-observability \
  --query 'addon.{name:addonName,status:status,version:addonVersion}' \
  --output table
```

## ルート2: Terraformで構成を読む

Terraformは実運用IaC寄りのルートです。学習用には `eksctl` が速いですが、レビュー可能なIaCとしてはTerraformを推奨します。

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
```

`terraform apply` はAWSリソースを作成します。実行前にコストと削除手順を確認してください。

## サンプルアプリをHelmでデプロイ

```bash
helm upgrade --install sample-app ./helm/sample-app \
  --namespace "$APP_NAMESPACE" \
  --create-namespace

kubectl get pods -n "$APP_NAMESPACE"
kubectl get service -n "$APP_NAMESPACE"
kubectl logs -n "$APP_NAMESPACE" deploy/sample-app --tail=20
```

`Service` はLoadBalancerを作成します。料金が発生するため、確認後は削除します。

## CloudWatchで確認する場所

- Container Insights: Node / Pod / Containerのメトリクス
- CloudWatch Logs: アプリログ、Podログ、CloudWatch Agent / Fluent Bit関連ログ
- Logs Insights: `queries/` のサンプルクエリ
- Alarm: `cloudwatch/alarm-pod-restarts.json`
- Dashboard: `cloudwatch/dashboard-container-insights.json`

### Alarm / Dashboardを作成する

サンプルJSON内の `CLUSTER_NAME` を現在のクラスター名に置き換えてから作成します。

```bash
mkdir -p tmp/cloudwatch

jq --arg cluster "$CLUSTER_NAME" '
  .AlarmName = ($cluster + "-pod-restarts")
  | (.Dimensions[] | select(.Name == "ClusterName") | .Value) = $cluster
' cloudwatch/alarm-pod-restarts.json > tmp/cloudwatch/alarm-pod-restarts.json

aws cloudwatch put-metric-alarm \
  --region "$AWS_REGION" \
  --cli-input-json file://tmp/cloudwatch/alarm-pod-restarts.json

jq --arg cluster "$CLUSTER_NAME" '
  (.widgets[]?.properties? | select(has("markdown")) | .markdown) |= gsub("CLUSTER_NAME"; $cluster)
  | (.widgets[]?.properties?.metrics[]?[]? | select(. == "CLUSTER_NAME")) = $cluster
' cloudwatch/dashboard-container-insights.json > tmp/cloudwatch/dashboard-container-insights.json

aws cloudwatch put-dashboard \
  --region "$AWS_REGION" \
  --dashboard-name "$CLUSTER_NAME-dashboard" \
  --dashboard-body file://tmp/cloudwatch/dashboard-container-insights.json
```

## Smoke Test

クラスター作成後の読み取り確認です。作成や削除はしません。

```bash
bash scripts/smoke_test.sh
```

## 削除

Helm releaseを削除します。

```bash
helm uninstall sample-app -n "$APP_NAMESPACE"
kubectl delete namespace "$APP_NAMESPACE"
```

eksctlルートの場合:

```bash
eksctl delete cluster --region "$AWS_REGION" --name "$CLUSTER_NAME"
```

Terraformルートの場合:

```bash
cd terraform
terraform destroy
```

最後に削除漏れを確認します。

```bash
bash scripts/cleanup_check.sh
```

CloudWatch Alarm、Dashboard、ロググループは、クラスター削除後も残る場合があります。検証後に不要であれば削除します。

```bash
aws cloudwatch delete-alarms \
  --region "$AWS_REGION" \
  --alarm-names "$CLUSTER_NAME-pod-restarts"

aws cloudwatch delete-dashboards \
  --region "$AWS_REGION" \
  --dashboard-names "$CLUSTER_NAME-dashboard"

for log_group in \
  "/aws/containerinsights/$CLUSTER_NAME/application" \
  "/aws/containerinsights/$CLUSTER_NAME/dataplane" \
  "/aws/containerinsights/$CLUSTER_NAME/host" \
  "/aws/containerinsights/$CLUSTER_NAME/performance" \
  "/aws/eks/$CLUSTER_NAME/cluster"; do
  aws logs delete-log-group \
    --region "$AWS_REGION" \
    --log-group-name "$log_group" || true
done
```

## Fargate / EKS Auto Modeについて

この初版ハンズオンはEC2 Managed Node Groupを前提にします。FargateやEKS Auto Modeでは、Node管理、DaemonSet前提の収集、Container Insightsの導線が変わるため、専用ハンズオンではなく補足レクチャーで整理します。

## 参考リンク

- Amazon EKS: https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html
- CloudWatch Observability EKS add-on: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Observability-EKS-addon.html
- Container Insights for EKS: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/deploy-container-insights-EKS.html
- eksctl getting started: https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html
- Terraform AWS EKS module: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
