module BetterNetrunning.Breach

import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.RadialUnlock.*

/*
 * Breach processing module for Access Point minigame completion
 * Handles bonus daemon injection, base game processing, and Better Netrunning extensions
 *
 * ARCHITECTURE:
 * - RefreshSlaves(): @wrapMethod pattern (3-step workflow)
 * - Pre-processing: Bonus daemon injection before base game execution
 * - Base Game Processing: wrappedMethod black box (acceptable for mod compatibility)
 * - Post-processing: Progressive Subnet Unlocking, radial unlock, NPC PING
 *
 * MOD COMPATIBILITY (2025-10-12 Policy):
 * - Uses @wrapMethod to preserve mod compatibility
 * - Base game daemon effects (180s camera/turret) + Better Netrunning permanent unlocks coexist
 * - Acceptable trade-off: wrappedMethod() is black box, but compatibility is prioritized
 *
 * FEATURES:
 * - Bonus daemon injection (settings-based auto-add)
 * - Progressive unlock per device type (cameras, turrets, NPCs, basic devices)
 * - Radial unlock integration (50m radius breach tracking)
 * - NPC Breach PING execution
 */

/*
 * Wraps base game RefreshSlaves() with Better Netrunning extensions
 *
 * VANILLA DIFF: Wraps base game processing with pre/post-processing steps
 * RATIONALE: Preserves base game daemon effects while adding Better Netrunning features
 * @replaceMethod REJECTED (2025-10-12): Mod compatibility prioritized over Composed Method pattern
 *
 * MOD COMPATIBILITY:
 * - Allows other mods to hook RefreshSlaves() (e.g., Daemon Netrunning Revamp)
 * - Tested with: CustomHackingSystem, RadialBreach
 *
 * ACCEPTABLE TRADE-OFFS:
 * - wrappedMethod() is black box (76 lines of base game code from accessPointController.script:416-490)
 * - Debug complexity manageable with base game source reference
 * - Base game daemons (180s) + Better Netrunning permanent unlocks coexist
 *
 * ARCHITECTURE: 3-step workflow (max nesting depth 2 in post-processing)
 * REVIEW DATE: 2025-10-12
 */
@wrapMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  // ========================================
  // Pre-processing Step 1: Check if Unconscious NPC Breach
  // ========================================
  let isUnconsciousNPCBreach: Bool = this.IsUnconsciousNPCBreach();

  // Create statistics object with correct breach type
  let breachType: String = isUnconsciousNPCBreach ? "UnconsciousNPC" : "AccessPoint";
  let stats: ref<BreachSessionStats> = BreachSessionStats.Create(
    breachType,
    this.GetDeviceName()
  );

  if isUnconsciousNPCBreach {
    // Mark NPC as breached (Problem ① fix)
    this.MarkUnconsciousNPCAsDirectlyBreached();
  }

  // ========================================
  // Pre-processing Step 2: Bonus Daemon Injection
  // ========================================
  this.InjectBonusDaemons();

  // Get minigame programs for statistics
  let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(
    this.GetMinigameBlackboard().GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms)
  );
  stats.programsInjected = ArraySize(minigamePrograms);

  // Extract unlock flags (needed for post-processing and stats)
  let unlockFlags: BreachUnlockFlags = DaemonFilterUtils.ExtractUnlockFlags(minigamePrograms);
  stats.unlockBasic = unlockFlags.unlockBasic;
  stats.unlockCameras = unlockFlags.unlockCameras;
  stats.unlockTurrets = unlockFlags.unlockTurrets;
  stats.unlockNPCs = unlockFlags.unlockNPCs;

  // Collect executed daemon information for display
  BreachStatisticsCollector.CollectExecutedDaemons(minigamePrograms, stats);

  // ========================================
  // Base Game Processing (Black Box)
  // ========================================
  wrappedMethod(devices);
  stats.minigameSuccess = true; // RefreshSlaves only called on success

  // ========================================
  // Post-processing: Better Netrunning Extensions + Statistics
  // ========================================
  this.ApplyBetterNetrunningExtensionsWithStats(devices, unlockFlags, stats, isUnconsciousNPCBreach);

  // ========================================
  // Output Statistics Summary
  // ========================================
  stats.Finalize();
  LogBreachSummary(stats);
}

