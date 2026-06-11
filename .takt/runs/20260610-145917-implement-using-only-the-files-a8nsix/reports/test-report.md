# テスト作成レポート

## 作成テスト

| ファイル | 種別 | テスト数 | 概要 |
|---------|------|---------|------|
| `web/tests/lib/format.test.ts` | 単体 | 11 | `formatDuration`（0秒・300秒・3600秒+）/ `formatDate`（不正ISO文字列で例外なし） |
| `web/tests/hooks/useLocalStorage.test.ts` | 単体 | 8 | 初期値返却 / 永続化 / JSON不正値フォールバック / SSR（window不在）安全性 |
| `web/tests/lib/api.test.ts` | 単体 | 20 | 全API関数のURL・ヘッダー / `deleteSource` URLエンコード（`&`・日本語） / ApiError正規化 / API キーのログ非出力 |
| `web/tests/app/api/proxy.test.ts` | 単体 | 13 | GET/POST/DELETE転送 / バックエンドステータス素通し / `X-Backend-Base-Url`欠落→400 / ftp/file/相対URL→400（SSRF緩和） / ネットワーク断→502 |
| `web/tests/contexts/AppContext.test.tsx` | 単体 | 12 | 初期`isConfigured:false` / `configure()`でlocalStorage永続化 / reducer（SET_PODCAST/PLAY/PAUSE/SET_TIME/SET_SPEED） / `volume`フィールドがstateに存在しないこと |
| `web/tests/components/ui/DifficultyBadge.test.tsx` | 単体 | 5 | 6難易度すべてのラベル / 未知文字列で例外なし・生値表示 |
| `web/tests/components/ui/Toast.test.tsx` | 単体 | 6 | メッセージ表示 / 3秒後自動消滅（fakeTimers） / `role="status"`（success） / `role="alert"`（error） |
| `web/tests/components/ui/ConfirmDialog.test.tsx` | 単体 | 6 | 開閉 / onConfirm/onCancelコールバック / Escapeキーで閉じる |
| `web/tests/components/ui/SetupModal.test.tsx` | 単体 | 7 | `type="password"` / 空入力で保存不可 / `https://`未満のURLでインラインエラー / 正常入力でonConfigure呼び出し / 接続テストボタン |
| `web/tests/components/NavigationBar.test.tsx` | 単体 | 7 | 4リンク（Feed/Podcast/Subscriptions/Settings） / 現在パスに`aria-current="page"` / 非現在パスには付かない |
| `web/tests/components/ArticleCard.test.tsx` | 単体 | 9 | タイトル/ソース/スコアバー（`aria-valuenow`） / 外部リンク（`target="_blank"` + `rel="noopener noreferrer"`） / Star/Dismiss操作 / `busy=true`でdisabled / score 0/1.0境界値 |
| `web/tests/components/PodcastCard.test.tsx` | 単体 | 7 | イントロ先頭80文字 / DifficultyBadge/duration/生成日 / 再生ボタン→onPlay / カード→`/podcast/:id`リンク / 保存済み位置「続きから MM:SS」 |
| `web/tests/components/AudioPlayerBar.test.tsx` | 単体 | 13 | `currentPodcast=null`で非表示 / イントロ50文字 / 再生・一時停止 / -15s/+30sボタン / シークバー（`aria-label`付き） / **音量スライダー（`aria-label="音量"`・0〜100・setVolume接続・初期値復元）** / 速度セレクタ8段階 |
| `web/tests/hooks/useAudioPlayer.test.ts` | 単体 | 25 | load（位置復元・`resumePosition>=duration`→0再生） / play/pause / seek/seekRelative / setSpeed / timeupdateスロットル（10秒間隔） / endedイベント（isPlaying=false・位置0リセット） / errorイベント通知 / **setVolume クランプ境界値（-0.1→0 / 1.5→1 / -999→0）** / **player_volumeキーへ保存** / **load時保存音量復元（未保存・不正値→1.0）** / アンマウント時pause |
| `web/tests/app/feed/page.test.tsx` | 統合 | 9 | getFeed→カード表示 / ローディング→SkeletonCard / 空→「まだ記事がありません」 / Star成功→トースト+カード残存 / Dismiss成功→カード除去 / 404/401/status=0エラートースト / リフレッシュボタン |
| `web/tests/app/podcast/page.test.tsx` | 統合 | 6 | getPodcasts→一覧表示 / 空→「Podcastがまだありません」 / **再生時getPodcast(id)再取得（D7: 署名付きURL失効対策）** / 保存済み位置のcurrentTime復元 / リフレッシュ |
| `web/tests/app/podcast/id/page.test.tsx` | 統合 | 6 | イントロ全文・難易度・duration・article_ids表示 / 再生ボタン / 404→「エピソードが見つかりません」+一覧リンク |
| `web/tests/app/subscriptions/page.test.tsx` | 統合 | 10 | getSources→一覧 / 空→「購読ソースがありません」 / URLバリデーション（http(s)://必須） / 409インライン（入力値保持） / 422インライン / 送信中disabled / 成功→入力クリア / 削除→ConfirmDialog→deleteSource / **削除成功→レスポンスでstate置換（再GET不要）** |
| `web/tests/app/settings/page.test.tsx` | 統合 | 8 | baseUrl表示 / apiKey値非表示（「設定済み」表示）/ `type="password"` / 難易度説明文（UI非表示の根拠） / 保存→localStorage更新 / 速度セレクタ→localStorage保存 / 接続テスト成功/失敗 |

