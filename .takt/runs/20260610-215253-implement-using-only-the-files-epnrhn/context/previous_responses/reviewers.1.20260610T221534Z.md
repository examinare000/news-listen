## ai_review
全体を精査しました。AI アンチパターン観点の検出結果をまとめます。

## レビュー結果: REJECT

差分ベースはタスク起点（新規 `web/` ディレクトリ全体）。Policy の全 `##` セクションを変更差分と照合し、以下を検出しました。

---

### 🔴 ブロッキング

#### `finding_id: AIR-001` — エラーの握りつぶし（空の catch）【new】
**ファイル:** `web/app/subscriptions/page.tsx:34-36`, `:81-83`

```ts
// fetchSources (34-36)
} catch {
  // Silently fail — empty list shown
} finally { setLoading(false) }

// handleDeleteConfirm (81-83)
} catch {
  // Handle silently
}
```

**問題:**
- `fetchSources` が 401・ネットワークエラー等を全て握り潰し、空リスト（「購読ソースがありません」）を表示する。認証失敗とソース未登録がユーザーから区別不能になる。
- `handleDeleteConfirm` が削除失敗（spec line 52 が定義する `404 Source not found` 等）を無言で破棄。ユーザーが削除ボタンを押しても何も起きず、フィードバックが一切ない。
- 同一実装内の他ページ（`feed/page.tsx:30-41` はエラー UI、`podcast/page.tsx:40-43` / `[id]/page.tsx:38-43` はトースト）はエラーを必ずユーザーに提示している。本ページだけ握り潰しており、**コンテキスト適合性（エラーハンドリングスタイルの一貫性）にも違反**。
- Policy「エラーの握りつぶし（空の catch）」「条件分岐でサイレント無視」に該当。`subscriptions/page.test.tsx` はこのエラー系を検証しておらず、契約要件ではなく実装ギャップ（テスト未カバー）。

**修正案:** 他ページと同様に、`ApiError` を判別してトースト表示またはインライン error state を出す。最低限 `fetchSources` は error state を持たせ、`handleDeleteConfirm` は失敗時にトースト（例: 「削除に失敗しました (${err.status})」）を出す。

---

#### `finding_id: AIR-002` — 論理的に到達不能な防御 try/catch + 空文字フォールバック【new】
**ファイル:** `web/lib/format.ts:21-35`

```ts
export function formatDate(iso: string): string {
  try {
    const d = new Date(iso)
    if (isNaN(d.getTime())) { return '' }   // ← 不正入力はここで処理済み
    ...
  } catch {
    return ''                                // ← 到達不能
  }
}
```

**問題:** `new Date(iso)` は任意の文字列入力で例外を投げず（Invalid Date を返すのみ）、続く `getTime()/getMonth()/getHours()/padStart()` も例外を投げない。不正入力は `isNaN` ガード（24行）で既に `''` を返している。したがって `try/catch`（22, 32-34行）は**論理的に到達不能なデッドコード**であり、catch は空文字フォールバック。Policy「論理的に到達不能な防御コード」「try-catch で空値返却 `catch { return '' }`」に該当。`format.test.ts` は「不正入力で throw しない／文字列を返す」のみ要求し、try/catch を要求していない（isNaN ガードだけで全テストを満たす）。

**修正案:** try/catch を削除し、`isNaN` ガードのみ残す。

---

### 🟠 Warning（非ブロッキング・記録）

#### `finding_id: AIR-003` — 到達不能なフォールバック `?? difficulty`
**ファイル:** `web/components/ui/DifficultyBadge.tsx:18`

`difficulty` は閉じた union `DifficultyLevel`（6値）で型付けされ、`DIFFICULTY_LABELS` は全6キーを網羅。型上 `DIFFICULTY_LABELS[difficulty]` は常に文字列を返し `?? difficulty` は到達しない。AI の「念のため」フォールバックの典型。ただし `Record<string, string>` 型を意図的に選び、バックエンドが union 外の値を返した場合に生キーを表示する実行時防御という解釈も成立しうるため Warning に留める。意図的なら `coder-decisions.md` に根拠を残すこと。

---

