# プロジェクトテンプレート

複数のAIエージェント（Claude / Codex / Gemini）が協調して開発を行う「Agentic Coding」前提のテンプレート。
レイヤー化された指示書体系で効率的かつ高品質な開発を実現する。

## 特徴

### Agentic Coding対応（2モード）

#### モードA: 複数LLM協調（`agent-rules/90-agentic-coding.md`）

| エージェント | 役割 |
|---|---|
| **Claude** | タスクマネジメント・統合判断 |
| **Codex** | コーディング・実装 |
| **Gemini** | 調査・分析 |

#### モードB: Claude単体サブエージェント協調（`agent-rules/91-claude-subagent-coding.md`）

メインClaudeはオーケストレーターに徹し、`.claude/agents/` 配下のサブエージェントを起動して相互レビューでコーディングを進める。

| Worker | 役割 | 権限 |
|---|---|---|
| **Planner** | 実装戦略の設計・タスク分解 | read-only |
| **Coder** | テストファースト実装 | Edit / Write |
| **Reviewer** | 相互レビュー・品質チェック | read-only |
| **Git-composer** | アトミックコミット・PR作成 | git操作 |

codex / gemini-cli MCP が無効な環境で自動的にモードB が選択される。

### レイヤー化されたルール体系

`agent-rules/` 配下に番号順にレイヤー構成。番号が大きいほど優先度が高い。

| レイヤー | 範囲 | 内容 |
|---|---|---|
| 0 | 00-09 | 基盤原則（絶対遵守） |
| 1 | 10-29 | ワークフロー（Git / テスト / セキュリティ / 可読性 / フロントエンド） |
| 2 | 30-49 | プロジェクト管理（ドキュメント） |
| 3 | 50-69 | 品質保証（プロダクション信頼性） |
| 4 | 70-89 | 言語・環境固有（Docker等） |
| 5 | 90- | 特殊戦略（エージェント連携） |

ファイル一覧は `agent-rules/README.md` を参照。

## 使用方法

### 1. 初期設定

```bash
git clone <このリポジトリのURL>
cd projectTemplate

# 必要に応じて .mcp.json を環境に合わせて調整
```

### 2. MCPサーバー

`.mcp.json` で以下が設定済み:
- **gemini-cli**: Google Gemini APIによる調査・分析
- **codex**: OpenAI Codexによるコーディング支援

Claude Code固有の設定は `.claude/settings.local.json` で管理（存在する場合）。

### 3. 開発ワークフロー

1. Claudeにタスクを日本語で依頼
2. Claudeがタスクを分解し適切なエージェントに割り当て
3. Codexが `development/feature/<task>` ブランチで実装
4. Geminiが必要に応じて `development/research/<topic>` で調査
5. Claudeが統合判断し develop へマージ

### ブランチ戦略概要

```
main (プロダクション)
└── develop (統合開発)
    └── development/ (Agentic coding専用)
        ├── feature/ (Codex)
        └── research/ (Gemini)
```

詳細は `agent-rules/10-git-strategy.md` と `agent-rules/90-agentic-coding.md`。

## 重要な原則

1. **デグレ防止最優先**: 既存の動作を絶対に壊さない
2. **TDD（t-wada方式）**: Red-Green-Refactorを厳守
3. **日本語コミュニケーション**: ユーザー出力・コメント・コミットは日本語

詳細は `agent-rules/00-core-principles.md`。

## ファイル構成

```
.
├── README.md                # このファイル
├── CLAUDE.md                # Claude Code用
├── AGENT.md                 # 汎用エージェント用
├── GEMINI.md                # Gemini-cli用
├── .mcp.json                # MCPサーバー設定
├── .claude/
│   ├── settings.local.json
│   └── agents/              # モードB用サブエージェント定義
│       ├── planner.md
│       ├── coder.md
│       ├── reviewer.md
│       └── git-composer.md
└── agent-rules/             # ルールセット（README.md参照）
```

## カスタマイズ

新規ルールは番号体系に従って追加:

| 範囲 | 用途 |
|---|---|
| 00-09 | 基盤変更（慎重に） |
| 10-29 | ワークフロー追加 |
| 30-49 | プロジェクト管理 |
| 50-69 | 品質関連 |
| 70-89 | 技術固有（例: `71-python-specific.md`） |
| 90- | 特殊戦略 |

## ライセンス

MIT
# AudioNews
