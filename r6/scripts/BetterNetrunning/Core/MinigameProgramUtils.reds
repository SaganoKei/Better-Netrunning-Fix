// ============================================================================
// BetterNetrunning - Minigame Program Utilities
// ============================================================================
// Shared utility for processing minigame programs (daemons)
// Used by both AccessPoint breach and RemoteBreach
//
// PURPOSE:
// Provides centralized daemon execution logic to avoid code duplication
//
// FUNCTIONALITY:
// - PING execution: Executes PING from device position
// - Datamine rewards: Money/crafting material/shard drops
// - Quest programs: Special quest-specific programs
//
// ARCHITECTURE:
// - Global functions (no class dependency)
// - Callable from AccessPointControllerPS and PlayerPuppet
// - DRY principle (single source of truth)
//
// USAGE:
// - AccessPoint breach: BreachProcessing.reds
// - RemoteBreach: RemoteBreachNetworkUnlock.reds
// - UnconsciousNPC breach: RemoteBreachNetworkUnlock.reds
//
// DEPENDENCIES:
// - BetterNetrunning.Common.* (BNLog)
// ============================================================================

module BetterNetrunning.Core

import BetterNetrunningConfig.*

// ============================================================================
// MINIGAME PROGRAM PROCESSING
// ============================================================================

/*
 * Processes all minigame programs (bonus daemons + player uploaded)
 * Handles PING execution, Datamine rewards, and quest-specific programs
 *
 * PURPOSE:
 * Centralized daemon execution logic shared by AccessPoint and RemoteBreach
 *
 * RATIONALE:
 * - P0 FIX: RemoteBreach was missing daemon execution logic
 * - DRY principle: Avoids code duplication between breach types
 * - Consistency: Same behavior across all breach types
 *
 * ARCHITECTURE:
 * - Global function (no class dependency)
 * - Early return pattern for undefined parameters
 * - Switch-style conditionals for program type detection
 *
 * Parameters:
 *   minigamePrograms: Array of successfully uploaded daemon programs
 *   sourceDevice: Device that initiated the breach (for PING execution)
 *   gameInstance: GameInstance for system access
 *   logContext: Optional context string for logging (e.g., "[RemoteBreach]", "[AccessPoint]")
 */
