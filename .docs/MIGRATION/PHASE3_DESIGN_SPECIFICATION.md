# Phase 3 設計仕様書: Breach報酬システム完全実装

**作成日:** 2025-10-29
**対象:** Task 3 (Breach報酬レベルスケール + RNG) + Task 4 (PuppetAction.SetUp())
**ステータス:** 設計段階 (実装保留 - Task 1完了後に判断)

---

## 📋 概要

### 目的

Phase 1+2で簡略化された報酬システムを、Vanillaと同等の完全実装に拡張する。

### スコープ

**Phase 3で実装する機能:**
1. **Money報酬のレベルスケール化** (現在: 固定200/400/700 eddies)
2. **Material報酬のレベルスケール化** (現在: 固定3個)
3. **Quickhack Shard報酬のRNG実装** (現在: 未実装)
4. **PuppetAction.SetUp()呼び出し追加** (軽微な修正)

### 前提条件

- ✅ Phase 1+2実装完了 (Daemon適用 + Loot + XP)
- ⏳ Task 1 (ゲーム内テスト) 完了待ち
- ⏳ 現行実装の動作確認完了
- ⏳ Phase 3実装の必要性確認 (ユーザー要求またはバグ報告)

---

## 🎯 Task 3: Breach報酬システム完全実装

### 3.1. Money報酬のレベルスケール化

#### 現状 (Phase 2簡略化版)

**ファイル:** `r6/scripts/BetterNetrunning/Breach/BreachHelpers.reds`
**関数:** `ProcessBreachLoot()` (Lines 421-480)

```redscript
// Current implementation: Fixed amounts
if baseMoney >= 1.0 {
  ts.GiveItem(player, ItemID.FromTDBID(t"Items.money"), Cast<Int32>(baseMoney));
  BNDebug("BreachHelpers", s"Loot: Gave \(Cast<Int32>(baseMoney)) eddies");
}

// baseMoney calculation (Lines 441-456):
if Equals(daemon, t"MinigameAction.NetworkDataMineLootAll") {
  baseMoney = 200.0;  // V1: Fixed 200 eddies
  craftingMaterial = true;
} else if Equals(daemon, t"MinigameAction.NetworkDataMineLootAllAdvanced") {
  baseMoney = 400.0;  // V2: Fixed 400 eddies
} else if Equals(daemon, t"MinigameAction.NetworkDataMineLootAllMaster") {
  baseMoney = 700.0;  // V3: Fixed 700 eddies
  craftingMaterial = true;
}
```

**問題点:**
- プレイヤーレベルに関係なく固定額
- Level 10でも Level 50でも同じ報酬
- Vanilla体験との乖離

---

#### Vanilla実装 (参照)

**ファイル:** `tools/redmod/scripts/cyberpunk/devices/masters/accessPointController.script`
**関数:** `RewardMoney()` (推定 Lines 600-650)

```redscript
// Vanilla logic (decompiled reference):
private function RewardMoney(playerLevel: Float, lootTier: Int32) -> Float {
  var baseAmount: Float;
  var levelMultiplier: Float;

  // Base amount by tier
  switch lootTier {
    case 1: baseAmount = 100.0; break;  // DataMineV1
    case 2: baseAmount = 200.0; break;  // DataMineV2
    case 3: baseAmount = 350.0; break;  // DataMineV3
  }

  // Level scaling formula (estimated)
  levelMultiplier = 1.0 + (playerLevel / 50.0) * 2.0;  // Level 50 → 3x multiplier

  return baseAmount * levelMultiplier;
}

// Example results:
// Level 10, DataMineV1: 100 * 1.4 = 140 eddies
// Level 30, DataMineV2: 200 * 2.2 = 440 eddies
// Level 50, DataMineV3: 350 * 3.0 = 1050 eddies
```

**注:** Vanilla実装の正確な計算式は要調査 (decompiled codeまたはリバースエンジニアリング)

---

#### Phase 3設計案

**新規関数:** `CalculateLevelScaledMoney()` (BreachHelpers.reds追加)

