コードレビューの問題点をすべて修正しました。npmが承認待ちのためテスト実行の証拠は出せませんが、静的解析は完了しています。

## 修正サマリー

### 🔴 Fix 1: デフォルト再生速度の配線（AI-NEW-default-speed-wiring）

**根本原因**: `AppContext` restore effectが `default_playback_speed` を無視、`settings/page.tsx` がdispatchを呼ばない

**修正箇所**:
1. **`contexts/AppContext.tsx`**: restore effectの先頭に `KEY_DEFAULT_PLAYBACK_SPEED` の読み取り + `dispatch({ type:'SET_SPEED', speed })` を追加
2. **`app/settings/page.tsx`**: speed `onChange` で `dispatch({ type:'SET_SPEED', speed })` を追加
3. **`components/AudioPlayerBar.tsx`**: `useEffect(() => player.setSpeed(state.playbackSpeed), [state.playbackSpeed])` でAppContext→Audio要素に速度を同期

### 🔴 Fix 2: 詳細ページ再生フロー（AI-NEW-podcast-detail-replay / ARCH-NEW-detail-play-flow）

**根本原因**: `handlePlay` がstale URLを再利用、保存位置を0にハードコード

**修正箇所**:
1. **`hooks/useStartPodcast.ts`** (新規): spec §9 L151 + §10.3 L201/L209に準拠した正規再生フロー（`getPodcast`再フェッチ + `getSavedPosition`復元）を一元化
2. **`app/podcast/[id]/page.tsx`**: `handlePlay` が `useStartPodcast` を使用するよう更新（DRY化）
3. **`app/podcast/page.tsx`**: 同じく `useStartPodcast` を使用（重複排除）

### 🔴 Fix 3: 未使用export型（AI-NEW-unused-response-types）

**修正箇所**:
- **`lib/api.ts`**: `FeedResponse`/`PodcastsResponse`/`SourcesResponse` を named importして実際に使用

### 🔴 Fix 4: 一時停止→再生で先頭巻き戻り / SET_TIME dead code（coding_review）

**根本原因**: resumeブランチが `player.load(state.currentTime=0)` を呼び、`state.currentTime` は常に0

**修正箇所**:
1. **`components/AudioPlayerBar.tsx`**: resumeブランチから `player.load()` を削除し `player.play()` のみに
2. **`contexts/AppContext.tsx`**: `SET_TIME` action + `currentTime`/`duration` state フィールドをすべて削除（dead code）

### テスト追加

| テストファイル | 追加テスト |
|---|---|
| `AppContext.test.tsx` | `default_playback_speed` 復元（4ケース）、`currentTime`/`duration` 非存在 |
| `AudioPlayerBar.test.tsx` | 一時停止→再生で位置保持、速度セレクタ初期値確認 |
| `podcast/id/page.test.tsx` | `getPodcast`再フェッチ確認、保存位置復元確認 |
| `settings/page.test.tsx` | AppContext.playbackSpeed即時反映確認 |