### 確認したが問題なしのセクション
- **スコープクリープ:** `subscriptions` 画面は order.md の「3画面」にないが、spec §10.4 / line 155 が「order.md の3画面は誤り（Subscriptions を含む）」と明記。正式にスコープ内。
- **インテグレーション一貫性:** 全ページ `createApiClient` 経由で統一。生成/手書きの混在なし。
- **幻覚 API / 配線忘れ:** BFF プロキシ（`route.ts`）→ `api.ts` → 各ページの結線は一貫。`X-Backend-Base-Url`/`X-API-Key` の転送経路も整合。
- **オブジェクト直接変更:** Set 更新は `new Set(prev)` で不変、`useReducer` は spread で不変更新。問題なし。
- **キャッシュ先回り / 過剰抽象化 / 冗長条件分岐 / コールバックキャプチャ:** 該当なし。
- **機密情報露出:** `console.log` ゼロ、API キーはヘッダ転送のみでログ出力なし。

---

**判定:** ブロッキング 2件（AIR-001, AIR-002）が `new` で存在するため **REJECT**。fix ステップで両件の修正を要求します。

---

## arch_review
全 Knowledge/Policy セクションを変更差分（新規 `web/` 全体 = ベース `baea491` からの累積差分）と照合しました。実コードで確認した事実に基づき、**REJECT** します。

---

# Architecture Review: REJECT

## レビュー基準点
- ベース: マージベース `baea4916`（`dev-frontend` ブランチ）
- 対象差分: `web/` ディレクトリ全体（新規・未追跡）+ `docs/plan/2026-06-10-web-frontend.md`
- 一次情報: `order.md`（タスク2・6）、`docs/spec/2026-06-10-web-frontend-spec.md`（§7〜§10）、実コード
- 前回 arch-review レポート: なし（本ステップ初回。`reports/` には coder-scope / coder-decisions のみ）

---

## ブロッキング指摘

### finding_id: ARCH-001 （状態: new）— 音声プレイヤーが「単一・グローバル」になっておらず、画面遷移で再生が継続しない

**該当箇所**
- `web/hooks/useAudioPlayer.ts:63` `const audioRef = useRef<HTMLAudioElement | null>(null)` ＋ `:75-80` `getAudio()` が `new Audio()` を**フックインスタンスごとに生成**
- `:126-133` アンマウント時クリーンアップで `audio.pause()`
- 呼び出し元が独立に3箇所:
  - `web/app/podcast/page.tsx:30` `const player = useAudioPlayer()`
  - `web/app/podcast/[id]/page.tsx:20` `const player = useAudioPlayer()`
  - `web/components/AudioPlayerBar.tsx:13` `const player = useAudioPlayer()`

**何が問題か（実コードで確認した事実）**
`useAudioPlayer` は `audioRef`（インスタンスローカル）に `new Audio()` を格納するため、上記3コンポーネントは**それぞれ別個の Audio 要素**を持つ。モジュールレベルの共有要素も Context 経由の共有も存在しない（`grep` で `new Audio()` はこの1箇所のみ、Audio を共有する仕組みなし）。結果:

1. **画面遷移で再生が止まる（spec §10.3 / order.md タスク6 違反）**
   `PodcastPage`（`page.tsx:54-61`）が自分の Audio 要素Aで再生を開始する。`/podcast` から離脱すると `PodcastPage` がアンマウントし、`useAudioPlayer.ts:127` の `audio.pause()` が要素Aを停止する。レイアウト常駐の `AudioPlayerBar` は別の要素Bを持つだけで何も再生していない。spec §10.3「ページ遷移しても再生継続（レイアウト常駐）」が**実装レベルで成立しない**。
2. **再生バーの操作が実際に鳴っている音声に届かない**
   `AudioPlayerBar` のシーク（`AudioPlayerBar.tsx:71`）・音量（`:81`）・一時停止（`:52`）は要素Bを操作する。`PodcastPage` が鳴らした要素Aは制御不能。
3. **二重再生**
   `AudioPlayerBar.handlePlayPause`（`:19-33`）の else 分岐が要素Bを `load`+`play` するため、要素A（未停止のケース）と同時再生になり得る。

