# AudioNews システム仕様書 (spec.md)

## 1. 概要
本システムは、海外テックニュース（HackerNews、Zenn.dev 等）を自動収集し、AI（Gemini 2.5 Flash）を用いてパーソナライズされた Podcast スクリプトを作成し、音声合成（Gemini TTS / OpenAI TTS / Google TTS）によって Podcast を生成するシステムである。

ターゲットユーザーは英語学習中のエンジニアであり、日本語での概要導入から始まり、英語での男女掛け合い（話者A・B）による本編を再生することで、効率的な情報キャッチアップとリスニング練習を両立させる。

---

## 2. システム構成・技術スタック

### 2.1 全体アーキテクチャ
- **iOS アプリ**: SwiftUI ネイティブ (iOS 17+)
- **Web フロントエンド**: Next.js 15 (App Router) + Tailwind CSS v4
- **バックエンド**: Python 3.12 + FastAPI
- **バッチ処理**: Cloud Run Jobs (rss-fetcher, recommendation, podcast-generator) + Cloud Scheduler
- **データストア**: Cloud Firestore (Native モード)
- **ファイルストレージ**: Cloud Storage (音声 MP3 保存、30日ライフサイクルルール)
- **シークレット管理**: GCP Secret Manager
- **API 認証**: 固定 API キー（Secret Manager 経由、リクエストヘッダー `X-API-Key` で照合）

### 2.2 外部サービス & API
- **AI 処理**: Gemini 2.5 Flash（スクリプト生成、レコメンド関心スコア計算、Context Caching の利用）
- **音声合成 (TTS)**:
  - **MVP**: Gemini TTS のみ（`gemini-2.5-flash-preview-tts`）。日本語イントロと英語本編を結合。
  - **Post-MVP**: OpenAI TTS（話者A/B演じ分け・高速並列処理）へ移行予定。`audio-news-openai-key` Secret は作成済みだが未使用。

---

## 3. コア機能仕様

### 3.1 Feed 機能（ニュース一覧）
- **RSS 購読**: 初期ソースは HackerNews・Zenn.dev。設定から任意 RSS URL を追加・削除可能。
- **レコメンド表示**: ユーザーの Star / Dismiss 履歴を Gemini (Context Caching) で分析し、関心スコア順に並べ替えて毎日表示。
- **スワイプ操作（iOS/Web）**:
  - 右スワイプ / Star 操作: 記事を Star 状態にし、バックエンドの Podcast 生成キュー（Cloud Tasks）に即時投入。
  - 左スワイプ / Dismiss 操作: 記事を非表示にし、翌日以降のレコメンド対象から除外。
- **既読管理**: Dismiss された記事は表示しない。

### 3.2 Podcast 再生機能
- **エピソード一覧**: 単体記事から生成されたエピソードの一覧（ステータス：生成中/完了/失敗）を表示。
- **即時オンデマンド生成**: Star 操作から 1〜2 分で Podcast 音声を生成完了する。
- **再生コントロール**:
  - 再生速度調整: 8段階（x0.5, x0.8, x1.0, x1.2, x1.5, x1.8, x2.0, x2.5）。
  - 再生位置保存: 秒単位で再生進捗を記憶（Firestore + ローカルキャッシュ）。
- **音声構成**:
  - 日本語イントロ: 日付、タイトル、および記事概要（1〜5センテンス）を日本語で読み上げ。
  - 英語本編: 記事本文＋関連ニュースを英語で掛け合い（男性話者A・女性話者B）形式で読み上げ。

### 3.3 設定機能 (Settings)
- **RSSソース管理**: 購読中のRSSソース一覧表示、新規追加、削除。
- **デフォルト設定**: Podcast のデフォルト難易度、デフォルト再生速度を設定。

---

## 4. 主要 API エンドポイント
バックエンドは以下の REST API を提供する。リクエストには `X-API-Key` ヘッダーによる認証が必要。

| メソッド | パス | 説明 | MVP |
| :--- | :--- | :--- | :--- |
| GET | `/feed` | レコメンド済み記事一覧を取得 | ✅ |
| POST | `/articles/{id}/star` | 記事を Star 状態にし、Podcast 生成キューに投入 | ✅ |
| POST | `/articles/{id}/dismiss` | 記事を Dismiss（非表示）にする | ✅ |
| GET | `/podcasts` | 生成された Podcast エピソード一覧を取得 | ✅ |
| GET | `/podcasts/{id}` | 指定エピソードの詳細・音声URLを取得 | ✅ |
| GET | `/settings/sources` | 購読中の RSS ソース一覧を取得 | ✅ |
| POST | `/settings/sources` | RSS ソースを追加 | ✅ |
| DELETE | `/settings/sources?url=...` | RSS ソースを削除 | ✅ |
| PATCH | `/podcasts/{id}/position` | 再生位置（秒）を更新 | Post-MVP |
| GET | `/health` | ヘルスチェック | ✅ |

---

## 5. データモデル仕様 (Firestore)

### 5.1 `articles` コレクション
各ニュース記事のメタデータと本文を保持。
```json
{
  "id": "string",
  "title": "string",
  "url": "string",
  "source": "string",
  "content": "string",
  "published_at": "timestamp",
  "fetched_at": "timestamp",
  "content_fetched_at": "timestamp | null"
}
```

### 5.2 `userPrefs` コレクション
ユーザーの設定およびアクション履歴。
```json
{
  "user_id": "string",
  "starred_article_ids": "string[]",
  "dismissed_article_ids": "string[]",
  "rss_sources": [
    { "name": "string", "url": "string" }
  ],
  "default_difficulty": "string",
  "default_playback_speed": 1.0,
  "digest_enabled": true,
  "digest_article_count": 5
}
```

### 5.3 `recommendations` コレクション
日次でユーザーごとに作成されるレコメンド順序。ドキュメント ID は `{user_id}_{date}`。
```json
{
  "user_id": "string",
  "date": "string", // "YYYY-MM-DD"
  "articles": [
    { "article_id": "string", "score": 0.95 }
  ],
  "generated_at": "timestamp"  // 必須（nullable でない）
}
```

### 5.4 `podcasts` コレクション
生成された Podcast エピソードの情報。ドキュメント ID は UUID。
```json
{
  "id": "string",
  "type": "single" | "digest",
  "article_ids": "string[]",
  "difficulty": "string",          // "toeic_600" | "toeic_900" | "ielts_55" | "ielts_7" | "eiken_2" | "eiken_p1"
  "audio_url": "string",
  "japanese_intro_text": "string",
  "duration_seconds": 300,
  "status": "processing" | "completed" | "failed" | "partial_failed",
  "error_message": "string | null",
  "created_at": "timestamp",
  "user_id": "string"
  // Post-MVP: "playback_position_seconds": 0, "completed_at": "timestamp | null"
}
```

---

## 6. Podcast スクリプト・音声生成仕様
- **Gemini へのプロンプト指示による出力フォーマット**:
  ```json
  {
    "intro": {
      "language": "ja",
      "text": "日本語の導入テキスト"
    },
    "segments": [
      { "speaker": "A", "language": "en", "text": "話者Aのセリフ" },
      { "speaker": "B", "language": "en", "text": "話者Bのセリフ" }
    ]
  }
  ```
- **音声の結合**: 日本語イントロ、および各セグメントの音声を並列で TTS API より生成し、FFmpeg 等を用いて最終的な 1 つの MP3 ファイルとして結合する。部分的な合成失敗時は、失敗セリフをスキップして結合し、ステータスを `partial_failed` とする。