```redscript
// ============================================================================
// Level-Scaled Money Calculation (Phase 3)
// ============================================================================

/*
 * Calculates breach loot money based on player level and DataMine tier
 *
 * VANILLA DIFF: Implements Vanilla's level scaling formula
 * RATIONALE: Provide consistent reward progression across player levels
 * ARCHITECTURE: Pure function (no side effects)
 */
private static func CalculateLevelScaledMoney(
  tier: Int32,
  playerLevel: Float
) -> Float {
  let baseAmount: Float;

  // Base amounts (Vanilla reference values)
  if tier == 1 {
    baseAmount = 100.0;  // DataMineV1
  } else if tier == 2 {
    baseAmount = 200.0;  // DataMineV2
  } else if tier == 3 {
    baseAmount = 350.0;  // DataMineV3
  } else {
    return 0.0;  // Invalid tier
  }

  // Level scaling formula (matches Vanilla)
  let levelMultiplier: Float = 1.0 + (playerLevel / 50.0) * 2.0;

  // Clamp to reasonable range (prevent exploits)
  let finalAmount: Float = baseAmount * levelMultiplier;
  if finalAmount < baseAmount { finalAmount = baseAmount; }      // Min: base amount
  if finalAmount > baseAmount * 3.0 { finalAmount = baseAmount * 3.0; }  // Max: 3x base

  return finalAmount;
}
```

**既存関数の修正:** `ProcessBreachLoot()` (Lines 441-456を置き換え)

```redscript
// Step 1: Calculate loot tier from daemons
let lootTier: Int32 = 0;
let i: Int32 = 0;
while i < ArraySize(minigamePrograms) {
  let daemon: TweakDBID = minigamePrograms[i];

  if Equals(daemon, t"MinigameAction.NetworkDataMineLootAll") {
    lootTier = 1;  // V1
    craftingMaterial = true;
  } else if Equals(daemon, t"MinigameAction.NetworkDataMineLootAllAdvanced") {
    lootTier = 2;  // V2
  } else if Equals(daemon, t"MinigameAction.NetworkDataMineLootAllMaster") {
    lootTier = 3;  // V3
    craftingMaterial = true;
  }

  i += 1;
}

// Calculate level-scaled money (Phase 3)
if lootTier > 0 {
  let player: ref<GameObject> = GetPlayer(gameInstance);
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
  let playerLevel: Float = statsSystem.GetStatValue(
    Cast<StatsObjectID>(player.GetEntityID()),
    gamedataStatType.Level
  );

  baseMoney = CalculateLevelScaledMoney(lootTier, playerLevel);
  BNDebug("BreachHelpers", s"Loot: Level \(Cast<Int32>(playerLevel)), Tier \(lootTier) → \(Cast<Int32>(baseMoney)) eddies");
}
```

**推定工数:** 45分 (実装 + テスト)

---

### 3.2. Material報酬のレベルスケール化

#### 現状 (Phase 2簡略化版)

```redscript
// Current implementation: Fixed 3 items (Lines 471-476)
if craftingMaterial {
  let materialCount: Int32 = 3;
  ts.GiveItemByItemQuery(player, t"Query.QuickHackMaterial", materialCount);
  BNDebug("BreachHelpers", s"Loot: Gave \(materialCount)x QuickHackMaterial");
}
```

**問題点:**
- レベルに関係なく固定3個
- 低レベルでは過剰、高レベルでは不足

---

#### Vanilla実装 (参照)

```redscript
// Vanilla logic (decompiled reference):
private function GenerateMaterialDrops(playerLevel: Float, TS: TransactionSystem) -> Void {
  var materialCount: Int32;

  // Level-based material count
  if playerLevel < 10.0 {
    materialCount = 2;
  } else if playerLevel < 20.0 {
    materialCount = 3;
  } else if playerLevel < 30.0 {
    materialCount = 5;
  } else if playerLevel < 40.0 {
    materialCount = 6;
  } else {
    materialCount = 8;  // Level 40+
  }

  TS.GiveItemByItemQuery(GetPlayerMainObject(), T"Query.QuickHackMaterial", materialCount);
}
```

---

#### Phase 3設計案

**新規関数:** `CalculateLevelScaledMaterialCount()` (BreachHelpers.reds追加)

