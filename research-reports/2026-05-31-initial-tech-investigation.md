# 初期技術調査報告書 (2026-05-31)

## 調査概要
- **テーマ**: プロジェクト AudioNews の技術スタックおよび初期コードベース分析
- **期間**: 2026-05-31
- **調査者**: Gemini CLI

## 主要発見事項
1. **プロジェクトの現状**:
   - PRDおよびバックエンド/iOSの実装プランは詳細に策定済み。
   - 実装コードは未着手（`main`および`develop`ブランチにソースコードなし）。
2. **技術スタックの検証 (2026年5月時点)**:
   - **Google GenAI**: 最新 v2.7.0。`gemini-2.5-flash` モデルの使用が推奨。新しい `google-genai` SDK（`genai.Client`）への移行が必要。
   - **Trafilatura**: 最新 v2.0.0。`Extractor` クラスを用いた実装と、LLM親和性の高い Markdown 出力設定がベストプラクティス。
   - **Feedparser**: 最新 v6.0.12。小規模なら十分だが、型安全性を重視する場合は `atoma`、速度重視なら `FastFeedParser` への代替も検討の余地あり。
   - **Firestore**: 最新 v2.27.0。`AsyncClient` による非同期処理が推奨。

## 技術的詳細

### 1. Google GenAI (Gemini 2.5 Flash)
- **SDK**: `google-genai` (旧 `google-generativeai` から移行)
- **最新機能**: Context Caching, Live API (Real-time), 改善された並列生成。
- **実装案**: `genai.Client` を使用し、非同期 (`client.aio`) でのリクエストを基本とする。

### 2. 本文抽出 (Trafilatura)
- **推奨設定**: `Extractor(output_format="markdown", include_links=True)`
- **利点**: LLMが記事構造（見出し、リンク）を把握しやすくなり、Podcastスクリプトの精度が向上する。

### 3. データストア (Firestore)
- **推奨**: `google-cloud-firestore` の `AsyncClient`。
- **注意点**: プランでは同期的な `Client` が想定されているが、FastAPI (async) と組み合わせる場合は非同期版が望ましい。

## 推奨事項
1. **ライブラリバージョンの更新**:
   - `requirements.txt` の `google-genai` を `2.7.0`、`trafilatura` を `2.0.0` に更新することを推奨。
2. **非同期実装の採用**:
   - バックエンド（FastAPI）およびFirestore操作を非同期 (async/await) で実装し、パフォーマンスとスケーラビリティを確保する。
3. **プロンプトエンジニアリングの最適化**:
   - Trafilatura の Markdown 出力を前提とした Gemini への指示出しを設計する。

## 次のステップ
- [ ] バックエンドの初期ディレクトリ構造作成 (Codexへの指示準備)
- [ ] iOSアプリのプロジェクト構成確認
- [ ] RSSソースの具体的な選定とテスト取得の検証
