## ai_review
I've completed the comprehensive sweep. I verified every source file against the spec and the AI-antipattern criteria. Here is my review.

---

# AI Antipattern Review — 1回目 / 判定: **REJECT**

ベース: `baea491`（マージベース）からの累積差分。`web/` 全体が新規追加のため全ファイルがスコープ内。本 run の Report Directory には過去の ai-review レポートはなく、初回網羅レビュー。`coder-decisions.md` は存在しない。

## ブロッキング指摘

### 🔴 AI-NEW-default-speed-wiring（new）— デフォルト再生速度の配線忘れ（機構はあるがエントリポイントに渡っていない）

- **該当**: `web/app/settings/page.tsx:17,86` / `web/contexts/AppContext.tsx:25-35,102-118` / `web/components/AudioPlayerBar.tsx:89`
- **何が問題か**:
  - spec §10.5 (L239) は「デフォルト再生速度セレクタ → **localStorage 保存 + AppContext 反映**」を要求。実装は `useLocalStorage` で localStorage に書くのみで、`dispatch({type:'SET_SPEED'})` を呼ばず **AppContext へ反映していない**。
  - spec §10.3 (L213) は AudioPlayerBar の「速度セレクタ（8 段階、**初期値はデフォルト速度**）」を要求。しかし `AppContext` の `playbackSpeed` は `1.0` 固定初期化（L34）で、restore effect（L102-118）も `default_playback_speed` を読まない。`AudioPlayerBar` のセレクタは `value={state.playbackSpeed}`（L89）なので、ユーザーがデフォルト速度を 1.5 等に設定しても**再生バーの初期速度に一切反映されない**。
  - grep 確認: `KEY_DEFAULT_PLAYBACK_SPEED` / `default_playback_speed` を読むのは settings ページのみ。つまりこの設定値は**書き込み専用で、実再生に効果ゼロ**（AI 特有の「配線忘れ」+ 要求不一致）。
- **どう修正すべきか**:
  1. `AppProvider` のマウント時 restore effect で `localStorage` の `default_playback_speed` を読み、`SET_SPEED` で初期化する（不正値は 1.0 フォールバック）。これで「セレクタ初期値＝デフォルト速度」を満たす。
  2. `settings/page.tsx` の `onChange` で localStorage 保存に加えて `dispatch({type:'SET_SPEED', speed})` を呼び、spec §10.5 の「AppContext 反映」を満たす。

### 🔴 AI-NEW-podcast-detail-replay（new）— 詳細ページ再生が spec「一覧と同フロー」に違反（インテグレーション不整合 + 復元欠落）

- **該当**: `web/app/podcast/[id]/page.tsx:52-58`（`handlePlay`）
- **何が問題か**: spec §10.3 (L209) は詳細の再生ボタンを「**一覧と同フロー**」と定義し、一覧フロー (L201 + §9 L151) は「再生押下時に必ず `getPodcast(id)` を呼び直して新鮮な署名付き URL を取得し、`podcast_position:{id}` から復元位置を渡す」。実装は:
  - `getPodcast` を呼び直さず、マウント時取得の `podcast.audio_url`（**失効しうる署名付き URL**）をそのまま使用 → spec §9 L151「**重要**…**必ず** `getPodcast(id)` を呼び直す」に違反。
  - `player.load(podcast.audio_url, 0, podcast.id)` と**復元位置を 0 にハードコード**。`getSavedPosition` を使わない。
  - 一覧ページ `web/app/podcast/page.tsx:45-47` は両方とも正しく実装済み → **同一目的処理がファイル間で別実装**（コピペ崩れ / インテグレーション一貫性違反）。
  - 加えて、この再生ハンドラの振る舞いはテスト未整備（`tests/app/podcast/id/page.test.tsx` はボタン存在のみ確認、`load` 引数を検証していない）。
- **どう修正すべきか**: 一覧と同一フローに統一する。
  ```ts
  const fresh = await createApiClient({ baseUrl: state.baseUrl, apiKey: state.apiKey }).getPodcast(podcast.id)
  const savedPosition = getSavedPosition(fresh.id)
  player.load(fresh.audio_url, savedPosition, fresh.id)
  await player.play()
  dispatch({ type: 'SET_PODCAST', podcast: fresh })
  dispatch({ type: 'PLAY' })
  ```
  併せて再生フロー（再フェッチ・復元位置）の単体テストを追加する。