// ============================================================================
// Pre-processing Helpers
// ============================================================================

/*
 * Checks if current breach is an Unconscious NPC breach
 *
 * DETECTION METHOD: Check if Entity in blackboard is a ScriptedPuppet
 */
@addMethod(AccessPointControllerPS)
private final func IsUnconsciousNPCBreach() -> Bool {
  let entity: wref<Entity> = FromVariant<wref<Entity>>(
    this.GetMinigameBlackboard().GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity)
  );

  let npcPuppet: wref<ScriptedPuppet> = entity as ScriptedPuppet;
  return IsDefined(npcPuppet);
}

/*
 * Injects bonus daemons into Blackboard before base game processing
 * Statistics: Records program count after injection
 */
@addMethod(AccessPointControllerPS)
private final func InjectBonusDaemons() -> Void {
  let minigameBB: ref<IBlackboard> = this.GetMinigameBlackboard();
  let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(
    minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms)
  );

  // Apply bonus daemons (from Common/BonusDaemonUtils.reds)
  ApplyBonusDaemons(minigamePrograms, this.GetGameInstance(), "[AccessPoint]");

  // Write back to Blackboard
  minigameBB.SetVariant(
    GetAllBlackboardDefs().HackingMinigame.ActivePrograms,
    ToVariant(minigamePrograms)
  );
}

// ============================================================================
// Post-processing Helpers
// ============================================================================

/*
 * Applies Better Netrunning extensions after base game processing
 * NEW: Collects statistics during processing
 *
 * BUG FIX (2025-10-18):
 * - Issue: Unconscious NPC breach rolls back its own unlocks
 * - Root Cause: RollbackIncorrectVanillaUnlocks() runs after ProcessUnconsciousNPCBreachCompletion()
 * - Solution: Skip RollbackIncorrectVanillaUnlocks() for Unconscious NPC breaches
 */
@addMethod(AccessPointControllerPS)
private final func ApplyBetterNetrunningExtensionsWithStats(
  const devices: script_ref<array<ref<DeviceComponentPS>>>,
  unlockFlags: BreachUnlockFlags,
  stats: ref<BreachSessionStats>,
  isUnconsciousNPCBreach: Bool
) -> Void {
  // Get active programs
  let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(
    this.GetMinigameBlackboard().GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms)
  );

  BNTrace("BreachProcessing", s"ApplyBetterNetrunningExtensions - isUnconsciousNPCBreach: \(ToString(isUnconsciousNPCBreach))");

  // Step 0.5: Rollback incorrect vanilla unlocks (Problem ② fix)
  // CRITICAL: Skip for Unconscious NPC breaches (they handle unlocks in ProcessUnconsciousNPCBreachCompletion)
  if !isUnconsciousNPCBreach {
    BNTrace("BreachProcessing", "Executing RollbackIncorrectVanillaUnlocks (NOT Unconscious NPC breach)");
    this.RollbackIncorrectVanillaUnlocks(devices, unlockFlags);
  } else {
    BNTrace("BreachProcessing", "SKIPPED RollbackIncorrectVanillaUnlocks (Unconscious NPC breach detected)");
  }

  // Step 1: Execute Bonus Daemons
  ProcessMinigamePrograms(minigamePrograms, this, this.GetGameInstance(), stats.executedNormalDaemons, "[AccessPoint]");

  // Step 1.5: Unlock standalone devices/vehicles/NPCs in radius (using unified collector)
  this.UnlockStandaloneDevicesInBreachRadius(unlockFlags, stats);

  // Step 2: Apply Progressive Subnet Unlocking + Collect Statistics
  this.ApplyBreachUnlockToDevicesWithStats(devices, unlockFlags, stats);

  // Step 3: Record breach position for RadialBreach integration
  this.RecordNetworkBreachPosition(devices);

  // Step 4: Execute NPC Breach PING if applicable
  this.ExecuteNPCBreachPingIfNeeded(minigamePrograms);
}

