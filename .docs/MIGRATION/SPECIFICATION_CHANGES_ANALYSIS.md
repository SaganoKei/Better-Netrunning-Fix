# 仕様変更分析: CustomRemoteBreach → バニラRemoteBreach移行

## 概要

本ドキュメントは、**VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md v2.3**（移行計画）に基づく **Task 3.3: RemoteBreach/削除** によって発生した**全仕様変更**を網羅的に文書化します。

**発見経緯**: コンパイルエラー調査中に、移行計画が以下の点で不完全であることが判明:
- 削除されたファイル: 14ファイル / 3,593行
- **文書化された機能影響**: HackingExtensions依存削除のみ（移行計画タイトル）
- **文書化されなかった仕様変更**: 一時的アンロック削除、JackIn自動復元削除、他
- **誤った記載**: RAM計算式が変更されたとの記述（実際は同一）

**移行計画のタイトル**: "バニラRemoteBreach実装実行計画"（Implementation Plan）
**実態**: "CustomRemoteBreach → バニラRemoteBreach移行計画"（Migration Plan with specification changes）

---

## 1. アンロック期限システム: 実装済み（確認事項）

### 現状（バニラRemoteBreach移行後）
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

**機能**:
- AccessPointブリーチで既に実装済み ✅
- デフォルト6時間の一時的アンロック（設定可能）
- 期限切れ時にタイムスタンプ自動リセット
- バニラRemoteBreach統合後も自動適用される（FilterPlayerProgramsがMinigameSystemで呼ばれるため）

### 旧仕様（CustomRemoteBreach）との比較
```redscript
// UnlockExpirationUtils.reds (240行) - 削除済み
// ✅ 機能は ProgramFilteringRules.reds に統合実装済み
public static func CheckUnlockExpiration(devicePS: ref<ScriptableDeviceComponentPS>) -> UnlockExpirationResult {
  let unlockDurationHours: Int32 = BetterNetrunningSettings.QuickhackUnlockDurationHours();
  let durationSeconds: Float = Cast<Float>(unlockDurationHours) * 3600.0;

  if elapsedTime > durationSeconds {
    devicePS.m_betterNetrunningUnlockTimestampBasic = 0.0; // リセット
    result.wasExpired = true;
  }
}
```

**実装詳細**:
- タイムスタンプフィールド: 4種類（Basic/Camera/Turret/NPC）- 既存
- 期限チェック呼び出し元: `FilterPlayerPrograms()` @wrapMethod（betterNetrunning.reds:80）
- デバイスタイプ別処理: `ShouldRemoveBreachedPrograms()` で統合

### 影響分析

| 項目 | 旧仕様（Custom） | 現仕様（バニラ統合後） | 変更 |
|------|-----------------|---------------------|------|
| **アンロック期間** | 10時間（設定可能） | 6時間（設定可能）✅ | デフォルト値のみ変更 |
| **JackIn再試行** | 期限切れ後に可能 | 期限切れ後に可能 ✅ | 同一（要#2実装） |
| **ミニゲーム再挑戦** | 期限切れ後に可能 | 期限切れ後に可能 ✅ | 同一 |
| **タイムスタンプリセット** | 自動（期限切れ時） | 自動（期限切れ時）✅ | 同一 |
| **設定項目** | QuickhackUnlockDurationHours | QuickhackUnlockDurationHours ✅ | 同一 |

**✅ 結論**: アンロック期限システムは**既に実装済み**
- ProgramFilteringRules.reds で AccessPoint/UnconsciousNPC ブリーチに適用中
- バニラRemoteBreach統合後も自動適用（FilterPlayerProgramsがバニラMinigameSystemで呼ばれる）
- **追加実装不要** - 動作確認のみで完了

**削除されたコード**: UnlockExpirationUtils.reds (240行) → ProgramFilteringRules.reds に統合済み

**移行計画での記載**: ❌ なし（実装済みだが文書化なし）

---

## 2. JackInインタラクション自動復元

### 旧仕様（CustomRemoteBreach）
```redscript
// DeviceInteractionUtils.reds (92行) - 削除済み
public static func EnableJackInInteractionForAccessPoint(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
  let sharedPS: ref<SharedGameplayPS> = devicePS;
  if !IsDefined(sharedPS) { return; }

  let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
  let i: Int32 = 0;
  while i < ArraySize(apControllers) {
    let apPS: ref<AccessPointControllerPS> = apControllers[i];
    if IsDefined(apPS) && apPS.IsDisabled() {
      apPS.ExecutePSAction(apPS.ActionSetDeviceON(), apPS);
    }
    i += 1;
  }
}
```

**機能**:
- アンロック期限切れ時にJackInインタラクション自動復元
- AccessPointのDisabled状態を検出 → `ActionSetDeviceON()`で復元
- 複数AccessPoint対応（ループ処理）

**呼び出し元**: `RemoveCustomRemoteBreachIfUnlocked()` (RemoteBreachVisibility.reds:263)
```redscript
let expirationResult: UnlockExpirationResult = UnlockExpirationUtils.CheckUnlockExpiration(this);

if expirationResult.wasExpired {
  DeviceInteractionUtils.EnableJackInInteractionForAccessPoint(this); // ← 自動復元
}
```

### 新仕様（バニラRemoteBreach）
```redscript
// 自動復元ロジック: 存在しない
// JackInは一度無効化されたら手動復元不可
```

**機能**:
- JackIn無効化後の復元機能なし
- AccessPointは永続的にDisabled状態維持

### 影響分析

