## ai_review
Comprehensive first-pass AI antipattern review complete. I verified each Policy/Knowledge `##` section against the cumulative diff (whole new `web/` tree). Here are my findings.

---

# AI Antipattern Review (1回目) — 判定: **REJECT**

## レビュー手順の実施記録
- Policy 全文（レビューポリシー + AI Antipattern 検出基準）を Read で取得し、全 `##` セクションを列挙して照合した。
- 差分基準: マージベースからの累積差分（`web/` 全体は本ブランチの新規追加）。
- 一次情報: `docs/spec/2026-06-10-web-frontend-spec.md`、実コードを参照。fix.1 レポートの「修正済み」記憶には依存せず、対象ファイルを再読・再 grep して検証した。
- 前段 fix の 4 件（default-speed-wiring / detail-replay / unused-response-types / AudioPlayerBar-resume）は再確認し、いずれも `resolved`（下記参照）。本レビューで**新規に**未配線・デッドコードを検出した。

---

## 🔴 ブロッキング指摘

### finding_id: `AI-NEW-audio-error-toast-unwired` — 状態: `new`
**該当セクション:** 「もっともらしいが間違っている検出（配線忘れ）」「未使用コードの検出」

**問題:** spec §エラーハンドリング（`docs/spec/2026-06-10-web-frontend-spec.md:144`）は
> `error`（Audio 要素のエラーイベント） | `isPlaying: false` にし、エラーを呼び出し元へ通知（**UI はトースト「音声を再生できません」を表示**）

を要求している。`useAudioPlayer` は `onError` コールバック機構を実装している（`web/hooks/useAudioPlayer.ts:13`, `72-75`, `123-126` の `handleError` → `onErrorRef.current?.()`）が、**唯一の本番呼び出し元** `AudioPlayerProvider`（`web/contexts/AudioPlayerContext.tsx:15`）は `useAudioPlayer()` を**引数なし**で呼んでおり、`onError` がどこからも配線されていない。

実証:
- `grep "useAudioPlayer(" --非test` → 本番は `AudioPlayerContext.tsx:15` の1箇所のみ、opts 未指定。
- `grep "onError" tests/` → `tests/hooks/useAudioPlayer.test.ts:270-279` のテストでのみ `onError` を渡しており、本番では未使用。
- `grep "再生できません|音声を再生|showToast"` → Audio `error` イベントに対応するトースト表示は本番コードに存在しない（`useStartPodcast.ts:38` の `再生できませんでした (${err.status})` は fetch の `ApiError` 用で、Audio 要素の error イベントとは別物）。

結果: 機構は実装されているがエントリポイントから渡されていない典型的な「配線忘れ」。本番で音声再生エラー（ネットワーク断・コーデックエラー）が起きてもユーザーに何も表示されない。spec 要件未達かつ `onError` オプションが本番未使用。

**修正案:** `ToastProvider` は `AudioPlayerProvider` の外側にある（`web/app/layout.tsx:19-20`）ため、`AudioPlayerProvider` 内で `useToast()` を呼べる。
```tsx
// web/contexts/AudioPlayerContext.tsx
export function AudioPlayerProvider({ children }: { children: React.ReactNode }) {
  const { showToast } = useToast()
  const player = useAudioPlayer({ onError: () => showToast('音声を再生できません', 'error') })
  ...
}
```
（`onError` を使わない設計にするなら、`UseAudioPlayerOptions` / `onError` / `onErrorRef` / `handleError` 一式を削除すること。ただし spec §144 がトースト表示を要求しているため、配線する方が正しい。）

---

### finding_id: `AI-NEW-appcontext-isplaying-dead-state` — 状態: `new`
**該当セクション:** 「デッドコード検出（未使用の変数・write-only state）」「コピペパターン検出（一貫性のない実装／同一概念の二重管理）」

**問題:** `AppState.isPlaying`（`web/contexts/AppContext.tsx:18`, 初期値 `:30`）と `PLAY`/`PAUSE` の reducer 分岐（`:54-57`）は **write-only（書き込み専用のデッド状態）**。
- 書き込み: `AudioPlayerBar.tsx:29,35`（`dispatch PAUSE/PLAY`）、`useStartPodcast.ts:35`（`dispatch PLAY`）。
- 読み取り: **本番コードにゼロ**。UI の再生/一時停止判定は全て `player.isPlaying`（`useAudioPlayer` 由来）を読む（`AudioPlayerBar.tsx:27,57,59`）。
- `grep "isPlaying" --非test` で確認。`state.isPlaying` を読むのは `tests/contexts/AppContext.test.tsx:42,152,164` のみで、reducer を機械的に検証しているだけ（実装詳細依存テスト）。