**なぜテストで検出されないか（事実）**
`web/tests/helpers/mockAudio.ts:86-90` `setupMockAudio()` が `vi.stubGlobal('Audio', vi.fn(() => instance))` で**単一インスタンスを返すよう** Audio をスタブしている。テスト環境では全フックインスタンスが偶然同一の MockAudio を共有するため、本番の「インスタンスごとに別要素」という欠陥が隠蔽される。Knowledge「呼び出しチェーン検証」「隠れた依存」、Policy「契約変更後の…テストデータ」に該当。

**修正案**
spec §9「再生ロジックは UI から完全分離」「単一プレイヤー」の意図に合わせ、Audio 要素を**1つだけ**共有する。いずれか:
- **(推奨)** 専用 `AudioPlayerProvider` を `app/layout.tsx` に常駐させ、その中で `useAudioPlayer()` を**1回だけ**呼ぶ。`load/play/pause/seek/setVolume` 等を Context で公開し、`PodcastPage` / `PodcastDetailPage` / `AudioPlayerBar` はこの Context 経由で操作する（自前の `useAudioPlayer()` を持たせない）。これにより spec §7 のグローバル状態と再生要素の所有者が一致する。
- もしくは `useAudioPlayer` 内の Audio 要素をモジュールスコープの遅延シングルトンにし、イベント登録／クリーンアップをページ単位の `pause()` で誤って止めない参照カウント方式へ変更する。

---

### finding_id: ARCH-002 （状態: new）— `SetupModal` がどこからも配線されておらず、`/` エントリーゲート（spec §10.1）が未実装

**該当箇所**
- `web/components/ui/SetupModal.tsx`（完全実装済みのモーダル：`onConfigure`・バリデーション・接続テスト）
- `web/app/page.tsx:1-5` — `/` が `redirect('/feed')` を**無条件実行**するだけ
- 配線確認: `grep -rn "SetupModal" web`（テスト・自身を除く）→ **使用箇所ゼロ**

**何が問題か**
spec §10.1 は `/` を「エントリーゲート + SetupModal」と定義し、(a)設定復元前=スケルトン、(b)設定済み=`/feed` へ replace、(c)未設定=SetupModal 表示（閉じて他画面に行けない）を要求する。実装の `app/page.tsx` はサーバーコンポーネントで `redirect('/feed')` を無条件実行するため、ゲートロジックが**完全に欠落**している。結果:
- `SetupModal` は実装済みだが**未使用コード**（Policy「未使用コード」「未完成コードの検出」/ Knowledge「その場しのぎ：空実装・スタブ放置」に該当 → ブロッキング）。
- 未設定ユーザーが `/feed` に直行し、空 credential（`AppContext` の `baseUrl=''`/`apiKey=''`）で `getFeed()` を叩く動線になる（spec §10.1 の設計意図に反する）。

**修正案**
`app/page.tsx` を spec §10.1 のゲートに置き換える。`AppContext` の復元状態（`isConfigured` と復元完了フラグ）を参照するクライアントゲートにし、(a)復元前スケルトン、(b)`isConfigured` なら `router.replace('/feed')`、(c)未設定なら `<SetupModal onConfigure={configure} />` を表示する。これで `SetupModal` が配線され、§10.1 が満たされる。
（`AppContext` には現状「復元完了」を示すフラグがないため、復元中スケルトンを正しく出すには `AppContext.tsx` に復元完了状態の追加が必要。あわせて検討すること。）

---

### finding_id: ARCH-003 （状態: new）— ページコンポーネントが `localStorage` を直接操作（spec §8 違反）

**該当箇所**
- `web/app/podcast/page.tsx:16-25` `getSavedPosition()` 内 `:18` `localStorage.getItem(podcastPositionKey(podcastId))`
- 確認: `grep -rn localStorage web/app web/components`（テスト除く）→ ヒットはこの1箇所のみ

**何が問題か**
spec §8（`docs/spec/...-spec.md:132`）は「ページコンポーネントから直接 `localStorage` を触る | **禁止**。必ずこのフック経由」と明記。`podcast_position:{id}` の**書き込み**は `useAudioPlayer.ts:45-51 savePosition()` がフック内に持つ一方、**読み出し**だけがページの生 `localStorage` アクセスになっており、同一キーへの操作が分散している（Knowledge「操作の一覧性」: 同じ永続化キーが目的の異なる箇所から直接操作される / 責務分散）。spec の明示禁止に対する**仕様準拠違反**でブロッキング。