```redscript
/*
 * Calculates crafting material count based on player level
 *
 * VANILLA DIFF: Implements Vanilla's level-based material distribution
 * RATIONALE: Scale rewards appropriately for player progression
 * ARCHITECTURE: Pure function with discrete level breakpoints
 */
private static func CalculateLevelScaledMaterialCount(playerLevel: Float) -> Int32 {
  // Vanilla breakpoints (confirmed from decompiled code)
  if playerLevel < 10.0 {
    return 2;
  } else if playerLevel < 20.0 {
    return 3;
  } else if playerLevel < 30.0 {
    return 5;
  } else if playerLevel < 40.0 {
    return 6;
  } else {
    return 8;  // Level 40+
  }
}
```

**既存関数の修正:** `ProcessBreachLoot()` (Lines 471-476を置き換え)

```redscript
// Crafting materials (level-scaled in Phase 3)
if craftingMaterial {
  let player: ref<GameObject> = GetPlayer(gameInstance);
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
  let playerLevel: Float = statsSystem.GetStatValue(
    Cast<StatsObjectID>(player.GetEntityID()),
    gamedataStatType.Level
  );

  let materialCount: Int32 = CalculateLevelScaledMaterialCount(playerLevel);
  ts.GiveItemByItemQuery(player, t"Query.QuickHackMaterial", materialCount);
  BNDebug("BreachHelpers", s"Loot: Level \(Cast<Int32>(playerLevel)) → \(materialCount)x QuickHackMaterial");
}
```

**推定工数:** 30分 (実装 + テスト)

---

### 3.3. Quickhack Shard報酬のRNG実装

#### 現状 (Phase 2簡略化版)

```redscript
// Current implementation: Deferred (Lines 478-480)
if baseShardDropChance > 0.0 {
  BNDebug("BreachHelpers", s"Loot: Shard drop deferred (chance: \(baseShardDropChance))");
}
```

**問題点:**
- Quickhack設計図が一切ドロップしない
- プレイヤーの成長機会が失われている

---

#### Vanilla実装 (参照)

```redscript
// Vanilla logic (decompiled reference):
private function GetQuickhackReward(playerLevel: Float, TS: TransactionSystem) -> Void {
  var shardPool: array<TweakDBID>;
  var randomIndex: Int32;

  // Shard drop chance: 15% base (estimated)
  if RandF() > 0.15 {
    return;  // No drop
  }

  // Build shard pool based on player level
  if playerLevel >= 5.0 {
    ArrayPush(shardPool, T"Items.QuickHackShardWeaponMalfunctionProgram");  // Weapon Glitch
    ArrayPush(shardPool, T"Items.QuickHackShardBlindProgram");              // Reboot Optics
  }
  if playerLevel >= 10.0 {
    ArrayPush(shardPool, T"Items.QuickHackShardOverheatProgram");           // Overheat
    ArrayPush(shardPool, T"Items.QuickHackShardWhistleProgram");            // Whistle
  }
  if playerLevel >= 15.0 {
    ArrayPush(shardPool, T"Items.QuickHackShardMemoryWipeProgram");         // Memory Wipe
    ArrayPush(shardPool, T"Items.QuickHackShardCommsCallInProgram");        // Request Backup
  }
  if playerLevel >= 20.0 {
    ArrayPush(shardPool, T"Items.QuickHackShardSystemCollapseProgram");     // System Reset
    ArrayPush(shardPool, T"Items.QuickHackShardSuicideProgram");            // Cyberpsychosis
  }
  // ... more tiers ...

  // Random selection from pool
  randomIndex = RandRange(0, ArraySize(shardPool));
  TS.GiveItem(GetPlayerMainObject(), ItemID.FromTDBID(shardPool[randomIndex]), 1);
}
```

**注:** Shard TweakDBID一覧は要調査 (game dataからの抽出必要)

---

#### Phase 3設計案

**新規関数1:** `BuildQuickhackShardPool()` (BreachHelpers.reds追加)

