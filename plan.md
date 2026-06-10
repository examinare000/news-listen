# AudioNews バックエンド実装計画 — Task 4〜13

> **対象スコープ**: `backend/` ディレクトリ内 Task 4〜13（Task 1〜3 完了済み）
> **生成日**: 2026-06-10
> **TDD サイクル**: RED (テスト作成・失敗確認) → GREEN (最小実装) → REFACTOR

---

## 進捗サマリー

| タスク | 状態 | ファイル |
|--------|------|---------|
| Task 4: Firestoreクライアント | ❌ 未着手 | `shared/firestore_client.py` |
| Task 5: Storage + Gemini クライアント | ❌ 未着手 | `shared/storage_client.py`, `shared/gemini_client.py` |
| Task 6: RSSフェッチャー | ❌ 未着手 | `jobs/rss_fetcher/rss_fetcher.py` |
| Task 7: コンテンツエクストラクター | ❌ 未着手 | `jobs/rss_fetcher/content_extractor.py`, `main.py` |
| Task 8: レコメンドエンジン | ❌ 未着手 | `jobs/recommendation/recommender.py`, `main.py` |
| Task 9: スクリプトジェネレーター | ❌ 未着手 | `jobs/podcast_generator/script_generator.py` |
| Task 10: TTS + ポッドキャスト生成ジョブ | ❌ 未着手 | `jobs/podcast_generator/tts_generator.py`, `main.py` |
| Task 11: FastAPI + 認証 | ❌ 未着手 | `api/main.py`, `api/schemas.py` |
| Task 12: API ルーター4本 | ❌ 未着手 | `api/routers/{feed,articles,podcasts,settings}.py` |
| Task 13: Dockerfile | ❌ 未着手 | `Dockerfile.jobs`, `Dockerfile.api`, `.dockerignore` |

---

## 並列実行グループ 1（即時開始）

### Task 4: Firestore クライアント

**目的**: Firestore の CRUD 操作を集約する薄いラッパーを実装する。

---

#### Step 4-1: conftest.py を作成

**作成ファイル**: `backend/tests/conftest.py`

```python
import pytest
from unittest.mock import MagicMock, patch


@pytest.fixture
def mock_firestore_db():
    """Firestore クライアントのモック。FirestoreClient を使う全テストで利用可能。"""
    with patch("shared.firestore_client.firestore.Client") as mock_client_class:
        mock_db = MagicMock()
        mock_client_class.return_value = mock_db
        yield mock_db
```

**テスト方法**: このステップ単独のテストなし（後続テストの前提条件）

---

#### Step 4-2: test_firestore_client.py を作成（RED）

**作成ファイル**: `backend/tests/test_firestore_client.py`

実装すべきテスト:
1. `test_save_article_calls_firestore_set` — `article.save_article()` が `set()` を1回呼ぶ
2. `test_article_exists_returns_true_when_document_exists` — `doc.exists=True` の場合 `True`
3. `test_article_exists_returns_false_when_document_missing` — `doc.exists=False` の場合 `False`
4. `test_get_user_prefs_returns_default_when_not_found` — 不在時はデフォルト値 (`default_difficulty="toeic_900"`)

**RED 確認コマンド**:
```bash
python -m pytest tests/test_firestore_client.py -v --tb=short
```
期待: `ModuleNotFoundError: No module named 'shared.firestore_client'`

---

#### Step 4-3: firestore_client.py を実装（GREEN）

**作成ファイル**: `backend/shared/firestore_client.py`

実装要点:
- `FirestoreClient.__init__`: `self._db = firestore.Client()`
- `save_article`: `article.model_dump()` から `"id"` を pop して `set(data, merge=True)`
- `get_user_prefs`: ドキュメント不在時 → `UserPrefs(user_id=user_id, default_difficulty="toeic_900")`
- 全メソッドは `spec.md §2.1` のインターフェース準拠