**修正案**
`podcast_position` の読み出しを所有者である `useAudioPlayer`（または `lib/config.ts` のキー所有モジュール）に集約する。例: `useAudioPlayer` から `getSavedPosition(podcastId): number` を export し、`PodcastPage` はそれを呼ぶ。生 `localStorage` アクセスをページから排除する。`savePosition`（書き込み）と読み出しが同一モジュールに揃い、§8 と「操作の一覧性」を満たす。

---

## 非ブロッキング（参考・Warning）

### finding_id: ARCH-004 （状態: new, Warning）— API クライアント生成の重複
`createApiClient({ baseUrl: state.baseUrl, apiKey: state.apiKey })` がインラインで反復している（`feed/page.tsx:28,54,80`、`podcast/page.tsx:38,56`、`podcast/[id]/page.tsx:36`、`settings/page.tsx:24`）。一方 `subscriptions/page.tsx:24-27` は `makeClient` で `useCallback` 化しており**一貫していない**。Policy「DRY」観点で軽微だが、`useApiClient()` フック（`useApp()` の `state` から client を生成）に集約すると全ページで統一でき、ARCH-003 同様「操作の一覧性」も向上する。ブロッキングにはしないが、ARCH 修正に合わせて整理を推奨。

---

## 照合したセクション（Knowledge / Policy）
構造・設計（ファイル分割／モジュール構成／操作の一覧性→ARCH-003/004／パブリックAPI公開範囲／関数設計／レイヤー設計／ディレクトリ構造／責務分離）、境界での解決・Tell Don't Ask・腐敗防止層・フェーズ分離、コード品質（説明コメント／状態直接変更）、セキュリティ基本、テスタビリティ、アンチパターン（隠れた依存→ARCH-001）、抽象化レベル、その場しのぎ（空実装・スタブ→ARCH-002）、未完成コード、DRY（→ARCH-004）、仕様準拠（→ARCH-002/003）、呼び出しチェーン検証（→ARCH-001/002）、品質特性、大局観、変更スコープ。Policy 全セクション（スコープ判定／REJECT基準／ファクトチェック／finding_id 管理／レビュー基本手順）。

## 判定
ブロッキング `new` 指摘が3件（ARCH-001/002/003）。**REJECT**。
ARCH-001 と ARCH-002 はいずれも spec の中核要件（単一プレイヤーの再生継続 §10.3、エントリーゲート §10.1）が実装で成立していない構造的欠陥であり、テストが mock 起因で緑のまま通る状態のため、修正と同時にテストが本番挙動（別 Audio 要素／未配線ゲート）を検出できるよう改めることを強く推奨する。

---

## coding_review
レビューに必要な事実確認が揃いました。結論を示します。

## コードレビュー結果: REJECT

新規 `web/` 実装一式を対象に、テスト・仕様（`docs/spec/2026-06-10-web-frontend-spec.md`）・実コードを突合しました。クリーンな点が多い（`any`/`console`/`TODO` ゼロ、BFF プロキシの SSRF スキーム検証、ApiError 正規化など）一方で、**コア機能を壊す実装バグが 2 件**あります。

---

### 🔴 Finding 1（ブロッキング）: `useAudioPlayer` がインスタンス共有されておらず、画面遷移での継続再生とグローバルプレイヤーが機能しない

**場所**
- `web/hooks/useAudioPlayer.ts:75-80`（`getAudio()` が `new Audio()` をフックインスタンスごとに生成）
- `web/components/AudioPlayerBar.tsx:13` / `web/app/podcast/page.tsx:30` / `web/app/podcast/[id]/page.tsx:20` — それぞれ独立に `useAudioPlayer()` を呼び出し（grep で 3 箇所確認済み、共有 Provider/シングルトンは存在しない）

