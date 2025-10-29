# 仕様変更実現可能性評価

## 概要

SPECIFICATION_CHANGES_ANALYSIS.md で特定された8項目の仕様変更について、バニラRemoteBreach移行後での実現可能性と妥当性を評価します。

---

## 評価結果サマリー

| # | 仕様 | 実現可能性 | 妥当性 | 推奨アクション | 理由 |
|---|------|-----------|-------|--------------|------|
| 1 | アンロック期限 | ✅ 高 | ⚠️ 要検討 | 復元 | ユーザー影響大、実装容易 |
| 2 | JackIn自動復元 | ✅ 高 | ✅ 高 | 復元 | 既存コード流用可能 |
| 3 | 可視性制御 | ✅ 高 | ❌ 低 | 新仕様維持 | 中央集約メリット小、分散が適切 |
| 4 | Daemonフィルタ | ✅ 高 | ✅ 高 | 動的フィルタ追加 | バニラ統合で正しい動作 |
| 5 | カスタムデーモン | ❌ 不可 | ✅ 高 | 新仕様維持 | HackingExtensions前提、移行目的と矛盾 |
| 6 | 成功コールバック | ✅ 高 | ⚠️ 要検討 | 段階的復元 | #9/#10に依存、単独復元不可 |
| 7 | 失敗コールバック | ✅ 高 | ✅ 高 | 復元 | 既存BreachLockUtils流用 |
| 9 | ネットワークアンロック | ✅ 高 | ✅ 高 | 復元 | コア機能、優先度最高 |
| 10 | 統計収集 | ✅ 高 | ⚠️ 要検討 | 復元（開発時） | デバッグ支援、本番不要 |

---

## 詳細評価

### #1: アンロック期限（一時的 → 永続）

**旧仕様**:
- 10時間（36,000秒）でアンロック期限切れ
- 期限切れ時にタイムスタンプ自動リセット → 再ブリーチ可能
- UnlockExpirationUtils.reds (240行)

**新仕様**:
- 永続アンロック（期限なし）
- タイムスタンプ設定のみ、期限チェックなし

**実現可能性**: ✅ **高（既存実装あり）**

**実装方法**:
```redscript
// ✅ 既存実装: ProgramFilteringRules.reds (lines 66-192)
public func ShouldRemoveBreachedPrograms(actionID: TweakDBID, entity: wref<GameObject>) -> Bool {
  // 期限チェック: QuickhackUnlockDurationHours() (デフォルト: 6時間)
  let unlockDurationHours: Int32 = BetterNetrunningSettings.QuickhackUnlockDurationHours();
  // 0 = 永続アンロック, >0 = 一時的アンロック（期限切れ後リセット）
}

private func HandleTemporaryUnlock(...) -> Bool {
  if elapsedTime > durationSeconds {
    ResetDeviceTimestamp(sharedPS, daemonType);  // タイムスタンプリセット
    return false;  // 期限切れ - プログラム表示（再ブリーチ可能）
  }
  return true;  // まだ有効 - プログラム削除
}

// 呼び出し元: betterNetrunning.reds:119 (FilterPlayerPrograms @wrapMethod)
if ShouldRemoveBreachedPrograms(Deref(programs)[i].actionID, this.m_entity as GameObject) {
  // プログラム削除（既ブリーチデバイスには表示しない）
}
```

**既存実装との統合**:
- **AccessPointブリーチ**: `FilterPlayerPrograms()` で期限チェック実装済み ✅
- **RemoteBreachブリーチ**: ❌ **現在未適用**（バニラMinigameSystemに統合後も未実装）
- **統合ポイント**: RemoteBreachにも `FilterPlayerPrograms()` が自動適用されるため、**追加実装不要**（バニラ統合で自動解決）

**妥当性**: ⚠️ **要検討（ユーザー影響あり）**

**懸念点**:
1. **リプレイ性**: 永続アンロック = ミニゲーム1回限り（スキルチェック機会喪失）
2. **ゲームバランス**: 期限なし = ネットワーク永久制圧（挑戦性低下）
3. **AccessPoint統合**: AccessPointは期限あり、RemoteBreachは永続 → 一貫性欠如

**推奨アクション**: **既に実装済み（確認のみ）**
- 理由: バニラRemoteBreach移行後も期限チェック実装は維持されている
- 現状: AccessPointブリーチで機能中、RemoteBreachはバニラ統合後に自動適用
- 工数: 0時間（**追加実装不要、動作確認のみ**）