// ============================================================================
// Pre-processing Helpers
// ============================================================================

/*
 * Marks unconscious NPC as directly breached (Problem ① fix)
 *
 * NOTE: ProcessUnconsciousNPCBreachCompletion() is now called from
 * NPCBreachExperience.reds, not here (to avoid duplicate processing)
 */
@addMethod(AccessPointControllerPS)
private final func MarkUnconsciousNPCAsDirectlyBreached() -> Void {
  let entity: wref<Entity> = FromVariant<wref<Entity>>(
    this.GetMinigameBlackboard().GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity)
  );

  let npcPuppet: wref<ScriptedPuppet> = entity as ScriptedPuppet;
  if !IsDefined(npcPuppet) {
    return;  // Not an NPC breach
  }

  BNInfo("UnconsciousNPC", "Detected unconscious NPC breach");

  let npcPS: ref<ScriptedPuppetPS> = npcPuppet.GetPuppetPS();
  if IsDefined(npcPS) {
    npcPS.m_betterNetrunningWasDirectlyBreached = true;
  }
}

/*
 * Unlock standalone devices in breach radius (Problem ① fix)
 * ARCHITECTURE: Uses BreachStatisticsCollector for unified radial unlock statistics
 */
@addMethod(AccessPointControllerPS)
private final func UnlockStandaloneDevicesInBreachRadius(unlockFlags: BreachUnlockFlags, stats: ref<BreachSessionStats>) -> Void {
  // Collect radial unlock statistics using unified collector
  BreachStatisticsCollector.CollectRadialUnlockStats(this, unlockFlags, stats, this.GetGameInstance());
}

/*
 * Unlock vehicles in breach radius (Problem ② fix)
 * DEPRECATED: Functionality merged into BreachStatisticsCollector.CollectRadialUnlockStats()
 * Kept for backward compatibility but not called
 */
@addMethod(AccessPointControllerPS)
private final func UnlockVehiclesInBreachRadius(unlockFlags: BreachUnlockFlags, stats: ref<BreachSessionStats>) -> Void {
  // No-op: Functionality moved to CollectRadialUnlockStats
}

/*
 * Unlock NPCs in breach radius (Problem ② fix)
 * DEPRECATED: Functionality merged into BreachStatisticsCollector.CollectRadialUnlockStats()
 * Kept for backward compatibility but not called
 */
@addMethod(AccessPointControllerPS)
private final func UnlockNPCsInBreachRadius(unlockFlags: BreachUnlockFlags, stats: ref<BreachSessionStats>) -> Void {
  // No-op: Functionality moved to CollectRadialUnlockStats
}

/*
 * Rollbacks incorrect vanilla unlocks (Problem ② fix)
 *
 * PURPOSE: Vanilla ProcessMinigameNetworkActions() unlocks ALL devices without checking unlockFlags
 *          This method reverts unlocks for device types that weren't successfully breached
 * ARCHITECTURE: Early return pattern, iterates devices and reverts incorrect breach flags
 *
 * BUG FIX (2025-10-12):
 * - Issue: NPC Subnet only success still unlocks vehicles (Basic devices)
 * - Root Cause: Vanilla wrappedMethod() calls ProcessMinigameNetworkActions() on all devices
 * - Solution: Revert breach flags for device types not in unlockFlags
 *
 * BUG FIX (2025-10-18):
 * - Issue: Unconscious NPC breach rolls back previously unlocked devices
 * - Root Cause: RollbackIncorrectVanillaUnlocks() unconditionally sets timestamp to 0.0,
 *               overwriting existing unlocks from previous breaches
 * - Solution: Only rollback if device was NOT already unlocked (timestamp == 0.0)
 *             Preserve existing unlock timestamps from previous breaches
 */