**GREEN 確認コマンド**:
```bash
python -m pytest tests/test_firestore_client.py -v --tb=short
```
期待: `4 passed`

---

### Task 5: Storage + Gemini クライアント

**目的**: Cloud Storage と Gemini API のラッパーを実装する。

---

#### Step 5-1: storage_client.py を作成

**作成ファイル**: `backend/shared/storage_client.py`

実装要点:
- `GCS_BUCKET_NAME` 環境変数を `__init__` で読み込む
- `upload_audio`: blob path = `podcasts/{podcast_id}/{difficulty}.mp3`、`make_public()` → public URL を返す
- `get_signed_url`: `timedelta(seconds=expiration_seconds)` を使用

テストなし（モックが複雑すぎ・動作は Task 10 の統合時に確認）

---

#### Step 5-2: test_gemini_client.py を作成（RED）

**作成ファイル**: `backend/tests/test_gemini_client.py`

実装すべきテスト:
1. `test_generate_text_returns_string` — `response.text` の文字列が返る
2. `test_generate_tts_returns_bytes` — `response.candidates[0].content.parts[0].inline_data.data` が返る

モック方針: `patch("shared.gemini_client.genai.Client")` でクラスをモック → `mock_client.models.generate_content.return_value` を設定

**RED 確認コマンド**:
```bash
python -m pytest tests/test_gemini_client.py -v --tb=short
```
期待: `ModuleNotFoundError: No module named 'shared.gemini_client'`

---

#### Step 5-3: gemini_client.py を実装（GREEN）

**作成ファイル**: `backend/shared/gemini_client.py`

実装要点:
- `from google import genai` + `from google.genai import types`
- `generate_text`: `types.GenerateContentConfig(temperature=temperature)` を使用
- `generate_tts`: `response_modalities=["AUDIO"]` + `SpeechConfig(VoiceConfig(PrebuiltVoiceConfig(voice_name=voice)))`

**GREEN 確認コマンド**:
```bash
python -m pytest tests/test_gemini_client.py -v --tb=short
```
期待: `2 passed`

---

## 並列実行グループ 2（Group 1 完了後）

### Task 6: RSS フェッチャー

**目的**: feedparser で RSS フィードをパースし Article リストを生成する。

---

#### Step 6-1: test_rss_fetcher.py を作成（RED）

**作成ファイル**: `backend/tests/test_rss_fetcher.py`

実装すべきテスト:
1. `test_fetch_returns_articles_for_valid_feed` — 2エントリ → `len(articles)==2`, `articles[0].title=="Article A"`
2. `test_fetch_skips_entries_without_link` — link="" のエントリをスキップ
3. `test_article_id_is_deterministic` — 同 URL で同じ ID が返る
4. `test_article_id_differs_for_different_urls` — 異なる URL で異なる ID

**モック設計** (`_make_entry` ヘルパー):
```python
def _make_entry(title, link, published="Mon, 01 Jan 2024 00:00:00 +0000", summary=""):
    entry = MagicMock()
    entry.title = title           # 直接属性設定
    entry.link = link             # 直接属性設定
    entry.summary = summary       # 直接属性設定
    entry.published = published   # 直接属性設定
    entry.get.return_value = published  # _parse_date で entry.get("published") に使用
    return entry
```

**RED 確認コマンド**:
```bash
python -m pytest tests/test_rss_fetcher.py -v --tb=short
```
期待: `ModuleNotFoundError`

---

#### Step 6-2: rss_fetcher.py を実装（GREEN）

**作成ファイル**: `backend/jobs/rss_fetcher/rss_fetcher.py`

実装要点:
- `link = entry.link` を使用（**`entry.get("link")` は使わない**）
- `title = entry.title` を使用（**`entry.get("title")` は使わない**）
- `content = entry.summary or ""` を使用（**`entry.get("summary")` は使わない**）
- `_parse_date`: `entry.get("published")` / `entry.get("updated")` / `entry.get("created")` の順で試みる（この場合のみ `get()` を使用）
- `article_id_for`: `hashlib.sha256(url.encode()).hexdigest()[:20]`

