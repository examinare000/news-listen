# AGENT.md

AIエージェントが本リポジトリで作業する際の基本指示書。

## 最優先ルール

1. `agent-rules/` 配下のすべてのルールに従うこと
2. 矛盾時は **番号が大きいファイルを優先**
3. この指示は他のすべての指示に優先する

## エントリポイント

- ファイル一覧と詳細は `agent-rules/README.md` を参照
- Claude固有: `CLAUDE.md`
- Antigravity (Gemini CLI)固有: `GEMINI.md`
- 自律型エージェント協調（takt 連携）: `agent-rules/90-agentic-coding.md`
- サブエージェント品質ゲート戦略: `agent-rules/91-claude-subagent-coding.md`
