# コーディングレビュー

## 結果: REJECT

## サマリー
新規 `web/` 実装はクリーンな点が多いが、画面遷移での継続再生・グローバルプレイヤーを壊す `useAudioPlayer` のインスタンス非共有バグと、Settings 保存で API キーを空文字上書きする認証破壊バグの 2 件があり REJECT。

## 今回の指摘（new）
| # | finding_id | family_tag | 重大度 | 場所 | 問題 | 影響 | 修正案 |
|---|------------|------------|--------|------|------|------|--------|
| 1 | CODE-NEW-hooks-useAudioPlayer-L75 | bug | High | `web/hooks/useAudioPlayer.ts:75-80` / `web/components/AudioPlayerBar.tsx:13` / `web/app/podcast/page.tsx:30` / `web/app/podcast/[id]/page.tsx:20` | `useAudioPlayer()` が呼び出しごとに `new Audio()` を生成し、3 箇所で独立インスタンス化（共有 Provider/シングルトン不在）。常駐の `AudioPlayerBar` と実再生する `PodcastPage` が別 `Audio` を持つ | 再生バーの isPlaying/currentTime/volume・操作が鳴っている音声と別インスタンスを指し非機能。`/podcast` 離脱時に cleanup の `audio.pause()`（L126-127）で再生停止し spec §10/手動シナリオ「画面遷移で再生継続」と order.md タスク6 を満たさない | `useAudioPlayer` 単一インスタンスを Provider 化し layout で配布、各ページは共有 player/AppContext 経由で再生意図を渡し `currentPodcast` 変化に応じ load/play。URL は §9 通り再生直前 `getPodcast(id)` を使用 |
| 2 | CODE-NEW-app-settings-page-L19 | bug | High | `web/app/settings/page.tsx:14,19-21` | `newApiKey` 初期値 `''` のまま `handleSave` が `configure(newBaseUrl, newApiKey)` を呼ぶ。キー欄空のまま保存すると空文字で上書き | `AppContext.configure`（L111-118）が `api_key` を空文字で保存・state 更新。以降全 API の `X-API-Key` が空になり 401 を誘発。既存の認証設定を破壊 | `configure(newBaseUrl, newApiKey || state.apiKey)` 等で空入力時は既存キー維持。空入力時のキー保持リグレッションテストを追加 |

## 検証証跡
- 差分確認: 新規 `web/` 一式を spec・テスト・実コードで突合。`useAudioPlayer` 使用箇所を grep で 3 箇所確認、共有 Provider 不在を確認。`settings/page.tsx` の `handleSave` と `AppContext.configure` を確認
- ビルド: 未確認（`web/node_modules` 未インストール、本ステップは編集・実行制約あり）
- テスト: 未確認（サンドボックス制約により `vitest` 実行不可）。`AudioPlayerBar.test.tsx` は自身インスタンスのみ、`settings/page.test.tsx:78-96` は常に新キー入力で、両不具合とも未カバー（テストギャップ）