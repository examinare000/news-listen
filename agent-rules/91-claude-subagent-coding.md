# 91. Claude サブエージェント品質ゲート戦略（takt 連携）
サブエージェントを Worker / Reviewer として起動し、品質を担保するための戦略。

## 適用条件＆エージェント一覧
- takt のステップで専門的なレビューやタスク分割が必要な場合に呼び出す。
- **planner**: 設計・分解 (`plan` ➔ `spec.md`, `plan.md`)
- **coder**: 実装/TDD (`execute_tdd` ➔ 実装・テストコード)
- **reviewer / quality-reviewer**: コード/総合品質レビュー (`review_code_quality` ➔ 改善指摘/承認)
- **ai-antipattern-reviewer**: AI手抜き検出 (`review_ai_antipattern` ➔ 手抜き指摘/リファクタ案)
- **spec-reviewer**: 仕様・プラン検証 (`review_spec` ➔ 矛盾/漏れ指摘)
- **git-composer**: コミット・統合 (COMPLETE直前 ➔ アトミックコミット/PR)

## 品質ゲートの運用フロー
1. **Worker起動**: メイン Claude が適切なサブエージェントを起動。
2. **ルール遵守**: 各エージェントは `00-core-principles.md` (日本語統一・TDD) を完全遵守。
3. **品質判定**: Reviewer系が `PASS` / `REJECT` を判定。
4. **ループ**: `REJECT` の場合は前段ステップ (例: `fix_implementation`) へ戻り修正。

## 起動プロンプト（テンプレート）
```markdown
あなたは <エージェント名> です。`.claude/agents/<ファイル名>.md` に従ってください。
taktステップ: <step_name> / コンテキスト: <plan.md/spec.md抜粋>
完遂条件: `00-core-principles.md` (日本語統一/TDD) を完全遵守し、次のステップへの判定条件 (PASS) を満たすこと。出力は事実ベースで簡潔に。
```

## 注意事項
- **コンテキスト**: 必要最小限のファイル・情報のみをサブに渡し効率化。
- **権限**: 破壊的なGit操作やファイル削除はメインまたは `git-composer` のみに限定。

---
**適用優先度**: 🔴 最高（サブエージェント使用時）