結果: 「再生中か」を `AppContext.isPlaying` と `useAudioPlayer.isPlaying` の **2 つの真実源で二重管理**し、前者は誰も読まない。両者が乖離し得る潜在バグであり、デッドコード。

**修正案:** いずれか一方に統一する。UI が `player.isPlaying` を単一の真実源にしているなら、`AppState.isPlaying` フィールド・`DEFAULT_STATE.isPlaying`・`PLAY`/`PAUSE` action と reducer 分岐・各 `dispatch({type:'PLAY'/'PAUSE'})`（`AudioPlayerBar.tsx:29,35`, `useStartPodcast.ts:35`）を削除する。逆にグローバル状態として保持したい（spec §116 は `isPlaying` を再生状態に列挙）なら、UI が `player.isPlaying` ではなく `state.isPlaying` を読むよう配線し、二重管理を解消する。どちらでも良いが、現状の「書くだけで読まない」状態は不可。

---

## 🟡 Warning（改善推奨・非ブロッキング判定の補足）

### finding_id: `AI-NEW-redundant-setspeed` — 状態: `new`（Warning）
**該当セクション:** 「冗長な条件分岐／冗長な式」

`AudioPlayerBar.tsx:90-97` の速度 `select` の `onChange` は `player.setSpeed(speed)`（:95）と `dispatch({type:'SET_SPEED'})`（:96）の両方を呼ぶ。しかし同コンポーネントの `useEffect`（:18-20）が `state.playbackSpeed` 変化時に `player.setSpeed(state.playbackSpeed)` を呼ぶため、`setSpeed` が二重に呼ばれる。`settings/page.tsx:86-92` の onChange は `dispatch` のみで effect に委譲しており実装が不整合。`AudioPlayerBar.tsx:95` の直接呼び出しを削除し effect に一本化すれば整合・冗長解消できる（数秒の修正）。

### finding_id: `AI-NEW-startpodcast-swallow` — 状態: `new`（Warning）
**該当セクション:** 「フォールバック・デフォルト引数の濫用検出（条件分岐でサイレント無視）」

`useStartPodcast.ts:36-40` の `catch` は `ApiError` のみトースト表示し、それ以外（`player.play()` の reject = autoplay ポリシー由来の `NotAllowedError` 等）を無言で握りつぶす。`finding AI-NEW-audio-error-toast-unwired` を配線すれば Audio error イベントは拾えるが、`play()` の promise reject は別経路。`else` 分岐で汎用トーストを出すか、少なくとも意図をコメント化することを推奨（`podcast/[id]/page.tsx:38-43` は else で汎用トーストを出しており、こちらと不整合）。

---

## ✅ 前段 fix 指摘の再検証（resolved）
| finding_id | 状態 | 根拠（再読・再grep） |
|---|---|---|
| AI-NEW-default-speed-wiring | resolved | `AppContext.tsx:99-109` restore→`SET_SPEED`、`settings/page.tsx:91` onChange→dispatch、`AudioPlayerBar.tsx:18-20` effect→`player.setSpeed` を実コードで確認 |
| AI-NEW-podcast-detail-replay | resolved | `useStartPodcast.ts` 新規・両ページ（`podcast/page.tsx:19,43`, `podcast/[id]/page.tsx:20,56`）が同一フックを使用 |
| AI-NEW-unused-response-types | resolved | `api.ts:8` で import、`:66,86,94` で `request<T>` のジェネリック引数として使用 |
| CODE-NEW-AudioPlayerBar-L26 | resolved | `AudioPlayerBar.tsx:26-36` resume は `player.play()` のみ、`player.load()` 不使用を確認。`SET_TIME` は本番コードに存在せず |

---

## 判定根拠
ブロッキング（`new`）が 2 件（`AI-NEW-audio-error-toast-unwired`, `AI-NEW-appcontext-isplaying-dead-state`）あるため、Policy「判定の最終手順 3」に従い **REJECT**。前段 4 件は resolved で、新たな構造悪化の混入は確認の上で上記 2 件を独立に検出した。

（注: テスト未実行。`npm run test` はサンドボックス承認ブロックのため未実行。本指摘はテスト結果ではなく実コードの静的事実＋ spec 突合に基づく。）

---

## arch_review
## アーキテクチャレビュー結果: REJECT

