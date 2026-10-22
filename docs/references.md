# 公式情報の参照先

以下は設計・実装時に確認するMicrosoft Learnの起点です。サービス仕様、APIバージョン、リージョン、GA/プレビュー状況は変わるため、デプロイ前に対象リージョンの最新ドキュメントを再確認してください。URLの現在の内容をこの作業環境からライブ検証できていないものは、確定した実装仕様ではなく参照候補として扱います。

| 領域 | 公式情報 |
| --- | --- |
| Azure AI Foundry Agent Service | [Agent Service overview](https://learn.microsoft.com/azure/ai-foundry/agents/overview) |
| Azure AI Search | [What is Azure AI Search?](https://learn.microsoft.com/azure/search/search-what-is-azure-search) |
| Azure Blob Storage | [Introduction to Azure Blob Storage](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction) |
| Azure App Service | [App Service overview](https://learn.microsoft.com/azure/app-service/overview) |
| Application Insights | [Application Insights overview](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview) |
| Azure SRE Agent | [Azure SRE Agent overview](https://learn.microsoft.com/azure/sre-agent/overview) |

Microsoft Learn MCPの正確な接続URL、認証・トランスポート、利用可能なツールは、公式の最新セットアップガイドとサービス側の設定を確認してから登録してください。Bicepの `learnMcpEndpoint` はその確認が済むまで空欄です。
