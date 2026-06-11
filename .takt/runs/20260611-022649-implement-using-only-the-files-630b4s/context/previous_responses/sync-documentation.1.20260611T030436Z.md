更新内容をまとめます。

**README.md** — iOS 前提の記述を Web/Next.js 構成へ全面更新:
- アーキテクチャ図: `[iOS App: SwiftUI]` → `[Web App: Next.js 15 / App Router]`、BFF プロキシの仕組みを補足注記として追加
- 使用サービス表: iOS 行を Web 行（Next.js 15 / TypeScript / Tailwind CSS / Vitest）に置換
- ディレクトリ構成: `ios/` を削除し `web/` のサブディレクトリ構成を追記、`docs/spec/` と `docs/plan/` を反映
- 前提条件: Node.js 22+ を追加
- セットアップ手順: 「iOS アプリ」セクションを「Web フロントエンド（ローカル開発）」に差し替え（`npm install / npm run dev / npm test` の手順を記載）
- ドキュメントリンク: iOS 実装プランを削除し、Web フロントエンド仕様書・実装プランへのリンクを追加

**.env.example** — `API_KEY` コメントの `iOS` 参照を削除し、Web アプリの設定フロー（SetupModal → localStorage）を明記。

インラインコメント（`AppContext.tsx`, `AudioPlayerBar.tsx`, `AudioPlayerContext.tsx`, `useStartPodcast.ts`）はすでに変更に合わせて更新済みであり、陳腐化した記述はありませんでした。