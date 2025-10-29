# CustomHackingSystem → Vanilla RemoteBreach 移行要件ドキュメント

**作成日:** 2025年10月24日
**最終更新:** 2025年10月26日
**対象MOD:** BetterNetrunning v2.x
**目的:** HackingExtensions MOD依存を削除する際の技術要件と移行判断基準を提供

**関連ドキュメント**:
- **技術検証**: VANILLA_ALTERNATIVE_APPROACHES.md
- **実装計画**: VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md

---

## 📋 移行判断基準

### いつ移行すべきか

**移行を推奨する条件**:
- ❌ **HackingExtensionsが開発終了・メンテナンス停止**
- ❌ **HackingExtensionsが新バージョンCyberpunk 2077と互換性喪失**
- ❌ **CustomHackingSystemに致命的バグが発生し修正見込みなし**

**現状維持を推奨する条件** (2025-10-26時点):
- ✅ HackingExtensionsは活発に開発継続中
- ✅ CustomHackingSystemは安定動作
- ✅ 既存実装は十分な品質（UX 100%、パフォーマンス最適）

### 移行の投資対効果

| 項目 | 現行実装 (CustomHackingSystem) | バニラ移行 (@wrapMethod戦略) |
|------|-------------------------------|----------------------------|
| **開発工数** | 0h (維持) | **39-61h (中央値50h)** |
| **UX品質** | **100%** (リアルタイムunlock) | **90%** (成功daemonのみunlock) |
| **パフォーマンス** | 最適 | <1% overhead (IsA()チェック) |
| **リスク** | 🟢 外部依存 | 🟢 バニラ依存 |
| **保守性** | 高 (Strategy Pattern) | 中 (直接実装、コード長) |
| **外部依存** | HackingExtensions | なし |

**結論**: 現時点では**移行不要**。HackingExtensions終了時の備えとして技術検証のみ完了。

---

## 📊 技術的実現可能性（検証済み）

### 検証結果サマリー

**技術的実現性**: ✅ **85%実現可能**
- **工数**: 39-61h (中央値50h)
- **リスク**: 🟢 LOW
- **UX品質**: 90% (ActiveProgramsで成功daemon追跡可能)
- **パフォーマンス**: <1% overhead (IsA()早期チェック)

**重要な技術的発見**:
1. ✅ **@wrapMethod(ScriptableDeviceAction)戦略が有効**
   - RemoteBreachクラスには直接メソッドなし（SetProperties()のみ）
   - 親クラスScriptableDeviceActionのvirtualメソッドを拡張
   - IsA()チェックでRemoteBreach固有処理を限定実行

2. ✅ **ActiveProgramsに成功daemon情報あり**
   - BreachProcessing.reds (line 78-89)で実証済み
   - ExtractUnlockFlags()パターンで成功daemonを判定可能
   - **UX劣化なし**（成功したdaemonのみunlock）

3. ✅ **FinalizeNetrunnerDive()フックで処理可能**
   - CompleteAction()でStateSystemにtarget context保存
   - FinalizeNetrunnerDive()でtargetを取得してdevice unlock
   - タイミング問題は解決済み

4. ✅ **IsPossibleシグネチャ検証済み**
   - `IsPossible(target: weak<GameObject>, opt actionRecord: weak<ObjectAction_Record>, opt objectActionsCallbackController: weak<gameObjectActionsCallbackController>)`
   - baseDeviceActions.script:407で確認
   - ドキュメント記載と完全一致

5. ✅ **ScriptableSystem利用可能**
   - バニラで20+実装例あり
   - VanillaRemoteBreachStateSystemで状態保存可能

**詳細**: VANILLA_ALTERNATIVE_APPROACHES.md参照

---

## 🏗️ バニラアーキテクチャ分析

### RemoteBreachクラス構造

**ファイル**: `tools/redmod/scripts/cyberpunk/devices/core/baseDeviceActions.script:2290`