@addMethod(AccessPointControllerPS)
private final func RollbackIncorrectVanillaUnlocks(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];
    let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;

    if IsDefined(sharedPS) {
      let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

      // Check if this device type should NOT be unlocked
      if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
        // Get current timestamp to check if device was already unlocked
        let currentTimestamp: Float = 0.0;
        switch deviceType {
          case DeviceType.NPC:
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampNPCs;
            break;
          case DeviceType.Camera:
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampCameras;
            break;
          case DeviceType.Turret:
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampTurrets;
            break;
          default: // DeviceType.Basic
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampBasic;
            break;
        }

        // Only rollback if device was NOT already unlocked (preserve existing unlocks)
        if currentTimestamp == 0.0 {
          switch deviceType {
            case DeviceType.NPC:
              sharedPS.m_betterNetrunningUnlockTimestampNPCs = 0.0;
              break;
            case DeviceType.Camera:
              sharedPS.m_betterNetrunningUnlockTimestampCameras = 0.0;
              break;
            case DeviceType.Turret:
              sharedPS.m_betterNetrunningUnlockTimestampTurrets = 0.0;
              break;
            default: // DeviceType.Basic
              sharedPS.m_betterNetrunningUnlockTimestampBasic = 0.0;
              break;
          }

          // DEBUG: Rollback only logged at DEBUG level (non-critical operation)
          BNDebug("RollbackUnlock", "Reverted vanilla unlock for device (Type: " +
            DeviceTypeUtils.DeviceTypeToString(deviceType) + ")");
        } else {
          // Device was already unlocked by a previous breach - preserve it
          BNDebug("RollbackUnlock", "Preserved existing unlock for device (Type: " +
            DeviceTypeUtils.DeviceTypeToString(deviceType) +
            ", Timestamp: " + ToString(currentTimestamp) + ")");
        }
      }
    }

    i += 1;
  }
}

/*
 * Executes NPC Breach PING if PING program is present (DISABLED - feature removed)
 */
@addMethod(AccessPointControllerPS)
private final func ExecuteNPCBreachPingIfNeeded(minigamePrograms: array<TweakDBID>) -> Void {
  // PING execution disabled (cannot implement single-device PING without extensive vanilla overrides)
  // Silently skip if PING daemon detected
}

// ============================================================================
// Supporting Helpers (Reused by Pre/Post-processing)
// ============================================================================

// Helper: Gets hacking minigame blackboard (centralized access)
@addMethod(AccessPointControllerPS)
private final func GetMinigameBlackboard() -> ref<IBlackboard> {
  return GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
}

// ============================================================================
// Device Unlock Implementation (Statistics Version)
// ============================================================================

/*
 * Applies breach unlock to devices and collects statistics
 * ARCHITECTURE: Uses BreachStatisticsCollector for unified statistics collection
 */
@addMethod(AccessPointControllerPS)
private final func ApplyBreachUnlockToDevicesWithStats(
  const devices: script_ref<array<ref<DeviceComponentPS>>>,
  unlockFlags: BreachUnlockFlags,
  stats: ref<BreachSessionStats>
) -> Void {
  // Collect network device statistics using unified collector
  BreachStatisticsCollector.CollectNetworkDeviceStats(Deref(devices), unlockFlags, stats);

  // Apply unlock to all devices
  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];
    if IsDefined(device) {
      this.UnlockDevice(device, unlockFlags);
    }
    i += 1;
  }
}

/*
 * Unlocks single device (statistics collection handled by BreachStatisticsCollector)
 */
@addMethod(AccessPointControllerPS)
private final func UnlockDevice(
  device: ref<DeviceComponentPS>,
  unlockFlags: BreachUnlockFlags
) -> Void {
  let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
  if !IsDefined(sharedPS) {
    return;
  }

  // Determine device type
  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

  // Check if device should be unlocked
  if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
    return;
  }

  // Apply timestamp-based unlock using centralized logic
  let gameInstance: GameInstance = this.GetGameInstance();
  DeviceUnlockUtils.ApplyTimestampUnlock(
    device,
    gameInstance,
    unlockFlags.unlockBasic,
    unlockFlags.unlockNPCs,
    unlockFlags.unlockCameras,
    unlockFlags.unlockTurrets
  );
}

