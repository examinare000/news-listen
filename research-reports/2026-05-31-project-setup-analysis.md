# 調査報告書: プロジェクトセットアップと現状分析

## 調査概要
- **テーマ**: AudioNews プロジェクトの初期セットアップ状況と実装プランの整合性確認
- **期間**: 2026-05-31
- **調査者**: Gemini CLI

## 主要発見事項
- **ブランチ構成**: `main`, `develop` ブランチは初期コミットのみで、ソースコードはまだ配置されていない。
- **実装プラン**: `docs/superpowers/plans/` 配下に非常に詳細なバックエンド（Python）および iOS（SwiftUI）の実装プランが存在する。
- **技術スタック**: バックエンドは Python 3.12, FastAPI, Google GenAI (Gemini 2.5 Flash), Firestore, Cloud Storage を中心とした GCP 構成。
- **進捗状況**: プラン上の Task 1（Python 環境セットアップ）すら未着手の状態。

## 技術的詳細
### バックエンド実装プランの要点
- `backend/` ディレクトリ配下に `api/`, `jobs/`, `shared/` を配置する構成。
- 3つの Cloud Run Jobs (`rss-fetcher`, `recommendation`, `podcast-generator`) と 1つの Cloud Run Service (`api`) で構成。
- TDD を前提としており、各タスクにテストコードの実装ステップが含まれている。

### ライブラリの更新要件
以前の調査 (`research-reports/2026-05-31-initial-tech-investigation.md`) で指摘された通り、プラン内の `requirements.txt` のバージョンを最新化することが推奨される。
- `google-genai`: 1.0.0 → 2.7.0 (推奨)
- `trafilatura`: 1.12.1 → 2.0.0 (推奨)

## 推奨事項
1. **実装の開始**:
   - Claude を通じて Codex に対し、`docs/superpowers/plans/2026-05-31-backend.md` の Task 1 から順次実装を開始するよう提案する。
2. **非同期 Firestore クライアントの検討**:
   - プランでは同期クライアントが想定されているが、FastAPI との親和性を考え、`AsyncClient` への変更を検討する。
3. **CI/CD の早期導入**:
   - GCP へのデプロイフロー（Artifact Registry への Push や Cloud Run へのデプロイ）を早期に自動化することを推奨。

## 次のステップ
- [ ] 調査ブランチ `development/research/project-setup` での本レポートのコミットとプッシュ。
- [ ] Claude への完了報告。