---

### #2: JackIn自動復元

**旧仕様**:
- アンロック期限切れ時に `ActionSetDeviceON()` で自動復元
- DeviceInteractionUtils.reds (92行)

**新仕様**:
- 自動復元なし（AccessPoint永久無効）

**実現可能性**: ✅ **高（既存コード流用可能）**

**実装方法**:
```redscript
// ✅ 既存実装: BreachLockUtils.DisableJackInInteraction()
// BreachLockUtils.reds:173 - JackIn無効化（BreachPenaltySystem.reds:423で使用中）
public static func DisableJackInInteraction(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
  let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
  if IsDefined(masterController) {
    masterController.SetHasPersonalLinkSlot(false);  // JackIn無効化
  }
}

// ❌ 削除実装: EnableJackInInteractionForAccessPoint()
// 旧実装: DeviceInteractionUtils.EnableJackInInteractionForAccessPoint()
// 理由: DeviceInteractionUtils.reds 自体が削除されている

// ✅ 実装方法: HandleTemporaryUnlock() に統合（既存実装活用）
private func HandleTemporaryUnlock(...) -> Bool {
  if elapsedTime > durationSeconds {
    ResetDeviceTimestamp(sharedPS, daemonType);  // ✅ 既存実装（ProgramFilteringRules.reds:178）
    BreachLockUtils.EnableJackInInteraction(sharedPS);  // ← 新規呼び出し追加
    return false;
  }
  return true;
}

// ✅ 推奨実装: DRY準拠の統合実装
public static func SetJackInInteractionState(
  devicePS: ref<ScriptableDeviceComponentPS>,
  enabled: Bool
) -> Void {
  let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
  if !IsDefined(masterController) { return; }
  masterController.SetHasPersonalLinkSlot(enabled);
}

// 後方互換性ラッパー
public static func DisableJackInInteraction(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
  SetJackInInteractionState(devicePS, false);
}

public static func EnableJackInInteraction(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
  SetJackInInteractionState(devicePS, true);
}
```

**妥当性**: ✅ **高（QoL向上）**

**メリット**:
- ユーザー体験改善（再試行可能）
- 一時的アンロックとの統合（期限切れ = リセット）

**推奨アクション**: **復元**
- 理由: 実装容易、ユーザー価値高い、DRY準拠の統合実装
- 工数: 1-2時間（SetJackInInteractionState統合実装 + HandleTemporaryUnlock統合）
- 実装箇所: BreachLockUtils.reds（DRY準拠リファクタリング） + ProgramFilteringRules.reds
- DRY準拠: 既存DisableJackInInteraction()と95%重複排除、統合メソッド+ラッパーパターン

---

### #3: 可視性制御（中央集約 → 分散）

**旧仕様**:
- 中央集約（RemoteBreachVisibility.reds: 318行）
- Defense-in-Depth（事前チェック + 事後削除）
- 期限管理 + JackIn復元統合

**新仕様**:
- 分散実装（Computer/Device/Vehicle別 - 3ファイル）
- 事前チェックのみ
- 期限管理なし

**実現可能性**: ✅ **高（新仕様の修正）**

**実装比較**:

| 観点 | 旧仕様（中央集約） | 新仕様（分散） |
|------|-----------------|--------------|
| **実装場所** | 1ファイル | 3ファイル |
| **修正コスト** | 1箇所 | 3箇所（コピペ同期必須） |
| **拡張性** | 1メソッド追加 | 3メソッド追加 |
| **コード重複** | なし | 高（StateSystem取得ロジック3回） |
| **責任分離** | RemoteBreachVisibility | 各Actionクラス |

**妥当性**: ❌ **低（分散が適切）**

**分散実装が適切な理由**:
1. **BaseScriptableAction拡張不可**: RemoteBreach = バニラクラス（メソッドなし）
2. **@wrapMethod必須**: ScriptableDeviceAction.GetQuickHackActions() で個別実装
3. **StateSystem差異**: Computer/Device/Vehicle で異なるStateSystem使用
4. **責任所在明確**: 各Action種別が自身の可視性制御を担当

