# 変更スコープ宣言

## タスク
`web/` ディレクトリに Next.js フロントエンド（Feed / Podcast / Settings 画面 + BFF プロキシ）を実装する

## 変更予定
| 種別 | ファイル |
|------|---------|
| 変更 | `web/app/feed/page.tsx` |
| 確認 | `web/app/podcast/page.tsx` |
| 確認 | `web/app/podcast/[id]/page.tsx` |
| 確認 | `web/app/settings/page.tsx` |
| 確認 | `web/app/subscriptions/page.tsx` |
| 確認 | `web/app/api/backend/[...path]/route.ts` |
| 確認 | `web/app/layout.tsx` |
| 確認 | `web/app/page.tsx` |
| 確認 | `web/components/NavigationBar.tsx` |
| 確認 | `web/components/ArticleCard.tsx` |
| 確認 | `web/components/PodcastCard.tsx` |
| 確認 | `web/components/AudioPlayerBar.tsx` |
| 確認 | `web/components/ui/DifficultyBadge.tsx` |
| 確認 | `web/components/ui/Toast.tsx` |
| 確認 | `web/components/ui/ConfirmDialog.tsx` |
| 確認 | `web/components/ui/SetupModal.tsx` |
| 確認 | `web/contexts/AppContext.tsx` |
| 確認 | `web/hooks/useAudioPlayer.ts` |
| 確認 | `web/hooks/useLocalStorage.ts` |
| 確認 | `web/lib/api.ts` |
| 確認 | `web/lib/config.ts` |
| 確認 | `web/lib/format.ts` |
| 確認 | `web/types/index.ts` |
| 確認 | `web/package.json` / `web/tsconfig.json` / `web/vitest.config.ts` / `web/next.config.ts` |

## 推定規模
Large

## 影響範囲
- `web/` ディレクトリ全体（新規 Next.js プロジェクト）
- 既存の `backend/`, `infra/`, `docs/` には変更なし
- 19 テストファイル（約 220 テストケース）すべてに対応する実装が存在することを確認済み