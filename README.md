# しらべてまとめるくん — platform

アプリケーション全体の設計、Azureインフラ（Bicep）、セキュリティと運用のナレッジを管理するリポジトリです。ユーザーが生成したレポート本文はここにはコミットせず、Azure Blob Storageを原本、Azure AI Searchを検索インデックスとして扱います。

## リポジトリ

| リポジトリ | 責務 |
| --- | --- |
| `shirabete-matomeru-kun-frontend` | TypeScriptのWeb UI。質問、回答と出典、レポート閲覧・検索 |
| `shirabete-matomeru-kun-backend` | Java / Spring Boot API。調査オーケストレーション、レポート作成・保存、検索 |
| `shirabete-matomeru-kun-platform` | Bicep、構成図、設計判断、セキュリティ・運用ナレッジ |

API契約とローカル起動手順は [アーキテクチャ概要](docs/architecture.md) を参照してください。

## ディレクトリ

```text
.
├── infra/
│   └── main.bicep
└── docs/
    ├── architecture.md
    ├── decisions.md
    ├── operations.md
    ├── references.md
    └── security.md
```

## Azureリソースの作成

テンプレートはリソースグループスコープです。作成にはAzure CLIとBicep CLIが必要です。**このリポジトリの作成時点ではAzureへのデプロイや課金リソースの作成は行っていません。**

```bash
az login
az account set --subscription <subscription-id>
az group create --name rg-shiramato-kun-dev --location japaneast
az deployment group what-if \
  --resource-group rg-shiramato-kun-dev \
  --template-file infra/main.bicep \
  --parameters environmentName=dev
```

差分を確認したあと、明示的に承認された環境でのみ `az deployment group create` を実行します。SKU、Azure AI Searchのリージョン提供状況、Foundryモデルの提供状況・クォータ、組織のネットワーク方針、必要なPrivate Endpoint/DNSを事前に確認してください。`what-if`だけでは、これらの要件やアプリケーションの接続確認は完了しません。

## 現在の境界

- BicepはApp Service API、Static Web Apps、Storage、Azure AI Search、Key Vault、Log Analytics、Application Insightsの土台を定義します。現状のAPIはBlob/Searchアダプター未実装なので、レポートの保存・検索にこれらのリソースはまだ使いません。
- Foundryプロジェクト・モデル・agentとMicrosoft Learn MCPは、リージョン・モデル・クォータ・接続仕様の環境差が大きいため、このテンプレートでは自動作成しません。接続設定と必要なID権限を環境ごとに確認してから追加します。
- Azure SRE Agent自体はテンプレートで作成しません。Azure MonitorとApplication Insightsによるテレメトリを先に整え、SRE Agentの利用可否を確認してから連携します。
- 初期テンプレートは公開エンドポイントを使い、レポートをApp Service内のローカルディスクに保存する開発用の土台です。ユーザー認証・認可、Blob/Search連携、閉域ネットワークが未実装のため、本番利用不可です。本番利用前に [セキュリティ設計](docs/security.md) のネットワーク、認証、権限、監査項目を完了してください。

## 関連ドキュメント

- [全体アーキテクチャとデータフロー](docs/architecture.md)
- [設計判断](docs/decisions.md)
- [運用・監視](docs/operations.md)
- [公式情報の参照先](docs/references.md)
- [セキュリティ設計と本番化チェックリスト](docs/security.md)