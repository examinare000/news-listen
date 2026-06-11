# コーディングレビュー

## 結果: REJECT

## サマリー
プレイヤーバーの一時停止→再生で再生位置が先頭に巻き戻る欠陥を検出。`SET_TIME` action が dead code（未 dispatch）のため `state.currentTime` が常に 0 で、order.md タスク6「継続再生」要件に違反する。

## 今回の指摘（new）
| # | finding_id | family_tag | 重大度 | 場所 | 問題 | 影響 | 修正案 |
|---|------------|------------|--------|------|------|------|--------|
| 1 | CODE-NEW-AudioPlayerBar-L26 | bug | High | `web/components/AudioPlayerBar.tsx:26-30` / `web/contexts/AppContext.tsx:47,62` | `SET_TIME` action は型定義と reducer case に存在するが一度も dispatch されず（grep で確認）、`state.currentTime` は常に初期値 0。resume 分岐が `player.load(audio_url, state.currentTime, id)` を呼び `audio.src` 再設定＋`currentTime=0` リセット（`useAudioPlayer.ts:167-169`） | 一時停止後に再生を押すと音声が先頭から再生し直され、再生位置が失われる。order.md タスク6「画面遷移後も継続再生」に違反。既存テストはボタンラベルのトグルのみ検証し本欠陥を検出不可 | resume 時は `load()` を呼ばず `await player.play()` のみにする（Context の単一プレイヤーは src・位置を保持）。再ロードが必要なら `useAudioPlayer` の `timeupdate` で `SET_TIME` を dispatch して `state.currentTime` を同期し `player.currentTime` を渡す。併せて未使用の `SET_TIME` を整理し、位置保持を検証するテストを追加 |

## 参考情報（非ブロッキング）
- デフォルト再生速度: `web/app/settings/page.tsx:17,85` が `KEY_DEFAULT_PLAYBACK_SPEED` を保存・表示するが、再生時に読み出して `setSpeed`/`playbackRate` に適用するコードが存在しない（grep 確認）。設定が再生に反映されない。
- BFF プロキシ SSRF: `web/app/api/backend/[...path]/route.ts:13-32` はスキームのみ検証しホスト未検証でオープンプロキシになり得る。ただしユーザ指定バックエンドURL・ローカル開発（localhost 宛）を許容する BFF 設計上のトレードオフのため非ブロッキング。コメントの「SSRF mitigation」の範囲を明記推奨。

## 検証証跡
- 差分確認: `web/` 全体が新規（未追跡）。AppContext / AudioPlayerContext / useAudioPlayer / AudioPlayerBar / lib(api,config,format) / proxy route / 各 page / useLocalStorage を実読。`grep -rn "SET_TIME"` および `currentTime` 書き込み箇所を確認し、dispatch 不在を実証。
- ビルド: 未確認（このステップは編集・実行制約あり）
- テスト: 未確認（`vitest` 未実行。`AudioPlayerBar.test.tsx` の Play/Pause はラベルトグルのみで位置保持を未検証であることを静的確認）