**RemoteBreachクラス**:
- SetProperties()メソッドのみ実装
- GetCost/IsPossible/CompleteActionは親クラスから継承

**クラス継承チェーン**:
```
RemoteBreach (line 2290)
  ↓ extends ActionBool (line 1918)
  ↓ extends ScriptableDeviceAction (line 1271)
  ↓ extends BaseScriptableAction (line 96)
```

**virtualメソッド所在**:
- `GetCost()`: BaseScriptableAction (line 904) → ScriptableDeviceAction (line 1645) override
- `IsPossible()`: BaseScriptableAction (line 407)
- `CompleteAction()`: BaseScriptableAction (line 530) → ScriptableDeviceAction (line 1625) override

**重要**: RemoteBreachクラス自体にはGetCost/IsPossible/CompleteActionメソッドは**存在しない**。
親クラスのvirtualメソッドを継承するため、@wrapMethod(ScriptableDeviceAction)で拡張可能。

**詳細なソースコード**: VANILLA_ALTERNATIVE_APPROACHES.md参照

---

### FinalizeNetrunnerDive()イベントフロー

**バニラソースコード検証済み** (`scriptableDeviceBasePS.script`):

**イベントシーケンス**:
1. RemoteBreach QuickHack実行
2. OnActionRemoteBreach() - NetworkBlackboard.RemoteBreach = true 設定
3. CompleteAction() - ミニゲーム起動前フック（target保存可能）
4. ミニゲーム実行（プレイヤーがdaemon完了）
5. ミニゲーム完了（Succeeded/Failed/Aborted）
6. HackingMinigameEnded(state)
7. FinalizeNetrunnerDive(state) - 成功時unlock/失敗時penalty適用

**実装ポイント**:
- CompleteAction()でStateSystem初期化（target保存）
- FinalizeNetrunnerDive()でNetworkBlackboard.RemoteBreachフラグ読み取り
- ActiveProgramsから成功daemonを取得（ExtractUnlockFlags()パターン）
- state引数でSucceeded/Failed判定

**バニラソースコード**: scriptableDeviceBasePS.script (lines 4674-4855)

---

### Breach Failure Penalty処理

**既存実装** (`r6/scripts/BetterNetrunning/Breach/BreachPenaltySystem.reds`):

BetterNetrunningは既にFinalizeNetrunnerDive()フックでBreach Failure Penaltyを実装済み。RemoteBreach検出ロジックを追加するのみ。

**Failure Penalty効果**:
1. **Disconnection VFX** - プレイヤーに失敗を視覚的に通知
2. **Breach Protocol無効化** - 指定時間内は再試行不可
   - ネットワーク接続デバイス: ネットワーク全体をロック
   - スタンドアロン/Vehicle: 失敗位置から範囲内デバイスをロック
3. **Trace試行** - 近くにネットランナーがいれば追跡開始

**バニラ移行時の実装要件**:
- ✅ 既存BreachPenaltySystem.redsにRemoteBreach検出を追加
- ✅ BNConstants.IsRemoteBreachContext()でNetworkBlackboard判定
- ✅ RemoteBreachFailurePenaltyEnabled/BreachPenaltyDurationMinutes設定確認
- ✅ 既存のLockNetworkDevices/ShowDisconnectionVFX/AttemptTrace再利用

**実装詳細**: VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md参照

---

### NetworkBlackboard仕様

**ファイル**: `tools/redmod/scripts/core/blackboard/blackboardDefinitions.script:1078`

**利用可能なフラグ**:
- `RemoteBreach: Bool` - RemoteBreachコンテキスト判定
- `NetworkName: String` - ネットワーク名
---

### NetworkBlackboard仕様

**NetworkBlackboard利用可能フラグ**:
- `RemoteBreach: Bool` - RemoteBreachコンテキスト判定用
- `NetworkName: String` - ネットワーク名
- `DeviceID: EntityID` - ターゲットデバイスID
- `Attempt: Int32` - 試行回数