### 🔴 AI-NEW-unused-response-types（new）— 未使用の export 型（デッドコード + 重複）

- **該当**: `web/types/index.ts:20-23 (FeedResponse) / 36-38 (PodcastsResponse) / 45-47 (SourcesResponse)`
- **何が問題か**: 3 つの response 型は export されているが、grep で**使用箇所が定義行以外に存在しない**（`app`/`components`/`contexts`/`hooks`/`lib`/`tests` 全走査で 0 件）。`web/lib/api.ts` は同じ形を `{ articles: Article[]; date: string }`（L65）、`{ podcasts: Podcast[] }`（L89）、`{ sources: Source[] }`（L105,113,125）とインライン定義しており、**型が二重定義**になっている。ポリシー「exportされているが grep で使用箇所が見つからない → REJECT」「本質的に同じ型の重複」に該当。
- **どう修正すべきか**: `api.ts` の戻り値型を `FeedResponse` / `PodcastsResponse` / `SourcesResponse` に置き換えて名前付き型を実際に使う（重複も解消）。それを行わないなら 3 型を削除する。

## 確認したが問題なし（主なもの）
- `lib/format.ts`: `try/catch` での握りつぶしなし、`isNaN` ガードのみ。OK。
- `app/page.tsx`: エントリゲート（isRestoring スケルトン / isConfigured リダイレクト / SetupModal）spec §10.1 準拠。
- `contexts/AudioPlayerContext.tsx` + 各ページ: `useAudioPlayerContext()` を一貫使用、`useAudioPlayer()` 直呼びなし。OK。
- `app/api/backend/[...path]/route.ts`: SSRF 対策（scheme 検証）あり、`any` なし。OK。
- `app/subscriptions/page.tsx`: 401 区別表示・409 入力保持・削除確認ダイアログ spec 準拠。OK。
- `hooks/useLocalStorage.ts` / `getSavedPosition` / `PLAYBACK_SPEEDS`: いずれも使用箇所あり、デッドコードではない。

## 参考（非ブロッキング）
- `app/feed/page.tsx:34-35`: fetch 時 401 を全画面 `errorMessage` 表示。spec §10.2 (L188) は操作系 401 を「トースト + `/settings` 誘導」とするが、取得失敗は §10.2 (L177)「エラーメッセージ + 再試行」に該当しうるため許容範囲。`/settings` 誘導リンクがない点のみ記録（参考情報）。

**判定: ブロッキング指摘 3 件（すべて `new`）→ REJECT。** 修正後、特に AI-NEW-default-speed-wiring と AI-NEW-podcast-detail-replay は実コードの再フェッチ・復元・AppContext 反映が実際に通るかをテストで検証すること。

---

## arch_review
アーキテクチャレビューを完了しました。Knowledge / Policy 全セクションを変更差分（`web/` 全体の新規実装）と照合した結果、**spec 準拠の配線漏れが2件**あり、**REJECT** と判定します。

---

## 判定: REJECT

差分基準点: マージベース（`web/` は全ファイル新規）。一次情報として `docs/spec/2026-06-10-web-frontend-spec.md`・実コードを参照。`coder-decisions.md` は存在せず、spec を正として評価。

---

### 🔴 ARCH-NEW-default-speed-wiring（new / BLOCKING）

**該当セクション:** Knowledge「呼び出しチェーン検証」「仕様準拠の検証」「境界での解決」/ Policy「契約変更後の…更新漏れ（配線漏れ）」

**問題:** デフォルト再生速度が localStorage に保存されるだけで、AppContext にもプレイヤーにも一切反映されない（dead config）。spec の明示要求2点に違反:
- spec §10.5 L239「デフォルト再生速度セレクタ → localStorage 保存 **+ AppContext 反映**」
- spec §10.3 L213「速度セレクタ（8 段階、**初期値はデフォルト速度**）」

