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
[Web App: Next.js 15 / App Router]
    │  BFF プロキシ（/api/backend/...）経由
    ▼
[Cloud Run Service: FastAPI]
    ├── GET  /feed            レコメンド記事一覧
    ├── POST /articles/:id/star    → recommendation + podcast-generator ジョブを自動起動
    ├── POST /articles/:id/dismiss → recommendation ジョブを自動起動
    ├── GET  /podcasts
    ├── GET  /podcasts/:id
    └── GET/POST/DELETE /settings/sources

[Cloud Scheduler] 毎日 06:00 JST
    ├── rss-fetcher-job     RSS 取得 → Firestore
    └── recommendation-job  Gemini で関心スコア計算

[Cloud Tasks Worker]
    記事本文取得 → Gemini 2.5 Flash でスクリプト生成
    → Gemini TTS で音声合成 → Cloud Storage に MP3 保存
    → Push 通知
```

> **BFF プロキシ**: バックエンドに CORS ミドルウェアがないため、ブラウザからの直接 fetch は不可。`web/app/api/backend/[...path]/route.ts` がリクエストを中継し、`X-API-Key` をヘッダーで転送する。API 接続設定（ベース URL・API キー）はブラウザの localStorage に保存し、ビルド時固定の環境変数は使用しない。

### 使用サービス

| レイヤー | サービス |
|----------|---------|
| Web | Next.js 15, TypeScript, Tailwind CSS, Vitest |
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
├── web/              # Next.js 15 Web フロントエンド
│   ├── app/          # App Router（ページ・BFF プロキシ Route Handler）
│   ├── components/   # UI コンポーネント
│   ├── contexts/     # React Context（AppContext・AudioPlayerContext）
│   ├── hooks/        # カスタムフック
│   ├── lib/          # API クライアント・設定キー・フォーマット
│   ├── types/        # 共通型定義
│   └── tests/        # Vitest テストスイート
├── infra/            # GCP セットアップスクリプト
├── docs/
│   ├── prd/          # PRD（要件定義・Phase 2 候補）
│   ├── adr/          # アーキテクチャ決定レコード（ADR）
│   ├── design/       # UI/バックエンド設計ドキュメント（Web の正本: app-ui.html）
│   ├── spec/         # フロントエンド仕様書（Living Doc）
│   ├── tech/         # 技術文書（技術的残課題等）
│   ├── operations/   # 運用文書（ローカル開発手順・デプロイ状況）
│   ├── plan/         # 実装計画（実行中のみ。完了後は削除し恒久ドキュメントへ反映 — plan/README.md 参照）
│   └── superpowers/  # 旧実装プラン
└── .env.example      # 環境変数テンプレート（バックエンド用）
```

---

## セットアップ

### 前提条件

- Python 3.12+
- [uv](https://docs.astral.sh/uv/)（バックエンドの venv・依存・実行に使用）
- Node.js 22+
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

バックエンドの venv 作成・依存インストール・実行はすべて [uv](https://docs.astral.sh/uv/) 経由で行う（`agent-rules/11-testing-strategy.md` に準拠）。`requirements.txt` を依存の正本とし、`uv pip install` で依存をインストールする（厳密に環境を一致させたい場合は `uv pip sync` を使う）。

```bash
cd backend

# venv 作成 & 依存インストール（初回のみ。再作成時は uv venv に --clear を付与）
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -r requirements.txt -r requirements-dev.txt

# テスト（uv が作成した venv の python を明示実行。activate 不要）
.venv/bin/python -m pytest tests/ -v

# サーバー起動
API_KEY=dev .venv/bin/python -m uvicorn api.main:app --reload
```

### 4. Web フロントエンド（ローカル開発）

```bash
cd web
npm install
npm run dev
# http://localhost:3000 でアプリが起動
```

初回アクセス時にセットアップモーダルが表示される。バックエンドの API URL と API キーを入力して保存（localStorage に記録される）。

テスト実行:

```bash
cd web
npm test
# 期待結果: 全テスト PASS
```

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

- [PRD](docs/prd/2026-05-31-news-listen.md) — 要件定義・システムアーキテクチャ詳細・Phase 2 候補
- [Web フロントエンド仕様書](docs/spec/2026-06-10-web-frontend-spec.md) — API 契約・状態管理設計・画面/デザイン仕様・受け入れ基準
- [ADR](docs/adr/) — BFF プロキシ / API 契約優先 / 純 CSS トークン / テーマ機構の決定記録
- [Web ローカル開発・検証手順](docs/operations/web-local-dev.md)
- [バックエンド実装プラン](docs/superpowers/plans/2026-05-31-backend.md)