**既存パターン確認**:
```redscript
// RemoteBreachActions.reds - バニラ拡張パターン
@wrapMethod(ScriptableDeviceAction)
public func IsPossible(...) -> Bool {
  if !this.IsA(n"RemoteBreach") { return wrappedMethod(...); }
  // RemoteBreach専用ロジック
}
```

**推奨アクション**: **新仕様維持**
- 理由: バニラ統合では分散実装が自然、中央集約のメリット小
- 代替案: 共通ロジックをUtilsクラスに抽出（コード重複削減）

---

### #4: Daemonフィルタ（静的 → 動的）

**旧仕様**:
- 静的デーモンリスト（CET Lua: remoteBreach.lua）
- Computer = Basic + Camera
- Device = Device-specific（Camera/Turret/Generic）
- Vehicle = Basic only

**新仕様**:
- 動的フィルタリング（バニラ `FilterPlayerPrograms()`）
- ネットワーク構成に基づくデーモン決定
- ProgramFiltering.reds (442行) - 既存実装

**実現可能性**: ✅ **高（既存フィルタリング統合）**

**ユーザー指摘の正確性**: ✅ **正しい**

> 基本的にはAPブリーチ/気絶NPCブリーチのフィルタリングが流用でき、リモートブリーチ時に対象毎のフィルタリングを新たに追加するだけでいい認識だが合っているか

**既存フィルタリングロジック**:
```redscript
// ProgramFilteringRules.reds - AccessPoint/UnconsciousNPC用実装
public func ShouldRemoveBreachedPrograms(...)  // 既ブリーチ除外
public func ShouldRemoveDeviceBackdoorPrograms(...)  // デバイス別除外
public func ShouldRemoveDeviceTypePrograms(...)  // デバイスタイプ可用性
public func ShouldRemoveAccessPointPrograms(...)  // AP制限

// 呼び出し元: ProgramFilteringCore.reds
@wrapMethod(MinigameGenerationRuleScalingPrograms)
protected func FilterPlayerPrograms(...) {
  // 各フィルタを順次適用
}
```

**RemoteBreach統合が必要な理由**:

現在の問題:
```redscript
// ProgramFilteringCore.reds:35-36
// CRITICAL LIMITATION - CustomHackingSystem RemoteBreach:
//   - CustomHackingSystem.StartNewHackInstance() bypasses FilterPlayerPrograms()
```

**旧RemoteBreachの動作**:
- CustomHackingSystem使用 → `FilterPlayerPrograms()` バイパス
- デーモンリスト = CET Luaで静的定義

**新RemoteBreachの期待動作**:
- バニラMinigameSystem使用 → `FilterPlayerPrograms()` 自動適用
- デーモンリスト = ネットワーク構成から動的生成

**必要な追加実装**:
```redscript
// ProgramFilteringRules.reds - RemoteBreach専用フィルタ追加
public func ShouldRemoveRemoteBreachPrograms(
  actionID: TweakDBID,
  targetType: String,  // "Computer" | "Device" | "Vehicle"
  devicePS: ref<ScriptableDeviceComponentPS>
) -> Bool {
  // Computer: Basic + Camera を許可
  if Equals(targetType, "Computer") {
    return !(actionID == PROGRAM_UNLOCK_QUICKHACKS()
          || actionID == PROGRAM_UNLOCK_CAMERA_QUICKHACKS());
  }

  // Device - Camera: Basic + Camera
  if DaemonFilterUtils.IsCamera(devicePS) {
    return !(actionID == PROGRAM_UNLOCK_QUICKHACKS()
          || actionID == PROGRAM_UNLOCK_CAMERA_QUICKHACKS());
  }

  // Device - Turret: Basic + Turret
  if DaemonFilterUtils.IsTurret(devicePS) {
    return !(actionID == PROGRAM_UNLOCK_QUICKHACKS()
          || actionID == PROGRAM_UNLOCK_TURRET_QUICKHACKS());
  }

  // Device - Generic: Basic only
  // Vehicle: Basic only
  return actionID != PROGRAM_UNLOCK_QUICKHACKS();
}
```

**妥当性**: ✅ **高（バニラ統合で正しい動作）**

**メリット**:
- ネットワーク構成反映（実際のデバイス数に基づく）
- バニラパイプライン統合（mod互換性向上）
- CET依存削減（Redscriptのみで完結）

**推奨アクション**: **動的フィルタ追加**
- 理由: バニラ統合の自然な帰結、ユーザー指摘通り
- 工数: 2-3時間（RemoteBreach専用フィルタ実装）

