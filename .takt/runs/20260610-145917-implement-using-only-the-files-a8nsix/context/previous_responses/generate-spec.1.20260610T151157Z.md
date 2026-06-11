generate_spec ステップの作業（Phase 1）が完了しました。

# generate_spec 実行レポート

## 成果物（2 ファイル）

| ファイル | 状態 | 内容 |
|---|---|---|
| `docs/spec/2026-06-10-web-frontend-spec.md` | **新規作成** | web スコープの実装仕様（全 15 章） |
| `docs/plan/2026-06-10-web-frontend.md` | **更新**（既存計画を正本として維持） | T1〜T17 実装計画 + 今回の差分反映 |

analyze_order の申し送りどおり、**ルート直下の `spec.md`/`plan.md`（バックエンド成果物）には一切触れていません**（`git status` で確認: 変更は上記 2 パスのみ）。

## 進め方（Superpowers 統合）

指示に従い `brainstorming` → `writing-plans` スキルを起動。非対話ワークフローのため両スキルのユーザー承認ゲートは **Step 3 (review_spec) が代行**する前提で自律消化しました。要件の明確化は analyze_order の検証結果（C1〜C7 / D1〜D10）が回答済み、代替アプローチ比較（BFF プロキシ vs CORS 追加 vs rewrites）は計画書 §3.1 の記録を実コードと照合のうえ採用しています。

## 判断の根拠（このステップで直接再確認した一次事実）

- `backend/api/main.py`（全 42 行読了）: `X-API-Key` + `hmac.compare_digest`、401 detail 文言、`/health` のみ認証不要
- `backend/api/routers/` 4 ファイル: エンドポイントは `GET /feed`、`POST /articles/{id}/star|dismiss`、`GET /podcasts(/{id})`、`GET/POST/DELETE /settings/sources` のみ。409/404 の detail 文言、追加/削除が**更新後全件**を返すことを確認
- `backend/api/schemas.py`（全 81 行読了）: `PodcastResponse` に `status`/`playback_position_seconds` なし、`audio_url: str`（non-null）
- `grep -i cors backend/api/` → **ヒット 0 件**（BFF プロキシ必須の根拠）
- `agent-rules/15-frontend-design.md:24,42`: 禁止フォント（Inter/Roboto/Arial/system-ui/Space Grotesk）

## spec.md の要点（異常系の厳密定義）

- **エラー型契約**: `ApiError(status, detail)` 1 本に正規化（非 JSON ボディ→`'Unknown error'`、ネットワーク断→`status: 0`）
- **異常系を全機能で定義**: 空 feed/空 podcasts/空 sources の文言、401/404/409/422 ごとの UI 挙動、プロキシの 400（ヘッダー欠落・不正スキーム=SSRF 緩和）/502（到達不能）、localStorage 不正 JSON フォールバック、SSR `window` 不在、未知 difficulty、不正 ISO 日時、`resumePosition >= duration` クランプ、Audio `error` イベント
- **テスト容易性**: クライアント注入型（`createApiClient`）、`Audio` モッククラス、制御コンポーネント化、localStorage フック集約を仕様として固定

## plan.md の更新内容（仕様策定で厳密化した差分の反映）

1. §0 に仕様書を「実装すべき仕様の正本」として追加
2. Task 3 に `checkHealth()` を追加（Task 8/16 の接続テストの配線漏れ防止）
3. Task 4 Red リストに「バックエンド到達不能 → 502」を追加
4. Task 11 Red リストに「Audio `error` イベント」「復元位置の範囲外クランプ」を追加
5. §0 に「参照すべき既存実装パターン（ファイル:行）」と「注意すべきアンチパターン」8 項目を追加（writing-plans 要件）

## セルフレビュー結果

- **仕様カバレッジ**: spec §5〜§13 の全要件が plan T1〜T17 のいずれかに対応することを突合済み（ギャップは上記 4 点で解消）
- **型整合**: spec §4 と plan §4 の型・関数名は 1:1 一致
- **プレースホルダー**: なし。なお plan は「具体的コードは含めない」方針（冒頭に明記済み・analyze_order 検証済み）であり、実テストコードは Step 4 (write_tests) が plan の Red リストから生成する分担

## 後続ステップへの申し送り

- **review_spec**: 仕様の正の優先順位は spec 冒頭に明記（実コード > spec > plan > PRD > design.html > order.md）。order.md との既知の衝突 C1〜C7 は意図的な乖離であり欠陥ではない
- **write_tests / implement**: T1→T17 の依存順厳守。Phase 2 境界（spec §15）着手禁止。Node.js バージョンと `create-next-app` のネットワーク可否は implement 冒頭で要確認（未確認事項）
- git 操作（add/commit/push）は実行していません（ワークフロー規約どおりシステムに委任）