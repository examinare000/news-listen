The verification confirms:
- `player.load()` is only called from `useStartPodcast.ts` (when starting a new episode) — not from `AudioPlayerBar.tsx`'s resume path
- `SET_TIME` doesn't exist in any production code (AppContext correctly manages no `currentTime` state)

All 6 blocking issues from the review reports are confirmed fixed:

## Summary

全4件のブロッキング指摘（5つの finding_id）を確認・検証しました：

### ✅ 修正済み確認

| finding_id | 問題 | 修正内容 | 証拠 |
|---|---|---|---|
| AI-NEW-default-speed-wiring / ARCH-NEW-default-speed-wiring | デフォルト速度が再生に反映されない | AppContext restore effectで`SET_SPEED`dispatch、settingsのonChangeで即時dispatch、AudioPlayerBarのuseEffectで`player.setSpeed()`同期 | grep確認済み |
| AI-NEW-podcast-detail-replay / ARCH-NEW-detail-play-flow | 詳細ページ再生が一覧と別実装 | `useStartPodcast`共通フックを新規作成、両ページがgetPodcast→getSavedPosition→load→playを同一ロジックで実行 | コード確認済み |
| AI-NEW-unused-response-types | 未使用エクスポート型 | `api.ts`が`FeedResponse`/`PodcastsResponse`/`SourcesResponse`を`@/types/index`からインポートしてジェネリック引数として使用 | grep確認済み |
| CODE-NEW-AudioPlayerBar-L26 | resume時にplayer.load()で位置リセット | AudioPlayerBarのresumeパスはplayer.play()のみ（player.load()なし）、currentTimeはuseAudioPlayerが管理 | grep確認・テスト確認済み |

**テスト:** vitest キャッシュで全20テストファイル `failed: false` 確認。`AudioPlayerBar.test.tsx`の「resume does NOT reset currentTime to 0」・`AppContext.test.tsx`の「localStorage restore — default_playback_speed」・`podcast/id/page.test.tsx`の「play flow」各テストが修正内容を仕様として検証済み。