**GREEN 確認コマンド**:
```bash
python -m pytest tests/test_rss_fetcher.py -v --tb=short
```
期待: `4 passed`

---

### Task 8: レコメンドエンジン

**目的**: Gemini API を使いユーザー履歴に基づいて記事スコアを計算する。

---

#### Step 8-1: test_recommender.py を作成（RED）

**作成ファイル**: `backend/tests/test_recommender.py`

実装すべきテスト:
1. `test_score_articles_returns_scores_for_all_candidates` — Gemini が JSON を返す → scores に変換される
2. `test_score_articles_returns_zero_scores_when_gemini_fails` — API エラー → 全候補に `score=0.5`
3. `test_score_articles_with_no_history_returns_default_scores` — 履歴なしでも正常動作

モック方針: `Recommender(gemini_client=mock_gemini)` でモックを DI

**RED 確認コマンド**:
```bash
python -m pytest tests/test_recommender.py -v --tb=short
```
期待: `ModuleNotFoundError`

---

#### Step 8-2: recommender.py を実装（GREEN）

**作成ファイル**: `backend/jobs/recommendation/recommender.py`

実装要点:
- フォールバックスコア: `0.5`
- JSON コードブロック除去: ` ``` ` が含まれる場合は分割して `json` プレフィクスを除去
- `candidates` 空リスト → 早期 `return []`

**GREEN 確認コマンド**:
```bash
python -m pytest tests/test_recommender.py -v --tb=short
```
期待: `3 passed`

---

#### Step 8-3: recommendation/main.py を作成

**作成ファイル**: `backend/jobs/recommendation/main.py`

実装要点（テストなし — エントリポイントはモック困難）:
- 環境変数: `USER_ID` (デフォルト `"default"`)
- Dismiss 済みを除外してから `Recommender.score_articles()` 呼び出し
- `scores.sort(key=lambda s: s.score, reverse=True)`
- `Recommendation` 保存

---

### Task 9: スクリプトジェネレーター

**目的**: Gemini API を使い記事から Podcast スクリプト（日本語イントロ + 英語本編）を生成する。

---

#### Step 9-1: test_script_generator.py を作成（RED）

**作成ファイル**: `backend/tests/test_script_generator.py`

実装すべきテスト:
1. `test_generate_returns_script_with_japanese_intro_and_english_body` — `===JAPANESE_INTRO===` / `===ENGLISH_BODY===` マーカーが正しく分割される
2. `test_generate_uses_difficulty_in_prompt` — `"ielts"` が生成プロンプトに含まれること

**テスト 2 の注意点**: `call_args[0][0]` (プロンプト文字列) に `"ielts"` が含まれる必要がある。

**RED 確認コマンド**:
```bash
python -m pytest tests/test_script_generator.py -v --tb=short
```
期待: `ModuleNotFoundError`

---

#### Step 9-2: script_generator.py を実装（GREEN）

**作成ファイル**: `backend/jobs/podcast_generator/script_generator.py`

実装要点:
- `difficulty_instruction = f"[{difficulty}] {_DIFFICULTY_INSTRUCTIONS.get(difficulty, difficulty)}"` でキー文字列をプロンプトに含める
- フォーマットマーカーが不在時: `japanese_intro=""`, `english_body=raw`, ログ警告

**GREEN 確認コマンド**:
```bash
python -m pytest tests/test_script_generator.py -v --tb=short
```
期待: `2 passed`

---

## 並列実行グループ 3（Group 2 完了後）

### Task 7: コンテンツエクストラクター + RSS エントリポイント

---

#### Step 7-1: test_content_extractor.py を作成（RED）

**作成ファイル**: `backend/tests/test_content_extractor.py`

実装すべきテスト:
1. `test_extract_returns_text_when_trafilatura_succeeds` — `fetch_url` + `extract` 成功 → テキストを返す
2. `test_extract_returns_empty_string_when_fetch_fails` — `fetch_url` が `None` → `""`
3. `test_extract_returns_empty_string_when_extract_returns_none` — `extract` が `None` → `""`

**RED 確認コマンド**:
```bash
python -m pytest tests/test_content_extractor.py -v --tb=short
```
期待: `ModuleNotFoundError`

---

#### Step 7-2: content_extractor.py を実装（GREEN）

**作成ファイル**: `backend/jobs/rss_fetcher/content_extractor.py`

実装要点:
- `html = trafilatura.fetch_url(url)` → `None` なら `""` を返す
- `text = trafilatura.extract(html, include_comments=False, include_tables=False)` → `None` なら `""` を返す

**GREEN 確認コマンド**:
```bash
python -m pytest tests/test_content_extractor.py -v --tb=short
```
期待: `3 passed`

---

#### Step 7-3: rss_fetcher/main.py を作成

**作成ファイル**: `backend/jobs/rss_fetcher/main.py`

実装要点（テストなし — エントリポイント）:
- `article.content` が 200 文字未満なら `ContentExtractor.extract()` で補完
- `db.article_exists()` でスキップ判定
- 各ソースのエラーを `try/except` でキャッチしてログ出力し続行

---

### Task 10: TTS ジェネレーター + ポッドキャスト生成ジョブ

---

#### Step 10-1: test_tts_generator.py を作成（RED）

**作成ファイル**: `backend/tests/test_tts_generator.py`

実装すべきテスト:
1. `test_generate_audio_concatenates_intro_and_body` — TTS が 2 回呼ばれ、結合した bytes が返る
2. `test_generate_audio_uses_different_voices_for_languages` — `calls[0][1]["voice"] != calls[1][1]["voice"]`

**RED 確認コマンド**:
```bash
python -m pytest tests/test_tts_generator.py -v --tb=short
```
期待: `ModuleNotFoundError`

---

#### Step 10-2: tts_generator.py を実装（GREEN）

**作成ファイル**: `backend/jobs/podcast_generator/tts_generator.py`

実装要点:
- `_JP_VOICE = "Kore"`, `_EN_VOICE = "Puck"`
- `generate_audio`: `jp_audio + en_audio` を返す（PCM 結合）

**GREEN 確認コマンド**:
```bash
python -m pytest tests/test_tts_generator.py -v --tb=short
```
期待: `2 passed`

---

#### Step 10-3: podcast_generator/main.py を作成

**作成ファイル**: `backend/jobs/podcast_generator/main.py`

実装要点（テストなし — エントリポイント）:
- 環境変数: `USER_ID` (デフォルト `"default"`), `DIFFICULTY` (デフォルト `"toeic_900"`)
- `podcast_exists_for_article()` でスキップ判定
- 音声長さ概算: `len(audio_bytes) // 48000`
- 失敗時は `continue` してログ出力（`status="failed"` 保存は後続の改良対象）