**影響（事実）**
- `useAudioPlayer()` は呼び出しごとに別個の `Audio` 要素とローカル state を持つ。`AudioPlayerBar` は `layout.tsx:21` で常時描画される一方、実際に再生するのは `PodcastPage.handlePlay`（`podcast/page.tsx:54-61`）が握る**別インスタンス**。
- 結果1: 再生バーの `player.isPlaying / currentTime / volume`（`AudioPlayerBar.tsx:53,70,80`）は、実際に鳴っている音声とは別インスタンスの値であり、再生バーの再生/一時停止/シーク操作は鳴っていない方の `Audio` を操作する（プレイヤーバーが実質非機能）。
- 結果2: `/podcast` から離脱すると `PodcastPage` がアンマウントされ、`useAudioPlayer` の cleanup（`useAudioPlayer.ts:126-127` の `audio.pause()`）が走り再生が止まる。仕様 §10/§14 手動シナリオ（spec 279行「画面遷移で再生継続」）および order.md タスク6「画面遷移後も継続再生」を満たさない。
- テストは各コンポーネントを単体で mock しているため（`AudioPlayerBar.test.tsx` は自身の player インスタンスのみ検証）、この結合不具合を検出できていない。

**修正方針**
- `useAudioPlayer` の単一インスタンスを Provider 化（例: `AudioPlayerProvider` を `layout.tsx` に置き `useAudioPlayer` の戻り値を Context で配布）し、`AudioPlayerBar` と各ページが同一インスタンスを参照する。
- ページ側は再生意図のみをこの共有 player（または AppContext 経由）に渡し、`AudioPlayerBar`/共有 player が `currentPodcast` 変化に応じて `load`/`play` する配線にする。`audio_url` は §9 の署名付き URL 失効対策に従い再生直前の `getPodcast(id)` 結果を使う。

---

### 🔴 Finding 2（ブロッキング）: Settings 保存でパスワード欄が空のとき API キーを空文字で上書きし、既存の認証設定を破壊する

**場所** `web/app/settings/page.tsx:14, 19-21`
```ts
const [newApiKey, setNewApiKey] = useState('')   // 初期値は空
async function handleSave() { configure(newBaseUrl, newApiKey) }
```

**影響（事実）**
- API キー欄は `type="password"` でマスクされ、現状は「API キー: 設定済み」表示＋placeholder「新しいキーを入力」（`settings/page.tsx:44,63`）。Base URL だけ変更してキー欄を空のまま「保存」すると `configure(newBaseUrl, '')` が走り、`AppContext.configure`（`AppContext.tsx:111-118`）が `api_key` を空文字で localStorage 保存＋state 更新する。以降の全 API 呼び出しの `X-API-Key` が空になり 401 を誘発する。
- `tests/app/settings/page.test.tsx:78-96` は常に新キーを入力してから保存しており、「キー欄空のまま保存＝既存キー維持」のケースが未検証（テストギャップ）。

**修正方針**
- `handleSave` で `newApiKey` が空のときは既存 `state.apiKey` を保持する（例: `configure(newBaseUrl, newApiKey || state.apiKey)`）。あわせて「空入力時は既存キー維持」のリグレッションテストを追加する。

---

### 参考（非ブロッキング）
- `web/app/podcast/[id]/page.tsx:54` の `handlePlay` は `resumePosition=0` 固定で、一覧側（`podcast/page.tsx:57` の `getSavedPosition`）の保存位置復元と挙動が不一致。詳細画面からの再生で前回位置が無視される。仕様 §14「リロード後に前回位置から再開」と整合させるなら復元を検討。
- 仕様 §7（118行）は reducer action に `RESTORE` を挙げるが実装は `CONFIGURE` で復元している（`AppContext.tsx:48-49,103`）。機能上は問題ないが spec と命名が不一致。

---

**判定**: Finding 1・2 はいずれも今回の実装で導入されたコア機能の不具合（継続再生／グローバルプレイヤー、認証設定の保持）であり、ポリシーのブロッキング基準に該当するため **REJECT** します。fix ステップで上記 2 件の修正と対応するテスト追加を求めます。

なお `web/node_modules` 未インストールのため `vitest` の実行確認は未実施（本ステップは編集・実行制約あり）。テスト実行はサンドボックス制約により未確認である点を明記します。