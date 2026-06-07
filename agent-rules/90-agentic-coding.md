# 90. 自律型エージェント協調ルール（takt / Antigravity 統合モード）
nrslib/takt ワークフロー管理と、Antigravity 及び Claude Code の協調開発ルール。

## コア・コンセプト
- **takt (規律)**: State Machine。ステップ（plan, execute_tdd, review等）のステート遷移に従い「成果物」と「判定条件」を満たす。
- **Antigravity (実行)**: 自律的完遂責任。実装・テスト・デバッグ・TDDサイクルを自己完結させる。
- **Claude Code (品質)**: 監督。全体の進捗管理、高レベル設計判断、最終品質の承認。

## エージェントの責務
- **Main Claude (オーケストレーター)**: ワークフロー起動、ステップ完了判定、成果物の `develop` 統合。
- **Antigravity (Actor)**: TDD実装、デバッグ、技術調査、`update_topic` 記録。
- **Sub-Agents (Specialized Worker)**: セキュリティ、アンチパターン等の専門レビュー（PASS/REJECT出力）。

## takt 連携プロトコル
1. **計画**: `spec.md`（仕様）と `plan.md`（タスクリスト）を生成。実装進捗に合わせリアルタイム更新（Living Documentation）。
2. **開発**: テスト（RED）を先行させ、AntigravityがGREEN化（TDD）。`update_topic`で現在ステップと意図を同期。
3. **レビュー**: ステート遷移に従い専門エージェントを自動起動し、エージェント間相互検証を実施。

## ブランチ＆コミュニケーション
- **ブランチ**: `develop` ➔ `task/<task-id>-<name>`。takt全ステップ完了時に `develop` へマージ。
- **言語**: 返答、コメント、ドキュメント、コミットは**日本語統一**（00-core-principles.md遵守）。

## 完了判定基準 (THE IRON LAW)
1. `spec.md` / `plan.md` と実装が完全一致。
2. 全テスト（ユニット/統合/E2E）の通過。
3. 全ReviewerエージェントによるPASS判定。
4. `00-core-principles.md` チェックリストの完全クリア。

---
**適用優先度**: 🔴 最高（takt / Antigravity 環境下で必須）
