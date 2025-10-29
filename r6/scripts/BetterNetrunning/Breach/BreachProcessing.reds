module BetterNetrunning.Breach

import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Breach.*
import BetterNetrunning.RemoteBreach.*
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
 * - Post-processing: Progressive Subnet Unlocking, radial unlock
 *
 * MOD COMPATIBILITY:
 * - Uses @wrapMethod to preserve mod compatibility
 * - Base game daemon effects (180s camera/turret) + Better Netrunning permanent unlocks coexist
 * - Acceptable trade-off: wrappedMethod() is black box, but compatibility is prioritized
 *
 * FEATURES:
 * - Bonus daemon injection (settings-based auto-add)
 * - Progressive unlock per device type (cameras, turrets, NPCs, basic devices)
 * - Radial unlock integration (50m radius breach tracking)
 */

/*
 * Wraps base game RefreshSlaves() with Better Netrunning extensions
 *
 * VANILLA DIFF: Wraps base game processing with pre/post-processing steps
 * RATIONALE: Preserves base game daemon effects while adding Better Netrunning features
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
 */
@wrapMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  // ========================================
  // Pre-processing Step 1: Check if Unconscious NPC Breach
  // ========================================
  let isUnconsciousNPCBreach: Bool = this.IsUnconsciousNPCBreach();

  // Create statistics object with correct breach type
  let breachType: String = isUnconsciousNPCBreach ? BNConstants.BREACH_TYPE_UNCONSCIOUS_NPC() : BNConstants.BREACH_TYPE_ACCESS_POINT();
  let stats: ref<BreachSessionStats> = BreachSessionStats.Create(
    breachType,
    this.GetDeviceName()
  );

  if isUnconsciousNPCBreach {
    // Mark NPC as breached for proper tracking
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
 * Collects statistics during processing
 *
 * FUNCTIONALITY:
 * - Rolls back incorrect vanilla unlocks for Unconscious NPC breaches
 * - Executes bonus daemons
 * - Unlocks standalone devices in radius
 * - Applies progressive subnet unlocking
 * - Records breach position for RadialBreach integration
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

  // Step 0.5: Rollback incorrect vanilla unlocks
  // CRITICAL: Skip for Unconscious NPC breaches to preserve their unlocks
  if !isUnconsciousNPCBreach {
    BNTrace("BreachProcessing", "Executing RollbackIncorrectVanillaUnlocks (NOT Unconscious NPC breach)");
    this.RollbackIncorrectVanillaUnlocks(devices, unlockFlags);
  } else {
    BNTrace("BreachProcessing", "SKIPPED RollbackIncorrectVanillaUnlocks (Unconscious NPC breach detected)");
  }

  // Step 1: Track executed daemons for statistics
  // All daemon execution (Quest programs, Datamine, etc.) handled by vanilla RefreshSlaves()
  BNDebug("[AccessPoint]", "Tracking executed daemons - Program count: " + ToString(ArraySize(minigamePrograms)));
  let i: Int32 = 0;
  while i < ArraySize(minigamePrograms) {
    ArrayPush(stats.executedNormalDaemons, minigamePrograms[i]);
    i += 1;
  }

  // Step 1.5: Apply shared breach extensions (DRY compliance - uses BreachHelpers)
  BreachHelpers.ExecuteRadiusUnlocks(this, unlockFlags, stats, this.GetGameInstance());

  // Step 2: Apply Progressive Subnet Unlocking + Collect Statistics (AccessPoint-specific)
  this.ApplyBreachUnlockToDevicesWithStats(devices, unlockFlags, stats);
}

// ============================================================================
// Pre-processing Helpers
// ============================================================================

