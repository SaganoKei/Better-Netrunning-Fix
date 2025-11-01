// ============================================================================
// BetterNetrunning - Breach Processing
// ============================================================================
//
// PURPOSE:
// Access Point minigame completion handling with Better Netrunning extensions
//
// FUNCTIONALITY:
// - Bonus daemon injection before base game processing
// - Progressive subnet unlocking per device type
// - Radial unlock integration (50m radius breach tracking)
// - NPC Breach PING execution
// - Base game daemon effects preservation
//
// ARCHITECTURE:
// - @wrapMethod pattern for mod compatibility
// - 3-step workflow: pre-processing → base game → post-processing
// - Composed Method pattern with shallow nesting (max 2 levels)
// - Blackbox base game processing (acceptable trade-off)
//

module BetterNetrunning.Breach

import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Utils.*
import BetterNetrunning.RadialUnlock.*

/*
 * Wraps base game RefreshSlaves() with Better Netrunning extensions.
 *
 * VANILLA DIFF: Adds pre-processing (bonus daemons, stats) and post-processing
 * (extensions + statistics) around base game daemon handling.
 */
@wrapMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  // ========================================
  // Pre-processing Step 1: Check if Unconscious NPC Breach
  // ========================================
  let isUnconsciousNPCBreach: Bool = this.IsUnconsciousNPCBreach();

  // Log breach target information (debug mode only)
  if !isUnconsciousNPCBreach {
    DebugUtils.LogAccessPointBreachTarget(this, "BreachStart");
  }

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
  // Pre-processing Step 2: Collect Displayed Daemons (Before Bonus Injection)
  // ========================================
  // CRITICAL: Must collect displayed daemons BEFORE InjectBonusDaemons()
  // Retrieve from ScriptableSystem (stored in FilterPlayerPrograms)
  let stateSystem: ref<DisplayedDaemonsStateSystem> = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance())
    .Get(BNConstants.CLASS_DISPLAYED_DAEMONS_STATE_SYSTEM()) as DisplayedDaemonsStateSystem;
  if IsDefined(stateSystem) {
    let displayedDaemons: array<TweakDBID> = stateSystem.GetDisplayedDaemons();
    BreachStatisticsCollector.CollectDisplayedDaemons(displayedDaemons, stats);
  }

  // ========================================
  // Pre-processing Step 3: Bonus Daemon Injection
  // ========================================
  this.InjectBonusDaemons();

  // Get minigame programs for statistics (after bonus injection)
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

  // ========================================
  // Base Game Processing (Black Box)
  // ========================================
  wrappedMethod(devices);
  stats.minigameSuccess = true; // RefreshSlaves only called on success

  // ========================================
  // Better Netrunning Extensions + Statistics
  // ========================================
  this.ApplyBetterNetrunningExtensionsWithStats(devices, unlockFlags, stats, isUnconsciousNPCBreach);

  // ========================================
  // Output Statistics Summary
  // ========================================
  stats.Finalize();
  LogBreachSummary(stats);
}

// ============================================================================
// Pre-processing Helper Methods
// ============================================================================

/*
 * Checks if current breach is an Unconscious NPC breach
 *
 * @return True if breach target is an NPC puppet
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
 */
@addMethod(AccessPointControllerPS)
private final func InjectBonusDaemons() -> Void {
  let minigameBB: ref<IBlackboard> = this.GetMinigameBlackboard();
  let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(
    minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms)
  );

  // Apply bonus daemons (from Common/BonusDaemonUtils.reds)
  BonusDaemonUtils.ApplyBonusDaemons(minigamePrograms, this.GetGameInstance(), "[AccessPoint]");

  // Write back to Blackboard
  minigameBB.SetVariant(
    GetAllBlackboardDefs().HackingMinigame.ActivePrograms,
    ToVariant(minigamePrograms)
  );
}

// ============================================================================
// Post-processing Helpers
// ============================================================================

// ============================================================================
// Post-processing Extensions
// ============================================================================