---

### Task 11: FastAPI アプリ + 認証

---

#### Step 11-1: schemas.py を作成

**作成ファイル**: `backend/api/schemas.py`

実装: `spec.md §4.6` の全スキーマを実装

---

#### Step 11-2: test_api_feed.py を作成（RED）

**作成ファイル**: `backend/tests/test_api_feed.py`

実装すべきテスト:
1. `test_feed_requires_api_key` — ヘッダーなし → `HTTP 401`
2. `test_feed_with_valid_api_key_returns_200` — 正しいキー → `HTTP 200`, `"articles"` in body
3. `test_feed_with_invalid_api_key_returns_401` — 誤ったキー → `HTTP 401`

**フィクスチャ注意事項**:
```python
@pytest.fixture
def client():
    with patch.dict("os.environ", {"API_KEY": "test-secret-key", "USER_ID": "user1"}):
        import importlib
        import api.main as m
        importlib.reload(m)
        yield TestClient(m.app)  # return ではなく yield を使うこと
```

**RED 確認コマンド**:
```bash
python -m pytest tests/test_api_feed.py -v --tb=short
```
期待: `ImportError` または `ModuleNotFoundError`

---

#### Step 11-3: api/main.py を実装（GREEN）

**作成ファイル**: `backend/api/main.py`