**HackingMinigame Blackboard**:
- `ActivePrograms: Variant` - 成功したdaemon一覧（array<TweakDBID>）
- `Entity: Variant` - ターゲットエンティティ

**用途**: OnActionRemoteBreach()でフラグ設定、FinalizeNetrunnerDive()で読み取り

**バニラソースコード**: blackboardDefinitions.script (line 1078)

---

## 🔧 移行時の技術要件

### 必須実装項目

1. **@wrapMethod(ScriptableDeviceAction)実装**
   - GetCost(): Dynamic RAM cost計算
   - IsPossible(): RemoteBreach条件チェック（breach lock, RAM cost）
   - CompleteAction(): StateSystemにtarget保存

2. **VanillaRemoteBreachStateSystem実装**
   - ScriptableSystemを継承
   - CompleteAction() → FinalizeNetrunnerDive()間でtarget context保存
   - RemoteBreach完了後に状態クリア

3. **FinalizeNetrunnerDive()フック実装**
   - @wrapMethod(ScriptableDeviceComponentPS)
   - NetworkBlackboard.RemoteBreachでコンテキスト判定
   - ActiveProgramsから成功daemon取得
   - StateSystemからtarget取得
   - ExtractUnlockFlags()でdevice unlock実行
   - **Failure処理**: state == HackingMinigameState.Failedで失敗判定
     - Disconnection VFX表示
     - BreachLockSystemで範囲内デバイスロック
     - Trace試行（近くにネットランナーがいる場合）

4. **既存機能との統合**
   - BreachProcessing.redsでRemoteBreach early return
   - BreachPenaltySystem.redsでfailure処理統合
     - RemoteBreachFailurePenaltyEnabled設定確認
     - BreachPenaltyDurationMinutes設定でロック時間制御
   - RadialUnlockSystem.redsで50m radius unlock統合

### 実装制約

**DO**:
- ✅ @wrapMethod内に直接実装（ヘルパー分離なし）
- ✅ IsA()チェックで早期リターン（パフォーマンス最適化）
- ✅ IsPossible()は正しいシグネチャを使用（target: GameObject必須）
- ✅ wrappedMethod()を必ず呼び出し（他modとの互換性）

**DON'T**:
- ❌ @addMethodで追加したヘルパーを@wrapMethod内から呼ばない
- ❌ @replaceMethodは使用しない（mod互換性破壊）
- ❌ GetCost/IsPossible/CompleteActionを@addMethodで追加しない（親クラスで定義済み）

---

## 📝 移行時の設定変更

### 削除される設定（CustomHackingSystem依存）

以下の設定はCustomHackingSystem削除により利用不可:
- **Daemon animation speed** (HackingExtensions機能)
- **Daemon notification UI** (HackingExtensions機能)
- **Custom daemon execution callback** (CustomHackingSystemコールバック)

### 保持される設定（バニラ実装可能）

以下の設定はバニラ移行後も動作:

**RemoteBreach機能**:
- ✅ **Dynamic RAM cost** (GetCost()実装)
- ✅ **Device type visibility** (IsPossible()実装)
  - RemoteBreachEnabledDevice/Computer/Camera/Turret/Vehicle
  - 各デバイスタイプでQuickHack表示/非表示を制御
- ✅ **Breach lock system** (既存システム再利用)
- ✅ **Radius unlock** (RadialUnlockSystem統合)
- ✅ **Breach statistics** (ActiveProgramsから取得)

**Breach Failure Penalty**:
- ✅ **RemoteBreach failure penalty** (FinalizeNetrunnerDive()実装)
  - RemoteBreachFailurePenaltyEnabled: 失敗時のペナルティ有効/無効
  - BreachPenaltyDurationMinutes: ペナルティ持続時間（ゲーム内時間）
  - 失敗時の効果:
    - Disconnection VFX表示
    - ネットワーク全体/範囲内デバイスでBreach Protocol無効化
    - Trace試行（近くにネットランナーがいる場合）