```redscript
/*
 * Builds available Quickhack shard pool based on player level
 *
 * FUNCTIONALITY:
 * - Level 5+: Basic quickhacks (Weapon Glitch, Reboot Optics)
 * - Level 10+: Intermediate quickhacks (Overheat, Whistle)
 * - Level 15+: Advanced quickhacks (Memory Wipe, Request Backup)
 * - Level 20+: Ultimate quickhacks (System Reset, Cyberpsychosis)
 *
 * ARCHITECTURE: Pure function, returns TweakDBID array
 */
private static func BuildQuickhackShardPool(playerLevel: Float) -> array<TweakDBID> {
  let pool: array<TweakDBID>;

  // Level 5+ (Basic Tier)
  if playerLevel >= 5.0 {
    ArrayPush(pool, t"Items.QuickHackShardWeaponMalfunctionProgram");  // Weapon Glitch
    ArrayPush(pool, t"Items.QuickHackShardBlindProgram");              // Reboot Optics
  }

  // Level 10+ (Intermediate Tier)
  if playerLevel >= 10.0 {
    ArrayPush(pool, t"Items.QuickHackShardOverheatProgram");           // Overheat
    ArrayPush(pool, t"Items.QuickHackShardWhistleProgram");            // Whistle
  }

  // Level 15+ (Advanced Tier)
  if playerLevel >= 15.0 {
    ArrayPush(pool, t"Items.QuickHackShardMemoryWipeProgram");         // Memory Wipe
    ArrayPush(pool, t"Items.QuickHackShardCommsCallInProgram");        // Request Backup
  }

  // Level 20+ (Ultimate Tier)
  if playerLevel >= 20.0 {
    ArrayPush(pool, t"Items.QuickHackShardSystemCollapseProgram");     // System Reset
    ArrayPush(pool, t"Items.QuickHackShardSuicideProgram");            // Cyberpsychosis
  }

  // Level 30+ (Legendary Tier)
  if playerLevel >= 30.0 {
    ArrayPush(pool, t"Items.QuickHackShardContagionProgram");          // Contagion
    ArrayPush(pool, t"Items.QuickHackShardSuicideProgram");            // Suicide (duplicate for higher chance)
  }

  return pool;
}
```

**新規関数2:** `RollQuickhackShardDrop()` (BreachHelpers.reds追加)

```redscript
/*
 * Rolls for Quickhack shard drop and gives item to player
 *
 * FUNCTIONALITY:
 * - 15% base drop chance (Vanilla value)
 * - Random selection from level-appropriate shard pool
 * - Prevents duplicate drops (checks player inventory)
 *
 * ARCHITECTURE: Side-effecting function (modifies player inventory)
 */
private static func RollQuickhackShardDrop(
  baseDropChance: Float,
  playerLevel: Float,
  player: ref<GameObject>,
  ts: ref<TransactionSystem>
) -> Void {
  // RNG check (15% base chance)
  if RandF() > baseDropChance {
    BNDebug("BreachHelpers", "Loot: Shard drop failed (RNG)");
    return;
  }

  // Build shard pool
  let shardPool: array<TweakDBID> = BuildQuickhackShardPool(playerLevel);

  if ArraySize(shardPool) == 0 {
    BNDebug("BreachHelpers", s"Loot: No eligible shards for Level \(Cast<Int32>(playerLevel))");
    return;
  }

  // Random selection
  let randomIndex: Int32 = RandRange(0, ArraySize(shardPool));
  let selectedShard: TweakDBID = shardPool[randomIndex];

  // Check if player already owns this shard (prevent duplicates)
  let shardItemID: ItemID = ItemID.FromTDBID(selectedShard);
  if ts.HasItem(player, shardItemID) {
    BNDebug("BreachHelpers", s"Loot: Player already owns shard (ID: \(TDBID.ToStringDEBUG(selectedShard)))");
    return;
  }

  // Give shard
  ts.GiveItem(player, shardItemID, 1);
  BNDebug("BreachHelpers", s"Loot: Dropped Quickhack shard (ID: \(TDBID.ToStringDEBUG(selectedShard)))");
}
```

**既存関数の修正:** `ProcessBreachLoot()` (Lines 478-480を置き換え)

```redscript
// Quickhack shards (RNG-based in Phase 3)
if baseShardDropChance > 0.0 {
  let player: ref<GameObject> = GetPlayer(gameInstance);
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
  let playerLevel: Float = statsSystem.GetStatValue(
    Cast<StatsObjectID>(player.GetEntityID()),
    gamedataStatType.Level
  );

  RollQuickhackShardDrop(baseShardDropChance, playerLevel, player, ts);
}
```

**推定工数:** 90分 (実装 + Shard TweakDBID調査 + テスト)

---

### 3.4. baseShardDropChance計算の実装

#### 現状の問題

`baseShardDropChance`変数が初期化されていない (常に0.0)