/*
 * Marks unconscious NPC as directly breached
 *
 * FUNCTIONALITY: Sets breach flag on NPC's persistent state for tracking purposes
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

  BNInfo(BNConstants.BREACH_TYPE_UNCONSCIOUS_NPC(), "Detected unconscious NPC breach");

  let npcPS: ref<ScriptedPuppetPS> = npcPuppet.GetPuppetPS();
  if IsDefined(npcPS) {
    npcPS.m_betterNetrunningWasDirectlyBreached = true;
  }
}

/*
 * Rollbacks incorrect vanilla unlocks
 *
 * PURPOSE: Vanilla ProcessMinigameNetworkActions() unlocks ALL devices without checking unlockFlags
 *          This method reverts unlocks for device types that weren't successfully breached
 * ARCHITECTURE: Early return pattern, iterates devices and reverts incorrect breach flags
 *
 * VANILLA BEHAVIOR:
 * - Issue: NPC Subnet only success still unlocks vehicles (Basic devices)
 * - Root Cause: Vanilla wrappedMethod() calls ProcessMinigameNetworkActions() on all devices
 * - Solution: Revert breach flags for device types not in unlockFlags
 *
 * PRESERVATION LOGIC:
 * - Only rollback if device was NOT already unlocked (timestamp == 0.0)
 * - Preserves existing unlock timestamps from previous breaches
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

  let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(this.GetGameInstance());
  DeviceUnlockUtils.SetDeviceUnlockTimestamp(sharedPS, deviceType, currentTime);
}

// ============================================================================
// RemoteBreach Success Processing (ScriptableDeviceComponentPS)
// ============================================================================
//
// PURPOSE:
// Applies network unlock effects when RemoteBreach succeeds.
// Called from ScriptableDeviceComponentPS.FinalizeNetrunnerDive() wrapper.
//
// FUNCTIONALITY:
// - Daemon-based unlock: Extract unlock flags from ActivePrograms Blackboard
// - Network device unlock: Apply unlock to all connected devices
// - Radial unlock: Record breach position for 50m radius standalone unlock
// - Statistics logging: Log breach result for debugging
//
// ARCHITECTURE:
// - Wraps FinalizeNetrunnerDive() for consistent processing across all devices
// - Reuses DaemonFilterUtils.ExtractUnlockFlags() (DRY principle)
// - Delegates to RemoteBreachUtils for network unlock (consistent with HE RemoteBreach)
//
// DEPENDENCIES:
// - RemoteBreachStateSystem: Provides target device reference
// - DaemonFilterUtils: Extracts unlock flags from ActivePrograms
// - RemoteBreachUtils: Performs network unlock logic
// - RadialUnlock: Records position for standalone device unlock
// ============================================================================

/*
 * Extends FinalizeNetrunnerDive() to process RemoteBreach success
 *
 * VANILLA DIFF: Adds network unlock processing for RemoteBreach minigame success
 * RATIONALE: Defer unlock to FinalizeNetrunnerDive for consistent daemon detection
 * ARCHITECTURE: Guard Clause pattern (max 2 nesting levels)
 */
@wrapMethod(ScriptableDeviceComponentPS)
public func FinalizeNetrunnerDive(state: HackingMinigameState) -> Void {
    // Call base processing (penalty system, vanilla logic)
    wrappedMethod(state);

    // Early return: Not successful
    if NotEquals(state, HackingMinigameState.Succeeded) {
        return;
    }

    // Early return: Not RemoteBreach
    if !this.IsRemoteBreach() {
        return;
    }

    // Process RemoteBreach success
    this.ProcessRemoteBreachSuccess();
}

/*
 * Checks if current breach is RemoteBreach
 * Delegates to RemoteBreachStateSystem
 */
@addMethod(ScriptableDeviceComponentPS)
private func IsRemoteBreach() -> Bool {
    let gameInstance: GameInstance = this.GetGameInstance();
    let stateSystem: ref<RemoteBreachStateSystem> = GameInstance
        .GetScriptableSystemsContainer(gameInstance)
        .Get(n"BetterNetrunning.RemoteBreach.RemoteBreachStateSystem") as RemoteBreachStateSystem;

    if !IsDefined(stateSystem) {
        return false;
    }

    return stateSystem.HasPendingRemoteBreach();
}

/*
 * Applies network unlock effects for RemoteBreach success
 * Orchestrates daemon extraction, network unlock, radial unlock
 */
@addMethod(ScriptableDeviceComponentPS)
private func ProcessRemoteBreachSuccess() -> Void {
    let gameInstance: GameInstance = this.GetGameInstance();

    BNInfo(BNConstants.BREACH_TYPE_REMOTE_BREACH(), "RemoteBreach succeeded - processing network unlock");

    // Get ActivePrograms from minigame
    let activePrograms: array<TweakDBID> = this.GetActivePrograms(gameInstance);
    BNInfo(BNConstants.BREACH_TYPE_REMOTE_BREACH(), "Active programs count: " + ToString(ArraySize(activePrograms)));

    // Extract unlock flags from daemons
    let unlockFlags: BreachUnlockFlags = DaemonFilterUtils.ExtractUnlockFlags(activePrograms);

    // Apply network unlock
    this.ApplyRemoteBreachUnlock(unlockFlags, gameInstance);

    // Apply radial unlock (consistent with AccessPoint breach)
    this.ApplyRemoteBreachRadialUnlock(gameInstance);

    // Clear state system
    let stateSystem: ref<RemoteBreachStateSystem> = GameInstance
        .GetScriptableSystemsContainer(gameInstance)
        .Get(n"BetterNetrunning.RemoteBreach.RemoteBreachStateSystem") as RemoteBreachStateSystem;

    if IsDefined(stateSystem) {
        stateSystem.ClearRemoteBreachTarget();
    }

    BNDebug(BNConstants.BREACH_TYPE_REMOTE_BREACH(), "RemoteBreach processing complete");
}