// Helper: Records network centroid position for radial unlock
@addMethod(AccessPointControllerPS)
private final func RecordNetworkBreachPosition(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  let centroid: Vector4 = this.CalculateNetworkCentroid(devices);

  // Only record if we found valid devices
  if centroid.X >= -999000.0 {
    RecordAccessPointBreachByPosition(centroid, this.GetGameInstance());
  }
}

// Helper: Calculates average position of all network devices
@addMethod(AccessPointControllerPS)
private final func CalculateNetworkCentroid(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Vector4 {
  let sumX: Float = 0.0;
  let sumY: Float = 0.0;
  let sumZ: Float = 0.0;
  let validDeviceCount: Int32 = 0;

  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];
    let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;

    if IsDefined(deviceEntity) {
      let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
      sumX += devicePosition.X;
      sumY += devicePosition.Y;
      sumZ += devicePosition.Z;
      validDeviceCount += 1;
    }
    i += 1;
  }

  // Return centroid if valid, otherwise return invalid position
  if validDeviceCount > 0 {
    return Vector4(sumX / Cast<Float>(validDeviceCount), sumY / Cast<Float>(validDeviceCount), sumZ / Cast<Float>(validDeviceCount), 1.0);
  }

  return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
}

// Helper: Processes final rewards (money + XP)
@addMethod(AccessPointControllerPS)
private final func ProcessFinalRewards(lootResult: BreachLootResult) -> Void {
  if lootResult.baseMoney >= 1.00 && this.ShouldRewardMoney() {
    this.RewardMoney(lootResult.baseMoney);
  }
  RPGManager.GiveReward(this.GetGameInstance(), t"RPGActionRewards.Hacking", Cast<StatsObjectID>(this.GetMyEntityID()));
}

// NOTE: ProcessMinigamePrograms() moved to MinigameProgramUtils.reds (shared utility)
// RATIONALE: DRY principle - shared by AccessPoint and RemoteBreach

// Helper: Processes loot program and updates result data
// NOTE: This is still used for vanilla loot processing (not daemon execution)
@addMethod(AccessPointControllerPS)
private final func ProcessLootProgram(programID: TweakDBID, result: script_ref<BreachLootResult>) -> Void {
  if programID == BNConstants.PROGRAM_DATAMINE_BASIC() {
    Deref(result).baseMoney += 1.00;
  } else if programID == BNConstants.PROGRAM_DATAMINE_ADVANCED() {
    Deref(result).baseMoney += 1.00;
    Deref(result).craftingMaterial = true;
  } else if programID == BNConstants.PROGRAM_DATAMINE_MASTER() {
    Deref(result).baseShardDropChance += 1.00;
  }
  Deref(result).shouldLoot = true;
  Deref(result).markForErase = true;
}

// Helper: Processes unlock program and updates unlock flags
@addMethod(AccessPointControllerPS)
private final func ProcessUnlockProgram(programID: TweakDBID, flags: script_ref<BreachUnlockFlags>) -> Void {
  if programID == BNConstants.PROGRAM_UNLOCK_QUICKHACKS() {
    Deref(flags).unlockBasic = true;
  } else if programID == BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS() {
    Deref(flags).unlockNPCs = true;
  } else if programID == BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS() {
    Deref(flags).unlockCameras = true;
  } else if programID == BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS() {
    Deref(flags).unlockTurrets = true;
  }
}

// Helper: Unlocks quickhacks based on device type (legacy compatibility - rarely used)
@addMethod(AccessPointControllerPS)
public final func ApplyDeviceTypeUnlock(device: ref<DeviceComponentPS>, unlockFlags: BreachUnlockFlags) -> Void {
  let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
  if !IsDefined(sharedPS) {
    return;
  }

  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

  if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
    return;
  }

  // Unlock quickhacks and set breach timestamp
  this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());

  let currentTime: Float = TimeUtils.GetCurrentTimestamp(this.GetGameInstance());
  TimeUtils.SetDeviceUnlockTimestamp(sharedPS, deviceType, currentTime);
}