**ファクト:**
- `web/app/settings/page.tsx:17,21` — `useLocalStorage(KEY_DEFAULT_PLAYBACK_SPEED, …)` で localStorage には書くが、`dispatch({type:'SET_SPEED'})` を呼ばず **AppContext へ反映していない**。
- `web/contexts/AppContext.tsx:102-118` — マウント時 restore effect は `baseUrl`/`apiKey` のみ復元し、`default_playback_speed` を読まない。`AppState.playbackSpeed` は固定初期値 `1.0`（L34）のまま。
- `web/components/AudioPlayerBar.tsx:89` — `value={state.playbackSpeed}` は常に `1.0` 始まりで「初期値はデフォルト速度」を満たさない。
- `grep default_playback_speed/KEY_DEFAULT_PLAYBACK_SPEED` → `settings/page.tsx` 内でしか読まれず、再生フローのどこからも消費されない。

**修正案:** 速度のデフォルト値は「境界で一度だけ解決」する。
1. `AppContext.tsx` の restore effect 内で `default_playback_speed` を localStorage から読み（不正値・未保存は `1.0` フォールバック）、`SET_SPEED` で `AppState.playbackSpeed` を初期化する（音量と異なり、§7 で playbackSpeed は AppState 管理と明記されているため AppState 側で解決するのが整合的）。
2. `settings/page.tsx` の速度変更時に `setDefaultSpeed(...)` と併せて `dispatch({type:'SET_SPEED', speed})` を呼び、保存と同時に反映する。
これで `AudioPlayerBar` の初期値=デフォルト速度となり §213/§239 を満たす。

---

### 🔴 ARCH-NEW-detail-play-flow（new / BLOCKING）

**該当セクション:** Knowledge「仕様準拠の検証」「呼び出しチェーン検証」「DRY違反の検出」/ Policy「テストがない新しい振る舞い」

**問題:** 詳細ページ `/podcast/[id]` の再生が「一覧と同フロー」になっておらず、spec で**「重要」**と明記された署名付き URL 失効対策と位置復元が無効化されている。
- spec §9 L151「署名付き URL 失効対策（重要）: 再生ボタン押下時に**必ず `getPodcast(id)` を呼び直し**、新鮮な URL を取得してから `Audio` にセット」
- spec §10.3 L201/L209「再生ボタン（**一覧と同フロー**）… `podcast_position:{id}` から**復元位置を渡す**」

**ファクト:** `web/app/podcast/[id]/page.tsx:52-58` handlePlay は
- (a) 再生時に `getPodcast` を呼び直さず、マウント時取得の `podcast.audio_url`（滞留中に失効し得る）を再利用。一覧 `web/app/podcast/page.tsx:45` は `handlePlay` 内で `getPodcast` を再取得している。
- (b) 復元位置に固定 `0` を渡す（`player.load(podcast.audio_url, 0, podcast.id)`）。一覧 `page.tsx:47` は `getSavedPosition(fresh.id)` を渡す。
- テスト未整備: `web/tests/app/podcast/id/page.test.tsx` に再生アクション（再取得・位置復元）のアサーションが無い。

**修正案:** 詳細 `handlePlay` を一覧と同一フローに揃える:
```
const fresh = await createApiClient({…}).getPodcast(podcast.id)
const pos = getSavedPosition(fresh.id)
player.load(fresh.audio_url, pos, fresh.id)
await player.play()
dispatch({ type: 'SET_PODCAST', podcast: fresh })
dispatch({ type: 'PLAY' })
// catch は一覧同様 ApiError → showToast
```
一覧・詳細で再生開始ロジックが重複するため、再生開始処理を1関数（例: `useAudioPlayerContext` 周辺の小ヘルパー、または共通フック）へ抽出して双方から呼ぶ（DRY。責務境界はプレイヤー/ページ間で保つ）。新しい振る舞いに対するテストも追加。

---

### 参考（非ブロッキング / 記録のみ）

- `web/components/AudioPlayerBar.tsx:20-34` handlePlayPause は pause からの再開時に毎回 `player.load()` を呼び `audio.src` を再設定するため、一時停止→再生のたびに再バッファが発生し得る。spec 違反ではないが UX 上の無駄。一時停止からの再開は `load` せず `player.play()` のみで足りる（`currentPodcast` が既ロード済みかをフックが判定できる設計が望ましい）。

---

良い点（解消済み確認）: `AudioPlayerProvider` による単一 Audio インスタンス共有（前回 ARCH-NEW-useAudioPlayer-L63 解消済み）、エントリーゲート（§10.1）、localStorage キー定数の `lib/config.ts` 集約と直接アクセス禁止（§8 L132）、BFF プロキシの SSRF 対策（scheme 検証）は spec と整合。