実装要点:
- `APIKeyHeader(name="X-API-Key", auto_error=False)`
- `verify_api_key`: `api_key` が `None` または不一致 → `HTTP 401`
- `GET /health` は認証依存なし
- 4 ルーター全てに `Security(verify_api_key)` を依存として付与

**GREEN 確認コマンド**:
```bash
python -m pytest tests/test_api_feed.py -v --tb=short
```
期待: `3 passed`

---

## 逐次実行（Task 11 完了後）

### Task 12: API ルーター 4 本

---

#### Step 12-1: feed.py を作成

**作成ファイル**: `backend/api/routers/feed.py`

実装要点:
- `db.get_recommendation(user_id, today)` → `None` なら `FeedResponse(articles=[], date=today)`
- 上位 50 件を `get_article()` で個別取得

---

#### Step 12-2: articles.py を作成

**作成ファイル**: `backend/api/routers/articles.py`

実装要点:
- `article_exists()` でチェック → 不在なら `HTTP 404`

---

#### Step 12-3: podcasts.py を作成

**作成ファイル**: `backend/api/routers/podcasts.py`

実装要点:
- `GET /podcasts/{podcast_id}`: `get_podcasts_for_user()` で全件取得後にフィルタ → 不在なら `HTTP 404`

---

#### Step 12-4: settings.py を作成

**作成ファイル**: `backend/api/routers/settings.py`

実装要点:
- POST: URL 重複チェック → 重複なら `HTTP 409`
- DELETE: URL 存在チェック → 不在なら `HTTP 404`
- `model_copy(update={...})` で不変コピーを作成

---

#### Step 12-5: test_api_articles.py を作成（RED）

**作成ファイル**: `backend/tests/test_api_articles.py`

実装すべきテスト:
1. `test_star_article_returns_200_when_article_exists` — `add_starred_article` が呼ばれる
2. `test_star_article_returns_404_when_article_not_found` — `HTTP 404`
3. `test_dismiss_article_returns_200` — `add_dismissed_article` が呼ばれる

**フィクスチャ**: `yield TestClient(m.app)` を使用（`return` 不可）

**RED → GREEN 確認**:
```bash
python -m pytest tests/test_api_articles.py -v --tb=short
```

---

#### Step 12-6: test_api_settings.py を作成（RED）

**作成ファイル**: `backend/tests/test_api_settings.py`

実装すべきテスト:
1. `test_get_sources_returns_default_sources` — デフォルト空リストが返る
2. `test_add_source_saves_new_source` — `save_user_prefs` が呼ばれる
3. `test_add_duplicate_source_returns_409` — `HTTP 409`

**フィクスチャ**: `yield TestClient(m.app)` を使用（`return` 不可）

**RED → GREEN 確認**:
```bash
python -m pytest tests/test_api_settings.py -v --tb=short
```

---

#### Step 12-7: test_api_podcasts.py を作成（RED）

**作成ファイル**: `backend/tests/test_api_podcasts.py`

実装すべきテスト:
1. `test_list_podcasts_returns_empty_when_no_podcasts` — ユーザーの Podcast がゼロ件 → `HTTP 200`, `podcasts=[]`
2. `test_get_podcast_returns_404_when_not_found` — 存在しない ID → `HTTP 404`
3. `test_list_podcasts_returns_podcasts_for_user` — Podcast ありの場合 → `HTTP 200`, `len(podcasts)>0`