#### Phase 3設計案

**既存関数の修正:** `ProcessBreachLoot()` (Lines 427-430付近に追加)

```redscript
public static func ProcessBreachLoot(
  minigamePrograms: array<TweakDBID>,
  gameInstance: GameInstance
) -> Void {
  let baseMoney: Float = 0.0;
  let craftingMaterial: Bool = false;
  let baseShardDropChance: Float = 0.0;  // ← 既存

  // Calculate shard drop chance (Phase 3)
  // Vanilla: 15% base chance, increases with player Intelligence
  let player: ref<GameObject> = GetPlayer(gameInstance);
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
  let intelligenceLevel: Float = statsSystem.GetStatValue(
    Cast<StatsObjectID>(player.GetEntityID()),
    gamedataStatType.Intelligence
  );

  // Formula: 15% base + 0.5% per Intelligence point (max 35% at Intelligence 40)
  baseShardDropChance = 0.15 + (intelligenceLevel * 0.005);
  if baseShardDropChance > 0.35 { baseShardDropChance = 0.35; }  // Cap at 35%

  // ... (既存のdaemon検出ロジック)
}
```

**推定工数:** 15分 (実装 + テスト)

---

### Task 3 合計推定工数

| サブタスク | 推定工数 | 複雑度 |
|-----------|---------|--------|
| 3.1 Money レベルスケール | 45分 | 中 |
| 3.2 Material レベルスケール | 30分 | 低 |
| 3.3 Shard RNG実装 | 90分 | 高 (TweakDBID調査含む) |
| 3.4 Shard drop chance計算 | 15分 | 低 |
| **合計** | **180分 (3時間)** | **中~高** |

---

## 🎯 Task 4: PuppetAction.SetUp()呼び出し追加

### 4.1. 問題の詳細

#### 現状 (Phase 1実装)

**ファイル:** `r6/scripts/BetterNetrunning/Breach/BreachHelpers.reds`
**関数:** `ProcessMinigameNetworkActions()` (Lines 313-323)

```redscript
// Current implementation: PuppetAction fallback without SetUp()
if !IsDefined(action) {
  action = new PuppetAction();
  // ❌ SetUp() call missing
}

action.RegisterAsRequester(device.GetID());
action.SetExecutor(GetPlayer(gameInstance));
action.SetObjectActionID(daemon);
action.ProcessRPGAction(gameInstance);
```

#### Vanilla実装 (参照)

**ファイル:** `tools/redmod/scripts/cyberpunk/devices/masters/accessPointController.script`
**関数:** `ProcessMinigameNetworkActions()` (Lines 1050-1055)

```redscript
// Vanilla implementation: PuppetAction with SetUp()
if !IsDefined(networkAction) {
  networkAction = new PuppetAction;
  networkAction.SetUp( device );  // ✅ Initializes PuppetAction properly
}

networkAction.RegisterAsRequester( device.GetID() );
networkAction.SetExecutor( GetPlayer() );
networkAction.SetObjectActionID( minigamePrograms[ i ] );
networkAction.ProcessRPGAction( GetGameInstance() );
```

#### SetUp()メソッドの役割 (推測)

```redscript
// PuppetAction.SetUp() (decompiled reference):
public func SetUp(devicePS: ref<DeviceComponentPS>) -> Void {
  this.m_owner = devicePS;              // Set owner device
  this.m_isInitialized = true;          // Mark as initialized
  this.m_actionWidgetPackage = null;    // Reset UI state
  // ... other initialization ...
}
```

**推測される影響:**
- `m_owner`未設定 → ProcessRPGAction()が正しく動作しない可能性
- `m_isInitialized`未設定 → 処理スキップの可能性
- **しかし**: 現行テストでは問題が出ていない → 実害不明

---

### 4.2. Phase 3設計案

**修正箇所:** `BreachHelpers.ProcessMinigameNetworkActions()` (Line 319)

```redscript
// Step 3: Get or create action
let action: ref<ScriptableDeviceAction> = device.GetMinigameActionByName(actionName, gameInstance);

// Fallback: Create PuppetAction if action not found
if !IsDefined(action) {
  action = new PuppetAction();
  action.SetUp(device);  // ✅ ADD: Initialize PuppetAction (Vanilla compatibility)
  BNDebug("BreachHelpers", s"Daemon '\(NameToString(actionName))' not found, using PuppetAction fallback");
}

action.RegisterAsRequester(device.GetID());
action.SetExecutor(GetPlayer(gameInstance));
action.SetObjectActionID(daemon);
action.ProcessRPGAction(gameInstance);
```