public func ProcessMinigamePrograms(
  minigamePrograms: array<TweakDBID>,
  sourceDevice: wref<DeviceComponentPS>,
  gameInstance: GameInstance,
  opt logContext: String
) -> Void {
  if NotEquals(logContext, "") {
    BNDebug(logContext, "ProcessMinigamePrograms called - Program count: " + ToString(ArraySize(minigamePrograms)));
  }

  if !IsDefined(sourceDevice) {
    if NotEquals(logContext, "") {
      BNError(logContext, "Source device not defined - cannot process programs");
    }
    return;
  }

  let TS: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gameInstance);
  let player: ref<GameObject> = GetPlayer(gameInstance);

  let i: Int32 = 0;
  while i < ArraySize(minigamePrograms) {
    let programID: TweakDBID = minigamePrograms[i];

    // Quest-specific programs
    if Equals(programID, t"minigame_v2.FindAnna") {
      AddFact(gameInstance, n"Kab08Minigame_program_uploaded");
      if NotEquals(logContext, "") {
        BNDebug(logContext, "Quest program executed: FindAnna");
      }
    }
    else if Equals(programID, BNConstants.PROGRAM_NETWORK_LOOT_Q003()) {
      TS.GiveItemByItemQuery(player, t"Query.Q003CyberdeckProgram");
      if NotEquals(logContext, "") {
        BNDebug(logContext, "Quest program executed: NetworkLootQ003");
      }
    }
    // PING execution - REMOVED
    // REASON: Cannot implement single-device PING without extensive vanilla overrides
    // All PING-related functionality has been disabled
    else if Equals(programID, BNConstants.PROGRAM_NETWORK_PING_HACK()) {
      if NotEquals(logContext, "") {
        BNTrace(logContext, "[PING] PING daemon detected but execution is disabled (feature removed)");
      }
    }
    // Datamine loot programs
    else if Equals(programID, BNConstants.PROGRAM_DATAMINE_BASIC())
         || Equals(programID, BNConstants.PROGRAM_DATAMINE_ADVANCED())
         || Equals(programID, BNConstants.PROGRAM_DATAMINE_MASTER()) {
      ProcessDatamineLoot(programID, TS, player, logContext);
    }

    i += 1;
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// ============================================================================
// ExecutePingOnSingleDevice - REMOVED
// ============================================================================
// REASON: Cannot implement single-device PING without extensive vanilla overrides
// - PingDevice action calls PingDevicesNetwork() in CompleteAction()
// - Device.PulseNetwork() uses EPingType.SPACE (network-wide)
// - No vanilla API exists for single-device PING
// All PING-related functionality has been disabled
// ============================================================================

// ============================================================================
// ExecutePingFromDevice - REMOVED
// ============================================================================
// REASON: Manual PING execution causes network propagation issues
// Vanilla breach completion handler should execute PING daemon automatically
// This prevents network-wide propagation while maintaining PING functionality
// ============================================================================

/*
 * Processes Datamine program and awards loot
 * Handles money, crafting materials, and shard drops
 *
 * PURPOSE:
 * Reward distribution for Datamine daemons
 *
 * ARCHITECTURE:
 * - Switch-style conditionals for program type
 * - Uses TransactionSystem for item rewards
 * - Simplified reward calculation (vanilla uses complex formulas)
 *
 * DESIGN DECISION:
 * - Simplified reward amounts for consistency
 * - Vanilla calculations vary by difficulty/level
 * - Better Netrunning uses flat rates for predictability
 */
public func ProcessDatamineLoot(
  programID: TweakDBID,
  TS: ref<TransactionSystem>,
  player: ref<GameObject>,
  opt logContext: String
) -> Void {
  let baseMoney: Float = 0.0;
  let craftingMaterial: Bool = false;
  let baseShardDropChance: Float = 0.0;

  if Equals(programID, BNConstants.PROGRAM_DATAMINE_BASIC()) {
    baseMoney = 1.0;
    if NotEquals(logContext, "") {
      BNTrace(logContext, "Datamine V1: Money +1.0");
    }
  }
  else if Equals(programID, BNConstants.PROGRAM_DATAMINE_ADVANCED()) {
    baseMoney = 1.0;
    craftingMaterial = true;
    if NotEquals(logContext, "") {
      BNTrace(logContext, "Datamine V2: Money +1.0, Crafting Material");
    }
  }
  else if Equals(programID, BNConstants.PROGRAM_DATAMINE_MASTER()) {
    baseShardDropChance = 1.0;
    if NotEquals(logContext, "") {
      BNTrace(logContext, "Datamine V3: Shard Drop +1.0");
    }
  }

  // Award money (simplified calculation)
  if baseMoney > 0.0 {
    let moneyAmount: Int32 = RandRange(50, 150) * Cast<Int32>(baseMoney);
    TS.GiveItem(player, ItemID.CreateQuery(t"Items.money"), moneyAmount);
    if NotEquals(logContext, "") {
      BNDebug(logContext, "Awarded money: " + ToString(moneyAmount) + " eddies");
    }
  }

  // Award crafting material
  if craftingMaterial {
    TS.GiveItemByItemQuery(player, t"Query.QuickHackMaterial", 1u);
    if NotEquals(logContext, "") {
      BNDebug(logContext, "Awarded crafting material");
    }
  }

  // Award shard (simplified logic - 50% drop chance)
  if baseShardDropChance > 0.0 {
    let shouldDrop: Bool = RandF() < 0.5;
    if shouldDrop {
      TS.GiveItemByItemQuery(player, t"Query.QuickHackMaterial", 2u);
      if NotEquals(logContext, "") {
        BNDebug(logContext, "Awarded bonus crafting materials (shard drop)");
      }
    }
  }
}
