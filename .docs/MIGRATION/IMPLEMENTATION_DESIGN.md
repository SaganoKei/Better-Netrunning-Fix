# バニラRemoteBreach機能復元 - 実装詳細設計書

**作成日**: 2025-10-26
**バージョン**: 1.0
**対象**: SPECIFICATION_FEASIBILITY_ANALYSIS.md Phase 1-4 実装

---

## 目次

1. [概要](#概要)
2. [設計原則とDRY準拠](#設計原則とdry準拠)
3. [ファイル構成](#ファイル構成)
4. [Phase 1: コア機能復元](#phase-1-コア機能復元)
5. [Phase 2: ペナルティシステム](#phase-2-ペナルティシステム)
6. [Phase 3: フィルタリング改善](#phase-3-フィルタリング改善)
7. [Phase 4: 開発支援（オプション）](#phase-4-開発支援オプション)
8. [テスト計画](#テスト計画)
9. [ロールバック計画](#ロールバック計画)

---

## 概要

### 目的

バニラRemoteBreach移行で削除された機能を、DRY原則に準拠して復元します。

### スコープ

| フェーズ | 機能 | 優先度 | 工数 |
|---------|------|--------|------|
| Phase 1 | #2 JackIn自動復元, #9 ネットワークアンロック | ✅ 必須 | 5-8h |
| Phase 2 | #7 失敗コールバック | ✅ 必須 | 2-3h |
| Phase 3 | #4 Daemonフィルタ | ⚠️ 推奨 | 2-3h |
| Phase 4 | #10 統計収集, #6 成功コールバック | ❌ オプション | 4-6h |

### 制約条件

1. **DRY原則厳守**: 重複実装禁止、共通ロジックは必ずユーティリティに抽出
2. **Mod互換性維持**: `@wrapMethod`優先、`@replaceMethod`回避
3. **REDscript制約**: `continue`不可、`ArraySize()`必須、CRLF改行+UTF-8 without BOM
4. **既存コード保護**: 既存メソッドは後方互換性維持（ラッパー化）

---

## 設計原則とDRY準拠

### DRY原則適用箇所

#### 1. JackIn状態管理の統合

**❌ Anti-pattern（違反）**:
```redscript
// DisableJackInInteraction() - 15行
public static func DisableJackInInteraction(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
  let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
  if !IsDefined(masterController) { return; }
  masterController.SetHasPersonalLinkSlot(false);
}

// EnableJackInInteraction() - 15行（95%重複）
public static func EnableJackInInteraction(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
  let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
  if !IsDefined(masterController) { return; }
  masterController.SetHasPersonalLinkSlot(true);  // ← 唯一の違い
}
```

**✅ DRY準拠設計（現行実装）**:
```redscript
// 統合実装（共通ロジック1箇所）- Utils/BreachLockUtils.reds
public static func SetJackInInteractionState(
  devicePS: ref<ScriptableDeviceComponentPS>,
  enabled: Bool
) -> Void {
  if !IsDefined(devicePS) {
    BNError("BreachLockUtils", "SetJackInInteractionState - devicePS is null");
    return;
  }

  let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
  if !IsDefined(masterController) {
    BNDebug("BreachLockUtils", "SetJackInInteractionState - devicePS is not MasterControllerPS");
    return;
  }

  masterController.SetHasPersonalLinkSlot(enabled);
  BNDebug("BreachLockUtils",
    "JackIn interaction " + (enabled ? "enabled" : "disabled") +
    " for device: " + ToString(masterController.GetID()));
}
```

**仕様変更（2025-10-26）**:
- ❌ **削除**: DisableJackInInteraction/EnableJackInInteraction ラッパーメソッド
- ✅ **理由**: 既存コードで一切使用されていないため後方互換性不要
- ✅ **採用**: 直接 `SetJackInInteractionState(devicePS, true/false)` 呼び出しに統一

**効果**:
- コード削減: 30行（旧計画）→ 20行（現行実装）= 33%削減
- メンテナンス: 1箇所のみ修正でOK
- テスト: 統合実装1箇所のみテスト
- API簡素化: ラッパー不要、Boolean引数で制御

---

#### 2. ブリーチ拡張処理の共通化

**❌ Anti-pattern（違反）**:
```redscript
// AccessPoint実装 - BreachProcessing.reds (30行)
private final func ApplyBetterNetrunningExtensionsWithStats(...) -> Void {
  // Step 1: Radius unlock
  if unlockFlags.unlockBasic {
    DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
    DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);
  }

  // Step 2: NPC unlock
  if unlockFlags.unlockNPCs {
    DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);
  }

  // Step 3: Position tracking
  DeviceUnlockUtils.RecordBreachPosition(devicePS, gameInstance);
}

// RemoteBreach実装 - RemoteBreachActions.reds (30行、完全重複）
private func ApplyRemoteBreachExtensions(gameInstance: GameInstance) -> Void {
  // Step 1: Radius unlock（同一コード）
  if unlockFlags.unlockBasic {
    DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
    DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);
  }

  // Step 2: NPC unlock（同一コード）
  if unlockFlags.unlockNPCs {
    DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);
  }

  // Step 3: Position tracking（同一コード）
  DeviceUnlockUtils.RecordBreachPosition(devicePS, gameInstance);
}
```

**✅ DRY準拠設計**:
```redscript
// Breach/BreachHelpers.reds（既存ファイルに統合）- 共通実装

// Section 3: Breach Extension Processing (新規追加)
/**
 * Apply full breach extensions (Radius + NPC + Position tracking)
 *
 * SHARED BY:
 * - AccessPoint breach (BreachProcessing.reds)
 * - RemoteBreach (RemoteBreachActions.reds)
 * - UnconsciousNPC breach (NPCBreachExperience.reds)
   *
   * @param devicePS - Target device (AccessPoint/Computer/Device/Vehicle/NPC)
   * @param unlockFlags - Unlock configuration (unlockBasic/unlockNPCs/etc.)
   * @param stats - Optional statistics collection (null if disabled)
   * @param gameInstance - Game instance reference
   */
  public static func ApplyBreachExtensions(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockFlags: BreachUnlockFlags,
    stats: ref<BreachSessionStats>,  // Optional: null for no stats
    gameInstance: GameInstance
  ) -> Void {
    // Step 1: Radius unlock (devices + vehicles)
    if unlockFlags.unlockBasic {
      DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
      DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);

      // Optional statistics collection
      if IsDefined(stats) {
        BreachStatisticsCollector.CollectRadialUnlockStats(devicePS, stats, gameInstance);
      }
    }

    // Step 2: NPC unlock
    if unlockFlags.unlockNPCs {
      DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);

      if IsDefined(stats) {
        BreachStatisticsCollector.CollectNPCUnlockStats(devicePS, stats, gameInstance);
      }
    }

    // Step 3: Position tracking (RadialUnlockSystem integration)
    DeviceUnlockUtils.RecordBreachPosition(devicePS, gameInstance);
  }
}

// AccessPoint実装（リファクタリング）- BreachProcessing.reds (5行)
private final func ApplyBetterNetrunningExtensionsWithStats(...) -> Void {
  // Use shared helper from BreachHelpers
  BreachHelpers.ApplyBreachExtensions(this, unlockFlags, stats, gameInstance);

  // AccessPoint-specific: Network unlock
  this.ApplyBreachUnlockToDevicesWithStats(devices, unlockFlags, stats);
}

// RemoteBreach実装（新規）- RemoteBreachActions.reds (5行)
private func ApplyRemoteBreachExtensions(gameInstance: GameInstance) -> Void {
  let devicePS: ref<ScriptableDeviceComponentPS> = this.GetOwnerPS(gameInstance);
  let unlockFlags: BreachUnlockFlags = this.GetUnlockFlags(gameInstance);
  let stats: ref<BreachSessionStats> = this.CreateStatsIfEnabled(gameInstance);

  // Use shared helper from BreachHelpers (同じモジュール内)
  BreachHelpers.ApplyBreachExtensions(devicePS, unlockFlags, stats, gameInstance);

  // RemoteBreach-specific: Network unlock (deferred to RefreshSlaves)
  // No additional processing needed here
}
```

**効果**:
- コード削減: 60行（30×2箇所）→ 40行（35共通+5×2呼び出し）= 33%削減
- 再利用: AccessPoint/RemoteBreach/UnconsciousNPCで共通利用（3箇所）
- メンテナンス: アンロックロジック変更時に1箇所修正のみ
- テスト: AccessPointで既存検証済み → RemoteBreachはテスト不要

---

### 設計パターン適用

#### Template Method Pattern（テンプレートメソッドパターン）

**適用箇所**: BreachHelpers.ApplyBreachExtensions()

**配置先**: `Breach/BreachHelpers.reds` (既存ファイルに統合)

**統合理由**:
- BreachHelpers.reds = ブリーチ処理ヘルパー関数群（GetMainframe、CheckConnectedClassTypes等）
- ApplyBreachExtensions()も同じ抽象度のヘルパー関数
- 70行の小規模ユーティリティで新規ファイル作成は過剰
- 既存importで対応可能（`import BetterNetrunning.Breach.*`）

**構造**:
```
ApplyBreachExtensions()  // Template Method（共通フロー定義）
  ↓
  Step 1: Radius unlock (共通処理)
  Step 2: NPC unlock (共通処理)
  Step 3: Position tracking (共通処理)
  ↓
Caller-specific processing  // 各ブリーチタイプ固有処理
  - AccessPoint: Network unlock (配下デバイスアンロック)
  - RemoteBreach: Deferred unlock (RefreshSlavesで遅延実行)
  - UnconsciousNPC: NPC-specific unlock
```

**メリット**:
- 共通フローを1箇所で管理
- 固有処理は各クラスで実装（Single Responsibility Principle）
- 拡張容易（新しいブリーチタイプ追加時も共通処理は再利用）
- ファイル増殖防止（既存BreachHelpers.redsに統合）

---

#### Strategy Pattern（戦略パターン）回避

**検討したが不採用**: DaemonUnlockStrategyパターン（旧実装）

**理由**:
1. **過剰な抽象化**: 3ターゲット（Computer/Device/Vehicle）で抽象クラス+3実装クラス（372行）
2. **REDscript制約**: 抽象メソッド未実装でコンパイルエラー
3. **シンプルさ優先**: 条件分岐で十分（可読性高い）

**採用パターン**: Helper Class + Conditional Logic (BreachHelpers.redsに統合)
```redscript
// ✅ シンプルで保守容易（BreachHelpers.redsに追加）
public static func ApplyBreachExtensions(devicePS, unlockFlags, ...) -> Void {
  if unlockFlags.unlockBasic { /* ... */ }
  if unlockFlags.unlockNPCs { /* ... */ }
  // 条件分岐でシンプルに実装
}
```

---

## ファイル構成

### 新規作成ファイル

**なし** - 既存ファイルへの統合で対応（ファイル増殖防止）

### 修正対象ファイル

| ファイル | 修正内容 | 行数変更 | DRY効果 |
|---------|---------|---------|---------|
| **Breach/BreachHelpers.reds** | ApplyBreachExtensions追加（Section 3） | +70, -0 | 60行削減（再利用） |
| **Utils/BreachLockUtils.reds** | SetJackInInteractionState統合実装 | +10, -0 | 30行→10行（67%削減） |
| **Minigame/ProgramFilteringRules.reds** | EnableJackInInteraction呼び出し追加 | +1, -0 | 既存実装活用 |
| **RemoteBreach/RemoteBreachActions.reds** | CompleteAction @wrapMethod | +25, -0 | BreachHelpers活用 |
| **Breach/BreachProcessing.reds** | BreachHelpers呼び出しにリファクタリング | +5, -25 | 30行削減 |
| **Breach/BreachPenaltySystem.reds** | FinalizeNetrunnerDive @wrapMethod追加 | +35, -0 | RemoteBreach判定統合 |

**統合理由（BreachHelpers.reds選定根拠）**:
1. **Single Responsibility維持**: BreachHelpers = "ブリーチ処理ヘルパー関数群"（GetMainframe/CheckConnectedClassTypes/ApplyBreachExtensions）
2. **抽象度の一致**: GetMainframe()（階層探索）とApplyBreachExtensions()（拡張処理）は同レベルのヘルパー
3. **ファイル増殖防止**: 70行の小規模ユーティリティで新規ファイル作成は過剰（DEVELOPMENT_GUIDELINES.md準拠）
4. **import文簡潔化**: 既存 `import BetterNetrunning.Breach.*` で対応可能（3ファイルでimport追加不要）
5. **命名一貫性**: Core/*Utils（基盤層）、Utils/*Utils（ビジネスロジック）、Breach/*Helpers（ブリーチ処理）

---

## Phase 1: コア機能復元

### 実装1: JackIn自動復元（#2）

#### 実装状況: ✅ 完了（既存実装確認済み）

**実装箇所**:
- `Minigame/ProgramFilteringRules.reds` Lines 169-179
- `Utils/BreachLockUtils.reds` Lines 137-168（SetJackInInteractionState）

**実装内容**:
```redscript
// ProgramFilteringRules.reds Line 169
if elapsedTime > durationSeconds {
  ResetDeviceTimestamp(sharedPS, daemonType);
  let devicePS: ref<ScriptableDeviceComponentPS> = sharedPS as ScriptableDeviceComponentPS;
  let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;

  if IsDefined(masterController) {
    BreachLockUtils.SetJackInInteractionState(devicePS, true);
    BNDebug("ProgramFiltering", "Unlock expired for " + daemonType + " - JackIn restored");
  }
}
```

#### 目的
アンロック期限切れ時にJackInインタラクションを自動復元します。

#### 実装箇所

**1. Utils/BreachLockUtils.reds** - DRY準拠統合実装（✅ 実装済み）

```redscript
module BetterNetrunning.Utils
import BetterNetrunning.Core.*

/**
 * Set JackIn interaction state (unified implementation)
 *
 * PURPOSE:
 * - DRY compliance: Single implementation for Enable/Disable operations
 * - Reduces code duplication (67% reduction from original design)
 *
 * RATIONALE:
 * - Centralized JackIn state management with guard clauses
 * - Boolean parameter controls both enable and disable operations
 *
 * @param devicePS - Target device (must be MasterControllerPS)
 * @param enabled - true = Enable JackIn, false = Disable JackIn
 */
public static func SetJackInInteractionState(
  devicePS: ref<ScriptableDeviceComponentPS>,
  enabled: Bool
) -> Void {
  if !IsDefined(devicePS) {
    BNError("BreachLockUtils", "SetJackInInteractionState - devicePS is null");
    return;
  }

  let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
  if !IsDefined(masterController) {
    BNDebug("BreachLockUtils", "SetJackInInteractionState - devicePS is not MasterControllerPS");
    return;
  }

  masterController.SetHasPersonalLinkSlot(enabled);

  BNDebug("BreachLockUtils",
    "JackIn interaction " + (enabled ? "enabled" : "disabled") +
    " for device: " + ToString(masterController.GetID()));
}
```

**仕様変更（2025-10-26）**:
- ❌ **削除**: DisableJackInInteraction/EnableJackInInteraction ラッパーメソッド
- ✅ **理由**: 既存コードで一切使用されていないため後方互換性不要
- ✅ **採用**: 直接 `SetJackInInteractionState(devicePS, true/false)` 呼び出しに統一
- ✅ **実装状況**: BreachLockUtils.reds (lines 137-168) に実装完了

**2. Minigame/ProgramFilteringRules.reds** - 期限切れ時の自動復元（✅ 実装済み）

```redscript
// Line 168 付近（HandleTemporaryUnlock内）

if elapsedTime > durationSeconds {
  // Expired - reset timestamp and restore JackIn interaction
  ResetDeviceTimestamp(sharedPS, daemonType);
  let devicePS: ref<ScriptableDeviceComponentPS> = sharedPS as ScriptableDeviceComponentPS;
  BreachLockUtils.SetJackInInteractionState(devicePS, true);  // ← Auto-restore
  BNDebug("ProgramFiltering", "Unlock expired for " + daemonType + " - JackIn restored");
  return false; // Show program (allow re-breach)
}
```

**実装状況**: ProgramFilteringRules.reds (lines 169-175) に実装完了

#### テスト手順

1. **前提条件**:
   - `QuickhackUnlockDurationHours` = 0.1（6分）に設定
   - AccessPointをブリーチ成功

2. **期待動作**:
   - 6分経過前: RemoteBreachプログラム非表示
   - 6分経過後: RemoteBreachプログラム表示、JackIn再有効化
   - 再ブリーチ可能

3. **検証項目**:
   - [ ] タイムスタンプがリセットされる（0.0）
   - [ ] JackInインタラクション再表示
   - [ ] RemoteBreachプログラム再表示
   - [ ] ログ出力: "Unlock expired for Basic - JackIn restored"

#### 工数見積もり: 1-2時間
- 実装: 30分
- テスト: 30分
- ドキュメント: 30分

---

### 実装2: ネットワークアンロック（#9）

#### 実装状況: ✅ 完了（既存実装確認済み）

**実装箇所**:
- `Breach/BreachHelpers.reds` Lines 203-242（ExecuteRadiusUnlocks）
- `RemoteBreach/RemoteBreachActions.reds` Line 177（BreachHelpers呼び出し）

**実装内容**:
```redscript
// BreachHelpers.reds Line 203
public static func ExecuteRadiusUnlocks(
  devicePS: ref<ScriptableDeviceComponentPS>,
  unlockFlags: BreachUnlockFlags,
  stats: ref<BreachSessionStats>,
  gameInstance: GameInstance
) -> Void {
  // Step 1: Radius unlock (devices + vehicles)
  if unlockFlags.unlockBasic {
    DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
    DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);
    if IsDefined(stats) {
      BreachStatisticsCollector.CollectRadialUnlockStats(...);
    }
  }

  // Step 2: NPC unlock
  if unlockFlags.unlockNPCs {
    DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);
  }

  // Step 3: Position tracking
  DeviceUnlockUtils.RecordBreachPosition(devicePS, gameInstance);
}

// RemoteBreachActions.reds Line 177
BreachHelpers.ExecuteRadiusUnlocks(devicePS, unlockFlags, stats, gameInstance);
```

#### 目的
RemoteBreach成功時にRadius/Network/NPC unlockを適用します。

#### 実装箇所

**1. Breach/BreachHelpers.reds** - 既存ファイルに追加（✅ 実装済み）

**統合理由**:
- BreachHelpers.reds = ブリーチ処理ヘルパー関数群（現在242行）
- 既存機能: GetMainframe()（階層探索）、CheckConnectedClassTypes()（種別検出）
- ExecuteRadiusUnlocks()も同じ抽象度のヘルパー関数
- 70行の小規模ユーティリティで新規ファイル作成は過剰
- 統合後242行（適切なファイルサイズ）

```redscript
// Breach/BreachHelpers.reds - Section 3: Breach Extension Processing
// Lines 165-242 (実装完了)

public abstract class BreachHelpers {

  /**
   * Execute radius-based device/NPC unlocks after successful breach
   *
   * PURPOSE:
   * - DRY compliance: Eliminate 60 lines of duplicate code (33% reduction)
   * - Shared by AccessPoint/RemoteBreach/UnconsciousNPC breach types
   *
   * ARCHITECTURE:
   * - Template Method Pattern: Common flow in single method
   * - Caller-specific: Network unlock logic remains in each breach type
   *
   * DESIGN DECISION:
   * - Rejected Strategy Pattern: Over-engineering for 3 types
   * - Preferred Helper Class + Conditional Logic: Simpler, more maintainable
   */
  public static func ExecuteRadiusUnlocks(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockFlags: BreachUnlockFlags,
    stats: ref<BreachSessionStats>,
    gameInstance: GameInstance
  ) -> Void {
    // Guard clause
    if !IsDefined(devicePS) { return; }

    // Step 1: Radius unlock (devices + vehicles) with optional statistics
    if unlockFlags.unlockBasic {
      DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
      DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);

      if IsDefined(stats) {
        BreachStatisticsCollector.CollectRadialUnlockStats(
          devicePS, unlockFlags, stats, gameInstance
        );
      }
    }

    // Step 2: NPC unlock
    if unlockFlags.unlockNPCs {
      DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);
    }

    // Step 3: Position tracking (RadialUnlockSystem integration)
    DeviceUnlockUtils.RecordBreachPosition(devicePS, gameInstance);
  }
}
```

**実装状況**: BreachHelpers.reds (lines 165-242) に実装完了

**2. RemoteBreach/RemoteBreachActions.reds** - CompleteAction @wrapMethod（✅ 実装済み）
 * DESIGN DECISION:
 * - Rejected Strategy Pattern (DaemonUnlockStrategy): Over-engineering for 3 types
 * - Preferred Helper Class + Conditional Logic: Simpler, more maintainable
 *
 * HISTORY:
 * - 2025-10-26: Created for RemoteBreach restoration (Phase 1)
 */
public static func ApplyBreachExtensions(
   * Apply full breach extensions (Radius + NPC + Position tracking)
   *
   * TEMPLATE METHOD PATTERN:
   * - Step 1: Radius unlock (devices + vehicles)
   * - Step 2: NPC unlock
   * - Step 3: Position tracking
   *
   * CALLER RESPONSIBILITIES:
   * - AccessPoint: Call ApplyBreachUnlockToDevicesWithStats() for network unlock
   * - RemoteBreach: Network unlock deferred to RefreshSlaves()
   * - UnconsciousNPC: NPC-specific unlock processing
   *
   * @param devicePS - Target device (AccessPoint/Computer/Device/Vehicle/NPC)
   * @param unlockFlags - Unlock configuration
   * @param stats - Optional statistics (null if disabled)
   * @param gameInstance - Game instance reference
   */
  public static func ApplyBreachExtensions(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockFlags: BreachUnlockFlags,
    stats: ref<BreachSessionStats>,
    gameInstance: GameInstance
  ) -> Void {
    // Guard: Validate inputs
    if !IsDefined(devicePS) || !IsDefined(gameInstance) {
      BNError("BreachHelpers", "Invalid parameters - devicePS or gameInstance is null");
      return;
    }

    BNDebug("BreachHelpers",
      "Applying breach extensions - unlockBasic: " + ToString(unlockFlags.unlockBasic) +
      ", unlockNPCs: " + ToString(unlockFlags.unlockNPCs));

    // Step 1: Radius unlock (devices + vehicles)
    if unlockFlags.unlockBasic {
      DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
      DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);

      // Optional statistics collection
      if IsDefined(stats) {
        BreachStatisticsCollector.CollectRadialUnlockStats(devicePS, stats, gameInstance);
      }

      BNDebug("BreachHelpers", "Radius unlock (devices + vehicles) completed");
    }

    // Step 2: NPC unlock
    if unlockFlags.unlockNPCs {
      DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);

      if IsDefined(stats) {
        BreachStatisticsCollector.CollectNPCUnlockStats(devicePS, stats, gameInstance);
      }

      BNDebug("BreachHelpers", "NPC unlock completed");
    }

    // Step 3: Position tracking (RadialUnlockSystem integration)
    DeviceUnlockUtils.RecordBreachPosition(devicePS, gameInstance);

    BNDebug("BreachHelpers", "Breach extensions completed");
  }
}
```

**2. RemoteBreach/RemoteBreachActions.reds** - CompleteAction @wrapMethod

**import文変更**: なし（既存 `import BetterNetrunning.Breach.*` で BreachHelpers使用可能）

```redscript
// RemoteBreach/RemoteBreachActions.reds (lines 109-180, 実装完了)

/**
 * RemoteBreach action completion handler
 *
 * PURPOSE:
 * - Apply BetterNetrunning extensions after vanilla RemoteBreach
 * - Uses shared BreachHelpers for DRY compliance
 *
 * INTEGRATION POINT:
 * - @wrapMethod ensures mod compatibility
 * - Calls wrappedMethod() first to preserve vanilla behavior
 */
@wrapMethod(ScriptableDeviceAction)
public func CompleteAction(gameInstance: GameInstance) -> Void {
  // Filter: Only process RemoteBreach actions
  if !this.IsA(n"RemoteBreach") {
    wrappedMethod(gameInstance);
    return;
  }

  // Execute vanilla CompleteAction
  wrappedMethod(gameInstance);

  // Apply RemoteBreach extensions
  this.ApplyRemoteBreachExtensions(gameInstance);
}

/**
 * Apply RemoteBreach-specific extensions
 *
 * DRY COMPLIANCE:
 * - Uses BreachHelpers.ExecuteRadiusUnlocks() for shared logic
 * - 30 lines of duplicate code reduced to 5 lines (83% reduction)
 */
@addMethod(ScriptableDeviceAction)
private func ApplyRemoteBreachExtensions(gameInstance: GameInstance) -> Void {
  // Get device PS
  let devicePS: ref<ScriptableDeviceComponentPS> = this.GetOwnerPS(gameInstance);
  if !IsDefined(devicePS) {
    BNError("RemoteBreachActions", "Failed to get device PS");
    return;
  }

  // Get minigame programs from Blackboard
  let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gameInstance)
    .Get(GetAllBlackboardDefs().HackingMinigame);
  let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(
    minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms)
  );

  // Extract unlock flags
  let unlockFlags: BreachUnlockFlags = DaemonFilterUtils.ExtractUnlockFlags(minigamePrograms);

  // Initialize statistics (always enabled for consistency with AccessPoint)
  let stats: ref<BreachSessionStats> = BreachSessionStats.Create(
    BNConstants.BREACH_TYPE_REMOTE_BREACH(),
    devicePS.GetDeviceName()
  );
  BreachStatisticsCollector.CollectExecutedDaemons(minigamePrograms, stats);

  // Apply shared breach extensions (DRY compliance)
  BreachHelpers.ExecuteRadiusUnlocks(devicePS, unlockFlags, stats, gameInstance);

  BNDebug("RemoteBreachActions", "RemoteBreach extensions completed");
}
```

**実装状況**: RemoteBreachActions.reds (lines 109-180) に実装完了
@addMethod(ScriptableDeviceAction)
private func GetMinigamePrograms() -> array<TweakDBID> {
  // Placeholder - actual implementation TBD
  let programs: array<TweakDBID>;
  return programs;
}
```

**3. Breach/BreachProcessing.reds** - 既存実装リファクタリング

```redscript
// Line 163付近（ApplyBetterNetrunningExtensionsWithStats内）

// BEFORE (30 lines):
// this.UnlockStandaloneDevicesInBreachRadius(unlockFlags, stats);
// this.ApplyBreachUnlockToDevicesWithStats(devices, unlockFlags, stats);
// this.RecordNetworkBreachPosition(devices);

// AFTER (5 lines):
// Apply shared breach extensions (DRY compliance)
BreachHelpers.ApplyBreachExtensions(this, unlockFlags, stats, gameInstance);

// AccessPoint-specific: Network unlock
this.ApplyBreachUnlockToDevicesWithStats(devices, unlockFlags, stats);
```

#### テスト手順

1. **前提条件**:
   - RemoteBreachでComputer/Device/Vehicleをターゲット
   - 50m範囲内に複数デバイス + 車両 + NPC配置

2. **期待動作**:
   - ミニゲーム成功後、以下が自動実行:
     - Radius unlock: 50m範囲内デバイス + 車両アンロック
     - NPC unlock: 50m範囲内NPCにQuickHack有効化
     - Position記録: RadialUnlockSystemに登録

3. **検証項目**:
   - [ ] 範囲内デバイスがアンロック（QuickHack表示）
   - [ ] 範囲内車両がアンロック（遠隔操作可能）
   - [ ] 範囲内NPCにQuickHack表示
   - [ ] ログ出力: "Breach extensions completed"
   - [ ] 統計ログ出力（設定有効時）

#### 工数見積もり: 4-6時間
- BreachHelpers統合（Section 3追加）: 2時間
- RemoteBreachActions実装: 1.5時間
- BreachProcessingリファクタリング: 30分
- テスト: 1.5時間
- ドキュメント: 30分

---

## Phase 2: ペナルティシステム

### 実装3: 失敗コールバック（#7）

#### 実装状況: ✅ 完了（既存実装確認済み）

**実装箇所**:
- `Breach/BreachPenaltySystem.reds` Lines 99-131（FinalizeNetrunnerDive）
- `Breach/BreachPenaltySystem.reds` Line 266（DetectBreachType）
- `Breach/BreachPenaltySystem.reds` Line 292（IsRemoteBreachingAnyDevice）
- `Breach/BreachPenaltySystem.reds` Line 457（ApplyFailurePenalty）

**実装内容**:
```redscript
// Line 99: FinalizeNetrunnerDive wrapper
@wrapMethod(ScriptableDeviceComponentPS)
public func FinalizeNetrunnerDive(state: HackingMinigameState) -> Void {
  if NotEquals(state, HackingMinigameState.Failed) || !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
    wrappedMethod(state);
    return;
  }

  let breachType: BreachType = this.DetectBreachType();
  if !this.IsBreachPenaltyEnabledForType(breachType) {
    wrappedMethod(state);
    return;
  }

  let gameInstance: GameInstance = this.GetGameInstance();
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  ApplyFailurePenalty(player, this, gameInstance, breachType);
  wrappedMethod(state);
}

// Line 266: Breach type detection
private func DetectBreachType() -> BreachType {
  if this.IsRemoteBreachingAnyDevice() { return BreachType.RemoteBreach; }
  if this.HasPersonalLinkSlot() { return BreachType.AccessPoint; }
  return BreachType.RemoteBreach; // Fallback
}

// Line 292: RemoteBreach state detection
private func IsRemoteBreachingAnyDevice() -> Bool {
  // Check RemoteBreachStateSystem, DeviceRemoteBreachStateSystem, VehicleRemoteBreachStateSystem
  // Returns true if this device is current RemoteBreach target
}

// Line 457: Apply penalties
public static func ApplyFailurePenalty(...) -> Void {
  ApplyBreachFailurePenaltyVFX(player, gameInstance);  // Red VFX
  RecordBreachFailureTimestamp(devicePS, gameInstance); // 10min lock
  TriggerTraceAttempt(player, gameInstance);           // Position reveal
}
```

#### 目的
RemoteBreach失敗時にペナルティ（スタン、ロック、VFX）を適用します。

#### 実装箇所

**Breach/BreachPenaltySystem.reds** - FinalizeNetrunnerDive統合

```redscript
module BetterNetrunning.Breach
import BetterNetrunning.RemoteBreach.*

/**
 * FinalizeNetrunnerDive wrapper - Detect RemoteBreach failure
 *
 * PURPOSE:
 * - Apply breach failure penalties for RemoteBreach (same as AccessPoint)
 *
 * INTEGRATION:
 * - RemoteBreachStateSystem provides breach type detection
 * - Reuses existing ApplyBreachFailurePenalty() logic
 *
 * RATIONALE:
 * - AccessPoint failure already handled (line 95)
 * - RemoteBreach needs same penalty system for game balance
 *
 * ARCHITECTURE:
 * - @wrapMethod(ScriptableDeviceComponentPS) targets ALL devices
 * - Covers Computer/Door/Terminal/Vehicle RemoteBreach failures
 * - NOT @wrapMethod(AccessPointControllerPS) (too narrow - AccessPoint only)
 */
@wrapMethod(ScriptableDeviceComponentPS)
public func FinalizeNetrunnerDive(state: HackingMinigameState) -> Void {
  wrappedMethod(state);

  // Check if this is a RemoteBreach (via RemoteBreachStateSystem)
  let stateSystem: ref<RemoteBreachStateSystem> =
    GameInstance.GetScriptableSystemsContainer(this.GetGameInstance())
      .Get(n"BetterNetrunning.RemoteBreach.RemoteBreachStateSystem") as RemoteBreachStateSystem;

  if !IsDefined(stateSystem) { return; }

  let isRemoteBreach: Bool = stateSystem.HasPendingRemoteBreach();

  if isRemoteBreach && Equals(state, HackingMinigameState.Failed) {
    BNDebug("BreachPenalty", "RemoteBreach failed - applying penalties");

    // Apply same penalties as AccessPoint failure
    this.ApplyRemoteBreachFailurePenalty();
  }
}

/**
 * Apply RemoteBreach failure penalties
 *
 * PENALTIES:
 * - Player stun (1.5s)
 * - VFX effect (glitch animation)
 * - Device lock (10s cooldown)
 *
 * REUSES:
 * - ApplyStunPenalty() - existing implementation
 * - RemoteBreachLockUtils - existing timestamp system
 */
@addMethod(ScriptableDeviceComponentPS)
private func ApplyRemoteBreachFailurePenalty() -> Void {
  let gameInstance: GameInstance = this.GetGameInstance();
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);

  // Penalty 1: Player stun
  if BetterNetrunningSettings.BreachFailureStunEnabled() {
    this.ApplyStunPenalty(player, 1.5); // 1.5s stun
  }

  // Penalty 2: VFX effect
  if BetterNetrunningSettings.BreachFailureVFXEnabled() {
    // TODO: Add VFX trigger (glitch effect)
  }

  // Penalty 3: Device lock (10s cooldown)
  if BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
    RemoteBreachLockUtils.RecordRemoteBreachFailure(this, gameInstance);
    BreachLockUtils.DisableJackInInteraction(this);

    BNInfo("BreachPenalty", "RemoteBreach locked for 10 seconds");
  }
}
```

#### テスト手順

1. **前提条件**:
   - RemoteBreachミニゲーム開始
   - 意図的に失敗（時間切れ）

2. **期待動作**:
   - プレイヤースタン（1.5秒）
   - VFX表示（グリッチエフェクト）
   - デバイスロック（10秒間RemoteBreach非表示）
   - 10秒経過後にロック解除

3. **検証項目**:
   - [ ] スタン適用（移動不可）
   - [ ] VFX表示
   - [ ] RemoteBreachプログラム非表示（10秒間）
   - [ ] 10秒後に再表示
   - [ ] ログ出力: "RemoteBreach locked for 10 seconds"

#### 工数見積もり: 2-3時間
- 実装: 1.5時間
- テスト: 1時間
- ドキュメント: 30分

---

## Phase 3: フィルタリング改善

### 実装4: Daemonフィルタ（#4）

#### 実装状況: ✅ 完了（2025-10-26実装済み）

**旧仕様（CustomHackingSystem）**:
- remoteBreach.lua（396行）で静的デーモンリスト定義
- Computer = Basic + Camera（固定）
- Device = Basic only（固定）
- **問題**: ネットワーク構成に関係なく固定、HackingExtensions依存

**新仕様（バニラ統合）**:
- 既存の`FilterPlayerPrograms()`を活用
- AccessPoint/UnconsciousNPCと同じフィルタリングロジック流用
- **ネットワーク構成に基づく動的フィルタリング**

#### 目的

RemoteBreach時にターゲットタイプ別のデーモンフィルタリングを適用します。

#### 実装箇所

**1. Minigame/ProgramFilteringRules.reds** - RemoteBreach専用フィルタ（✅ 実装済み）

Lines 528-622（93行）

```redscript
/**
 * Determines if a daemon should be removed from RemoteBreach minigame
 *
 * PURPOSE:
 * Filters daemons for vanilla RemoteBreach based on target device type,
 * replacing CustomHackingSystem's static daemon lists with dynamic filtering.
 *
 * ARCHITECTURE:
 * Mirrors AccessPoint's ShouldRemoveBreachedPrograms() pattern:
 * - Device type detection (Computer/Camera/Turret/Device/Vehicle)
 * - TweakDBID-based filtering (keeps only relevant daemons)
 * - Integration with vanilla FilterPlayerPrograms() pipeline
 *
 * DEVICE TYPE DAEMON MAPPING (from remoteBreach.lua):
 * - Computer: Basic + Camera (network access devices)
 * - Device: Basic only (generic hackable devices)
 * - Camera: Basic + Camera (surveillance devices)
 * - Turret: Basic + Turret (combat devices)
 * - Vehicle: Basic only (no network unlock for vehicles)
 *
 * @param actionID - The daemon's TweakDB ID
 * @param breachEntity - The entity being breached (Computer/Device/Camera/Turret/Vehicle)
 * @return True if daemon should be removed (not applicable to this target type)
 */
public func ShouldRemoveRemoteBreachPrograms(
  actionID: TweakDBID,
  breachEntity: wref<GameObject>
) -> Bool {
  // Only applies to RemoteBreach (not AccessPoint or NPC breach)
  // Caller must verify breach type before calling this function

  if !IsDefined(breachEntity) {
    return false;
  }

  // Get device PS for type detection
  let device: ref<Device> = breachEntity as Device;
  if !IsDefined(device) {
    // Not a device (might be puppet) - allow all daemons
    return false;
  }

  let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
  if !IsDefined(devicePS) {
    return false;
  }

  // Determine device type and filter accordingly
  let isComputer: Bool = DaemonFilterUtils.IsComputer(devicePS);
  let isCamera: Bool = DaemonFilterUtils.IsCamera(devicePS);
  let isTurret: Bool = DaemonFilterUtils.IsTurret(devicePS);
  let isVehicle: Bool = IsDefined(devicePS as VehicleControllerPS);

  // Computer: Allow Basic + Camera daemons only
  if isComputer {
    return !(Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS())
          || Equals(actionID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()));
  }

  // Camera: Allow Basic + Camera daemons only
  if isCamera {
    return !(Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS())
          || Equals(actionID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()));
  }

  // Turret: Allow Basic + Turret daemons only
  if isTurret {
    return !(Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS())
          || Equals(actionID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()));
  }

  // Vehicle: Allow Basic daemon only (no network unlock)
  if isVehicle {
    return !Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS());
  }

  // Generic Device: Allow Basic daemon only
  return !Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS());
}
```

**実装状況**: ProgramFilteringRules.reds Lines 528-622に実装完了

**2. betterNetrunning.reds** - FilterPlayerPrograms統合（✅ 実装済み）

Line 172に統合ポイント追加:

```redscript
} else if ShouldRemoveNonNetrunnerPrograms(...) {
  shouldRemove = true;
  filterName = "NonNetrunnerFilter";
} else if this.m_isRemoteBreach && ShouldRemoveRemoteBreachPrograms(actionID, this.m_entity as GameObject) {
  shouldRemove = true;
  filterName = "RemoteBreachFilter";
} else if ShouldRemoveDeviceTypePrograms(...) {
```

**実装状況**: betterNetrunning.reds Line 172に統合完了

#### テスト手順

1. **前提条件**:
   - HackingExtensions無効化（バニラRemoteBreach使用）
   - Computer/Camera/Turret/Generic Device/Vehicleでそれぞれテスト

2. **期待動作**:
   - Computer: Basic + Camera デーモン表示
   - Camera: Basic + Camera デーモン表示
   - Turret: Basic + Turret デーモン表示
   - Generic Device: Basic のみ表示
   - Vehicle: Basic のみ表示

3. **検証項目**:
   - [ ] 各ターゲットタイプで正しいデーモンセット表示
   - [ ] 不正なデーモンは非表示
   - [ ] ログ出力: "RemoteBreachFilter" によるフィルタリング結果

#### 工数見積もり: 1時間完了（実装30分 + テスト30分）
- ✅ 実装: 30分（完了）
- ⏳ テスト: 30分（次タスク）
- ⏳ ドキュメント: 15分（本セクション更新完了）

---

## Phase 4: 開発支援（オプション）

### 実装5: 統計収集（#10）

#### 実装状況: ✅ 完了（既存実装確認済み）

**実装箇所**:
- `Utils/BreachSessionLogger.reds` Lines 46-120（BreachSessionStats）
- `Utils/BreachSessionLogger.reds` Line 133（LogBreachSummary）
- `RemoteBreach/RemoteBreachActions.reds` Line 168（統計収集）
- `Breach/BreachProcessing.reds` Line 104（AccessPoint統計）

**実装内容**:
```redscript
// BreachSessionStats class (Line 46)
public class BreachSessionStats {
  public let breachType: String;
  public let breachTarget: String;
  public let minigameSuccess: Bool;
  public let devicesTotal: Int32;
  public let devicesUnlocked: Int32;
  // ... 46フィールド total
}

// LogBreachSummary (Line 133)
public static func LogBreachSummary(stats: ref<BreachSessionStats>) -> Void {
  // 16セクション構造化ログ出力
  // ╔═══════════════════════════════════════╗
  // ║   BREACH SESSION SUMMARY             ║
  // ╚═══════════════════════════════════════╝
  // Type: RemoteBreach | Target: Computer
  // Result: SUCCESS | Processing: 234.5 ms
  // Total: 23 | Unlocked: 18 (78%)
}

// RemoteBreachActions.reds Line 168
let stats: ref<BreachSessionStats> = BreachSessionStats.Create(
  BNConstants.BREACH_TYPE_REMOTE_BREACH(),
  devicePS.GetDeviceName()
);
BreachStatisticsCollector.CollectExecutedDaemons(minigamePrograms, stats);
BreachHelpers.ExecuteRadiusUnlocks(devicePS, unlockFlags, stats, gameInstance);
```

#### 追加作業**:
**追加作業**: なし（既に完全実装済み）

#### 工数見積もり: 0時間（実装完了）
- テスト: 30分（statisticsLogging設定有効化でログ出力確認）

---

### 実装6: 成功コールバック（#6）

#### 実装状況: ✅ 完了（Phase 1で実装済み）

Phase 1の`ApplyRemoteBreachExtensions()`がオーケストレーター役割を担当。

**追加作業なし**。

---

## テスト計画

### 単体テスト

| 機能 | テストケース | 期待結果 | 優先度 |
|------|------------|---------|--------|
| **JackIn復元** | 期限切れ（6分経過） | JackIn再有効化 | ✅ 必須 |
| **Radius unlock** | 50m範囲内に10デバイス | 全デバイスアンロック | ✅ 必須 |
| **NPC unlock** | 50m範囲内に5 NPC | QuickHack有効化 | ✅ 必須 |
| **失敗ペナルティ** | ミニゲーム失敗 | スタン+ロック適用 | ✅ 必須 |
| **Daemonフィルタ** | Computer/Device/Vehicle | 正しいデーモンセット | ⚠️ 推奨 |
| **統計収集** | 設定有効時 | ログ出力 | ❌ オプション |

### 統合テスト

| シナリオ | 手順 | 期待結果 |
|---------|------|---------|
| **完全ブリーチサイクル** | 1. RemoteBreach実行 → 2. 成功 → 3. 期限切れ → 4. 再ブリーチ | 全機能正常動作 |
| **失敗→成功サイクル** | 1. 失敗（ペナルティ） → 2. 10秒待機 → 3. 再挑戦成功 | ペナルティ解除 |
| **複数ターゲット** | Computer/Device/Vehicleを連続ブリーチ | 各ターゲット固有処理正常 |

### Mod互換性テスト

**対象MOD**:
- CustomHackingSystem（HackingExtensions）
- RadialBreach
- Daemon Netrunning (Revamp)

**検証項目**:
- [ ] `@wrapMethod` チェーン動作確認
- [ ] 競合なくロード可能
- [ ] 相互機能影響なし

---

## ロールバック計画

### Phase 1ロールバック

**条件**: JackIn復元またはネットワークアンロックが重大バグ

**手順**:
1. `Breach/BreachHelpers.reds` の ApplyBreachExtensions() セクション削除（Section 3、70行）
2. `Utils/BreachLockUtils.reds` の `SetJackInInteractionState()` 削除
3. `RemoteBreach/RemoteBreachActions.reds` の `CompleteAction()` @wrapMethod削除
4. `Minigame/ProgramFilteringRules.reds` の `EnableJackInInteraction()` 呼び出し削除
5. `Breach/BreachProcessing.reds` を旧実装に復元

**影響**: Phase 1機能すべて無効化、Phase 2-4は動作可能

### Phase 2ロールバック

**条件**: 失敗ペナルティがゲームバランス破壊

**手順**:
1. `Breach/BreachPenaltySystem.reds` の `FinalizeNetrunnerDive()` @wrapMethod削除
2. `ApplyRemoteBreachFailurePenalty()` 削除

**影響**: Phase 2のみ無効化、Phase 1/3/4は影響なし

---

## 工数サマリー

| フェーズ | 実装 | テスト | ドキュメント | 合計 |
|---------|------|--------|-------------|------|
| Phase 1 | 3.5h | 2h | 1h | **6.5h** |
| Phase 2 | 1.5h | 1h | 0.5h | **3h** |
| Phase 3 | 1h | 1h | 0.5h | **2.5h** |
| Phase 4 | 2h | 1h | 0.5h | **3.5h** (オプション) |
| **合計** | 8h | 5h | 2.5h | **15.5h** (フル) |
| **必須のみ** | 6h | 4h | 2h | **12h** |

---

## 次のステップ

### 即座実行可能な作業

**Phase 1-2, 4: テストのみ（3.5時間）**
- Phase 1: JackIn復元 + Radius unlock テスト（2h）
- Phase 2: 失敗ペナルティテスト（1h）
- Phase 4: 統計収集テスト（30min）

**Phase 3: 実装 + テスト（2.5時間）**
- GetRemoteBreachPrograms() 実装（1h）
- FilterRemoteBreachPrograms() 実装（30min）
- 5ターゲットタイプ検証（1h）

### 推奨実施順序

1. **Phase 3実装** - Daemonフィルタ（2.5h）
   ```powershell
   # 実装箇所: Minigame/ProgramFilteringRules.reds
   # 関数追加: GetRemoteBreachPrograms(), FilterRemoteBreachPrograms()
   ```

2. **Phase 1テスト** - JackIn復元（2h）
   ```powershell
   # AccessPoint breach → 6分待機 → JackIn復元確認
   # Computer RemoteBreach → 6分待機 → JackIn復元確認
   # Camera/Turret → JackInスキップ確認
   ```

3. **Phase 2テスト** - 失敗ペナルティ（1h）
   ```powershell
   # RemoteBreach失敗 → 赤色VFX → 10分ロック → 解除確認
   ```

4. **Phase 3テスト** - Daemonフィルタ（1h）
   ```powershell
   # HackingExtensions無効化
   # Computer/Camera/Turret/Device/Vehicle各テスト
   ```

5. **Phase 4テスト** - 統計収集（30min）
   ```powershell
   # statisticsLogging = true
   # r6/logs/BetterNetrunning.log確認
   ```

6. **統合テスト** - 完全サイクル（1h）
   ```powershell
   # シナリオ1: 成功 → 期限切れ → 再ブリーチ
   # シナリオ2: 失敗 → ペナルティ → 再挑戦
   # シナリオ3: 複数ターゲット連続ブリーチ
   ```

### ドキュメント更新

- [ ] IMPLEMENTATION_DESIGN.md: Phase 3実装完了マーク
- [ ] SPECIFICATION_FEASIBILITY_ANALYSIS.md: Phase 1-4完了ステータス更新
- [ ] バージョンタグ作成: v2.0.0-RemoteBreachRestore-Complete

---

**合計工数見積もり**: 実装1h + テスト5.5h + 統合テスト1h = **7.5時間**

---

**承認**: 実装開始前にこの設計書をレビューしてください。
