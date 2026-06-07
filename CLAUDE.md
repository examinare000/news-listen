# CLAUDE.md

## 最優先ルール
1. `agent-rules/` 配下の全ルールを遵守（矛盾時は**ファイル番号が大きい方**を優先）。
2. この指示（CLAUDE.md）は他の全指示に最優先。
3. 優先度: 🔴絶対 > 🟠高 > 🟡中。01等のエージェント専用ルールは該当エージェントで最優先。
4. ルール一覧・インデックスの正本：`agent-rules/README.md`
5. **正本**: `agent-rules/90-agentic-coding.md`（takt / Antigravity 統合モード）

## 動作モード判定
開始時に必ず判定。
- **自律型エージェント協調（takt 連携）**: Antigravity (Gemini CLI) 有効時 ➔ `agent-rules/90-agentic-coding.md`
- **サブエージェント品質ゲート戦略**: 専門レビューやタスク分割が必要な場合 ➔ `agent-rules/91-claude-subagent-coding.md`（メインはオーケストレーター、専門エージェントを Task ツールで起動）

## 主要ルール参照
- 開発サイクル・3原則: `agent-rules/00-core-principles.md`
- Claude固有/共通動作: `agent-rules/01-claude-behavior.md` / `03-agent-behavior.md`
- Git戦略・コミット規約: `agent-rules/10-git-strategy.md`
- TDD・テスト戦略: `agent-rules/11-testing-strategy.md`
- ドキュメント管理（Living Doc）: `agent-rules/30-documentation-management.md`