---

### #5: カスタムデーモン（4種類 → バニラのみ）

**旧仕様**:
- カスタムデーモン4種類（Basic/Camera/Turret/NPC）
- RemoteBreachProgram.reds (213行)
- HackingExtensions.Programs.HackProgramAction 継承

**新仕様**:
- バニラデーモンのみ
- カスタムデーモンクラスなし

**実現可能性**: ❌ **不可（HackingExtensions前提）**

**ユーザー指摘の正確性**: ✅ **完全に正しい**

> カスタムデーモンを導入した経緯は、そもそもHackingExtensionsがバニラデーモンをサポートしていなかったから。移行後はバニラRemoteBreachになったことにより、不要になった認識だが合っているか

**技術的背景**:

**HackingExtensions制約**:
```redscript
// 旧実装: RemoteBreachProgram.reds
public class DeviceDaemonAction extends HackProgramAction {
  // HackingExtensions.Programs.HackProgramAction 継承必須
  // バニラMinigameProgramアクションはサポートされず
}
```

**HackingExtensionsアーキテクチャ**:
- CustomHackingSystem = 独自ミニゲームエンジン
- HackProgramAction = カスタムデーモン基底クラス
- バニラMinigameProgramとの互換性なし

**バニラRemoteBreach統合**:
```redscript
// 新実装: バニラMinigameSystem使用
// RemoteBreach (vanilla action) → vanilla MinigameSystem → vanilla programs
// カスタムデーモン不要（バニラデーモンをそのまま使用）
```

**妥当性**: ✅ **高（移行目的そのもの）**

**復元が不適切な理由**:
1. **移行目的と矛盾**: HackingExtensions依存削除が移行目的
2. **アーキテクチャ不一致**: バニラMinigameSystemはHackProgramAction非対応
3. **実装コスト**: CustomHackingSystem再導入が必要（移行の逆戻り）

**推奨アクション**: **新仕様維持**
- 理由: 移行目的と一致、バニラ統合の自然な帰結
- 代替案: なし（HackingExtensions必須のため）

---

### #6: 成功コールバック（統計収集 + ネットワークアンロック）

