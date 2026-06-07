# 10. Git戦略
ブランチ・コミット運用の正本（Git-Flowベース）。

## 必須ルール
- 1ブランチ = 1イニシアチブ（短命に）。
- `main` / `develop`への直接コミット、共有ブランチへの force-push 禁止。
- `git add .` 禁止（意図しない混入防止）。WIP連投・無関係な変更の混在禁止。

## ブランチ構成
- **`main`**: 本番用。タグリリースのみ（直コミ禁止）。
- **`develop`**: 統合開発用（直コミ禁止）。
- **`feature/<task-name>`**: 新機能（developから分岐 ➔ developへマージ）。
- **`release/<version>`**: リリース準備（developから分岐 ➔ main + developへマージ）。
- **`hotfix/<name>`**: 緊急修正（mainから分岐 ➔ main + developへマージ）。
- ※命名例: `feature/user-auth-session-timeout`, `release/v0.5.0`, `hotfix/critical-sync-bug`
- ※拡張ブランチは `90-agentic-coding.md` 参照。

## アトミックコミット
1. **1コミット = 1論理変更**。
2. **複数ファイルは原則別コミット**（相互依存でビルドエラーになる場合のみ同一コミット）。
3. **独立した取り消し可能性**: 単体で revert 可能であること。

## コミットメッセージ規約
- **形式**: `<種別>: <説明>`（日本語、1〜2文、WHY優先）。
- **種別**: 機能, 修正, 改善, 削除, 移動, 名前変更, テスト, 文書, 設定, 構成, 統合
- **禁止語**: `update`, `WIP` は使用禁止。
- **例**: `改善: ボタン色をCSS変数に移行（保守性向上）` / `統合: feature/user-authをdevelopにマージ`

## マージ戦略
- マージコミット（`git merge --no-ff` 等）許容。
- コンフリクト解決後は `統合: <理由>` でコミット。

## 典型フロー（機能開発）
```bash
git checkout develop && git pull origin develop
git checkout -b feature/<task-name>
# アトミック開発 (git add <file> && git commit -m "機能: <WHY>")
git checkout develop && git pull origin develop
git merge feature/<task-name> && git push origin develop
git branch -d feature/<task-name>
```