| 項目 | 旧仕様 | 新仕様 | 影響 |
|------|--------|--------|------|
| **期限切れ後JackIn** | 自動復元（再試行可能） | 復元なし（永久無効） | QoL低下 |
| **手動復元** | 不要（自動） | 不可能 | 操作不可 |
| **AccessPoint再利用** | 可能（期限切れ時） | 不可能（永続無効） | コンテンツ消耗 |
| **失敗ペナルティ統合** | 独立（期限管理） | なし | 機能喪失 |

**削除されたコード**: DeviceInteractionUtils.reds (92行)
- `EnableJackInInteractionForAccessPoint()`: メインロジック
- `DisableJackInInteractionForAccessPoint()`: 無効化ロジック（BreachLockUtils.redsに移植済み）

**移行先**:
- `DisableJackInInteractionForAccessPoint()` → `BreachLockUtils.DisableJackInInteraction()` (移植済み)
- `EnableJackInInteractionForAccessPoint()` → **移植なし**（永続アンロック採用により不要と判断）

**移行計画での記載**: ❌ なし

---

## 3. RemoteBreachアクション可視性制御

### 旧仕様（CustomRemoteBreach）
```redscript
// RemoteBreachVisibility.reds (318行) - 削除済み

// メソッド1: 事前チェック（追加防止）
public final func TryAddCustomRemoteBreach(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  if this.IsDeviceAlreadyUnlocked() { return; }  // アンロック済みなら追加しない
  if BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(this) { return; }  // 失敗ペナルティ中なら追加しない

  // RemoteBreachActionを追加（Computer/Device/Vehicle）
}

// メソッド2: 事後削除（フェイルセーフ）
public final func RemoveCustomRemoteBreachIfUnlocked(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let expirationResult: UnlockExpirationResult = UnlockExpirationUtils.CheckUnlockExpiration(this);

  if expirationResult.wasExpired {
    DeviceInteractionUtils.EnableJackInInteractionForAccessPoint(this);  // JackIn復元
  }

  let isUnlocked: Bool = expirationResult.isUnlocked
    || this.IsBasicDeviceBreachedByCustomHackingSystem();

  if isUnlocked {
    this.RemoveCustomRemoteBreachAction(outActions);  // アクション削除
  }
}

// メソッド3: アンロック状態判定
public final func IsDeviceAlreadyUnlocked() -> Bool {
  // Vehicle: m_betterNetrunningUnlockTimestampBasic > 0.0
  // Camera: m_betterNetrunningUnlockTimestampCameras > 0.0
  // Turret: m_betterNetrunningUnlockTimestampTurrets > 0.0
  // Basic: m_betterNetrunningUnlockTimestampBasic > 0.0 OR DeviceRemoteBreachStateSystem
  return /* OR条件判定 */;
}
```

**アーキテクチャ**: Defense-in-Depth（多層防御）
- **Primary**: `TryAddCustomRemoteBreach()`で事前チェック → UI閃き防止
- **Secondary**: `RemoveCustomRemoteBreachIfUnlocked()`で事後削除 → フェイルセーフ
- **Integration**: `IsDeviceAlreadyUnlocked()`でCustomHackingSystem統合

**機能**:
1. **UIフラッシュ防止**: アンロック済みデバイスにRemoteBreachアクション追加を事前ブロック
2. **期限管理統合**: `CheckUnlockExpiration()` + JackIn復元を1メソッドに統合
3. **StateSystem統合**: CustomHackingSystemのブリーチ状態とタイムスタンプ両方をチェック

### 新仕様（バニラRemoteBreach）
```redscript
// RemoteBreachActions.reds (190行)
// @wrapMethod(ScriptableDeviceComponentPS) GetQuickHackActions() で個別実装

@wrapMethod(ComputerControllerPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
  wrappedMethod(actions, context);

  if !BetterNetrunningSettings.RemoteBreachEnabledComputer() { return; }
  if BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(this) { return; }

  let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(this.GetGameInstance());
  if IsDefined(stateSystem) && stateSystem.IsComputerBreached(this.GetID()) { return; }

  let breachAction: ref<RemoteBreachAction> = this.ActionCustomRemoteBreach();
  ArrayPush(actions, breachAction);
}
```

**アーキテクチャ**: Per-Device Type Implementation
- Computer: `ComputerControllerPS.GetQuickHackActions()` (RemoteBreachAction_Computer.reds:132)
- Device: `ScriptableDeviceComponentPS.GetQuickHackActions()` (RemoteBreachAction_Device.reds:143)
- Vehicle: `VehicleComponentPS.GetQuickHackActions()` (RemoteBreachAction_Vehicle.reds:120)

**機能**:
1. **設定チェック**: `RemoteBreachEnabled*()` で機能有効化確認
2. **失敗ペナルティチェック**: `IsDeviceLockedByRemoteBreachFailure()` でロック状態確認
3. **ブリーチ状態チェック**: `Is*Breached()` でStateSystem確認
4. **期限管理**: なし（永続アンロック）

### 影響分析

| 項目 | 旧仕様 | 新仕様 | 影響 |
|------|--------|--------|------|
| **実装場所** | 中央集約（1ファイル） | 分散（3ファイル） | コード重複 |
| **期限チェック** | 統合（CheckUnlockExpiration） | なし | 機能喪失 |
| **JackIn復元** | 統合（EnableJackInInteraction） | なし | 機能喪失 |
| **UIフラッシュ防止** | 2段階（事前+事後） | 1段階（事前のみ） | 品質低下 |
| **拡張性** | 中央管理（修正1箇所） | 個別管理（修正3箇所） | 保守性低下 |