/*
 * Retrieves ActivePrograms from minigame Blackboard
 * Returns executed daemon program IDs
 */
@addMethod(ScriptableDeviceComponentPS)
private func GetActivePrograms(gameInstance: GameInstance) -> array<TweakDBID> {
    let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gameInstance)
        .Get(GetAllBlackboardDefs().HackingMinigame);

    let programsVariant: Variant = minigameBB.GetVariant(
        GetAllBlackboardDefs().HackingMinigame.ActivePrograms
    );

    return FromVariant<array<TweakDBID>>(programsVariant);
}

/*
 * Applies network unlock to all connected devices
 * Uses RemoteBreachLockSystem for network traversal
 */
@addMethod(ScriptableDeviceComponentPS)
private func ApplyRemoteBreachUnlock(
    unlockFlags: BreachUnlockFlags,
    gameInstance: GameInstance
) -> Void {
    // Get network devices (includes this device)
    let networkDevices: array<ref<ScriptableDeviceComponentPS>> = RemoteBreachLockSystem.GetNetworkDevices(this, false);
    BNInfo(BNConstants.BREACH_TYPE_REMOTE_BREACH(), "Network devices count: " + ToString(ArraySize(networkDevices)));

    // Apply unlock to each device
    let i: Int32 = 0;
    while i < ArraySize(networkDevices) {
        let device: ref<ScriptableDeviceComponentPS> = networkDevices[i];
        this.ApplyDeviceUnlock(device, unlockFlags);
        i += 1;
    }
}

/*
 * Applies unlock flags to individual device
 * Reuses AccessPoint unlock logic for consistency
 */
@addMethod(ScriptableDeviceComponentPS)
private func ApplyDeviceUnlock(
    device: ref<ScriptableDeviceComponentPS>,
    unlockFlags: BreachUnlockFlags
) -> Void {
    if !IsDefined(device) {
        return;
    }

    let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

    // Check if this device type should be unlocked
    if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
        return;
    }

    // Unlock quickhacks
    let accessPointPS: ref<AccessPointControllerPS> = this as AccessPointControllerPS;
    if IsDefined(accessPointPS) {
        accessPointPS.QueuePSEvent(device, accessPointPS.ActionSetExposeQuickHacks());
    }

    // Set breach timestamp
    let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(this.GetGameInstance());
    DeviceUnlockUtils.SetDeviceUnlockTimestamp(device, deviceType, currentTime);

    BNDebug(BNConstants.BREACH_TYPE_REMOTE_BREACH(), "Unlocked device: " + device.GetDeviceName()
        + " (type: " + DeviceTypeUtils.DeviceTypeToString(deviceType) + ")");
}

/*
 * Records breach position for radial unlock
 * Delegates to DeviceUnlockUtils for network device unlock
 */
@addMethod(ScriptableDeviceComponentPS)
private func ApplyRemoteBreachRadialUnlock(gameInstance: GameInstance) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
    if !IsDefined(player) {
        return;
    }

    // Get device position
    let deviceEntity: ref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(deviceEntity) {
        return;
    }

    let devicePosition: Vector4 = deviceEntity.GetWorldPosition();

    // Record breach position for tracking
    DeviceUnlockUtils.RecordBreachPosition(this, gameInstance);

    // Extract unlock flags from current breach session
    let activePrograms: array<TweakDBID> = this.GetActivePrograms(gameInstance);
    let unlockFlags: BreachUnlockFlags = DaemonFilterUtils.ExtractUnlockFlags(activePrograms);

    // Unlock nearby network devices
    let result: RadialUnlockResult = DeviceUnlockUtils.UnlockNearbyNetworkDevices(
        player,
        gameInstance,
        unlockFlags.unlockBasic,
        unlockFlags.unlockNPCs,
        unlockFlags.unlockCameras,
        unlockFlags.unlockTurrets,
        BNConstants.BREACH_TYPE_REMOTE_BREACH()
    );

    BNInfo(BNConstants.BREACH_TYPE_REMOTE_BREACH(), "Radial network unlock: "
        + ToString(result.basicUnlocked) + "/" + ToString(result.basicCount) + " basic, "
        + ToString(result.cameraUnlocked) + "/" + ToString(result.cameraCount) + " cameras, "
        + ToString(result.turretUnlocked) + "/" + ToString(result.turretCount) + " turrets, "
        + ToString(result.npcUnlocked) + "/" + ToString(result.npcCount) + " NPCs");

    // Unlock nearby standalone devices
    player.UnlockNearbyStandaloneDevices(devicePosition, unlockFlags);

    BNDebug(BNConstants.BREACH_TYPE_REMOTE_BREACH(), "Radial unlock applied at position: "
        + ToString(devicePosition));
}

