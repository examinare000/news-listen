All static verifications pass. Let me now summarize the complete verification evidence:

---

## 修正完了レポート

### 実行した修正（全4指摘）

#### ✅ #1 `AI-NEW-audio-error-toast-unwired` / `ARCH-NEW-onerror-unwired` (BLOCKING)
**ファイル:** `web/contexts/AudioPlayerContext.tsx`

`AudioPlayerProvider` に `useToast()` を追加し、`onError: () => showToast('音声を再生できません', 'error')` を `useAudioPlayer()` へ渡した。`layout.tsx` で `ToastProvider` が `AudioPlayerProvider` の外側にあるため `useToast()` の呼び出しは安全。

```tsx
const { showToast } = useToast()
const player = useAudioPlayer({
  onError: () => showToast('音声を再生できません', 'error'),
})
```

---

#### ✅ #2 `AI-NEW-appcontext-isplaying-dead-state` (BLOCKING)
**ファイル:** `web/contexts/AppContext.tsx`, `web/components/AudioPlayerBar.tsx`, `web/hooks/useStartPodcast.ts`

`AppState.isPlaying`、`Action PLAY/PAUSE`、`reducer case PLAY/PAUSE` を完全削除。`AudioPlayerBar` と `useStartPodcast` から `dispatch({ type: 'PLAY' })` / `dispatch({ type: 'PAUSE' })` を除去。`player.isPlaying`（`useAudioPlayer`）が唯一の正規源として機能する。

**grep 証跡（本番コードに PLAY/PAUSE dispatch なし）:**
```
grep -rn "dispatch.*PLAY|dispatch.*PAUSE" web/app web/components web/hooks web/contexts
→ (空出力 — 一致なし)
```

**isPlaying 参照はすべて `player.isPlaying` に集約:**
```
AudioPlayerBar.tsx:27: player.isPlaying  ← useAudioPlayer から
AudioPlayerBar.tsx:55,57: player.isPlaying  ← useAudioPlayer から
AppContext.tsx:20: コメントのみ
```

---

#### ✅ #3 `AI-NEW-redundant-setspeed` (Warning)
**ファイル:** `web/components/AudioPlayerBar.tsx`

`onChange` 内の `player.setSpeed(speed)` を削除。`dispatch({ type: 'SET_SPEED' })` のみで良く、既存の `useEffect([state.playbackSpeed])` が `player.setSpeed()` を呼ぶことで単一経路に統一。

---

#### ✅ #4 `AI-NEW-startpodcast-swallow` (Warning)
**ファイル:** `web/hooks/useStartPodcast.ts`

`catch` の `else` 分岐を追加し、`ApiError` 以外（`NotAllowedError` 等）も `showToast('再生できませんでした', 'error')` でユーザーへ通知。

---

### テスト更新

| ファイル | 変更内容 |
|----------|---------|
| `tests/contexts/AppContext.test.tsx` | `isPlaying is false initially` テスト削除、`PLAY/PAUSE actions` describe 削除、`isPlaying NOT in AppContext` 検証テスト追加 |
| `tests/components/AudioPlayerBar.test.tsx` | 全 `<AudioPlayerProvider>` レンダーに `<ToastProvider>` 追加（`AudioPlayerProvider` が `useToast()` を呼ぶため必須）、エラー→トースト結合テスト追加 |

---

### 静的検証証跡

| 検証項目 | 根拠 |
|---------|------|
| PLAY/PAUSE dispatch なし | grep 0件（本番コード全ディレクトリ） |
| isPlaying は player から読む | grep: AudioPlayerBar.tsx のみ `player.isPlaying`、AppContext は comment のみ |
| useToast が ToastProvider 内で使用 | layout.tsx: ToastProvider → AudioPlayerProvider の順でネスト確認 |
| テストの ToastProvider 追加 | grep: AudioPlayerProvider の全3箇所が ToastProvider に包まれている |

⚠️ **制約事項:** サンドボックスにより `npm run test` / `tsc --noEmit` の実行許可が得られず、テスト実行と型チェックは静的分析で代替した。`supervise` / `final_verification` ステップでの実行確認を推奨する。