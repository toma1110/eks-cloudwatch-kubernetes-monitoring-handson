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

### インストール手順の参考

このセクションは、ハンズオン開始前に何を入れればよいかを確認するための参考です。OS、CPUアーキテクチャ、社用PCの管理権限、既存のパッケージマネージャーによって最適な手順は変わるため、迷った場合やエラーが出た場合は各ツールの公式手順を優先してください。

すでにインストール済みの場合は、再インストールせずに後述のバージョン確認だけ実行してください。

- AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- kubectl: https://kubernetes.io/docs/tasks/tools/
- eksctl: https://docs.aws.amazon.com/eks/latest/eksctl/installation.html
- Helm: https://helm.sh/docs/intro/install/
- Terraform: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
- jq: https://jqlang.org/download/

#### Windows

1. Bashスクリプトを実行できるように、Git for WindowsまたはWSLを用意します。このリポジトリの `scripts/*.sh` はPowerShellではなく、Git BashまたはWSL上で実行する想定です。
2. AWS CLI v2はWindows用MSIインストーラーでインストールします。
3. kubectl、eksctl、Helm、Terraform、jqをそれぞれ公式手順に沿ってインストールし、実行ファイルを `PATH` に追加します。`PATH` を変更した後は、新しいターミナルを開き直してください。
4. Git BashまたはWSLで後述のバージョン確認を実行し、同じターミナルから `bash scripts/validate.sh` が動くことを確認します。

#### macOS

Homebrewを使う場合の例です。

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg ./AWSCLIV2.pkg -target /

brew tap aws/tap
brew tap hashicorp/tap
brew install kubectl aws/tap/eksctl helm hashicorp/tap/terraform jq
```

#### Ubuntu / Debian

UbuntuまたはDebian系Linuxでの例です。

```bash
sudo apt-get update
sudo apt-get install -y curl unzip gpg software-properties-common jq

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp
sudo install -m 0755 /tmp/eksctl /usr/local/bin/eksctl

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh

wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install -y terraform
```

インストール後、以下でコマンドが使えることを確認します。

```bash
aws --version
kubectl version --client
eksctl version
helm version
terraform version
jq --version
```

## 推奨リージョンと名前

講座では以下の値を例にします。必要に応じて変更してください。

```bash
export AWS_REGION=ap-northeast-1
export CLUSTER_NAME=eks-cw-handson
export APP_NAMESPACE=sample-observability
```

<a id="precheck-list"></a>

## 事前チェックリスト

AWSリソースを作る前に、ローカル環境と入力値だけを確認します。
ツールが未導入の場合は、先に [インストール手順の参考](#インストール手順の参考) を確認してください。

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