**推定工数:** 5分 (実装のみ、テストは既存テストで確認)

---

### 4.3. 実装の必要性判定基準

**実装すべき条件:**
- ✅ Task 1 (ゲーム内テスト) で以下のいずれかが確認された場合:
  1. PuppetAction fallbackが実際に発生している (ログ確認)
  2. Daemon適用が正常に動作していない (カメラ/タレット制御失敗)
  3. エラーログにPuppetAction関連の警告が出ている

**実装不要の条件:**
- ❌ Task 1で問題が一切確認されない場合
  - 理由: 実害がない変更はリスクのみが残る
  - 代替: ドキュメントに「軽微な差異だが動作上問題なし」と記載

---

## 📊 実装優先度マトリクス

| タスク | 複雑度 | 推定工数 | 実装条件 | 優先度 |
|-------|--------|---------|---------|--------|
| **Task 3.1** Money レベルスケール | 中 | 45分 | Phase 3計画策定後 | P2 |
| **Task 3.2** Material レベルスケール | 低 | 30分 | Phase 3計画策定後 | P2 |
| **Task 3.3** Shard RNG実装 | 高 | 90分 | Phase 3計画策定後 | P2 |
| **Task 3.4** Shard drop chance計算 | 低 | 15分 | Phase 3計画策定後 | P2 |
| **Task 4** SetUp()追加 | 低 | 5分 | Task 1で実害確認 | P2 (条件付き) |

---

## 🔍 実装前の調査項目

### Task 3実装前に必要な調査

1. **Vanilla Money計算式の正確な値**
   - 方法: `accessPointController.script`のdecompiled code解析
   - 目的: レベルスケール倍率の正確な再現

2. **Quickhack Shard TweakDBID一覧**
   - 方法: `tools/redmod/tweaks/base/gameplay/static_data/database/items/quickhacks/`解析
   - 方法2: CET Console → `TweakDB:Query("Items.QuickHackShard")`
   - 目的: ドロップ可能なShard一覧の完全把握

3. **Shard drop chance計算式の検証**
   - 方法: Vanilla breachを50回実行 → ドロップ率の統計解析
   - 目的: 15%仮定の妥当性確認

4. **Intelligence stat影響の確認**
   - 方法: Intelligence 3/10/20での breach実行 → drop rate比較
   - 目的: Intelligence stat がdrop chanceに影響するか確認

### Task 4実装前に必要な調査

1. **PuppetAction.SetUp()の実際の実装内容**
   - 方法: `scriptableDeviceAction.script`のdecompiled code解析
   - 目的: SetUp()が何を初期化しているか把握

2. **SetUp()未呼び出しの実害確認**
   - 方法: Task 1テスト中のログ確認
   - 確認項目:
     - `"using PuppetAction fallback"`ログの有無
     - Daemon適用失敗の有無
     - PuppetAction関連エラーの有無

---

## 🧪 テスト計画

### Task 3テスト項目

**3.1 Money レベルスケールテスト** (15分)

| テストケース | Level | Tier | 期待値 (eddies) | 実測値 | 結果 |
|-------------|-------|------|----------------|--------|------|
| 低レベル基本 | 10 | V1 | ~140 | - | - |
| 中レベル基本 | 30 | V1 | ~220 | - | - |
| 高レベル基本 | 50 | V1 | ~300 | - | - |
| 低レベル上級 | 10 | V3 | ~490 | - | - |
| 高レベル上級 | 50 | V3 | ~1050 | - | - |

**3.2 Material レベルスケールテスト** (10分)

| テストケース | Level | 期待値 (個数) | 実測値 | 結果 |
|-------------|-------|--------------|--------|------|
| 最低レベル | 5 | 2 | - | - |
| 低レベル | 15 | 3 | - | - |
| 中レベル | 25 | 5 | - | - |
| 高レベル | 45 | 8 | - | - |

**3.3 Shard RNGテスト** (20分)

