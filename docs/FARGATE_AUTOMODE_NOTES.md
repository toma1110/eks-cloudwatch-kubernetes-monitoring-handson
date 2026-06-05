# Fargate / EKS Auto Mode補足

このハンズオンはEC2 Managed Node Groupを前提にしています。

## Fargate

FargateはNode管理を減らせますが、DaemonSet前提の収集やNodeメトリクスの見え方が変わります。Container Insightsの導線もEC2 Managed Node Groupと同じ説明では扱いません。

## EKS Auto Mode

EKS Auto ModeはAWS管理範囲が広がる選択肢です。受講者が見るべき場所、Node/Pod/Containerメトリクスの確認観点、コスト確認ポイントが標準ハンズオンと変わる可能性があります。

## 本講座での扱い

- 本編ハンズオンはEC2 Managed Node Group
- Fargate / EKS Auto Modeは補足レクチャー
- 専用構築ハンズオンは初版の範囲外