**旧仕様**:
- OnRemoteBreachSucceeded (191行)
- 統計収集 (#10)
- ボーナスデーモン実行
- ネットワークアンロック (#9)

**新仕様**:
- バニラ処理のみ（コールバックなし）

**実現可能性**: ✅ **高（AccessPointパターン流用）**

**実装方法**:
```redscript
// 既存パターン: BreachProcessing.reds (AccessPointブリーチ)
@wrapMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  // Pre-processing: 統計収集 + ボーナスデーモン
  let stats: ref<BreachSessionStats> = BreachSessionStats.Create("AccessPoint", ...);
  this.InjectBonusDaemons();

  // Base game processing
  wrappedMethod(devices);

  // Post-processing: ネットワークアンロック + 統計出力
  this.ApplyBetterNetrunningExtensionsWithStats(devices, unlockFlags, stats, ...);
  LogBreachSummary(stats);
}
```

**RemoteBreach統合パターン**:
```redscript
// RemoteBreachActions.reds に追加
@wrapMethod(ScriptableDeviceAction)
public func CompleteAction(gameInstance: GameInstance) -> Void {
  if !this.IsA(n"RemoteBreach") {
    wrappedMethod(gameInstance);
    return;
  }

  // Pre-processing: 統計収集
  let stats: ref<BreachSessionStats> = BreachSessionStats.Create("RemoteBreach", ...);
  let unlockFlags: BreachUnlockFlags = this.GetUnlockFlags();

  // Base game processing
  wrappedMethod(gameInstance);

  // Post-processing: ネットワークアンロック (#9) + 統計 (#10)
  this.ApplyRemoteBreachExtensions(unlockFlags, stats, gameInstance);
  LogBreachSummary(stats);
}
```

**妥当性**: ⚠️ **要検討（依存関係あり）**

**依存分析**:
- **#9に依存**: ネットワークアンロック実装が必須
- **#10に依存**: 統計収集クラスが必須
- **単独復元不可**: オーケストレーターのため、#9/#10なしでは空コールバック

**推奨アクション**: **段階的復元**
1. Phase 1: #9復元（ネットワークアンロック）
2. Phase 2: #10復元（統計収集）
3. Phase 3: #6復元（統合オーケストレーター）

- 理由: #9/#10が実装本体、#6は制御フロー
- 工数: 2-3時間（AccessPointパターン適用）

---

### #7: 失敗コールバック（VFX + スタン + ロック）

**旧仕様**:
- OnRemoteBreachFailed (53行)
- VFX表示
- プレイヤースタン
- RemoteBreachロック（10秒クールダウン）

**新仕様**:
- バニラ処理（限定的）

**実現可能性**: ✅ **高（既存BreachLockUtils流用）**

**実装方法**:
```redscript
// ✅ 既存実装: BreachLockUtils.reds:49
public static func IsDeviceLockedByRemoteBreachFailure(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
  return RemoteBreachLockSystem.IsRemoteBreachLockedByTimestamp(devicePS, devicePS.GetGameInstance());
}
// 使用箇所: DeviceQuickhackFilters.reds:59, DeviceProgressiveUnlock.reds:181

// ✅ 既存実装: RemoteBreachLockSystem.reds (タイムスタンプ管理)
// BreachPenaltySystem.reds (失敗ペナルティ適用)

// ❌ 未実装: バニラMinigameController統合
// 旧実装: OnRemoteBreachFailed.Execute() (RemoteBreachHelpers.reds:872)
//   - FinalizeNetrunnerDive(HackingMinigameState.Failed) 呼び出し
//   - BreachPenaltySystem経由でペナルティ適用

// ✅ 実装方法: FinalizeNetrunnerDive @wrapMethod
// BreachPenaltySystem.reds にRemoteBreach検出ロジック追加
@wrapMethod(AccessPointControllerPS)
protected cb func FinalizeNetrunnerDive(minigameResult: HackingMinigameState) -> Void {
  wrappedMethod(minigameResult);

  // RemoteBreachStateSystem から RemoteBreach判定
  let stateSystem: ref<RemoteBreachStateSystem> = ...;
  if stateSystem.HasPendingRemoteBreach() {
    if Equals(minigameResult, HackingMinigameState.Failed) {
      this.ApplyRemoteBreachFailurePenalty();  // 失敗ペナルティ
    }
  }
}
```

**妥当性**: ✅ **高（ゲームバランス維持）**

**メリット**:
- スパム防止（クールダウン）
- 失敗ペナルティ（スキルチェック意味づけ）
- 既存実装流用（BreachLockUtils）

**推奨アクション**: **復元**
- 理由: 既存コード流用可能、ゲームバランス重要
- 工数: 2-3時間（FinalizeNetrunnerDive統合 + RemoteBreach判定）
- 実装箇所: BreachPenaltySystem.reds (FinalizeNetrunnerDive @wrapMethod追加)

---

### #9: ネットワークアンロック（4段階 → バニラのみ）

**旧仕様**:
- DaemonUnlockStrategy.reds (372行)
- 4段階アンロック:
  1. Radius unlock（50m範囲内デバイス + 車両）
  2. Network unlock（AccessPoint配下デバイス）
  3. NPC unlock（50m範囲内NPC）
  4. Position記録（RadialUnlockSystem統合）

**新仕様**:
- バニラデフォルト（AccessPoint配下のみ）

**実現可能性**: ✅ **高（独立実装、依存なし）**

**実装方法**:
```redscript
// ✅ 既存実装: DeviceUnlockUtils.reds
public static func UnlockDevicesInRadius(...)  // Line 189 - Radius unlock
public static func UnlockVehiclesInRadius(...)  // Line 252 - Vehicle unlock
public static func UnlockNPCsInRadius(...)  // Line 90 - NPC unlock
public static func RecordBreachPosition(...)  // Line 835,849 - Position記録

// ❌ 削除実装: DaemonUnlockStrategy.reds (372行)
// 旧実装: ComputerUnlockStrategy, DeviceUnlockStrategy, VehicleUnlockStrategy
// Strategy Patternで3ターゲット別実装 → 現在なし

// ✅ AccessPoint実装パターン流用
// BreachProcessing.reds:ApplyBetterNetrunningExtensionsWithStats() (line 163)
private final func ApplyBetterNetrunningExtensionsWithStats(...) -> Void {
  // Step 1.5: Radius unlock
  this.UnlockStandaloneDevicesInBreachRadius(unlockFlags, stats);
    ↓ 内部で DeviceUnlockUtils.UnlockDevicesInRadius() 呼び出し
    ↓ 内部で DeviceUnlockUtils.UnlockVehiclesInRadius() 呼び出し
    ↓ 内部で DeviceUnlockUtils.UnlockNPCsInRadius() 呼び出し

  // Step 2: Network unlock
  this.ApplyBreachUnlockToDevicesWithStats(devices, unlockFlags, stats);

  // Step 3: Position記録
  this.RecordNetworkBreachPosition(devices);
    ↓ Line 650で DeviceUnlockUtils.RecordBreachPosition() 呼び出し
}

// ✅ RemoteBreach統合パターン（DRY準拠 - 共通ユーティリティ活用）
@wrapMethod(ScriptableDeviceAction)
public func CompleteAction(gameInstance: GameInstance) -> Void {
  if !this.IsA(n"RemoteBreach") { wrappedMethod(gameInstance); return; }

  wrappedMethod(gameInstance);  // バニラ処理

  // RemoteBreach extensions
  this.ApplyRemoteBreachExtensions(gameInstance);  // ← 新規実装
}

@addMethod(ScriptableDeviceAction)
private func ApplyRemoteBreachExtensions(gameInstance: GameInstance) -> Void {
  let devicePS: ref<ScriptableDeviceComponentPS> = this.GetOwnerPS(gameInstance);
  let unlockFlags: BreachUnlockFlags = this.GetUnlockFlags(gameInstance);
  let stats: ref<BreachSessionStats>;

  // 統計収集有効時のみ初期化
  if BetterNetrunningSettings.EnableBreachStatistics() {
    stats = BreachSessionStats.Create("RemoteBreach", devicePS, gameInstance);
  }

  // ✅ DRY準拠: AccessPointと共通化されたブリーチ拡張処理
  // Core/BreachExtensionUtils.reds で実装（Radius/NPC unlock + Position記録）
  BreachExtensionUtils.ApplyBreachExtensions(devicePS, unlockFlags, stats, gameInstance);

  // RemoteBreach固有: Network unlock（RefreshSlavesで遅延実行）
  // 実装不要 - RemoteBreachStateSystemが自動処理

  // 統計ログ出力
  if IsDefined(stats) {
    LogBreachSummary(stats);
  }
}
```
public func CompleteAction(gameInstance: GameInstance) -> Void {
  if !this.IsA(n"RemoteBreach") { wrappedMethod(gameInstance); return; }

  wrappedMethod(gameInstance);  // バニラ処理

  // RemoteBreach extensions
  this.ApplyRemoteBreachExtensions(gameInstance);  // ← 新規実装
}

@addMethod(ScriptableDeviceAction)
private func ApplyRemoteBreachExtensions(gameInstance: GameInstance) -> Void {
  let devicePS: ref<ScriptableDeviceComponentPS> = this.GetOwnerPS(gameInstance);
  let unlockFlags: BreachUnlockFlags = this.GetUnlockFlags(gameInstance);

  // 1. Radius unlock
  if unlockFlags.unlockBasic {
    DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
    DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);
  }

  // 2. NPC unlock
  if unlockFlags.unlockNPCs {
    DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);
  }

  // 3. Network unlock (新規実装必要)
  this.UnlockNetworkDevicesForRemoteBreach(devicePS, unlockFlags, gameInstance);

  // 4. Position記録
  DeviceUnlockUtils.RecordBreachPosition(devicePS, gameInstance);
}
```

**妥当性**: ✅ **高（コア機能、優先度最高）**

**ユーザー影響**:
- Radius unlock喪失 = 50m範囲内デバイス手動ブリーチ必要
- NPC unlock喪失 = NPC QuickHack手動有効化必要
- Vehicle unlock喪失 = 車両制御不可

**推奨アクション**: **優先復元**
- 理由: 独立実装、ユーザー影響最大、DRY準拠の共通化実装
- 工数: 4-6時間（BreachExtensionUtils共通化 + CompleteAction統合）
- 実装箇所:
  - Core/BreachExtensionUtils.reds（新規 - AccessPoint/RemoteBreach共通処理）
  - RemoteBreachActions.reds（CompleteAction拡張）
  - BreachProcessing.reds（既存AccessPoint実装をリファクタリング）
- DRY準拠: Radius/NPC unlock + Position記録をBreachExtensionUtilsに集約（30行 → 5行呼び出し）

---

### #10: 統計収集（包括的 → なし）

**旧仕様**:
- BreachSessionStats (190行)
- BreachStatisticsCollector
- 5カテゴリ統計:
  1. ミニゲーム結果
  2. デーモン情報
  3. ネットワーク統計
  4. Radial unlock統計
  5. ログ出力

**新仕様**:
- 統計収集なし
- バニラデフォルトログのみ

**実現可能性**: ✅ **高（AccessPoint実装あり）**

**実装方法**:
```redscript
// ✅ 既存実装: BreachSessionLogger.reds (lines 1-398)
public class BreachSessionStats {
  let breachType: String;  // "AccessPoint", "RemoteBreach", "UnconsciousNPC"
  let breachTarget: String;
  let minigameSuccess: Bool;
  let programsInjected: Int32;
  let unlockBasic: Bool;
  let unlockCameras: Bool;
  let unlockTurrets: Bool;
  let unlockNPCs: Bool;
  let executedNormalDaemons: array<TweakDBID>;
  let executedSubnetDaemons: array<TweakDBID>;
  let networkDeviceCount: Int32;
  let devicesUnlocked: Int32;
  // ... (50+ fields)
}

