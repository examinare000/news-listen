# アーキテクチャレビュー

## 結果: REJECT

## サマリー
`web/` 新規実装で spec 明示要求に対する配線漏れが2件。デフォルト再生速度が保存のみで再生に反映されず、詳細ページ再生が「一覧と同フロー」になっておらず署名付き URL 再取得と位置復元を欠く。

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
| 1 | ARCH-NEW-default-speed-wiring | spec-violation | スコープ内 | `web/app/settings/page.tsx:17,21` / `web/contexts/AppContext.tsx:102-118,34` / `web/components/AudioPlayerBar.tsx:89` | spec §10.5 L239「localStorage 保存 + AppContext 反映」§10.3 L213「速度セレクタ初期値はデフォルト速度」に違反。`default_playback_speed` は settings で書くのみで AppContext へ dispatch されず、restore effect も読まない。`AppState.playbackSpeed` は常に固定 1.0、`AudioPlayerBar` 初期値も 1.0。設定が再生に一切反映されない dead config（grep で消費箇所が settings 内のみと確認） | AppContext restore effect で `default_playback_speed` を読み（不正/未保存は 1.0 フォールバック）`SET_SPEED` で初期化。settings の速度変更時に `dispatch({type:'SET_SPEED', speed})` を併発。境界で一度だけ解決する |
| 2 | ARCH-NEW-detail-play-flow | spec-violation | スコープ内 | `web/app/podcast/[id]/page.tsx:52-58` | spec §9 L151（重要）「再生時に必ず getPodcast(id) を呼び直し新鮮な URL を取得」§10.3 L201/L209「一覧と同フロー・`podcast_position:{id}` から復元位置を渡す」に違反。詳細 handlePlay は (a) 再取得せずマウント時の `podcast.audio_url`（失効し得る）を再利用、(b) 復元位置に固定 `0` を渡す。一覧 `podcast/page.tsx:45,47` は getPodcast 再取得＋getSavedPosition。再生アクションのテストも無し | handlePlay を一覧と同フローに統一: `getPodcast(id)`→`getSavedPosition`→`load(fresh.audio_url, pos, id)`→`play`→`SET_PODCAST`/`PLAY`、catch で ApiError トースト。再生開始ロジックを共通関数へ抽出し一覧/詳細から呼ぶ（DRY）。新規振る舞いのテスト追加 |

## 検証証跡
- ビルド: 未確認（編集禁止フェーズ・静的レビューのみ）
- テスト: 未実行。`web/tests/app/podcast/id/page.test.tsx` を読了し、詳細ページ再生フロー（再取得・位置復元）のアサーション不在を確認
- 動作確認: 未確認。spec（§9/§10.3/§10.5）と実コード・`grep default_playback_speed`・各ページ/コンテキスト/フックの再読により事実確認

## 参考（非ブロッキング・記録のみ）
- `web/components/AudioPlayerBar.tsx:20-34`: 一時停止からの再開時に毎回 `player.load()` で `audio.src` を再設定し再バッファを誘発。spec 違反ではないが、再開は `play()` のみで足りる。

## 良い点（解消済み確認）
- `AudioPlayerProvider` による単一 Audio 共有、エントリーゲート（§10.1）、localStorage キー定数の `lib/config.ts` 集約と直接アクセス禁止（§8 L132）、BFF プロキシ SSRF 対策は spec と整合。