Knowledge（`arch-review.1...md`）と Policy（`arch-review.1...md`）の全 `##` セクションを Read で全文取得し、各判定基準を `baea491..HEAD` の累積差分（`web/` 配下 新規実装 9,495行）と照合しました。一次情報として `docs/spec/2026-06-10-web-frontend-spec.md` と実コードを参照しています。

---

### 列挙した Knowledge セクション（取捨選択なし）
構造・設計（ファイル分割／モジュール構成／操作の一覧性／パブリックAPI公開範囲／関数設計／レイヤー設計／ディレクトリ構造／責務の分離）／境界での解決（Tell Don't Ask／腐敗防止層／フェーズ分離）／コード品質の検出手法（説明コメント／状態の直接変更）／セキュリティ基本／テスタビリティ／アンチパターン検出／抽象化レベルの評価／その場しのぎの検出／未完成コードの検出／DRY違反／仕様準拠の検証／呼び出しチェーン検証／品質特性／大局観／変更スコープの評価

---

### ブロッキング指摘

#### 🔴 finding_id: `ARCH-NEW-onerror-unwired`（new / REJECT）
**該当セクション:** 呼び出しチェーン検証・未完成コードの検出・仕様準拠の検証・テスタビリティ

**事実:**
- `web/hooks/useAudioPlayer.ts:12-13,69,72-74,125` に `onError` コールバック機構（`UseAudioPlayerOptions.onError` → `onErrorRef` → 音声 `error` イベントで `onErrorRef.current?.()`）が実装されている。
- しかし本番で `useAudioPlayer` を呼ぶ唯一の箇所 `web/contexts/AudioPlayerContext.tsx:15` は `const player = useAudioPlayer()` と**引数なし**で呼んでおり、`onError` を渡していない（grep 全件確認済み）。
- `onError` を渡すのは `web/tests/hooks/useAudioPlayer.test.ts:272` の**テストのみ**。
- 結果、spec §9 L144「`error`（Audio 要素のエラーイベント）→ UI はトースト『音声を再生できません』を表示」が**未実装**。文字列「音声を再生できません」はコードベースに 0 件（grep 確認済み）。

**何が問題か:**
- 呼び出しチェーン検証の危険パターンに該当 ——「機能が実装されているのに全呼び出し元が省略し常にフォールバック（no-op）」かつ「テストがモックで直接値をセットし実呼び出しチェーンを経由しない」。`onError` 機構は本番では到達不能なデッドパスであり、同時に spec で要求された異常系 UI が欠落している。

**どう修正すべきか（具体）:**
`AudioPlayerProvider` は layout 上 `ToastProvider` の内側（`web/app/layout.tsx:19-20`）なので `useToast()` が使える。`web/contexts/AudioPlayerContext.tsx` を以下に修正し、`onError` をトーストへ配線する:
```tsx
import { useToast } from '@/components/ui/Toast'
// ...
export function AudioPlayerProvider({ children }: { children: React.ReactNode }) {
  const { showToast } = useToast()
  const player = useAudioPlayer({ onError: () => showToast('音声を再生できません', 'error') })
  // ...
}
```
併せて、配線をテストで担保すること（error イベント発火 → トースト表示の結合テスト）。

---

### 非ブロッキング（記録・改善提案）

- **finding_id: `ARCH-W-apiclient-construction-dup`（Warning）** — 構造・設計（操作の一覧性）／アンチパターン（Shotgun Surgery）
  `createApiClient({ baseUrl: state.baseUrl, apiKey: state.apiKey })` の config 構築が `web/app/feed/page.tsx:28,54,80`・`web/app/podcast/page.tsx:27`・`web/app/podcast/[id]/page.tsx:36`・`web/app/subscriptions/page.tsx:28`・`web/hooks/useStartPodcast.ts:27-30` の 7 箇所に重複。AppState の資格情報表現が変わると全箇所修正が必要（Shotgun Surgery 兆候）。操作自体は `lib/api.ts` に集約されており「操作の一覧性」は満たすため非ブロッキングとするが、`useApiClient()`（AppContext を読み `createApiClient` を返す hook。既存の「hook が context を読む」境界と整合）への集約を提案。

- **finding_id: `ARCH-W-api-comment-inaccurate`（Warning）** — コード品質（説明コメント）
  `web/lib/api.ts:1-7` のコメント「The proxy adds X-Backend-Base-Url and X-API-Key」は事実誤認。実際は本クライアントの `request()`（`api.ts:35-36`）が両ヘッダーを付与し、プロキシは読み取り・転送するのみ。誤誘導コメントなので「クライアントが付与しプロキシが転送する」旨へ修正を推奨。