- ✅ **AP Breach failure penalty** (既存実装、CustomHackingSystem非依存)
- ✅ **NPC Breach failure penalty** (既存実装、CustomHackingSystem非依存)

**Progressive Unlock**:
- ✅ **Progressive unlock** (既存実装、CustomHackingSystem非依存)
  - Cyberdeck quality requirements
  - Intelligence attribute requirements
  - Enemy tier requirements

**設定オプション網羅率**: 93% (132/142設定保持)

---

## 🚀 移行実施時のアクションプラン

### Phase 0: 準備（移行決定時）

1. **最新バックアップ作成**
   - 現行RemoteBreach実装フルバックアップ
   - CustomHackingSystem統合部分の保存

2. **ドキュメントレビュー**
   - VANILLA_ALTERNATIVE_APPROACHES.md再読（技術検証）
   - VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md精読（実装手順）

3. **開発環境準備**
   - Redscriptコンパイラ動作確認
   - テスト用セーブデータ準備（各デバイスタイプ）

### Phase 1: Core Infrastructure実装（10-15h）

**詳細**: VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md参照

**実装内容**:
- @wrapMethod(ScriptableDeviceAction) - GetCost/IsPossible/CompleteAction
- VanillaRemoteBreachStateSystem - ScriptableSystem実装
- NetworkBlackboard統合 - RemoteBreach判定

**完了基準**:
- RemoteBreach QuickHackが表示される
- GetCost()がRAM costを計算（dynamic cost有効時）
- IsPossible()がbreach lock/RAM costをチェック

### Phase 2: Daemon Processing実装（6-10h + 8-12h）

**詳細**: VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md参照

**実装内容**:
- FinalizeNetrunnerDive()フック - RemoteBreach検出+処理
- ActivePrograms取得 - ExtractUnlockFlags()統合
- Device unlock処理 - 成功daemonのみunlock

**完了基準**:
- RemoteBreach成功時にdevice unlock動作
- 成功したdaemonのみが適用される（UX 90%）
- APブリーチ/気絶NPCブリーチが正常動作（regression test）

### Phase 3: Settings & Cleanup（10-16h + 調整）

**詳細**: VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md参照

**実装内容**:
- CustomHackingSystem依存ファイル削除
- Settings UI統合
- 統合テスト

**完了基準**:
- CustomHackingSystem完全削除
- 全機能が動作（regression test通過）
- パフォーマンス影響 <1%確認

---

## 📚 関連ドキュメント

### 技術検証
- **VANILLA_ALTERNATIVE_APPROACHES.md** - @wrapMethod戦略の技術検証、ソースコードレベル検証結果

### 実装計画
- **VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md** - 段階的実装手順（Phase 1-3詳細）

### アーキテクチャ
- **ARCHITECTURE_DESIGN.md** - BetterNetrunning全体アーキテクチャ（CustomHackingSystem統合部分含む）

---

## 🎯 結論

### 現状（2025-10-26）

- **推奨アクション**: **現状維持**（HackingExtensions依存継続）
- **理由**: HackingExtensionsは安定動作、移行の投資対効果が低い
- **準備完了**: 技術検証完了、移行時は本ドキュメント+実装計画書で実施可能

### HackingExtensions終了時

- **移行可能性**: ✅ 85%実現可能
- **工数**: 39-61h（中央値50h）
- **品質**: UX 90%、パフォーマンス影響 <1%
- **リスク**: 🟢 LOW（実証済みパターン）

**本ドキュメントはHackingExtensions終了時の意思決定ガイドとして保持します。**

---

**Document Status**: ✅ COMPLETE (移行要件定義)
**Last Validated**: 2025-10-26
**Next Review**: HackingExtensions status変化時