public static func LogBreachSummary(stats: ref<BreachSessionStats>) -> Void {
  // 統合されたログ出力（既存実装）
}

// ✅ 既存実装: BreachStatisticsCollector.reds
public abstract class BreachStatisticsCollector {
  public static func CollectExecutedDaemons(...);
  public static func CollectNetworkDeviceStats(...);
  public static func CollectRadialUnlockStats(...);
}

// ✅ 使用箇所: BreachProcessing.reds (AccessPointブリーチ)
let stats: ref<BreachSessionStats> = BreachSessionStats.Create("AccessPoint", ...);
BreachStatisticsCollector.CollectExecutedDaemons(minigamePrograms, stats);
BreachStatisticsCollector.CollectRadialUnlockStats(this, unlockFlags, stats, gameInstance);
stats.Finalize();
LogBreachSummary(stats);

// ✅ RemoteBreach統合パターン
@addMethod(ScriptableDeviceAction)
private func ApplyRemoteBreachExtensions(gameInstance: GameInstance) -> Void {
  let stats: ref<BreachSessionStats> = BreachSessionStats.Create("RemoteBreach", ...);
  let unlockFlags: BreachUnlockFlags = this.GetUnlockFlags(gameInstance);

  // ... アンロック処理 ...

  // 統計収集
  BreachStatisticsCollector.CollectExecutedDaemons(..., stats);
  BreachStatisticsCollector.CollectRadialUnlockStats(..., stats, gameInstance);

  stats.Finalize();
  LogBreachSummary(stats);
}
```

**妥当性**: ⚠️ **要検討（開発支援 vs 本番不要）**

**メリット/デメリット**:

| 観点 | メリット | デメリット |
|------|---------|-----------|
| **開発時** | デバッグ容易、振る舞い検証 | - |
| **本番時** | - | ログ肥大化、パフォーマンス影響 |
| **トラブルシューティング** | 問題再現に有用 | - |

**推奨アクション**: **段階的復元**
- Phase 1（開発時）: RemoteBreachに統計収集統合
- Phase 2（本番）: 設定で無効化可能にする

- 理由: 開発・デバッグ支援に有用、本番では選択式
- 工数: 2-3時間（既存実装流用、RemoteBreach統合のみ）
- 実装箇所: RemoteBreachActions.reds (ApplyRemoteBreachExtensions内)

---

## 復元優先度マトリックス

### 高優先度（ユーザー影響大、実装容易）

| # | 仕様 | ユーザー影響 | 実装難易度 | 工数 | 依存 |
|---|------|------------|----------|------|------|
| **9** | ネットワークアンロック | ★★★★★ | 中 | 4-6h | なし |
| **2** | JackIn自動復元 | ★★★★☆ | 低 | 1h | #1 |
| **7** | 失敗コールバック | ★★★☆☆ | 低 | 2-3h | なし |
| **1** | アンロック期限 | ★★★☆☆ | 中 | 2-3h | なし |

### 中優先度（開発支援、段階的実装）

| # | 仕様 | ユーザー影響 | 実装難易度 | 工数 | 依存 |
|---|------|------------|----------|------|------|
| **4** | Daemonフィルタ | ★★☆☆☆ | 低 | 2-3h | なし |
| **6** | 成功コールバック | ★☆☆☆☆ | 中 | 2-3h | #9, #10 |
| **10** | 統計収集 | ★☆☆☆☆ | 低 | 3-4h | なし |

### 復元不要（新仕様が適切）

| # | 仕様 | 理由 |
|---|------|------|
| **3** | 可視性制御 | 分散実装がバニラ統合では自然 |
| **5** | カスタムデーモン | HackingExtensions前提、移行目的と矛盾 |

---

## 推奨実装順序

### Phase 1: コア機能復元（5-8時間）

1. **#9: ネットワークアンロック**（4-6h）
   - 独立実装、依存なし
   - ユーザー影響最大
   - DeviceUnlockUtils流用

2. **#2: JackIn自動復元**（1-2h）
   - EnableJackInInteraction実装
   - HandleTemporaryUnlock統合

**#1は既に実装済み**（確認のみ、0h）

### Phase 2: ペナルティシステム（2-3時間）

4. **#7: 失敗コールバック**（2-3h）
   - ゲームバランス維持
   - BreachLockUtils流用

### Phase 3: フィルタリング改善（2-3時間）

5. **#4: Daemonフィルタ**（2-3h）
   - バニラ統合完成
   - ProgramFilteringRules拡張

### Phase 4: 開発支援（4-6時間、オプション）

6. **#10: 統計収集**（2-3h）
   - デバッグ支援
   - 既存実装流用
   - 設定で無効化可能

7. **#6: 成功コールバック**（2-3h）
   - #9/#10統合
   - オーケストレーター

---

## 総工数見積もり

| フェーズ | 内容 | 工数 | 必須度 |
|---------|------|------|--------|
| Phase 1 | コア機能復元 | 5-8h | ✅ 必須 |
| Phase 2 | ペナルティシステム | 2-3h | ✅ 必須 |
| Phase 3 | フィルタリング改善 | 2-3h | ⚠️ 推奨 |
| Phase 4 | 開発支援 | 4-6h | ❌ オプション |
| **合計** | | **9-14h** (必須) | |
| **合計** | | **15-23h** (フル) | |

---

## 結論

### ユーザー指摘への回答

**Q: 1,2,6,7,9,10の旧仕様復元は可能か？**
- **A**: ✅ すべて実現可能（#1は既に実装済み）。既存コード流用で工数9-14時間。

**Q: 3は旧新どちらが好ましい？**
- **A**: 新仕様（分散実装）が適切。バニラ統合では中央集約のメリットなし。

**Q: 4の静的 → 動的は、APブリーチのフィルタリング流用 + 対象毎追加で実装可能か？**
- **A**: ✅ 完全に正しい。ProgramFilteringRules.redsにRemoteBreach専用フィルタ追加のみ。

**Q: 5のカスタムデーモンは、HackingExtensions非対応が理由で移行後は不要か？**
- **A**: ✅ 完全に正しい。移行目的そのもの、復元は移行の逆戻り。

### 最終推奨

**必須復元** (Phase 1-2):
- #9: ネットワークアンロック
- #1: アンロック期限
- #2: JackIn自動復元
- #7: 失敗コールバック

**推奨復元** (Phase 3):
- #4: Daemonフィルタ

**オプション復元** (Phase 4):
- #10: 統計収集（開発時のみ）
- #6: 成功コールバック（#9/#10実装後）

**復元不要**:
- #3: 可視性制御（新仕様維持）
- #5: カスタムデーモン（新仕様維持）

**合計工数**: 9-14時間（必須）、15-23時間（フル）

**重要な発見**:
- **#1 (アンロック期限)**: 既に実装済み（ProgramFilteringRules.reds）、バニラRemoteBreach移行後も維持
- **#2 (JackIn復元)**: EnableJackInInteraction実装のみ必要（1-2h）
- **#7 (失敗コールバック)**: FinalizeNetrunnerDive統合パターン（AccessPoint同様）
- **#9 (ネットワークアンロック)**: DeviceUnlockUtils既存実装流用、Network unlock部分のみ新規
- **#10 (統計収集)**: BreachSessionStats/BreachStatisticsCollector既存実装流用
