# AI生成コードレビュー

## 結果: REJECT

## サマリー
新規 `web/` 実装に、デフォルト再生速度の配線忘れ・詳細ページ再生の spec 逸脱・未使用 export 型の 3 件のブロッキング問題があり REJECT。

## 検証した項目
| 観点 | 結果 | 備考 |
|------|------|------|
| 仮定の妥当性 | ❌ | デフォルト速度設定が再生に効かない（書込専用） |
| API/ライブラリの実在 | ✅ | 幻覚 API なし。Next.js App Router / HTML5 Audio 正常使用 |
| コンテキスト適合 | ❌ | 詳細ページ再生が一覧と別実装（インテグレーション不整合） |
| スコープ | ❌ | 未使用 export 型（デッドコード + 重複定義） |

## 今回の指摘（new）
| # | finding_id | family_tag | カテゴリ | 場所 | 問題 | 修正案 |
|---|------------|------------|---------|------|------|--------|
| 1 | AI-NEW-default-speed-wiring | wiring-gap | 配線忘れ/要求不一致 | `web/app/settings/page.tsx:17,86`・`web/contexts/AppContext.tsx:34,102-118`・`web/components/AudioPlayerBar.tsx:89` | spec §10.5(L239)「AppContext 反映」未実装。settings は localStorage 保存のみで `SET_SPEED` を dispatch しない。`playbackSpeed` は 1.0 固定初期化で restore も `default_playback_speed` を読まず、spec §10.3(L213)「速度セレクタ初期値＝デフォルト速度」を満たさない。grep 上この設定値は書込専用で再生に効果ゼロ | restore effect で `default_playback_speed` を読み `SET_SPEED` 初期化＋settings の onChange で `dispatch({type:'SET_SPEED',speed})` を呼ぶ |
| 2 | AI-NEW-podcast-detail-replay | integration-inconsistency | スコープ/一貫性 | `web/app/podcast/[id]/page.tsx:52-58` | spec §10.3(L209)「一覧と同フロー」に違反。`getPodcast` 再フェッチをせず失効しうる署名付き URL を使用（§9 L151「必ず呼び直す」違反）、復元位置を 0 ハードコードし `getSavedPosition` 不使用。一覧 `app/podcast/page.tsx:45-47` は正しく実装済みで別実装になっている。再生フローのテストも未整備 | 一覧と同じく `getPodcast(id)`→`getSavedPosition`→`load(fresh.audio_url, savedPosition, fresh.id)` に統一し、再フェッチ・復元のテストを追加 |
| 3 | AI-NEW-unused-response-types | dead-code | 未使用コード/重複 | `web/types/index.ts:20-23,36-38,45-47` | `FeedResponse`/`PodcastsResponse`/`SourcesResponse` は export されているが全走査で使用箇所 0 件。`lib/api.ts:65,89,105,113,125` が同形をインライン定義しており二重定義 | api.ts の戻り値型を名前付き 3 型に置換して使用（重複解消）、または 3 型を削除 |

## 継続指摘（persists）
なし（本 run 初回レビュー）

## 解消済み（resolved）
なし

## 再開指摘（reopened）
なし

## REJECT判定条件
- `new` 3 件（AI-NEW-default-speed-wiring / AI-NEW-podcast-detail-replay / AI-NEW-unused-response-types）により REJECT。