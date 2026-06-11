# アーキテクチャレビュー

## 結果: REJECT

## サマリー
spec の中核要件（単一プレイヤーの再生継続 §10.3、エントリーゲート §10.1、localStorage 直接操作禁止 §8）が実装で成立しておらず、構造的欠陥3件を検出。テストは mock 起因で緑のまま通る状態。

## 確認した観点
- [x] 構造・設計
- [x] コード品質
- [x] 変更スコープ
- [x] テストカバレッジ
- [x] デッドコード
- [x] 呼び出しチェーン検証

## 今回の指摘（new）
| # | finding_id | family_tag | スコープ | 場所 | 問題 | 修正案 |
|---|------------|------------|---------|------|------|--------|
| 1 | ARCH-NEW-useAudioPlayer-L63 | design-violation | スコープ内 | `web/hooks/useAudioPlayer.ts:63,75-80,126-133` ／ 呼出元 `web/app/podcast/page.tsx:30`・`web/app/podcast/[id]/page.tsx:20`・`web/components/AudioPlayerBar.tsx:13` | `useAudioPlayer` がフックインスタンスごとに `new Audio()` を生成し、3コンポーネントが別個の Audio 要素を持つ。`/podcast` 離脱時アンマウントの `audio.pause()`(L127) で再生中要素が停止し spec §10.3「ページ遷移で再生継続」が成立しない。再生バーの操作も実際に鳴る要素に届かず、二重再生も起こり得る。`tests/helpers/mockAudio.ts:86-90` が Audio を単一インスタンスにスタブするため欠陥が隠蔽されている | `app/layout.tsx` 常駐の `AudioPlayerProvider` で `useAudioPlayer()` を1回だけ呼び、`load/play/pause/seek/setVolume` を Context 公開。各ページ・バーは自前フックを持たず Context 経由で操作（または Audio をモジュール単一インスタンス化しページ単位 pause を排除）。あわせてテストを本番挙動検出可能に修正 |
| 2 | ARCH-NEW-page-L1 | spec-violation | スコープ内 | `web/app/page.tsx:1-5` ／ 未配線 `web/components/ui/SetupModal.tsx` | `/` が `redirect('/feed')` を無条件実行するだけで spec §10.1 のエントリーゲート（復元前スケルトン／設定済み replace／未設定 SetupModal）が未実装。`SetupModal` は完全実装済みだが `grep` で使用箇所ゼロ＝未使用コード。未設定ユーザーが空 credential で `/feed` に直行する | `app/page.tsx` を `AppContext` 復元状態を参照するクライアントゲートに置換し、未設定時 `<SetupModal onConfigure={configure} />` を表示して配線。復元中スケルトン用に `AppContext` へ復元完了フラグ追加を検討 |
| 3 | ARCH-NEW-podcastpage-L18 | spec-violation | スコープ内 | `web/app/podcast/page.tsx:16-25`（L18 `localStorage.getItem`） | spec §8（spec.md:132）「ページから直接 localStorage を触る禁止・必ずフック経由」に違反。`podcast_position` の書き込みは `useAudioPlayer.ts:45-51` がフック内に持つのに読み出しだけページの生アクセスで分散している | 読み出しを所有者へ集約。`useAudioPlayer`（または `lib/config.ts`）から `getSavedPosition(podcastId)` を export し、ページはそれを呼ぶ。生 localStorage アクセスをページから排除 |

## 参考（非ブロッキング・Warning）
| finding_id | family_tag | 場所 | 問題 | 修正案 |
|------------|------------|------|------|--------|
| ARCH-NEW-apiclient-dup | dry-minor | `feed/page.tsx:28,54,80`・`podcast/page.tsx:38,56`・`podcast/[id]/page.tsx:36`・`settings/page.tsx:24` | `createApiClient({baseUrl,apiKey})` のインライン生成が反復。`subscriptions/page.tsx:24-27` のみ `makeClient` 化で不統一 | `useApiClient()` フックに集約し全ページ統一 |

## 継続指摘（persists）
なし（本ステップ初回レビュー）

## 解消済み（resolved）
なし

## 再開指摘（reopened）
なし

## 検証証跡
- ビルド: 未確認（編集禁止フェーズ・静的レビューのみ）
- テスト: 未実行。ただし `tests/helpers/mockAudio.ts:86-90` が `vi.stubGlobal('Audio', vi.fn(() => instance))` で Audio を単一インスタンス化しており、ARCH-NEW-useAudioPlayer-L63 の本番欠陥（インスタンスごと別要素）をテストが検出できない構造であることをコードで確認
- 動作確認: 未確認。配線は `grep -rn "SetupModal" web`（使用ゼロ）、`grep -rn localStorage web/app web/components`（`podcast/page.tsx:18` の1件のみ）で確認

## 判定
`new` ブロッキング3件（ARCH-NEW-useAudioPlayer-L63 / ARCH-NEW-page-L1 / ARCH-NEW-podcastpage-L18）により REJECT。