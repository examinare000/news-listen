調査が完了しました。検証に必要な一次事実をすべて実ファイルで確認済みです。以下、analyze_order の分析結果です。

---

# analyze_order 分析レポート

## 1. モード判定: 【検証モード】

`order.md` 自体は粗いタスク指示書だが、コードベース内に本タスクと完全に対応する詳細実装計画 **`docs/plan/2026-06-10-web-frontend.md`**（T1〜T17、TDD観点付き）が存在する。よって新規設計は行わず、**order.md と既存計画書の両方を実 API・既存ルールと照合検証**した。

## 2. 検証済みの一次事実（すべて実ファイルで直接確認）

| 事実 | 確認方法 |
|---|---|
| `web/` は存在しない（完全新規） | `ls web/` → No such file or directory |
| バックエンドに **CORS ミドルウェアなし** | `grep -rn -i cors backend/api/` → ヒット 0 件 |
| `PodcastResponse` に `status`・`playback_position_seconds` は**ない** | `backend/api/schemas.py:26-34` を直接読了（L80 の `status` は `ActionResponse` のもの） |
| `audio_url` は non-nullable `str`（署名付き GCS URL） | `schemas.py:31` + `from_podcast` の docstring |
| 設定保存 API は `/settings/sources`（RSS のみ）。`PUT /settings`・`PATCH /podcasts/:id/position` は**存在しない** | サブエージェントによる `backend/api/routers/` 全件調査（feed/articles/podcasts/settings の4ルーター + `/health`） |
| 認証は `X-API-Key`（`hmac.compare_digest`）、`/health` のみ認証不要 | `backend/api/main.py`（調査報告 + schemas 直接確認） |
| フォント禁止リスト（Inter/Roboto/Arial/system-ui/Space Grotesk） | `agent-rules/15-frontend-design.md:24,41-42` を grep 確認 |
| ルート直下の `spec.md`・`plan.md` は**バックエンド用成果物**（Task 4〜13） | 両ファイルの先頭を直接読了 |
| PRD は **Next.js 15 (App Router) + TypeScript + Tailwind CSS v4** を既に確定 | `docs/prd/2026-05-31-news-listen.md`（調査報告） |

## 3. 検証結果: `docs/plan/2026-06-10-web-frontend.md` は実装に値する（採用推奨）

計画書の核心である「設計書と実 API の差分決定 D1〜D10」を実コードと照合した結果、**全件が事実と整合**:

- **D4**（status 非公開）→ schemas.py で直接確認 ✅
- **D6**（CORS なし → BFF プロキシ必須）→ grep で直接確認 ✅
- **D1/D3**（`/subscriptions/:id`・`PUT /settings` 不在 → `/settings/sources` 使用・localStorage 保存）→ ルーター調査と整合 ✅
- **D7/D8**（署名付き URL 1時間失効 → 再生直前に `GET /podcasts/:id` 再取得、型は `string`）→ schemas.py と整合 ✅
- テスト容易性: fetch モック・`Audio` モッククラス・localStorage フック集約・制御コンポーネント化（API 呼び出しはページ責務）が計画に明記済みで、TDD 観点（Red リスト）が全タスクに付随 ✅

## 4. order.md と事実の衝突点（後続ステップで計画書側を正とすべき）

| # | order.md の記述 | 事実・正 |
|---|---|---|
| C1 | 「Feed / Podcast / Settings の**3画面**」 | デザイン・PRD・計画書は **Subscriptions を含む4画面 + `/podcast/[id]` + セットアップゲート** |
| C2 | 「環境変数 `NEXT_PUBLIC_API_BASE_URL` で API エンドポイント設定」 | バックエンドに CORS がなく**ブラウザ直接 fetch は失敗する**（検証済み）。計画書どおり **BFF プロキシ + ユーザー実行時設定（localStorage）** が正。`NEXT_PUBLIC_*` はビルド時固定になるため実行時設定の設計とも矛盾 |
| C3 | 「App Router / Pages Router を判断して採用」 | PRD が **App Router を既に確定**（SSR 対応・型安全・ファイルベースルーティング）。新規判断は不要、記録のみ |
| C4 | 「`web/src/contexts/`」等の src 構成 | 計画書 §5 は **src なし構成**（`web/app/`, `web/components/`…）。どちらかに統一が必要 → 計画書を正とする |
| C5 | 「アクティブ画面を Context で管理」 | App Router では**画面状態は URL（ルーティング）が正**。Context 管理対象は API 設定・再生状態・速度のみ（計画書 §3.2）。二重管理は状態不整合の温床 |
| C6 | 「Jest + RTL（または Vitest）」「テストは優先度: 低」 | 計画書は **Vitest + RTL** で確定。かつ CLAUDE.md / agent-rules/11 で **TDD は必須** — テストは後置タスクではなく**各タスクで先行作成**（order.md のタスク8は実質無効） |
| C7 | デザイン HTML 内の `/subscriptions/:id`・`PATCH position`・`GET/PUT /settings`・status ポーリング | **すべて実 API に存在しない**。web-design.html を盲信せず計画書 §2/§4 を正とすること |

## 5. order.md の Open Questions への回答（確認済み）

1. **API 仕様の所在**: `backend/api/routers/*.py`（最終的な正）+ ルート `spec.md`（バックエンド仕様書）+ 計画書 §4（転記済み API 契約）。独立した OpenAPI ドキュメントファイルは未確認。
2. **Settings の保存先**: `localStorage`（確定）。設定保存用バックエンド API（`PUT /settings`）は存在しないため選択の余地なし。RSS ソース管理のみ `/settings/sources` API を使用。

## 6. 後続ステップへの申し送り（懸念・制約）

1. **spec.md の上書き禁止**: ルート直下 `spec.md`/`plan.md` はバックエンドの完成済み成果物。generate_spec ステップは **web スコープの別ファイル**（例: `docs/spec/2026-06-10-web-frontend-spec.md` または `web/spec.md`）として出力し、既存ファイルを破壊しないこと。
2. **仕様の正の優先順位**: `backend/api/`（実コード） > `docs/plan/2026-06-10-web-frontend.md` > PRD > `web-design.html` > order.md。
3. **タスク順序**: 計画書 §6 の T1→T17 依存順を維持。1タスク = 1関心事に分割済みで、各タスクに RED テスト観点が明記されているため、write_tests / implement ステップはこれをそのまま消化できる。
4. **セキュリティ制約**: BFF プロキシは `X-Backend-Base-Url` の `http(s)://` スキーム検証必須（SSRF 緩和、計画書 §3.1）。API キー・署名付き URL のログ出力禁止（agent-rules/12）。
5. **デザイン制約**: 禁止フォント回避（Bricolage Grotesque / Zen Kaku Gothic New / IBM Plex Mono を next/font で導入）、CSS 変数トークンは web-design.html の値をそのまま採用。
6. **未確認事項**: ローカル環境の Node.js バージョン（計画書は node:22-alpine 前提）、`create-next-app` 実行時のネットワーク可否 — implement ステップ冒頭で確認が必要。
7. **Phase 2 境界の厳守**: status ポーリング・再生位置サーバー同期・難易度設定 UI・CORS 追加は計画書 §9 で着手禁止。実装中に必要を感じても触れないこと。

**結論**: order.md 単体では実 API と複数の矛盾があるが、`docs/plan/2026-06-10-web-frontend.md` がそれらをすべて解決済みであり、検証の結果この計画書は実装に値する。generate_spec は本レポートの衝突表（§4）と計画書を入力として、web スコープの仕様を策定すべきである。