**削除されたコード**: RemoteBreachVisibility.reds (318行)
- `TryAddCustomRemoteBreach()`: 事前チェック（防止）
- `TryAddMissingCustomRemoteBreach()`: 強制注入（NetrunnerChair等）
- `RemoveCustomRemoteBreachIfUnlocked()`: 事後削除（期限管理統合）
- `IsDeviceAlreadyUnlocked()`: アンロック状態判定
- `IsBasicDeviceBreachedByCustomHackingSystem()`: CustomHackingSystem統合
- `RemoveCustomRemoteBreachAction()`: アクション削除ヘルパー

**新規実装**:
- RemoteBreachAction_Computer.reds:132-149 (ComputerControllerPS.GetQuickHackActions)
- RemoteBreachAction_Device.reds:143-191 (ScriptableDeviceComponentPS.GetQuickHackActions)
- RemoteBreachAction_Vehicle.reds:120-147 (VehicleComponentPS.GetQuickHackActions)

**移行計画での記載**: ❌ なし

---

## 4. Daemon フィルタリングシステム

### 旧仕様（CustomRemoteBreach）
```redscript
// RemoteBreachHelpers.reds:517 - 削除済み
public static func GetMinigameID(targetType: MinigameTargetType, difficulty: GameplayDifficulty, opt devicePS: ref<ScriptableDeviceComponentPS>) -> TweakDBID {
  switch targetType {
    case MinigameTargetType.Computer:
      return MinigameIDHelper.GetComputerMinigameID(difficulty);  // Basic + Camera
    case MinigameTargetType.Device:
      return MinigameIDHelper.GetDeviceMinigameID(difficulty, devicePS);  // Device-specific
    case MinigameTargetType.Vehicle:
      return MinigameIDHelper.GetVehicleMinigameID(difficulty);  // Basic only
  }
}
```

**Minigame定義**:
- **Computer**: Basic + Camera デーモン（Easy/Medium/Hard）
- **Device - Camera**: Basic + Camera デーモン（Easy/Medium/Hard）
- **Device - Turret**: Basic + Turret デーモン（Easy/Medium/Hard）
- **Device - Generic**: Basic デーモンのみ（Easy/Medium/Hard）
- **Vehicle**: Basic デーモンのみ（固定難易度）

**実装**: BaseRemoteBreachAction.reds:33-71 (アーキテクチャコメント)
> RemoteBreach uses CustomHackingSystem (HackingExtensions MOD) instead of the vanilla MinigameGenerationRuleScalingPrograms pipeline.
>
> 1. DAEMON LISTS ARE STATIC - Defined in remoteBreach.lua at game initialization
> 2. NO DYNAMIC FILTERING - FilterPlayerPrograms() is NOT called
> 3. DESIGN RATIONALE - Daemons represent CAPABILITIES granted by breaching that target type

### 新仕様（バニラRemoteBreach）
```redscript
// バニラMinigameGenerationRuleScalingPrograms使用
// 動的フィルタリング: ProgramFiltering.reds でデーモンを動的に決定
```

**Minigame定義**:
- **バニラRemoteBreach**: 単一TweakDBID（`Minigame.RemoteBreach`）
- デーモンリスト: 動的生成（ネットワーク構成に基づく）

**実装**: ProgramFiltering.reds (442行) - 既存コード（削除されず）
- `FilterPlayerPrograms()`: ネットワークデバイスから利用可能なデーモンを抽出
- `PhysicalRangeFilter`: 50m範囲内デバイスのみフィルタ
- `AccessPointFilter`: AccessPoint配下デバイスのみフィルタ

### 影響分析

| 項目 | 旧仕様 | 新仕様 | 影響 |
|------|--------|--------|------|
| **Minigame定義数** | 9種類（3ターゲット×3難易度） | 1種類（バニラ） | カスタマイズ性低下 |
| **デーモンリスト** | 静的（CETで定義） | 動的（ネットワーク依存） | セマンティック変化 |
| **デバイスタイプ別** | 固定（Computer=Basic+Camera） | 動的（実際のネットワーク） | ゲームプレイ変化 |
| **難易度システム** | あり（Easy/Medium/Hard） | なし（バニラ） | ゲームバランス変化 |
| **拡張性** | CET Lua（外部設定） | Redscript（内部ロジック） | モッディング困難化 |

**削除されたコード**:
- RemoteBreachHelpers.reds:MinigameIDHelper (lines 517-596)
- RemoteBreachHelpers.reds:GameplayDifficulty (enum)
- RemoteBreachHelpers.reds:MinigameTargetType (enum)
- BaseRemoteBreachAction.reds:33-71 (アーキテクチャドキュメント)

**維持されたコード**:
- ProgramFiltering.reds (442行) - デーモンフィルタリングロジック（既存機能）

**移行計画での記載**: ⚠️ 部分的
> CustomHackingSystem → Vanilla RemoteBreach
>
> しかし、静的定義 → 動的フィルタリング の変化は記載なし

---

## 5. カスタムHackingSystem統合

### 旧仕様（CustomRemoteBreach）
```redscript
// BaseRemoteBreachAction.reds:97 - 削除済み
public func CompleteAction(gameInstance: GameInstance) -> Void {
  this.SetStateSystemTarget(gameInstance);  // StateSystemにターゲット設定

  let customHackSystem: ref<CustomHackingSystem> = /* 取得 */;
  let onSucceed: ref<OnRemoteBreachSucceeded> = new OnRemoteBreachSucceeded();
  let onFailed: ref<OnRemoteBreachFailed> = new OnRemoteBreachFailed();

  customHackSystem.StartNewQuickhackInstance(
    this.m_networkName,
    this,
    this.m_minigameDefinition,
    this.m_targetHack,
    emptyData,
    onSucceed,   // ← 成功コールバック
    onFailed     // ← 失敗コールバック
  );

  // Blackboard初期化（vanilla準拠）
}
```

