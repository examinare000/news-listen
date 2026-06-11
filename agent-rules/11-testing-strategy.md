# 11. テスト戦略
TDD実践とテスト品質の正本。基本原則は `00-core-principles.md` 参照。

## テスト階層
E2E（ユーザーシナリオ） ➔ 統合（システム動作） ➔ コンポ（モジュール間連携） ➔ ユニット（個別関数・メソッド）

## TDD実践（t-wada方式）
- **Red-Green-Refactor**:
  1. *Red*: 失敗するテストを先行作成（正常・異常系）。
  2. *Green*: 最小限の実装でテストを通過させる。
  3. *Refactor*: 振る舞いを維持したままコード改善。
- **実装ファースト禁止**: テスト未作成での実装は不可。

## 必須テストパターン
- **A. エラーハンドリング**: 境界値や異常値で例外を出さず、適切にエラー応答するか検証。
- **B. 境界値**: 最小・最大・限界超過・空文字の網羅。
- **C. 統合ワークフロー**: 一連の操作（作成➔取得➔更新➔削除➔確認）を一気通貫で検証。
- **D. インターフェース契約**: レスポンスの必須フィールド・型を検証し、互換性を保証。
  ```python
  # 契約検証例
  for field in ['assessment', 'timestamp', 'success']: assert field in result
  assert isinstance(result['assessment']['overall_score'], (int, float))
  ```

## テスト実行戦略
- **順序**: ユニット ➔ 統合 ➔ システム ➔ E2E
- **本プロジェクトはモノレポ**: サブディレクトリごとにテストランナーが異なる。対象ディレクトリへ `cd` してから実行すること。
  - **`backend/`（Python / pytest）**:
    ```bash
    cd backend
    # venv 未作成時のみ（初回・worktree 新規作成時）:
    uv venv --python 3.12 .venv && uv pip install --python .venv/bin/python -r requirements.txt -r requirements-dev.txt
    # テスト実行:
    .venv/bin/python -m pytest tests/ -q   # activate 済みなら python -m pytest tests/ -q
    ```
  - **`web/`（Next.js / vitest、`npm test` = `vitest run`）**:
    ```bash
    cd web
    npm install        # node_modules 未作成時は必須。これを忘れると `vitest: command not found` で実行不能になる
    npm test           # = vitest run
    ```
- **依存未インストールはテスト「失敗」ではなく「実行不能」**: テストを走らせる前に、上記の依存インストールが済んでいるか必ず確認する。`command not found` / `ModuleNotFoundError` はテスト結果ではなく環境未整備のサイン。
- **他言語の一般例**（参考）: `go test ./...` 等。

## 品質指標
- **カバレッジ**: ユニット≥80%（振る舞い優先）、統合・E2E主要フロー100%。
- **成功率**: 95%以上。
- **実行時間**: ユニット10秒以内、統合5分以内、E2E30分以内。

## モック戦略
- 外部依存（DB/API/ファイル/時刻）はモック化し、ロジックを分離。
- **注意**: 統合テストでは乖離防止のため、実DB/実APIでの検証を原則とする。

## データ＆パフォーマンス
- **データ管理**: フィクスチャを活用。テスト後には必ずデータをクリーンアップ。
- **性能アサーション**: 主要操作には実行時間検証（例: `assert time.time() - start < 1.0`）を導入。

---
**適用優先度**: 🔴 最高（全コードに適用必須）