/*
 * Applies Better Netrunning extensions after base game processing.
 *
 * Uses Composed Method pattern with shallow nesting (max 2 levels).
 *
 * @param devices Array of network devices to process
 * @param unlockFlags Flags indicating which device types to unlock
 * @param stats Statistics collector for breach session
 * @param isUnconsciousNPCBreach Whether this is an unconscious NPC breach
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

  // Collect executed daemon information AFTER minigame completion
  BreachStatisticsCollector.CollectExecutedDaemons(minigamePrograms, stats);

  // Step 0.5: Rollback incorrect vanilla unlocks (Problem ② fix)
  this.RollbackIncorrectVanillaUnlocks(devices, unlockFlags);

  // Step 1: Unlock standalone devices/vehicles/NPCs in radius (using unified collector)
  this.UnlockStandaloneDevicesInBreachRadius(unlockFlags, stats);

  // Step 2: Apply Progressive Subnet Unlocking + Collect Statistics
  this.ApplyBreachUnlockToDevicesWithStats(devices, unlockFlags, stats);

  // Step 3: Record breach position for RadialBreach integration
  this.RecordNetworkBreachPosition(devices);

  // Step 4: Execute NPC Breach PING if applicable
  this.ExecuteNPCBreachPingIfNeeded(minigamePrograms);
}

// ============================================================================
// Unconscious NPC Breach Processing
// ============================================================================

/*
 * Marks unconscious NPC as directly breached.
 *
 * VANILLA DIFF: Problem ① fix - Sets m_betterNetrunningWasDirectlyBreached flag.
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

  let npcPS: ref<ScriptedPuppetPS> = npcPuppet.GetPuppetPS();
  if IsDefined(npcPS) {
    npcPS.m_betterNetrunningWasDirectlyBreached = true;
    DebugUtils.LogUnconsciousNPCBreachTarget(npcPuppet, npcPS, "BreachStart");
  }
}

/*
 * Unlocks standalone devices in breach radius.
 *
 * Uses BreachStatisticsCollector for unified radial unlock statistics.
 *
 * @param unlockFlags Flags indicating which device types to unlock
 * @param stats Statistics collector for breach session
 */
@addMethod(AccessPointControllerPS)
private final func UnlockStandaloneDevicesInBreachRadius(unlockFlags: BreachUnlockFlags, stats: ref<BreachSessionStats>) -> Void {
  // Collect radial unlock statistics using unified collector with network separation
  BreachStatisticsCollector.CollectRadialUnlockStats(this, this.GetID(), unlockFlags, stats, this.GetGameInstance());
}

/*
 * Rollbacks incorrect vanilla unlocks (Problem ② fix)
 *
 * VANILLA DIFF: ProcessMinigameNetworkActions() unlocks ALL devices without checking unlockFlags
 *
 * Operations:
 * - Reverts unlocks for device types that weren't successfully breached
 * - Only reverts if device was not previously unlocked (timestamp == 0.0)
 * - Preserves existing unlocks from prior breaches
 *
 * @param devices Array of network devices
 * @param unlockFlags Flags indicating successfully breached device types
 */
@addMethod(AccessPointControllerPS)
private final func RollbackIncorrectVanillaUnlocks(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];
    let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;

    if IsDefined(sharedPS) {
      let TargetType: TargetType = DeviceTypeUtils.GetDeviceType(device);

      // Check if this device type should NOT be unlocked
      if !DeviceTypeUtils.ShouldUnlockByFlags(TargetType, unlockFlags) {
        // Get current timestamp to check if device was already unlocked
        let currentTimestamp: Float = 0.0;
        switch TargetType {
          case TargetType.NPC:
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampNPCs;
            break;
          case TargetType.Camera:
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampCameras;
            break;
          case TargetType.Turret:
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampTurrets;
            break;
          default: // TargetType.Basic
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampBasic;
            break;
        }

        // Only rollback if device was NOT already unlocked (preserve existing unlocks)
        if currentTimestamp == 0.0 {
          switch TargetType {
            case TargetType.NPC:
              sharedPS.m_betterNetrunningUnlockTimestampNPCs = 0.0;
              break;
            case TargetType.Camera:
              sharedPS.m_betterNetrunningUnlockTimestampCameras = 0.0;
              break;
            case TargetType.Turret:
              sharedPS.m_betterNetrunningUnlockTimestampTurrets = 0.0;
              break;
            default: // TargetType.Basic
              sharedPS.m_betterNetrunningUnlockTimestampBasic = 0.0;
              break;
          }

          // DEBUG: Rollback only logged at DEBUG level (non-critical operation)
          BNDebug("RollbackUnlock", "Reverted vanilla unlock for device (Type: " +
            DeviceTypeUtils.DeviceTypeToString(TargetType) + ")");
        } else {
          // Device was already unlocked by a previous breach - preserve it
          BNDebug("RollbackUnlock", "Preserved existing unlock for device (Type: " +
            DeviceTypeUtils.DeviceTypeToString(TargetType) +
            ", Timestamp: " + ToString(currentTimestamp) + ")");
        }
      }
    }

    i += 1;
  }
}