**アーキテクチャ**: CustomHackingSystem依存
- **Action Base Class**: `BaseRemoteBreachAction extends CustomAccessBreach`
- **Daemon Classes**: `DeviceDaemonAction extends HackProgramAction`
- **Callback System**: `OnRemoteBreachSucceeded` / `OnRemoteBreachFailed`
- **StateSystem**: Computer/Device/Vehicle別に3システム

**機能**:
1. **成功コールバック**: ボーナスデーモン実行 + 統計収集 + ネットワークアンロック
2. **失敗コールバック**: ペナルティ適用（VFX + スタン + RemoteBreachロック）
3. **StateSystemターゲット設定**: `SetStateSystemTarget()` でデーモン実行前にターゲット登録
4. **Minigame定義選択**: Computer/Device/Vehicle別にTweakDBID選択

### 新仕様（バニラRemoteBreach）
```redscript
// RemoteBreachActions.reds:70
@wrapMethod(ScriptableDeviceAction)
public func IsPossible(opt context: GetActionsContext) -> Bool {
  let result: Bool = wrappedMethod(context);

  // VanillaのRemoteBreachアクション処理
  let vanillaRemoteBreach: ref<RemoteBreach> = this as RemoteBreach;
  if !IsDefined(vanillaRemoteBreach) { return result; }

  // ロック状態チェック（失敗ペナルティ）
  if BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(vanillaRemoteBreach.GetExecutor() as ScriptableDeviceComponentPS) {
    return false;
  }

  return result;
}
```

**アーキテクチャ**: バニラクラス拡張
- **Action Base Class**: `RemoteBreach` (vanilla) を @wrapMethod で拡張
- **Daemon Classes**: なし（バニラのデフォルトデーモン使用）
- **Callback System**: なし（バニラのMinigame完了処理使用）
- **StateSystem**: バニラの `HackingMinigame` Blackboard使用

**機能**:
1. **IsPossible() wrap**: 失敗ペナルティチェックのみ追加
2. **GetCost() wrap**: RAM計算式オーバーライド（RemoteBreachCostCalculator使用）
3. **バニラ処理委譲**: 成功/失敗処理はバニラMinigameSystemが処理

### 影響分析

| 項目 | 旧仕様 | 新仕様 | 影響 |
|------|--------|--------|------|
| **カスタムデーモン** | あり（4種類: Basic/Camera/Turret/NPC） | なし（バニラのみ） | 機能削減 |
| **成功コールバック** | OnRemoteBreachSucceeded（統計収集） | バニラ処理（統計なし） | デバッグ情報喪失 |
| **失敗コールバック** | OnRemoteBreachFailed（ペナルティ適用） | バニラ処理（限定的） | ペナルティ機能削減 |
| **StateSystem** | 3システム（Computer/Device/Vehicle） | バニラBlackboard | 状態管理簡素化 |
| **Minigame定義** | 9種類（3ターゲット×3難易度） | バニラ定義（1種類） | カスタマイズ性低下 |

**削除されたコード**:
- BaseRemoteBreachAction.reds (373行)
- DaemonImplementation.reds (184行)
- DaemonRegistration.reds (97行)
- DaemonUnlockStrategy.reds (372行)
- RemoteBreachProgram.reds (213行)
- RemoteBreachHelpers.reds:OnRemoteBreachSucceeded (lines 657-847)
- RemoteBreachHelpers.reds:OnRemoteBreachFailed (lines 849-901)

