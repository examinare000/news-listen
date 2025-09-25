# プロジェクトテンプレート

この詳細な開発ルール体系を持つプロジェクトテンプレートです。

## 概要

このテンプレートは、複数のAIエージェント（Claude、Codex、Gemini）が協調して開発作業を行う「Agentic Coding」を前提とした開発環境を提供します。レイヤー化された指示書体系により、効率的で高品質な開発が可能です。

## 特徴

### Agentic Coding対応
- **Claude**: タスクマネジメント・統合判断専任
- **Codex**: コーディング・実装専任
- **Gemini**: 調査・分析専任

### 階層化されたルール体系
プロジェクト固有のエージェント動作ルールは `agent-rules/` ディレクトリに5つのレイヤーで構成：

#### レイヤー0: 基盤原則（00-10番台）
- `00-core-principles.md`: **絶対原則**（デグレ防止、日本語使用、TDD）
- `01-claude-behavior.md`: Claude専用の動作制約
- `02-development-workflow.md`: 開発フローの基本原則

#### レイヤー1: ワークフロー（10-30番台）
- `10-git-strategy.md`: Git戦略（統一版）
- `11-testing-strategy.md`: テスト戦略（TDD、品質保証）
- `12-security-guidelines.md`: セキュリティ原則

#### レイヤー2: プロジェクト管理（30-50番台）
- `30-documentation-management.md`: ドキュメント管理

#### レイヤー3: 品質保証（50-70番台）
- `50-production-reliability.md`: プロダクション信頼性

#### レイヤー4: 環境固有（70-89番台）
- `70-docker-environments.md`: Docker環境管理

#### レイヤー5: 特殊戦略（90番台以降）
- `90-agentic-coding.md`: **Agentic Coding役割分担戦略**

## 使用方法

### 1. プロジェクトの初期設定

```bash
# このテンプレートをクローンまたはダウンロード
git clone <このリポジトリのURL>
cd projectTemplate

# 必要に応じて.mcp.jsonを環境に合わせて調整
```

### 2. 開発環境の設定

#### MCPサーバーの設定
`.mcp.json`ファイルで以下のMCPサーバーが設定済み：
- **gemini-cli**: Google Gemini APIを使用した調査・分析
- **codex**: OpenAI Codexを使用したコーディング支援

#### Claude Code設定
`.claude/settings.local.json`で Claude Code固有の設定を管理（存在する場合）

### 3. 開発ワークフロー

#### 通常の開発タスク
1. Claudeにタスクを日本語で依頼
2. Claudeがタスクを分解し、適切なエージェントに割り当て
3. Codexが`development/feature/xxx`ブランチで実装
4. Geminiが必要に応じて技術調査を実施
5. Claudeが統合判断を行い、developブランチへマージ

#### ブランチ戦略
```
main (プロダクション)
├── develop (統合開発)
└── development/ (Agentic coding専用)
    ├── feature/ (Codex開発ブランチ)
    └── research/ (Gemini調査ブランチ)
```

## 重要な原則

### 1. デグレッション防止最優先
- 既存の動作している機能を絶対に壊さない
- 新機能追加時は既存テストが全て通ることを確認

### 2. Test-Driven Development (TDD)
- t-wada推奨手法の厳格な遵守
- Red-Green-Refactorサイクルの徹底
- テストを生きた仕様書として活用

### 3. 日本語でのコミュニケーション
- ユーザー向けのすべての出力は日本語
- コメント・エラーメッセージも日本語
- ただし変数名・関数名は英語慣習に従う

## ファイル構成

```
.
├── README.md                    # このファイル
├── CLAUDE.md                    # Claude Code用指示書
├── .mcp.json                    # MCPサーバー設定
├── .claude/                     # Claude Code設定ディレクトリ
│   └── settings.local.json      # ローカル設定（任意）
└── agent-rules/                 # エージェント動作ルール
    ├── 00-core-principles.md     # 基盤原則（最優先）
    ├── 01-claude-behavior.md     # Claude専用制約
    ├── 02-development-workflow.md
    ├── 10-git-strategy.md
    ├── 11-testing-strategy.md
    ├── 12-security-guidelines.md
    ├── 30-documentation-management.md
    ├── 50-production-reliability.md
    ├── 70-docker-environments.md
    └── 90-agentic-coding.md      # Agentic Coding戦略
```

## ルールの優先順位

- **番号が大きいファイルが高優先度**
- **🔴マーク**: 絶対遵守必須
- **🟠マーク**: 高優先度
- **矛盾時は番号の大きいファイルを優先**

## カスタマイズ

### 新しいルールの追加
適切なレイヤーと番号を選択してルールファイルを追加：
- **基盤変更**: 00-10番台（慎重に検討）
- **ワークフロー追加**: 10-30番台
- **プロジェクト管理**: 30-50番台
- **品質関連**: 50-70番台
- **技術固有**: 70-89番台
- **特殊戦略**: 90番台以降

### プロジェクト固有の調整
1. 言語固有のルール（例：`71-python-specific.md`）
2. フレームワーク固有のルール（例：`72-django-guidelines.md`）
3. 組織固有のルール（例：`91-company-standards.md`）

## サポート

このテンプレートに関する質問や改善提案は、プロジェクト管理者にお問い合わせください。

## ライセンス

このプロジェクトテンプレートはMITライセンスの下で提供されています。