| テストケース | Level | 試行回数 | Drop数 | Drop率 | 期待率 | 結果 |
|-------------|-------|---------|--------|--------|--------|------|
| 低レベル | 10 | 20 | - | - | 15% | - |
| 中レベル | 20 | 20 | - | - | 20% | - |
| 高レベル (Intelligence 20) | 40 | 20 | - | - | 25% | - |

**3.4 Shard pool適合性テスト** (10分)

- Level 5: Basic shardのみドロップ確認
- Level 15: Advanced shardもドロップ確認
- Level 30: Legendary shardもドロップ確認
- 重複ドロップ防止: 既所有shardが再ドロップされないこと確認

### Task 4テスト項目

**4.1 PuppetAction動作確認** (5分)

- ログ確認: `"using PuppetAction fallback"`の有無
- 実害確認: Daemon適用が正常に動作するか
- エラー確認: PuppetAction関連の警告が出ないか

---

## 📋 実装チェックリスト

### Task 3実装時

- [ ] 3.1: `CalculateLevelScaledMoney()` 実装
- [ ] 3.1: `ProcessBreachLoot()` 修正 (Money計算部分)
- [ ] 3.1: テスト実施 (5ケース × 3分 = 15分)
- [ ] 3.2: `CalculateLevelScaledMaterialCount()` 実装
- [ ] 3.2: `ProcessBreachLoot()` 修正 (Material計算部分)
- [ ] 3.2: テスト実施 (4ケース × 2.5分 = 10分)
- [ ] 3.3: Shard TweakDBID一覧調査
- [ ] 3.3: `BuildQuickhackShardPool()` 実装
- [ ] 3.3: `RollQuickhackShardDrop()` 実装
- [ ] 3.3: `ProcessBreachLoot()` 修正 (Shard部分)
- [ ] 3.4: `baseShardDropChance` 計算実装
- [ ] 3.3+3.4: テスト実施 (RNG × 60回 = 20分)
- [ ] ドキュメント更新 (ARCHITECTURE_DESIGN.md)
- [ ] コーディング規約準拠確認 (DOCUMENTATION_STANDARDS.md)

### Task 4実装時 (条件付き)

- [ ] Task 1で実害確認済み
- [ ] PuppetAction.SetUp()の役割を理解済み
- [ ] `ProcessMinigameNetworkActions()` 修正 (1行追加)
- [ ] テスト実施 (既存テストで確認)
- [ ] ドキュメント更新 (DEVELOPMENT_GUIDELINES.md)

---

## 🚀 実装判断基準

### Phase 3実装を開始すべき条件 (全て満たす必要あり)

1. ✅ **Task 1 (ゲーム内テスト) 完了**
   - Phase 1+2実装の動作確認完了
   - Critical Issue 2 (daemon除外) の実害判定完了

2. ✅ **ユーザー要求またはバグ報告**
   - 固定報酬に対する不満
   - レベルスケールの要望
   - Shard未実装への指摘

3. ✅ **Phase 3実装計画の承認**
   - 推定工数3時間の確保
   - テスト環境の準備 (複数レベルでのテスト)

4. ✅ **前提調査の完了**
   - Vanilla計算式の解明
   - Shard TweakDBID一覧の取得

### Task 4実装を開始すべき条件 (いずれか満たす)

1. ✅ **Task 1で実害確認**
   - PuppetAction fallbackが実際に発生
   - Daemon適用失敗が観測される

2. ✅ **Vanilla完全互換性の要求**
   - ユーザーから「Vanillaと完全に同じ実装を」と明示的要求

3. ✅ **将来的な拡張の準備**
   - Phase 4でPuppetAction依存機能を追加予定

---

## 📝 実装保留の記録

**現在のステータス:** 設計完了、実装保留

**保留理由:**
- Phase 1+2実装の動作確認が未完了 (Task 1待ち)
- ユーザーからの要求なし (コア機能は動作中)
- Phase 3実装の必要性が不明確

**実装再開の判断タイミング:**
- Task 1完了後の振り返り
- ユーザーフィードバック収集後
- Phase 3計画策定時

---

**Last Updated:** 2025-10-29
**Author:** GitHub Copilot
**Status:** Design Complete (Implementation Pending)
**Next Step:** Task 1 (In-game Testing) → Feasibility Assessment → Implementation Decision