**新規実装**:
- RemoteBreachActions.reds:70-104 (@wrapMethod IsPossible)
- RemoteBreachActions.reds:112-155 (@wrapMethod GetCost)
- RemoteBreachStateSystem.reds (114行、簡素化版）

**移行計画での記載**: ⚠️ 部分的
> CustomAccessBreach → RemoteBreach (vanilla action)
>
> しかし、デーモンシステム削除・コールバック削除は記載なし

---

## 6. ネットワークデバイスアンロックロジック

### 旧仕様（CustomRemoteBreach）
```redscript
// DaemonUnlockStrategy.reds (372行) - 削除済み

// Strategy Pattern: 3種類（Computer/Device/Vehicle）
public class ComputerUnlockStrategy extends IDaemonUnlockStrategy {
  public func ExecuteUnlock(daemonType: String, deviceType: DeviceType, sourcePS: ref<DeviceComponentPS>, gameInstance: GameInstance) -> Void {
    // 1. Radius unlock (Basic daemon): 50m範囲内デバイス + 車両
    if unlockBasic {
      DeviceUnlockUtils.UnlockDevicesInRadius(computerPS, gameInstance);
      DeviceUnlockUtils.UnlockVehiclesInRadius(computerPS, gameInstance);
    }

    // 2. Network unlock: AccessPoint配下デバイス
    ComputerRemoteBreachUtils.UnlockNetworkDevices(computerPS, unlockBasic, unlockNPCs, unlockCameras, unlockTurrets);

    // 3. NPC unlock: 50m範囲内NPC
    if unlockNPCs {
      DeviceUnlockUtils.UnlockNPCsInRadius(computerPS, gameInstance);
    }

    // 4. Breach position記録
    RemoteBreachUtils.RecordBreachPosition(computerPS, gameInstance);
  }
}
```

**アーキテクチャ**: Strategy Pattern
- **IDaemonUnlockStrategy**: 抽象インターフェース
- **ComputerUnlockStrategy**: Computer専用ロジック
- **DeviceUnlockStrategy**: Device専用ロジック
- **VehicleUnlockStrategy**: Vehicle専用ロジック

**アンロック処理**: 4段階
1. **Radius unlock**: 50m範囲内standalone devices + vehicles
2. **Network unlock**: AccessPoint配下network devices
3. **NPC unlock**: 50m範囲内NPCs（NPC daemonのみ）
4. **Position記録**: RadialUnlockSystem統合

### 新仕様（バニラRemoteBreach）
```redscript
// バニラRemoteBreachはデフォルトアンロック処理を使用
// カスタムアンロックロジック: 削除
```

**アーキテクチャ**: バニラ処理委譲
- Strategy Pattern: なし
- Daemon実行: バニラMinigameSystemが処理

**アンロック処理**: バニラデフォルト
- AccessPoint配下デバイスのみアンロック
- Radius unlock: なし
- NPC unlock: なし
- Position記録: なし

### 影響分析

| 項目 | 旧仕様 | 新仕様 | 影響 |
|------|--------|--------|------|
| **Radius unlock** | あり（50m範囲） | なし | 機能削減 |
| **Vehicle unlock** | あり（Radiusに統合） | なし | 機能削減 |
| **NPC unlock** | あり（NPC daemon） | なし | 機能削減 |
| **Position記録** | あり（RadialUnlock統合） | なし | 機能削減 |
| **Strategy Pattern** | 3実装（Computer/Device/Vehicle） | なし | アーキテクチャ簡素化 |

**削除されたコード**:
- DaemonUnlockStrategy.reds (372行)
  - IDaemonUnlockStrategy (interface)
  - ComputerUnlockStrategy (119行)
  - DeviceUnlockStrategy (136行)
  - VehicleUnlockStrategy (117行)

**削除された機能**:
- `RemoteBreachUtils.UnlockNearbyNetworkDevices()` (RemoteBreachHelpers.reds:238)
- `ComputerRemoteBreachUtils.UnlockNetworkDevices()` (RemoteBreachHelpers.reds:401)

**移行計画での記載**: ❌ なし

---

## 7. 統計収集・ロギングシステム

### 旧仕様（CustomRemoteBreach）
```redscript
// RemoteBreachHelpers.reds:OnRemoteBreachSucceeded.ExecuteProgramsAndRewardsWithStats (lines 776-847) - 削除済み

private func ExecuteProgramsAndRewardsWithStats(activePrograms: array<TweakDBID>, device: wref<ScriptableDeviceComponentPS>) -> Void {
  let stats: ref<BreachSessionStats> = BreachSessionStats.Create("RemoteBreach", device.GetDeviceName());
  stats.minigameSuccess = true;
  stats.programsInjected = ArraySize(activePrograms);

  // 実行デーモン情報収集
  BreachStatisticsCollector.CollectExecutedDaemons(activePrograms, stats);

  // ネットワークデバイス統計収集
  BreachStatisticsCollector.CollectNetworkDeviceStats(networkDevices, unlockFlags, stats);

  // プログラム実行
  ProcessMinigamePrograms(activePrograms, device, GetGameInstance(), stats.executedNormalDaemons, "[RemoteBreach]");

  // Radial unlock統計収集
  BreachStatisticsCollector.CollectRadialUnlockStats(device, unlockFlags, stats, GetGameInstance());

  // 統計サマリーログ出力
  stats.Finalize();
  LogBreachSummary(stats);
}
```

**収集データ**:
- **ミニゲーム結果**: 成功/失敗、注入プログラム数
- **デーモン情報**: Basic/Camera/Turret/NPC実行フラグ
- **ネットワーク統計**: デバイスカウント（Camera/Turret/NPC/Basic）、アンロック数
- **Radial unlock統計**: 50m範囲内デバイス数、アンロック数

**ログ出力例**:
```
[RemoteBreach] Session completed: Computer_Network_AP
  - Minigame: Success (3 programs injected)
  - Daemons: Basic=✓, Camera=✓, Turret=✗, NPC=✗
  - Network: 12 devices (3 cameras, 2 turrets, 7 basic) - 12 unlocked
  - Radial: 5 devices in range - 3 unlocked
```

### 新仕様（バニラRemoteBreach）
```redscript
// 統計収集: なし
// ログ出力: なし（バニラデフォルトログのみ）
```

**収集データ**: なし

**ログ出力**: バニラMinigameSystemのデフォルトログのみ

### 影響分析

| 項目 | 旧仕様 | 新仕様 | 影響 |
|------|--------|--------|------|
| **統計収集** | 包括的（5カテゴリ） | なし | デバッグ困難 |
| **ログ出力** | 構造化（サマリー形式） | 最小限（バニラ） | トラブルシューティング困難 |
| **デーモン情報** | 実行済みデーモンリスト | なし | 振る舞い検証不可 |
| **ネットワーク統計** | デバイスカウント + アンロック数 | なし | 機能検証不可 |
| **開発体験** | リッチログ（開発支援） | ミニマル（本番のみ） | 開発効率低下 |

**削除されたコード**:
- RemoteBreachHelpers.reds:OnRemoteBreachSucceeded (lines 657-847)
- BreachSessionStats構造体（別ファイル、調査中）
- BreachStatisticsCollector クラス（別ファイル、調査中）

**移行計画での記載**: ❌ なし

---

## 8. 削除されたヘルパー構造体・ユーティリティ

### 削除された構造体（RemoteBreachHelpers.reds）

#### TargetingSetup (lines 175-183)
```redscript
@if(ModuleExists("HackingExtensions"))
public struct TargetingSetup {
  let isValid: Bool;
  let player: ref<PlayerPuppet>;
  let targetingSystem: ref<TargetingSystem>;
  let query: TargetSearchQuery;
  let sourcePos: Vector4;
  let breachRadius: Float;
}
```
**用途**: Radius unlock時のターゲティングシステムパラメータバンドル（ネスト削減）

#### UnlockFlags (lines 186-192)
```redscript
@if(ModuleExists("HackingExtensions"))
public struct UnlockFlags {
  let unlockBasic: Bool;
  let unlockNPCs: Bool;
  let unlockCameras: Bool;
  let unlockTurrets: Bool;
}
```
**用途**: デーモン別アンロックフラグバンドル（パラメータ数削減）

#### VehicleProcessResult (lines 195-198)
```redscript
@if(ModuleExists("HackingExtensions"))
public struct VehicleProcessResult {
  let vehicleFound: Bool;
  let unlocked: Bool;
}
```
**用途**: Vehicle処理結果（ネスト削減、`UnlockVehiclesInRadius()`用）

### 削除されたユーティリティクラス

#### RemoteBreachRAMUtils (lines 87-122)
```redscript
@if(ModuleExists("HackingExtensions"))
public abstract class RemoteBreachRAMUtils {
  public static func CheckAndLockRemoteBreachRAM(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
    // RAM不足アクションを非アクティブ化
  }
}
```
**用途**: RemoteBreachアクションのRAM可用性チェック + 非アクティブ化

**呼び出し元**: `ApplyPermissionsToActions()` (BreachProcessing.reds), `GetRemoteActions()` (MinigameProcessing.reds)

#### ProgramIDUtils (lines 124-169)
```redscript
@if(ModuleExists("HackingExtensions"))
public abstract class ProgramIDUtils {
  public static func ApplyProgramToSharedPS(programID: TweakDBID, sharedPS: ref<SharedGameplayPS>, gameInstance: GameInstance) -> Void;
  public static func IsAnyDaemonCompleted(sharedPS: ref<SharedGameplayPS>) -> Bool;
  public static func CreateBreachEventFromProgram(programID: TweakDBID, gameInstance: GameInstance) -> ref<SetBreachedSubnet>;
}
```
**用途**: Program TweakDBID → タイムスタンプフィールド マッピング

#### RemoteBreachUtils (lines 207-382)
```redscript
@if(ModuleExists("HackingExtensions"))
public abstract class RemoteBreachUtils {
  public static func RecordBreachPosition(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Void;
  public static func UnlockNearbyNetworkDevices(sourceEntity: wref<GameObject>, ...) -> RadialUnlockResult;
  private static func SetupDeviceTargeting(...) -> TargetingSetup;
  private static func ProcessNetworkDevice(...) -> RadialUnlockResult;
  private static func UnlockDeviceByType(...) -> Bool;
}
```
**用途**: RemoteBreach専用ユーティリティ（Position記録、Network unlock、Radius unlock）

#### ComputerRemoteBreachUtils (lines 401-482)
```redscript
@if(ModuleExists("HackingExtensions"))
public abstract class ComputerRemoteBreachUtils {
  public static func UnlockNetworkDevices(computerPS: ref<ComputerControllerPS>, ...) -> Void;
  private static func ProcessAccessPointDevices(...) -> Void;
  private static func CreateBreachEvent(...) -> ref<SetBreachedSubnet>;
  private static func ProcessNetworkConnectedDevice(...) -> Void;
  private static func ShouldUnlockDeviceType(...) -> Bool;
}
```
**用途**: Computer RemoteBreach専用ネットワークアンロック

#### RemoteBreachActionHelper (lines 598-713)
```redscript
public abstract class RemoteBreachActionHelper {
  public static func Initialize(action: ref<CustomAccessBreach>, devicePS: ref<ScriptableDeviceComponentPS>, actionName: CName) -> Void;
  private static func SetDynamicRAMCost(...) -> Void;
  public static func SetMinigameDefinition(...) -> Void;
  public static func GetCurrentDifficulty() -> GameplayDifficulty;
  public static func RemoveTweakDBRemoteBreach(...) -> Void;
}
```
**用途**: RemoteBreachアクション初期化ヘルパー（RAM計算、Minigame選択）

**削除理由**: 新実装ではバニラRemoteBreachを拡張するため、カスタムアクション初期化不要

### 影響分析

| カテゴリ | 削除数 | 機能喪失 | 影響 |
|---------|-------|---------|------|
| **構造体** | 3個 | パラメータバンドル | コード可読性低下 |
| **ユーティリティクラス** | 6個 | Radius unlock, Network unlock, 統計収集 | 機能削減 |
| **ヘルパーメソッド** | 20+ | 初期化、RAM計算、デバイスフィルタ | 重複コード増加 |

**移行計画での記載**: ❌ なし

---

## 9. HackingExtensions依存性削除

### 旧仕様（CustomRemoteBreach）
```redscript
@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

public class RemoteBreachAction extends BaseRemoteBreachAction {
  // CustomAccessBreach (HackingExtensions) に依存
}

public class DeviceDaemonAction extends HackProgramAction {
  // HackProgramAction (HackingExtensions.Programs) に依存
}
```

**依存クラス**:
- `CustomAccessBreach` - BaseRemoteBreachActionの親クラス
- `HackProgramAction` - DeviceDaemonActionの親クラス
- `CustomHackingSystem` - ミニゲーム管理システム
- `OnCustomHackingSucceeded` / `OnCustomHackingFailed` - コールバックベースクラス

**条件コンパイル**: `@if(ModuleExists("HackingExtensions"))`
- HackingExtensions未インストール時: RemoteBreach機能全体が無効化

### 新仕様（バニラRemoteBreach）
```redscript
// HackingExtensions import: なし
// 条件コンパイル: なし

@wrapMethod(ScriptableDeviceAction)
public func IsPossible(opt context: GetActionsContext) -> Bool {
  let result: Bool = wrappedMethod(context);

  let vanillaRemoteBreach: ref<RemoteBreach> = this as RemoteBreach;
  if !IsDefined(vanillaRemoteBreach) { return result; }

  // バニラRemoteBreachを拡張
}
```

**依存クラス**:
- `RemoteBreach` - バニラクラス（game/core/actions.script）
- `ScriptableDeviceAction` - バニラクラス（game/core/actions.script）

**条件コンパイル**: なし（常時有効）

### 影響分析

| 項目 | 旧仕様 | 新仕様 | 影響 |
|------|--------|--------|------|
| **外部依存** | あり（HackingExtensions） | なし | スタンドアロン化 |
| **条件コンパイル** | あり（14ファイル） | なし | コード簡素化 |
| **カスタムアクション** | あり（CustomAccessBreach） | なし（バニラ拡張） | 拡張性低下 |
| **カスタムデーモン** | あり（HackProgramAction） | なし | 機能削減 |
| **インストール必須** | HackingExtensions | なし | ユーザビリティ向上 |

**削除されたコード**:
- 全RemoteBreachファイルの `@if(ModuleExists("HackingExtensions"))` ガード
- CustomAccessBreach依存コード
- HackProgramAction依存コード

**移行計画での記載**: ✅ あり（タイトル）
> バニラRemoteBreach実装実行計画
>
> Goal: Replace HackingExtensions-dependent CustomRemoteBreach with vanilla RemoteBreach

---

## 10. まとめ: 仕様変更マトリックス

| # | 機能 | 旧仕様 | 新仕様 | 変更タイプ | 文書化 | 削除コード行数 |
|---|------|--------|--------|-----------|--------|--------------|
| 1 | **アンロック期限** | 一時的（10時間） | 永続 | ❌ Removed | ❌ NO | 240行 |
| 2 | **JackIn自動復元** | あり（期限切れ時） | なし | ❌ Removed | ❌ NO | 92行 |
| 3 | **可視性制御** | 中央集約（1ファイル） | 分散（3ファイル） | 🔄 Changed | ❌ NO | 318行 |
| 4 | **Daemonフィルタ** | 静的（CET定義） | 動的（ネットワーク） | 🔄 Changed | ⚠️ Partial | 79行 |
| 5 | **カスタムデーモン** | 4種類（Basic/Camera/Turret/NPC） | なし（バニラのみ） | ❌ Removed | ⚠️ Partial | 213行 |
| 6 | **成功コールバック** | あり（統計収集+ネットワークアンロック） | なし（バニラ処理のみ） | ❌ Removed | ⚠️ Partial | 191行 |
| 7 | **失敗コールバック** | あり（VFX+スタン+ロック） | 限定的（バニラ処理） | 🔄 Changed | ⚠️ Partial | 53行 |
| ~~8~~ | ~~**Minigame定義**~~ | ~~9種類（3ターゲット×3難易度）~~ | ~~1種類（バニラ）~~ | ~~🔄 Changed~~ | ~~⚠️ Partial~~ | ~~782行~~ |
| 9 | **ネットワークアンロック** | 4段階（Radius/Network/NPC/Position） | バニラ（Networkのみ） | ❌ Removed | ❌ NO | 372行 |
| 10 | **統計収集** | 包括的（5カテゴリ） | なし | ❌ Removed | ❌ NO | 190行 |
| ~~-~~ | ~~**HackingExtensions依存削除**~~ | ~~必須~~ | ~~なし~~ | ~~✅ Migration~~ | ~~✅ YES~~ | ~~（全体）~~ |

**変更タイプ凡例**:
- ❌ **Removed**: 機能削除（代替なし）
- 🔄 **Changed**: 仕様変更（別実装で代替）
- ✅ **Migration**: 移行目的（判断不要）

**合計削除コード**: 1,548行（14ファイル、Minigame定義782行 + ヘルパー1,028行除外）

**実際の仕様変更**: 8項目
- ✅ 判断不要: 2項目（HackingExtensions依存削除、Minigame定義削減 - **移行目的/設計判断**）
- ⚠️ 判断必要: 8項目（CustomHacking統合による機能喪失3項目を含む）

**文書化率**（判断必要な8項目のみ）:
- ✅ 文書化済み: 0項目（0%）
- ⚠️ 部分的: 4項目（50.0%）- #4, #5, #6, #7（移行計画で「CustomHacking → バニラ」と記載）
- ❌ 未文書化: 4項目（50.0%）

**CustomHacking統合による機能喪失**（セクション5より抽出）:
- **#5 カスタムデーモン削除**: DeviceDaemonAction（Basic/Camera/Turret/NPC）→ バニラデーモンのみ
- **#6 成功コールバック削除**: OnRemoteBreachSucceeded（統計収集+ボーナスデーモン+ネットワークアンロック）→ バニラ処理
- **#7 失敗コールバック削減**: OnRemoteBreachFailed（VFX+スタン+RemoteBreachロック）→ バニラ処理（限定的）
- ~~**#8 Minigame定義削減**~~: 9種類（Computer/Device/Vehicle × Easy/Medium/Hard）→ 1種類（バニラ）**[クローズ済み - 設計判断]**

**ヘルパー削除の分析結果**:
- **旧#11 ヘルパー削除**: 6クラス + 3構造体（1,028行）→ **削除済み**
- **理由**: すべてのヘルパーは既存項目（#5, #9）を支援するコードであり、独自の機能影響なし
- **内訳**:
  - RemoteBreachRAMUtils: RemoteBreachCostCalculator.redsに移植済み（機能維持）
  - ProgramIDUtils: #5カスタムデーモンを支援（既カウント）
  - RemoteBreachUtils: #9ネットワークアンロックを支援（既カウント）
  - ComputerRemoteBreachUtils: #9ネットワークアンロックを支援（既カウント）
  - RemoteBreachActionHelper: #5カスタムデーモンを支援（既カウント）
  - TargetingSetup/UnlockFlags/VehicleProcessResult: #9を支援（既カウント）

---

## 11. 推奨アクション

### A. 仕様変更の承認プロセス確立

**問題**: 移行計画は「完全再現」を目標としているが、事前の仕様変更説明なし

**推奨**:
1. **仕様変更セクション追加**: 移行計画に以下を追加
   - 削除される機能リスト（ユーザー影響含む）
   - 変更される機能リスト（Before/After比較）
   - 維持される機能リスト（互換性保証）
2. **影響分析**: 各変更のユーザー影響度評価（Critical/Major/Minor）
3. **承認プロセス**: 仕様変更承認後に実装開始

### B. 機能復元 vs 新仕様採用

**Option A: 旧機能復元** (推定8-12時間)
- 一時的アンロック復元（UnlockExpirationUtils.reds）
- JackIn自動復元復元（DeviceInteractionUtils.EnableJackInInteraction）
- カスタム統計収集復元（BreachSessionStats）
- Radius unlock復元（RemoteBreachUtils）

**Option B: 新仕様採用** (推定2-4時間)
- 移行計画修正（仕様変更セクション追加）
- ユーザー向けドキュメント更新（変更点ガイド）
- 設定項目整理（未使用設定削除）

**推奨**: **Option B + 段階的機能追加**
1. Phase 1: 新仕様文書化（このドキュメント）
2. Phase 2: コンパイルエラー修正
3. Phase 3: ユーザーフィードバック収集
4. Phase 4: 必要機能のみ復元（優先度順）

### C. ドキュメント改善

**移行計画に追加すべきセクション**:
```markdown
## ⚠️ 仕様変更

### 削除される機能
1. 一時的アンロック（10時間期限） → 永続アンロック
   - 理由: バニラRemoteBreachは永続アンロックのため
   - 影響: ミニゲーム再挑戦不可、JackIn再試行不可
   - 代替: なし（仕様変更）

2. JackIn自動復元 → 手動復元不可
   - 理由: 期限システム削除により不要
   - 影響: AccessPoint永続無効化
   - 代替: なし（仕様変更）

### 変更される機能
（なし - RAM計算式は仕様変更ではなくリファクタリング）

### 維持される機能
1. デバイスタイプ別フィルタ（Camera/Turret/NPC）
2. ブリーチ失敗ペナルティ（VFX/スタン/ロック）
3. Progressive unlock（Intelligence/Rarity/Cyberdeck）
```

---

## 12. 結論

**発見事実**:
- 移行計画は**14ファイル / 3,593行**を削除したが、**50.0%の仕様変更が未文書化**
- 最も重大な変更（一時的アンロック削除、JackIn自動復元削除）が事前説明なし
- 移行計画のタイトルは「実装計画」だが、実態は「移行計画 with 仕様変更」
- **RAM計算式は仕様変更ではなくリファクタリング**（旧実装も同じ計算式 `MaxRAM × percent ÷ 100`）
- **HackingExtensions依存削除は移行目的そのもの**（判断不要）
- **CustomHacking統合削除により3つの機能が喪失**（カスタムデーモン、成功/失敗コールバック）
- **Minigame定義削減は設計判断**（クローズ済み）
- **ヘルパー削除は重複**（既存項目#5/#9の支援コード、独自影響なし）

**根本原因**:
1. **移行計画の性質誤認**: "実装"ではなく"移行"であることの認識不足
2. **完全再現前提の欠如**: 「バニラ採用 = 仕様変更」の暗黙の前提
3. **影響分析の欠如**: 削除ファイルリストのみで、機能影響説明なし
4. **コード調査不足**: 旧実装の実際の挙動を確認せず推測で記載

**是正措置**:
1. ✅ **本ドキュメント作成**: 全仕様変更を網羅的に文書化（完了）
2. ✅ **RAM計算式誤記訂正**: 「仕様変更」→「リファクタリング」に修正（完了）
3. 🔄 **TODO更新**: 機能復元TODOに詳細情報追加（進行中）
4. ⏸️ **ユーザー判断**: 旧機能復元 vs 新仕様採用の意思決定待ち

**次のステップ**:
1. 本ドキュメントをユーザーに提示
2. Option A（復元）vs Option B（採用）の判断を仰ぐ
3. 選択に基づいてコンパイルエラー修正 + 機能実装
