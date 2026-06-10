# news-listen

海外テックニュースを自動収集し、AI が Podcast 形式の音声に変換する個人向けアプリ。
通勤・家事中に耳でテックニュースをキャッチアップしながら英語リスニング練習もできる。

---

## 概要

| 項目 | 内容 |
|------|------|
| ターゲット | 英語学習中のエンジニア（TOEIC 600〜900 相当）、最大 5 名の個人・ファミリー利用 |
| ニュースソース | HackerNews・Zenn.dev（アプリ内から任意 RSS URL を追加可能） |
| Podcast 生成 | Star した記事を 1〜2 分で音声化。日本語イントロ → 英語本編（男女掛け合い） |
| 難易度 | TOEIC 600〜 / TOEIC 730-900 / IELTS 5.5-6.5 / IELTS 7.0+ / 英検2級 / 英検準1級 の 6 段階 |
| 月次コスト | 約 $2.67（1 ユーザー・1 日 5 エピソード） |

---

## アーキテクチャ

```
[iOS App: SwiftUI]
    │  X-API-Key 認証
    ▼
[Cloud Run Service: FastAPI]
    ├── GET  /feed            レコメンド記事一覧
    ├── POST /articles/:id/star    → Cloud Tasks にPodcast生成タスク投入
    ├── POST /articles/:id/dismiss
    ├── GET  /podcasts
    └── GET/PUT /settings

[Cloud Scheduler] 毎日 06:00 JST
    ├── rss-fetcher-job     RSS 取得 → Firestore
    └── recommendation-job  Gemini で関心スコア計算

[Cloud Tasks Worker]
    記事本文取得 → Gemini 2.5 Flash でスクリプト生成
    → Gemini TTS で音声合成 → Cloud Storage に MP3 保存
    → Push 通知
```

### 使用サービス

| レイヤー | サービス |
|----------|---------|
| iOS | SwiftUI, AVFoundation, iOS 17+ |
| バックエンド | Python 3.12, FastAPI, Cloud Run, Cloud Tasks |
| バッチ | Cloud Run Jobs, Cloud Scheduler |
| AI | Gemini 2.5 Flash（スクリプト生成・レコメンド）+ Gemini TTS（音声合成） |
| ストレージ | Firestore（データ）, Cloud Storage（音声ファイル） |
| 認証・設定 | Secret Manager |

---

## ディレクトリ構成

```
news-listen/
├── backend/          # Python (FastAPI) バックエンド
│   ├── shared/       # 共通モデル・Firestore/Storage/Gemini クライアント
│   ├── jobs/         # Cloud Run Jobs（RSS取得・レコメンド・Podcast生成）
│   ├── api/          # FastAPI REST API
│   └── tests/        # pytest テストスイート
├── ios/              # Swift iOS アプリ
├── infra/            # GCP セットアップスクリプト
├── docs/
│   ├── prd/          # PRD（要件定義）
│   ├── design/       # UI/バックエンド設計ドキュメント
│   └── superpowers/  # 実装プラン
└── .env.example      # 環境変数テンプレート
```

---

## セットアップ

### 前提条件

- Python 3.12+
- `gcloud` CLI（認証済み）
- GCP プロジェクト作成済み

### 1. 環境変数

```bash
cp .env.example .env
# .env に GCP_PROJECT_ID, GCS_BUCKET_NAME, GEMINI_API_KEY, API_KEY, USER_ID を設定
```

### 2. GCP リソース作成

```bash
bash infra/setup.sh
```

### 3. バックエンド（ローカル開発）

```bash
cd backend
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt

# テスト
python -m pytest tests/ -v

# サーバー起動
API_KEY=dev uvicorn api.main:app --reload
```

### 4. iOS アプリ

Xcode 16 以上で `ios/TechNewsPodcast.xcodeproj` を開き、ビルド・実行。
初回起動時に表示される設定画面で Cloud Run の API URL と API キーを入力。

---

## 機能一覧

### Feed タブ
- HackerNews・Zenn 等の RSS を毎日自動収集
- Gemini による過去の Star/Dismiss 履歴に基づくパーソナライズ表示
- 右スワイプ → Star（Podcast 生成キューに追加）
- 左スワイプ → Dismiss（非表示・翌日以降も除外）

### Podcast タブ
- Star した記事が 1〜2 分で Podcast に変換される
- 日本語イントロ（記事概要）→ 英語本編（掛け合い形式）
- 難易度・再生速度（×0.5〜×2.5）の調整
- 再生位置の秒単位保存

### Settings タブ
- RSS ソースの追加・削除
- デフォルト難易度・再生速度の設定

---

## ドキュメント

- [PRD](docs/prd/2026-05-31-news-listen.md) — 要件定義・システムアーキテクチャ詳細
- [バックエンド実装プラン](docs/superpowers/plans/2026-05-31-backend.md)
- [iOS 実装プラン](docs/superpowers/plans/2026-05-31-ios-app.md)