/*
 * Executes NPC Breach PING if PING program is present
 *
 * DISABLED:
 * Feature removed - single-device PING cannot be implemented without extensive vanilla overrides
 *
 * @param minigamePrograms - Array of completed minigame programs
 */
@addMethod(AccessPointControllerPS)
private final func ExecuteNPCBreachPingIfNeeded(minigamePrograms: array<TweakDBID>) -> Void {
  // PING execution disabled (cannot implement single-device PING without extensive vanilla overrides)
  // Silently skip if PING daemon detected
}

// ============================================================================
// Supporting Helpers
// ============================================================================

/*
 * Gets hacking minigame blackboard
 *
 * @return HackingMinigame blackboard reference
 */
@addMethod(AccessPointControllerPS)
private final func GetMinigameBlackboard() -> ref<IBlackboard> {
  return GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
}

// ============================================================================
// Device Unlock Implementation
// ============================================================================

/*
 * Applies breach unlock to devices and collects statistics.
 *
 * Uses BreachStatisticsCollector for unified statistics collection.
 *
 * @param devices Array of network devices to unlock
 * @param unlockFlags Flags indicating which device types to unlock
 * @param stats Statistics collector for breach session
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
 * Unlocks single device based on unlock flags.
 *
 * Statistics collection handled by BreachStatisticsCollector.
 *
 * @param device Device power state to unlock
 * @param unlockFlags Flags indicating which device types to unlock
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
  let TargetType: TargetType = DeviceTypeUtils.GetDeviceType(device);

  // Check if device should be unlocked
  if !DeviceTypeUtils.ShouldUnlockByFlags(TargetType, unlockFlags) {
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

/*
 * Records network centroid position for radial unlock
 *
 * @param devices - Array of network devices
 */
@addMethod(AccessPointControllerPS)
private final func RecordNetworkBreachPosition(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  let centroid: Vector4 = this.CalculateNetworkCentroid(devices);

  // Only record if we found valid devices
  if centroid.X >= -999000.0 {
    RecordAccessPointBreachByPosition(centroid, this.GetGameInstance());
  }
}

/*
 * Calculates average position of all network devices
 *
 * @param devices - Array of network devices
 * @return Network centroid position, or invalid position if no devices
 */
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

/*
 * Unlocks quickhacks based on device type. Legacy compatibility method - rarely used.
 *
 * @param device Device power state to unlock
 * @param unlockFlags Flags indicating which device types to unlock
 */
@addMethod(AccessPointControllerPS)
public final func ApplyDeviceTypeUnlock(device: ref<DeviceComponentPS>, unlockFlags: BreachUnlockFlags) -> Void {
  let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
  if !IsDefined(sharedPS) {
    return;
  }

  let TargetType: TargetType = DeviceTypeUtils.GetDeviceType(device);

  if !DeviceTypeUtils.ShouldUnlockByFlags(TargetType, unlockFlags) {
    return;
  }

  // Unlock quickhacks and set breach timestamp
  this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());

  let currentTime: Float = TimeUtils.GetCurrentTimestamp(this.GetGameInstance());
  TimeUtils.SetDeviceUnlockTimestamp(sharedPS, TargetType, currentTime);
}
