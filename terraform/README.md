# Terraform最小構成

このディレクトリは、実運用IaC寄りの読み物兼ハンズオン雛形です。

学習用にNAT Gatewayを使わず、public subnet上のManaged Node Groupで構成しています。本番ではprivate subnet、NATまたはVPC endpoint、より厳密なIAM/ネットワーク設計を検討してください。

## 実行例

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
```

`terraform apply` はAWSリソースを作成します。料金と削除手順を確認してから実行してください。

削除:

```bash
terraform destroy
```
