# タスク完了サマリー

## タスク
`docs/design/web-design.html` のデザインに基づき `web/` に Next.js（App Router）フロントエンドを実装する。グローバル状態管理・ナビゲーションバー・REST API fetch ラッパー・Feed/Podcast/Settings の3画面・音声プレイヤー・テスト環境を構築する。

## 結果
完了（requirements validation 合格。テスト/ビルドの実行確定は final_verification に委譲）

## 変更内容
| 種別 | ファイル | 概要 |
|------|---------|------|
| 作成 | `web/contexts/AppContext.tsx` | Context + useReducer グローバル状態（baseUrl/apiKey/currentPodcast/playbackSpeed）、localStorage 復元 |
| 作成 | `web/contexts/AudioPlayerContext.tsx` | 単一 Audio インスタンス共有 + onError→toast 配線 |
| 作成 | `web/hooks/useAudioPlayer.ts` | HTML5 Audio 制御（再生状態の単一情報源・位置保存/復元） |
| 作成 | `web/hooks/useStartPodcast.ts` | 一覧/詳細共通の再生開始フロー（新鮮 URL 再取得 + 保存位置復元） |
| 作成 | `web/lib/api.ts` | 型付き fetch ラッパー（4xx/5xx/ネットワークエラー統一処理、generics） |
| 作成 | `web/lib/config.ts` | localStorage キー定数の単一情報源 |
| 作成 | `web/app/api/backend/[...path]/route.ts` | BFF プロキシ（baseUrl ランタイム設定・SSRF 緩和） |
| 作成 | `web/components/NavigationBar.tsx` | 画面切替ナビ（usePathname アクティブ判定） |
| 作成 | `web/components/AudioPlayerBar.tsx` | 再生/停止・シーク・音量・速度 UI（layout 常駐で画面遷移後も継続再生） |
| 作成 | `web/app/feed/page.tsx` | Feed 画面（ローディング/エラー/空リストの3状態） |
| 作成 | `web/app/podcast/page.tsx`, `web/app/podcast/[id]/page.tsx` | Podcast 一覧/詳細 + 共通再生フロー |
| 作成 | `web/app/settings/page.tsx` | 設定の表示・変更・保存（localStorage） |
| 作成 | `web/app/layout.tsx` | Provider 階層（App→Toast→AudioPlayer）と Navbar/PlayerBar 常駐 |
| 作成 | `web/tests/**`（20ファイル） | Vitest + React Testing Library 単体テスト（fetch はモック） |
| 変更 | `web/components/AudioPlayerBar.tsx` | resume を `player.play()` のみに修正（位置リセット防止）、速度 dispatch 単一経路化 |
| 変更 | `web/contexts/AppContext.tsx` | `isPlaying`/`PLAY`/`PAUSE` 削除、デフォルト再生速度の localStorage 復元配線 |
| 変更 | `web/contexts/AudioPlayerContext.tsx` | onError→toast を end-to-end 配線 |
| 変更 | `web/hooks/useStartPodcast.ts` | catch に else 分岐追加（非 ApiError も通知、握りつぶし解消） |
| 変更 | `web/tests/components/AudioPlayerBar.test.tsx`, `web/tests/contexts/AppContext.test.tsx` | 上記修正に対応する回帰テスト追加 |

## 検証証跡
- 要件照合: `order.md` を最小単位 36 要件に分解し全件を実コードで個別照合（❌ 0 件）。設計差分2件（アクティブ画面の App Router ルーティング管理、env 変数の不採用）は `docs/spec/2026-06-10-web-frontend-spec.md:36` で根拠付き決定済みであり、要求の本質を満たすと判定。
- 前段 finding 再評価: reviewers 8 findings の resolved を実コードで再検算し全て妥当と確認（SET_SPEED 単一経路、resume 位置保持、onError→toast 配線、isPlaying デッドステート除去 等）。
- 本番コード健全性: `app/components/contexts/hooks/lib/types` を grep し TODO/FIXME/スタブ/モック残存なし（`settings/page.tsx:64` の `placeholder` 属性は正当な UI）。
- テスト ⚠️: テストは存在し3レビュアーが静的整合を確認。ただし唯一の実行証跡 vitest キャッシュ（`results.json` mtime 1781144677）は fix 変更ファイル（mtime ≥1781145809）より約19分古く post-fix の合格証跡ではない。本 run はサンドボックス承認ブロックで再実行不可。**final_verification（Step 10）で `npm test` 実行が必須。**
- ビルド ⚠️ / 動作確認 ⚠️: `tsc --noEmit`・`next build`・起動/E2E は本 run 未実行（承認ブロック）。型・配線は静的読解で問題未検出。final_verification での実行確認を必須とする。