**合計: 19テストファイル / 約188テストケース**

テストインフラとして `web/package.json`（vitest/RTL/Next.js依存定義）・`web/tsconfig.json`・`web/vitest.config.ts`・`web/tests/setup.ts`・`web/tests/helpers/mockAudio.ts`（HTML5 Audio APIモック）を合わせて作成済み。

---

## 実行結果（参考）

実装前のためテスト失敗・import エラーは想定内。

| 状態 | 件数 | 備考 |
|------|------|------|
| Pass | 0 | プロダクションコード未実装のため |
| Fail / Import Error（想定内） | 約188 | `Cannot find module '@/lib/format'` 等 — 未実装の23モジュール起因 |
| Error（要対応） | 0 | 実装完了後も残るパスミス等はなし（全importパスは計画書の成果物ファイル構成と一致） |

> **注記:** 本環境では `npm install` が Permission 制約により自動実行できなかった。`cd web && npm install && npm test` を実行すると全件 `Cannot find module` で失敗し、RED状態であることを確認できる。

---

## 備考

**spec §9 音量要求（order.md タスク6・review_spec 是正対象）の重点カバレッジ:**
- `setVolume(-0.1)` → 0.0 クランプ、`setVolume(1.5)` → 1.0 クランプ（境界値テスト）を `useAudioPlayer.test.ts` に明示
- `load` 時の保存音量復元・不正値→1.0フォールバックを独立テストで担保
- `AudioPlayerBar.test.tsx` に音量スライダーの `aria-label="音量"`・0〜100レンジ・`setVolume`呼び出し・初期値反映を個別テストとして記述
- `AppContext.test.tsx` で `state` に `volume` フィールドが存在しないことを明示（spec §9 「AppContextには置かない」設計判断の契約テスト）

**インテグレーションテスト判定:**
Feed/Podcast/Subscriptions/Settings の各ページテストは、AppContext + ToastProvider + APIクライアントの3モジュール以上を横断するデータフローをカバーするため、統合テストとして分類した。別途 `integration/` ディレクトリは設けず、各ページテストが統合パターンを兼ねる構成とした。

**implement ステップへの申し送り（テストを通過させるための実装要件）:**
- `AppProvider` は `initialState` prop（テスト向け初期状態注入）を受け付けること
- `useAudioPlayer(opts?: { onError?: () => void })` — errorイベントコールバックを受け付けること
- `load(url: string, resumePosition: number, podcastId: string)` — podcastId引数が必須
- `export const PLAYBACK_SPEEDS` を `useAudioPlayer.ts` からエクスポートすること
- BFFプロキシは `web/app/api/backend/[...path]/route.ts`（ブラケット含むディレクトリ名）で作成すること