ブロッキング2件（いずれも new）があるため **REJECT**。`fix` ステップで上記2件を修正のこと。

---

## coding_review
Review complete. I've verified the core flows against the actual code. Here are my findings.

## レビュー結果: REJECT

### 🔴 ブロッキング指摘 1: プレイヤーバーの一時停止→再生で先頭に巻き戻る（`SET_TIME` が dead code）

**場所:**
- `web/components/AudioPlayerBar.tsx:24-34`（`handlePlayPause` の resume 分岐）
- `web/contexts/AppContext.tsx:47,62-63`（`SET_TIME` action / reducer case）

**事実（確認済み）:**
- `SET_TIME` action は型定義（L47）と reducer case（L62-63）に存在するが、アプリ全体で**一度も dispatch されていない**（`grep -rn "type: 'SET_TIME'"` → AppContext.tsx の定義のみ）。
- `useAudioPlayer` の `currentTime` はフックローカル state であり、`AppContext` には同期されない（`state.currentTime` への書き込み箇所はゼロ）。
- したがって `state.currentTime` は常に初期値 `0` のまま。
- `AudioPlayerBar.handlePlayPause` の resume 分岐は `player.load(currentPodcast.audio_url, state.currentTime, currentPodcast.id)` を呼ぶ（L26-30）。`load()` は `audio.src` を再設定し `audio.currentTime = resumePosition`（=0）にリセットする（`useAudioPlayer.ts:167-169`）。

**影響:**
- プレイヤーバーで一時停止した後に再生ボタンを押すと、音声が**先頭（0秒）から再生し直される**。再生中だった位置が失われる。
- これは order.md タスク6「再生状態はグローバル状態管理で管理し、画面遷移後も継続再生できるようにする」に直接違反する。
- 既存テスト `AudioPlayerBar.test.tsx` の「Play / Pause」はボタンラベルのトグルしか検証しておらず（L86-93）、位置保持を検証していないためこの欠陥を検出できていない。

**修正方針（いずれか）:**
1. resume 時は `load()` を呼ばず `await player.play()` のみにする。Context のプレイヤーインスタンスは単一で、一時停止しても src と再生位置を保持しているため再ロードは不要かつ破壊的。
2. どうしても再ロードが必要な設計なら、`useAudioPlayer` の `timeupdate` で `dispatch({ type: 'SET_TIME', ... })` を発行して `state.currentTime` を実際に同期し、`load()` には `player.currentTime` を渡す。
- どちらを選んでも、未使用のまま残る `SET_TIME`（または逆に未使用化する読み出し）を整理し、位置保持を検証するテストを追加すること。

---

### 参考情報（非ブロッキング）

**A. デフォルト再生速度がプレイヤーに適用されていない**
- `web/app/settings/page.tsx:17,85` は `KEY_DEFAULT_PLAYBACK_SPEED` を localStorage に保存・表示するが、`grep` の結果この値を**再生時に読み出して `setSpeed`/`playbackRate` に適用するコードが存在しない**（`useAudioPlayer.load` も既定速度を設定しない）。設定UIは動くが再生に反映されない。order.md タスク7のスコープは「保存UI」までのため非ブロッキングとするが、spec で「既定速度の適用」まで要求している場合は要対応。

**B. BFF プロキシの SSRF 範囲（設計判断事項）**
- `web/app/api/backend/[...path]/route.ts:13-32` は `X-Backend-Base-Url` のスキーム（http/https）のみ検証し、ホストは検証しない。リクエスト元が任意のヘッダを送れるため、サーバが任意の内部URL（例: クラウドメタデータ）へ fetch するオープンプロキシになり得る。ただしユーザが自分のバックエンドURLを指定する BFF の設計上、ローカル開発では `localhost` 宛が正当であり、private/loopback の一律ブロックは正規ユースケースを壊す。スキーム限定は意図的な設計トレードオフと判断し非ブロッキングとするが、コメントの「SSRF mitigation」はスキーム限定にとどまる旨を明記しておくのが望ましい。

---

**まとめ:** 指摘1（一時停止→再生で先頭巻き戻り＋未使用 `SET_TIME`）は order.md タスク6の中核要件に反する実コード上の欠陥であり、REJECT。修正と位置保持テストの追加を要する。