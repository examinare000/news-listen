I have completed the verification — both my own fact-checking against the backend code and the mandatory spec-reviewer subagent (which independently confirmed the API contract and surfaced additional findings from `firestore_client.py`, `storage_client.py`, and the recommendation sort logic that I had not yet read). Here is the consolidated review.

---

# review_spec 検証結果

## 検証方法
- バックエンド実コード（`main.py` / `schemas.py` / `routers/*.py` / `shared/models.py`）を直接読了し、spec/plan の API 契約転記を 1 項目ずつ照合
- `grep` で CORS 不在（0 件）・`web/` 未作成（greenfield）を確認
- PRD・web-design.html を照合し、設計判断の出典を検証
- **spec-reviewer サブエージェントを起動**（必須要件）し、独立検証を実施。`firestore_client.py:94-102`（`limit=50` / `created_at DESCENDING`）、`storage_client.py`（`expiration_seconds=3600`）、recommendation の score 降順ソートまで追加確認

## 観点別の結論

| 観点 | 結論 | 根拠 |
|---|---|---|
| API 契約の正確性 | **完全一致（誤りなし）** | 401 文言=main.py:25-30 / feed 空時 `[]`・最大50=feed.py:25,32 / star・dismiss 文言=articles.py:18-34 / 署名URL1時間=podcasts.py:23 / PodcastResponse に status 無し=schemas.py:26-34（model には status あるが API 非公開=models.py:61 と整合）/ audio_url 非null=schemas.py:31 / RssSource=name,url のみ=models.py:25-27 / difficulty 6値=models.py:11 / sources 409・404・422・全件返却=settings.py:34,57,44,61 |
| 既存ロジック衝突 | **なし** | `web/` 未作成、backend 無変更方針（plan §1・§9）、CORS grep 0 件 → BFF プロキシ方針は妥当 |
| テスト容易性 | **充足** | fetch=`vi.stubGlobal`、Audio=`tests/helpers/mockAudio.ts`、localStorage/window=`useLocalStorage` 集約・SSR 安全。隔離方法と配置が plan に具体化（plan:124,269,291,404） |
| 影響範囲の配線 | **網羅** | `createApiClient` 注入経路、`checkHealth` の SetupModal/settings 共通化、BFF ヘッダー引き継ぎ、再生時 `getPodcast(id)` 再取得フローまで結線済み |

## 検出した問題

### ブロッキング（REJECT 相当）
**なし。** API 契約・アーキテクチャ・テスト戦略に技術的破綻はなく、実装着手は可能。

### 是正要求（CONDITIONAL の条件）
1. **【出典虚偽・要訂正】** spec §2（spec.md:25）は App Router 採用根拠を「PRD で確定済み」とするが、**PRD に Next.js/App Router の記述は皆無**（grep 0 件、PRD のプラットフォーム表は iOS+backend のみ）。実際の根拠は `web-design.html:82,84,95`。判断自体（App Router 採用）は order タスク1・SSR/BFF 方針と整合し妥当だが、**根拠の出典が事実と異なる**ため「設計書(web-design.html)で確定済み」へ訂正が必要。
2. **【明示要求の欠落】** order タスク6（order.md:51）は音声プレイヤーに「再生/停止、シークバー、**音量**」を明示要求するが、spec §9・§10.3（spec.md:146,210）はシーク(-15s/+30s)と速度のみで**音量コントロールへの言及がなく、省略理由(WHY)も不在**。音量 UI を仕様へ追加するか、省略理由を明記すべき。

### 逸脱だが妥当（追加是正不要・注記済み）
- order タスク2「アクティブ画面の Context 管理」不採用（spec.md:122）→ App Router で URL が画面状態の単一真実源。妥当。
- order タスク4「`NEXT_PUBLIC_API_BASE_URL` 環境変数」不採用（spec.md:36）→ 実行時 localStorage 設定と矛盾するため。妥当。
- order「3画面」→ 4画面（Subscriptions 追加、spec.md:152）→ PRD の RSS 購読管理要件を満たすため。妥当。

いずれも両ドキュメントに逸脱として注記済み。

---

## 【判定】CONDITIONAL PASS

API 契約の転記精度は全項目で backend 実コードと一致し、BFF プロキシ・署名 URL 失効対策・状態管理分離・テスト隔離戦略・配線網羅に技術的破綻はない。実装（write_tests / implement）への移行は可能。

ただし以下 2 点の**文言・スコープ修正**を条件とする（API 契約や設計の作り直しは不要）:
1. spec.md:25 の App Router 根拠を「PRD で確定済み」→「設計書(web-design.html)で確定済み」へ訂正
2. 音量コントロール（order タスク6 明示要求）を spec §9/§10.3 に追加、または省略理由を明記

次ステップ（write_tests / implement）への申し送り: 上記 2 点を反映のうえ着手すること。特に音量については、実装するならば AudioPlayerBar とテスト観点（plan Task12）への追加が必要。