- **観測（sync_documentation 向け・非ブロッキング）:** spec §7 L116,118 は Context に `currentTime`/`duration` と action `SET_TIME`/`RESTORE` を記載するが、実装は単一情報源化のため `currentTime`/`duration` を `useAudioPlayer` へ移し、action は `RESTORE_DONE`（`SET_TIME` なし）。これは前段レビューで承認済みの意図的改善であり構造的に妥当。spec 本文が陳腐化しているため Step 9 で更新されるべき。

---

### 構造評価（良好点）
レイヤー依存方向（types → lib → hooks/contexts → components → pages）は概ね健全、BFF プロキシ境界・SSRF スキーム検証あり、localStorage キーは `lib/config.ts` に集約、操作は `lib/api.ts` に集約、再生ロジックは `useAudioPlayer` で UI から分離されテスト可能。前 run の `default-speed-wiring`・`detail-play-flow` は実コードで解消を確認（`AppContext.tsx:104`/`settings/page.tsx:91`/`AudioPlayerBar.tsx:19`、両 podcast ページの `useStartPodcast` 共用）。変更スコープは Large（~9,495行・新規実装）だが論理的にまとまっており行数理由の REJECT はしない。

**判定: REJECT** — `ARCH-NEW-onerror-unwired`（new/blocking）が 1 件あるため。修正後の再レビューで `onError` 配線と spec §9 異常系トーストの実装・テストを確認します。

---

## coding_review
全中核ファイルとテストを精読し、ファクトチェックを完了しました。

## レビュー結果: APPROVE

### 検証した内容（実コード・実ファイルで確認）

**直近 fix の4件（finding_id 5件）はソース上で修正確認済み:**

| 問題 | 確認した事実 |
|---|---|
| デフォルト速度の配線 | `AppContext.tsx` L99-109 で restore 時に `SET_SPEED` dispatch（invalid/負値は 1.0 fallback）。`settings/page.tsx` L86-92 で onChange 時に即時 dispatch。`AudioPlayerBar.tsx` L18-20 の useEffect で `player.setSpeed(state.playbackSpeed)` 同期。3点が一貫して配線されている |
| 詳細ページ再生フロー | `useStartPodcast.ts` 共通フックを `podcast/page.tsx` L19,43 と `podcast/[id]/page.tsx` L20,56 の両方が使用。getPodcast→getSavedPosition→load→play が同一ロジック |
| 未使用レスポンス型 | `api.ts` L8 が `FeedResponse`/`PodcastsResponse`/`SourcesResponse` をインポートし L66,86,94,98 等でジェネリック引数として使用。`types/index.ts` に定義あり。デッドエクスポートなし |
| resume 時の位置リセット | `AudioPlayerBar.tsx` L26-37 の resume パスは `player.play()` のみで `load()` 呼び出しなし。`currentTime` は `useAudioPlayer` が単一管理（reducer に `SET_TIME`/`currentTime` 状態は存在しない） |

**リグレッション・構造の健全性:**
- リファクタで置換された旧 play ロジックの残存なし（両ページとも `startPodcast` に委譲、重複なし）
- 再生状態は `AudioPlayerProvider` が layout レベルで単一 Audio を保持し、画面遷移後も継続再生（`AudioPlayerContext.tsx` / `layout.tsx` L20-23 で確認）
- BFF プロキシは scheme 検証（http/https のみ）で SSRF 緩和済み（`route.ts` L17-25）。base URL はユーザー自身が設定する自己ホスト構成であり、今回差分起因の新規リスクなし

**テスト充足:**
- 修正対応テストが spec として存在: `AppContext.test.tsx` L187-216（速度復元・invalid/負値 fallback）、`settings/page.test.tsx` L125-148（SET_SPEED 即時 dispatch）、`AudioPlayerBar.test.tsx` L94-110（resume が currentTime=120 を保持）、`podcast/id/page.test.tsx` L129-162（再フェッチ+位置復元フロー）

### 制約事項（未確認の明記）
- テストスイートの実行（`vitest run`）は本環境の権限制約により `npm`/`node`/`vitest` 系コマンドが承認待ちで**実行できませんでした**。よって「全239テスト PASS」は**実行による再確認は未完**です。ただしテストファイルの内容が修正後の振る舞いを spec として検証していること、対象ソースがそれと整合していることは精読で確認済みです。

### 結論
今回の差分に起因するブロッキングなバグ・リグレッション・セキュリティリスク・テスト不足は**検出されませんでした**。**APPROVE** とします。