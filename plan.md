# AudioNews 実装プラン (plan.md)

## 1. 進捗サマリー
- **インフラ/環境セットアップ**: 0% (0/2)
- **バックエンド (Python/FastAPI)**: 8% (1/13)
- **Web フロントエンド (Next.js/TS)**: 0% (0/6)
- **iOS アプリ (SwiftUI)**: 0% (0/8)
- **全体進捗率**: 3% (1/29)

---

## 2. インフラ・共通タスク
- [ ] **Task I-1: ローカル環境構築**
  - `.env` ファイルの設定。
- [ ] **Task I-2: GCP リソースセットアップ**
  - `infra/setup.sh` のドライラン及び実行による GCP API 有効化、Firestore / GCS バケット / Cloud Tasks / Service Account / Secret Manager / Artifact Registry の作成。

---

## 3. バックエンド実装タスク (backend/)
`docs/superpowers/plans/2026-05-31-backend.md` に基づく詳細実装タスク。

- [x] **Task B-1: Python 環境セットアップ**
  - `pyproject.toml`, `requirements.txt`, `requirements-dev.txt` 作成。仮想環境構築と依存関係インストール。
- [ ] **Task B-2: 共有データモデル定義**
  - `shared/models.py` (Article, UserPrefs, Recommendation, Podcast) 実装及びテスト。
- [ ] **Task B-3: Firestore クライアント実装**
  - `shared/firestore_client.py` 実装及びテスト（モック使用）。
- [ ] **Task B-4: Storage & Gemini クライアント実装**
  - `shared/storage_client.py` および `shared/gemini_client.py` 実装とテスト。
- [ ] **Task B-5: RSS フェッチャー実装**
  - `jobs/rss_fetcher/rss_fetcher.py` 実装。複数ソースの並行フェッチと重複排除。
- [ ] **Task B-6: 記事本文エクストラクター実装**
  - `jobs/rss_fetcher/content_extractor.py` 実装。`trafilatura` を用いたクリーンな本文抽出。
- [ ] **Task B-7: レコメンドエンジン実装**
  - `jobs/recommendation/recommender.py` 実装。Gemini 2.5 Flash でユーザー履歴に基づく関心スコア計算。
- [ ] **Task B-8: Podcast スクリプトジェネレーター実装**
  - `jobs/podcast_generator/script_generator.py` 実装。構造化 JSON での日本語イントロ・英語掛け合いスクリプト生成。
- [ ] **Task B-9: TTS ジェネレーター + Podcast 生成ジョブ実装**
  - `jobs/podcast_generator/tts_generator.py` 実装。セリフ単位の TTS 並列処理と FFmpeg による音声結合・保存。
- [ ] **Task B-10: FastAPI アプリ + 認証ミドルウェア実装**
  - `api/main.py` 実装。API キー認証ミドルウェアの実装。
- [ ] **Task B-11: API ルーター実装**
  - `/feed`, `/articles/{id}/star`, `/articles/{id}/dismiss`, `/podcasts`, `/settings` などのエンドポイント実装。
- [ ] **Task B-12: Docker 環境の構築**
  - `Dockerfile.jobs` と `Dockerfile.api` の作成とテスト。
- [ ] **Task B-13: Cloud Run デプロイと動作検証**
  - Cloud Run Service / Jobs へのデプロイと Cloud Scheduler の設定。

---

## 4. Web フロントエンド実装タスク (web/)
`docs/design/web-design.html` に基づく Next.js 実装タスク。

- [ ] **Task W-1: Next.js プロジェクト初期セットアップ**
  - Next.js 15 (App Router) + TS + Tailwind CSS v4 の環境構築。
- [ ] **Task W-2: 共通状態管理 & UIレイアウト構築**
  - React Context / useReducer を用いた APIキーなどのグローバル状態管理とナビゲーションバーの構築。
- [ ] **Task W-3: API クライアント実装**
  - バックエンド REST API と通信するための `fetch` ラッパー実装。
- [ ] **Task W-4: Feed 画面の実装**
  - RSS 記事一覧の表示、パーソナライズ順の並べ替え、スワイプジェスチャー / ボタンによる Star・Dismiss アクションの実装。
- [ ] **Task W-5: Podcast 画面 & 音声プレイヤー実装**
  - 生成されたエピソード一覧の表示、HTML5 Audio API を用いた再生・シーク・速度調整（x0.5〜x2.5）機能の実装。
- [ ] **Task W-6: Settings 画面の実装**
  - RSS 購読ソースの追加・削除、デフォルト難易度・再生速度設定の実装。

---

## 5. iOS アプリ実装タスク (ios/)
`docs/superpowers/plans/2026-05-31-ios-app.md` に基づく SwiftUI 実装タスク。

- [ ] **Task I-1: Xcode プロジェクトセットアップ**
  - Xcode での新規 SwiftUI プロジェクト作成とフォルダ構造の構築。
- [ ] **Task I-2: データモデル定義 (Swift)**
  - `Article`, `UserPrefs`, `Recommendation`, `Podcast` などの Swift 構造体定義。
- [ ] **Task I-3: API クライアント実装 (Swift)**
  - Swift での URLSession または Alamofire を用いた API 通信とエラーハンドリングの実装。
- [ ] **Task I-4: AppState と エントリポイントの実装**
  - `@Observable` を用いた共有状態管理とアプリライフサイクルの定義。
- [ ] **Task I-5: Feed タブの実装**
  - 記事のリスト表示、難易度バッジ、左右スワイプアクション (Star / Dismiss) の実装。
- [ ] **Task I-6: Podcast タブ + 音声プレイヤー実装**
  - 再生コントロール（再生/一時停止、再生速度、シークバー）と `AVPlayer` を用いたバックグラウンド再生機能の実装。
- [ ] **Task I-7: Settings タブの実装**
  - RSS ソースの追加・削除、デフォルト設定画面の実装。
- [ ] **Task I-8: 実機テストとデバッグ**
  - 実機シミュレータでの動作確認、GCP バックエンドとの接続テスト。
