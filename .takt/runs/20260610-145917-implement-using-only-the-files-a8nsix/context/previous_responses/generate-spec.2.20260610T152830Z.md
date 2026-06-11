generate_spec ステップ（2 回目・review_spec 差し戻し対応）の作業が完了しました。

# generate_spec 実行レポート（iteration 2 — REJECT 是正対応）

## 対応した指摘（review_spec / `reports/01-spec-review.md`）

| finding_id | 指摘内容 | 対応 |
|---|---|---|
| REQ-NEW-spec-web-frontend-L25 | App Router 採用根拠を「PRD で確定済み」と記載（PRD に該当記述なし＝出典虚偽） | **訂正済み**。spec §2 の根拠を「設計書（`web-design.html:82,84,95`）で確定済み」へ変更（spec.md:25） |
| REQ-NEW-spec-web-frontend-L146 | order タスク 6 明示要求の音量コントロールが spec §9/§10.3 に未記載・省略理由も不在 | **仕様追加を選択**（省略理由の明記ではなく）。spec §9 に `setVolume` 契約、§10.3 に音量スライダー UI を追加し、plan Task 2/11/12 へ RED テスト観点を配線 |

## 是正前に再確認した一次事実（このステップで直接実行）

- `grep web-design.html` → `Next.js 15 (App Router)` は **82, 84, 95 行**に実在。`Tailwind CSS` は **86, 97 行**に実在
- `grep docs/prd/` → `Next.js / App Router / Tailwind` いずれも **0 件**（出典虚偽の裏取り）
- `order.md:51` → 「音声プレイヤー UI（再生/停止、シークバー、**音量**）」の明示要求を確認
- `plan.md:332` の「PRD のユースケースは通勤中のスマホ利用」は **PRD:36 に実在**（誤出典ではないため変更不要と判定）

## 変更内容

### `docs/spec/2026-06-10-web-frontend-spec.md`（7 箇所）
1. **§2:25** — App Router 根拠を `web-design.html:82,84,95` へ訂正（指摘 #2）
2. **§2:26** — Tailwind 根拠「PRD・設計書」も同種の出典誤りのため `web-design.html:86,97` へ訂正（指摘外だが同一欠陥クラス。PRD grep 0 件を確認済み）
3. **§1** — 目的に「音量」を追加
4. **§8** — localStorage キーに `player_volume` を追加
5. **§9** — 音量の操作契約を追加: `setVolume(v)` は **[0,1] クランプ** → `Audio.volume` 反映 → `player_volume` 保存。`load` 時に復元（未保存・不正値は 1.0）。**フック内ローカル状態とし AppContext に置かない**（WHY: 参照 UI は AudioPlayerBar のみ。グローバル状態の汚染・二重管理を防止）
6. **§10.3** — AudioPlayerBar に音量スライダー（`input[type=range]`・0〜100・`aria-label="音量"`）を追加
7. **§12/§14** — 境界値（音量 <0 / >1 クランプ）と受け入れ手動シナリオに音量変更を追加

### `docs/plan/2026-06-10-web-frontend.md`（4 箇所）
1. **Task 2** — `lib/config.ts` のキー定数に `player_volume` を追加
2. **Task 11 (useAudioPlayer)** — RED 観点に「`setVolume` の反映・保存・クランプ・`load` 時復元」を追加。「AppContext へ SET_VOLUME を**追加しない**」を明記
3. **Task 12 (AudioPlayerBar)** — RED 観点に「音量スライダー操作で `setVolume` が呼ばれる・初期値は保存済み音量」を追加（review の申し送りどおり）
4. **§7 受け入れ基準** — 手動シナリオに音量変更を追加

## スコープ管理
- `git status` で変更が上記 2 ファイルのみであることを確認済み（`docs/plan` modified / `docs/spec` 未追跡=正常）。ルート直下の `spec.md`/`plan.md`（バックエンド成果物）には触れていません
- API 契約・アーキテクチャは無変更（review 判定どおり作り直し不要）。音量は既存の `useLocalStorage` / `useAudioPlayer` / AudioPlayerBar の枠内で完結し、AppContext reducer・BFF・API クライアントへの影響ゼロ

## 後続ステップへの申し送り
- **review_spec**: 是正条件 2 点はいずれも反映済み。音量は「追加」を選択（order の明示要求であり、省略を正当化する根拠が PRD・設計書のどちらにも存在しないため）
- **write_tests / implement**: Task 11 の RED に音量クランプ境界値（-0.1 / 1.5）、Task 12 の RED に音量スライダー操作テストが追加されている。`player_volume` キーは Task 2 の `lib/config.ts` で定数化してから使用すること
- git 操作（add/commit/push）は実行していません（ワークフロー規約どおりシステムに委任）