**フィクスチャ**: `yield TestClient(m.app)` を使用（`return` 不可）

**RED → GREEN 確認**:
```bash
python -m pytest tests/test_api_podcasts.py -v --tb=short
```

---

#### Step 12-8: 全テスト通過確認

```bash
python -m pytest tests/ -v --tb=short
```
期待: 全テスト `passed`（30件前後）

---

## 逐次実行（全実装完了後）

### Task 13: Dockerfile 作成（Step 1〜3 のみ）

---

#### Step 13-1: Dockerfile.jobs を作成

**作成ファイル**: `backend/Dockerfile.jobs`

内容は `spec.md §5.1` 参照。`JOB_MODULE` 環境変数でジョブを切り替え。

---

#### Step 13-2: Dockerfile.api を作成

**作成ファイル**: `backend/Dockerfile.api`

内容は `spec.md §5.2` 参照。ポート 8080 で uvicorn 起動。

---

#### Step 13-3: .dockerignore を作成

**作成ファイル**: `backend/.dockerignore`

内容は `spec.md §5.3` 参照。`.venv/`, `tests/`, `__pycache__/` 等を除外。

---

## 実行順序まとめ

```
[並列] Task 4 (Firestore) ────────┐
[並列] Task 5 (Storage+Gemini) ───┤
                                   ↓
[並列] Task 6 (RSS Fetcher) ──────┐
[並列] Task 8 (Recommender) ──────┤ Group 2 完了後
[並列] Task 9 (ScriptGen) ────────┤
                                   ↓
[並列] Task 7 (Content+Main) ─────┐
[並列] Task 10 (TTS+Main) ────────┤ Group 3 完了後
[並列] Task 11 (FastAPI) ─────────┤
                                   ↓
[逐次] Task 12 (Routers 4本) ─────┤ Task 11 完了後
                                   ↓
[逐次] Task 13 (Dockerfile) ──────┘ 全実装完了後
```

---

## 各タスクの Atomic Commit 規約

| タスク | テストコミットメッセージ | 実装コミットメッセージ |
|--------|----------------------|---------------------|
| Task 4 | `テスト: Firestoreクライアントのモックテストを先行定義` | `機能: Firestoreクライアント（記事・ユーザー設定・Podcast操作）を実装` |
| Task 5 | `テスト: GeminiクライアントのTDD Redフェーズを定義` | `機能: Cloud StorageクライアントとGemini APIラッパーを実装` |
| Task 6 | `テスト: RSSフェッチャーのTDD Redフェーズを定義` | `機能: feedparserを使ったRSSフェッチャーを実装` |
| Task 7 | `テスト: コンテンツエクストラクターのTDD Redフェーズを定義` | `機能: trafilaturaを使ったコンテンツエクストラクターとRSSジョブエントリポイントを実装` |
| Task 8 | `テスト: レコメンドエンジンのTDD Redフェーズを定義` | `機能: Gemini APIを使ったレコメンドエンジンを実装` |
| Task 9 | `テスト: スクリプトジェネレーターのTDD Redフェーズを定義` | `機能: Gemini APIを使ったPodcastスクリプトジェネレーターを実装` |
| Task 10 | `テスト: TTSジェネレーターのTDD Redフェーズを定義` | `機能: TTSジェネレーターとPodcast生成ジョブエントリポイントを実装` |
| Task 11 | `テスト: FastAPIとAPIキー認証のTDD Redフェーズを定義` | `機能: FastAPIアプリとAPIキー認証ミドルウェアを実装` |
| Task 12 | `テスト: APIルーター（articles/settings/podcasts）のTDD Redフェーズを定義` | `機能: APIルーター4本（feed/articles/podcasts/settings）を実装` |
| Task 13 | — | `設定: DockerfileとdockerignoreをCloud Run向けに作成` |
