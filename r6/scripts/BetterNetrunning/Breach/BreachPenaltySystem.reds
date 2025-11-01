// ============================================================================
// BetterNetrunning - Breach Penalty System
// ============================================================================
//
// PURPOSE:
// Apply penalties when players fail breach protocol minigames for game balance
//
// FUNCTIONALITY:
// - Failure detection via HackingMinigameState monitoring
// - Red VFX application for failure scenarios (2-3 seconds)
// - Type-specific lock recording (deviceID/timestamp/position)
// - Position reveal trace initiation via TracePositionOverhaul integration
// - Configurable penalty duration (default 10 minutes)
//
// ARCHITECTURE:
// - Single @wrapMethod on FinalizeNetrunnerDive() for all breach types
// - Type-specific lock recording strategies (3 mechanisms)
// - Guard Clause pattern with shallow nesting (max 2 levels)
// - Strategy pattern for penalty application
//

module BetterNetrunning.Breach
import BetterNetrunning.Logging.*
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Integration.*
import BetterNetrunning.RemoteBreach.Common.*
import BetterNetrunning.RemoteBreach.Core.*

/*
 * Breach Type Enum - identifies breach context for type-specific penalty
 * application and enables individual penalty toggles per breach type.
 *
 * Values:
 * - Unknown: Default/fallback (applies unified penalty)
 * - AccessPoint: Physical Access Point breach (MasterControllerPS)
 * - UnconsciousNPC: Unconscious NPC breach (ScriptedPuppetPS)
 * - RemoteBreach: RemoteBreach feature (RemoteBreachProgram)
 */
public enum BreachType {
  Unknown = 0,
  AccessPoint = 1,
  UnconsciousNPC = 2,
  RemoteBreach = 3
}

/*
 * Applies breach failure penalties across all breach types. Wraps game's base breach
 * completion handler to inject penalty logic for all breach types (AP Breach, Unconscious
 * NPC Breach, Remote Breach).
 *
 * Processing:
 * 1. Check if breach failed (state == HackingMinigameState.Failed)
 * 2. Check if penalty enabled in settings
 * 3. Apply full failure penalty (VFX + RemoteBreach lock + trace attempt)
 * 4. Call wrappedMethod() for base game processing
 *
 * State handling:
 * - HackingMinigameState.Succeeded → Early return, no penalty (wrappedMethod only)
 * - HackingMinigameState.Failed → Full penalty applied (skip and timeout both)
 * - HackingMinigameState.Unknown/InProgress → Early return (should not occur)
 *
 * Penalties (all failed states):
 * - Red VFX (2-3 seconds)
 * - RemoteBreach lock (10 minutes, 50m radius)
 * - Position reveal trace (60s upload, requires real netrunner NPC)
 *
 * Coverage:
 * - AP Breach: AccessPointControllerPS.FinalizeNetrunnerDive() → Covered
 * - Unconscious NPC Breach: AccessBreach.CompleteAction() → FinalizeNetrunnerDive() → Covered
 * - Remote Breach: RemoteBreachProgram explicitly calls FinalizeNetrunnerDive() → Covered
 *
 * Vanilla diff: Injects penalty
 * on Failed states before calling base processing. @wrapMethod with early-return guards →
 * apply penalty → wrappedMethod().
 *
 * @param state Current hacking minigame state
 */
@wrapMethod(ScriptableDeviceComponentPS)
public func FinalizeNetrunnerDive(state: HackingMinigameState) -> Void {
  // Early Return: Success or penalty disabled
  if NotEquals(state, HackingMinigameState.Failed) || !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
    wrappedMethod(state);
    return;
  }

  // Detect breach type for type-specific penalty
  let breachType: BreachType = this.DetectBreachType();

  // Early Return: Type-specific penalty disabled
  if !this.IsBreachPenaltyEnabledForType(breachType) {
    wrappedMethod(state);
    return;
  }

  // Penalty enabled and breach failed - apply appropriate penalty
  let gameInstance: GameInstance = this.GetGameInstance();
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    BNError("BreachPenalty", "Player not found, skipping penalty");
    wrappedMethod(state);
    return;
  }

  // Apply failure penalty (VFX + type-specific lock + trace attempt)
  ApplyFailurePenalty(player, this, gameInstance, breachType);

  // Call base game processing (network unlock, etc.)
  wrappedMethod(state);
}

/*
 * Suppresses NPC global alert on AP breach failure while preserving success path.
 *
 * Vanilla behavior: AccessPointControllerPS.FinalizeNetrunnerDive(Failed) calls
 * SendMinigameFailedToAllNPCs(), which sends MinigameFailEvent to all NPCs.
 * ScriptedPuppet.OnMinigameFailEvent() then calls NPCStatesComponent.AlertPuppet(this),
 * causing immediate hostile state.
 *
 * Rationale: Better Netrunning replaces instant alert with delayed traceback system
 * (30-60s upload, interruptible). Vanilla alert behavior breaks stealth gameplay and
 * removes tactical choices.
 *
 * Implementation: Wrap AccessPointControllerPS.FinalizeNetrunnerDive() to skip
 * SendMinigameFailedToAllNPCs() on failure. Success path remains unchanged (calls
 * super.FinalizeNetrunnerDive()).
 *
 * Coverage:
 * - AP Breach: ✓ Covered (no alert on failure)
 * - Unconscious NPC Breach: ✓ Covered (BreachHelpers.reds already disables ALARM)
 * - Remote Breach: ✓ Not affected (uses CustomAccessBreach, no MinigameFailEvent)
 *
 * Vanilla diff: Skips SendMinigameFailedToAllNPCs() on Failed to prevent immediate NPC alert.
 *
 * Implementation: @wrapMethod - success → wrappedMethod(), failure → emulate parent behavior
 * and apply penalty.
 *
 * @param state - Current hacking minigame state
 */
@wrapMethod(AccessPointControllerPS)
public func FinalizeNetrunnerDive(state: HackingMinigameState) -> Void {
  // Success path: Normal processing
  if Equals(state, HackingMinigameState.Succeeded) {
    wrappedMethod(state);
    return;
  }

  // Failure path: Skip SendMinigameFailedToAllNPCs() to prevent NPC alert
  if Equals(state, HackingMinigameState.Failed) {
    // Call parent (ScriptableDeviceComponentPS) directly to skip SendMinigameFailedToAllNPCs()
    // Note: Cannot call super.super in Redscript, so duplicate parent logic

    // Increment attempt counter (from ScriptableDeviceComponentPS.FinalizeNetrunnerDive)
    this.m_minigameAttempt += 1;

    // Execute ToggleNetrunnerDive action (from ScriptableDeviceComponentPS.FinalizeNetrunnerDive)
    let player: ref<GameObject> = this.GetPlayerMainObject();
    let toggleAction: ref<ToggleNetrunnerDive> = this.ActionToggleNetrunnerDive(true);
    toggleAction.SetExecutor(player);
    this.ExecutePSAction(toggleAction);

    // Apply failure penalty (VFX + device lock + trace attempt)
    let playerPuppet: ref<PlayerPuppet> = player as PlayerPuppet;
    if IsDefined(playerPuppet) {
      let gameInstance: GameInstance = this.GetGameInstance();
      let breachType: BreachType = this.DetectBreachType();
      ApplyFailurePenalty(playerPuppet, this, gameInstance, breachType);
    }

    BNInfo("BreachPenalty", "AP breach failed - NPC alert suppressed (SendMinigameFailedToAllNPCs skipped)");
    return;
  }

  // Unknown/InProgress states: Pass through
  wrappedMethod(state);
}

/*
 * Prevents NPC alert on Unconscious NPC breach failure.
 *
 * Vanilla behavior: AccessPointControllerPS.OnNPCBreachEvent(Failed) calls
 * SendMinigameFailedToAllNPCs(), which sends MinigameFailEvent to all NPCs.
 * This triggers NPCStatesComponent.AlertPuppet().
 *
 * Rationale: Same as FinalizeNetrunnerDive() - replace instant alert with delayed
 * traceback system. Maintains consistency across all breach types (AP, Unconscious NPC,
 * Remote).
 *
 * Implementation: Wrap OnNPCBreachEvent() to skip SendMinigameFailedToAllNPCs() on
 * failure. Success path calls SetIsBreached(true) and RefreshSlaves_Event() as vanilla.
 *
 * Coverage:
 * - AP Breach: ✓ Covered by FinalizeNetrunnerDive() wrap
 * - Unconscious NPC Breach: ✓ Covered by this wrap (OnNPCBreachEvent)
 * - Remote Breach: ✓ Not affected (uses CustomAccessBreach, no NPCBreachEvent)
 *
 * Vanilla diff: Skips
 * SendMinigameFailedToAllNPCs() on Failed; success path unchanged. @wrapMethod: branch on
 * evt.state, perform minimal handling, and return DoNotNotifyEntity.
 *
 * @param evt NPCBreachEvent carrying the result state
 * @return EntityNotificationType - vanilla result on success or DoNotNotifyEntity
 */
@wrapMethod(AccessPointControllerPS)
public func OnNPCBreachEvent(evt: ref<NPCBreachEvent>) -> EntityNotificationType {
  // Success path: Normal processing
  if Equals(evt.state, HackingMinigameState.Succeeded) {
    this.SetIsBreached(true);
    this.RefreshSlaves_Event();
    return EntityNotificationType.DoNotNotifyEntity;
  }

  // Failure path: Skip SendMinigameFailedToAllNPCs() to prevent NPC alert
  if Equals(evt.state, HackingMinigameState.Failed) {
    // Increment attempt counter (vanilla behavior)
    this.m_minigameAttempt += 1;

    // NOTE: Do NOT apply penalty here - UnconsciousNPC breach penalty is handled in
    // ScriptedPuppet.OnAccessPointMiniGameStatus() to ensure correct NPC entity is targeted
    // (OnNPCBreachEvent fires on AccessPoint, not NPC)

    // SKIP: SendMinigameFailedToAllNPCs() - prevents MinigameFailEvent → AlertPuppet()
    BNInfo("BreachPenalty", "Unconscious NPC breach failed - NPC alert suppressed (SendMinigameFailedToAllNPCs skipped)");
    return EntityNotificationType.DoNotNotifyEntity;
  }

  // Unknown/InProgress states: Pass through
  return wrappedMethod(evt);
}

/*
 * Detects breach context using blacklist + fallback strategy for type-specific
 * penalty application.
 *
 * Detection strategy (Blacklist + Fallback):
 * 1. RemoteBreach detection (PRIORITY): Check state systems (Computer/Device/Vehicle)
 * 2. AccessPoint detection: Check JackIn capability (HasPersonalLinkSlot)
 * 3. Fallback: Default to RemoteBreach (safer than AccessPoint)
 *
 * Rationale:
 * - State system check is most reliable for RemoteBreach detection
 * - HasPersonalLinkSlot() supports dynamic m_personalLinkComponent setup
 * - Fallback to RemoteBreach prevents incorrect AP penalty application
 *
 * @return BreachType enum identifying the breach context
 */
@addMethod(ScriptableDeviceComponentPS)
private func DetectBreachType() -> BreachType {
  // Strategy: Check RemoteBreach state systems first (most reliable indicator)
  // Fallback: Detect JackIn capability via HasPersonalLinkSlot() (runtime state)
  // Defensive: Default to RemoteBreach if detection fails (safer than AccessPoint)

  // Step 1: Check if device is being breached via RemoteBreach (state system check)
  if this.IsRemoteBreachingAnyDevice() {
    return BreachType.RemoteBreach;
  }

  // Step 2: Check if device supports JackIn (runtime capability check)
  // Note: HasPersonalLinkSlot() reflects runtime state (includes dynamic m_personalLinkComponent setup)
  if this.HasPersonalLinkSlot() {
    // Device has JackIn capability and not in RemoteBreach state → JackIn breach
    return BreachType.AccessPoint;
  }

  // Step 3: Fallback - Device has no JackIn capability → Must be RemoteBreach
  // Covers: Camera, Turret, Vehicle, and any future non-JackIn devices
  return BreachType.RemoteBreach;
}

/*
 * Checks if ANY device is being breached via RemoteBreach.
 *
 * Rationale: Extensible detection covering all RemoteBreach state systems:
 * - ComputerControllerPS: RemoteBreachStateSystem (Computer-specific)
 * - TerminalControllerPS: DeviceRemoteBreachStateSystem (generic device)
 * - VehicleComponentPS: VehicleRemoteBreachStateSystem (vehicle-specific)
 * - Future devices: Automatically covered by adding new state system checks
 *
 * Defensive: Returns false if state systems unavailable (safer than assuming RemoteBreach).
 *
 * @return True if device is being breached via RemoteBreach, false otherwise
 */
@addMethod(ScriptableDeviceComponentPS)
private func IsRemoteBreachingAnyDevice() -> Bool {
  let gameInstance: GameInstance = this.GetGameInstance();
  let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);

  // Defensive: If container unavailable, cannot determine state → return false
  if !IsDefined(container) {
    return false;
  }

  // Check 1: Computer RemoteBreach (RemoteBreachStateSystem)
  let computerPS: ref<ComputerControllerPS> = this as ComputerControllerPS;
  if IsDefined(computerPS) {
    let computerSystem: ref<RemoteBreachStateSystem> = container.Get(BNConstants.CLASS_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
    if IsDefined(computerSystem) {
      let currentComputer: wref<ComputerControllerPS> = computerSystem.GetCurrentComputer();
      if IsDefined(currentComputer) && currentComputer == computerPS {
        return true;
      }
    }
  }

  // Check 2: Terminal/Camera/Turret/Other RemoteBreach (DeviceRemoteBreachStateSystem)
  let deviceSystem: ref<DeviceRemoteBreachStateSystem> = container.Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as DeviceRemoteBreachStateSystem;
  if IsDefined(deviceSystem) {
    let currentDevice: wref<ScriptableDeviceComponentPS> = deviceSystem.GetCurrentDevice();
    if IsDefined(currentDevice) && currentDevice == this {
      return true;
    }
  }

  // Check 3: Vehicle RemoteBreach (VehicleRemoteBreachStateSystem)
  let vehiclePS: ref<VehicleComponentPS> = this as VehicleComponentPS;
  if IsDefined(vehiclePS) {
    let vehicleSystem: ref<VehicleRemoteBreachStateSystem> = container.Get(BNConstants.CLASS_VEHICLE_REMOTE_BREACH_STATE_SYSTEM()) as VehicleRemoteBreachStateSystem;
    if IsDefined(vehicleSystem) {
      let currentVehicle: wref<VehicleComponentPS> = vehicleSystem.GetCurrentVehicle();
      if IsDefined(currentVehicle) && currentVehicle == vehiclePS {
        return true;
      }
    }
  }

  // Not in any RemoteBreach state
  return false;
}

/*
 * Checks if penalty is enabled for specific breach type using individual
 * toggles per breach type (AP, NPC, RemoteBreach). Guard Clause pattern for
 * early return, type-specific settings from config.reds. Enables granular
 * control over penalty application per breach context.
 *
 * @param breachType The type of breach to check
 * @return True if penalty enabled for this type, false otherwise
 */
@addMethod(ScriptableDeviceComponentPS)
private func IsBreachPenaltyEnabledForType(breachType: BreachType) -> Bool {
  if Equals(breachType, BreachType.AccessPoint) {
    return BetterNetrunningSettings.APBreachFailurePenaltyEnabled();
  }
  if Equals(breachType, BreachType.UnconsciousNPC) {
    return BetterNetrunningSettings.NPCBreachFailurePenaltyEnabled();
  }
  if Equals(breachType, BreachType.RemoteBreach) {
    return BetterNetrunningSettings.RemoteBreachFailurePenaltyEnabled();
  }
  // Unknown type: Default to RemoteBreach penalty setting
  return BetterNetrunningSettings.RemoteBreachFailurePenaltyEnabled();
}

/*
 * Applies penalty based on breach type with unified VFX and trace, but
 * type-specific lock recording (deviceID for AP, timestamp for NPC, position
 * for RemoteBreach).
 *
 * Penalty breakdown:
 * - AccessPoint: VFX + Device Lock (PersistentID) + Trace
 * - UnconsciousNPC: VFX + NPC Lock (timestamp on PS) + Trace
 * - RemoteBreach: VFX + Position Lock (50m radius) + Trace
 *
 * Guard Clause pattern for entity validation, type-specific lock recording
 * strategies, unified VFX and trace application for consistency.
 *
 * @param player Player reference
 * @param devicePS Device persistent state
 * @param gameInstance Game instance
 * @param breachType Type of breach that failed
 */
public static func ApplyFailurePenalty(
  player: ref<PlayerPuppet>,
  devicePS: ref<ScriptableDeviceComponentPS>,
  gameInstance: GameInstance,
  breachType: BreachType
) -> Void {
  // Apply visual penalty effect (all types)
  ApplyBreachFailurePenaltyVFX(player, gameInstance);

  // Type-specific lock recording
  let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(deviceEntity) {
    BNDebug("BreachPenalty", "ApplyFailurePenalty: deviceEntity not resolved");
    TriggerTraceAttempt(player, gameInstance);
    return;
  }

  if Equals(breachType, BreachType.RemoteBreach) {
    // RemoteBreach: record timestamp + range lock
    RecordBreachFailureByType(player, devicePS, deviceEntity.GetWorldPosition(), gameInstance, breachType);
  } else if Equals(breachType, BreachType.AccessPoint) {
    // AP: record device timestamp for specific device lock
    if RecordBreachFailureTimestamp(devicePS, gameInstance) {
      // Disable JackIn interaction immediately after recording lock
      DeviceInteractionUtils.DisableJackInInteractionForAccessPoint(devicePS);
      BNDebug("BreachPenalty", "Disabled JackIn interaction for failed AP breach");
    }
  }
  // Note: UnconsciousNPC breach uses separate overload (ApplyFailurePenalty with ScriptedPuppet parameter)
  // to avoid sibling class casting issues (PuppetDeviceLinkPS ↔ ScriptableDeviceComponentPS)

  // Trigger position reveal trace (all types)
  TriggerTraceAttempt(player, gameInstance);
}

/*
 * ApplyFailurePenalty() overload for UnconsciousNPC breach using ScriptedPuppet directly
 * to avoid sibling class casting issues (PuppetDeviceLinkPS ↔ ScriptableDeviceComponentPS).
 *
 * Penalty components:
 * - Red glitch VFX
 * - Timestamp on ScriptedPuppetPS.m_betterNetrunningNPCBreachFailedTimestamp
 * - Position reveal trace attempt
 *
 * Reuses ApplyBreachFailurePenaltyVFX(), TriggerTraceAttempt(), and
 * RecordBreachFailureTimestamp() for DRY principle.
 *
 * @param player Player reference
 * @param npcPuppet Target NPC puppet
 * @param gameInstance Game instance
 */
public static func ApplyFailurePenalty(
  player: ref<PlayerPuppet>,
  npcPuppet: ref<ScriptedPuppet>,
  gameInstance: GameInstance
) -> Void {
  // Apply visual penalty effect
  ApplyBreachFailurePenaltyVFX(player, gameInstance);

  // Record NPC breach failure timestamp
  if IsDefined(npcPuppet) {
    let npcPS: ref<ScriptedPuppetPS> = npcPuppet.GetPuppetPS();
    if RecordBreachFailureTimestamp(npcPS, gameInstance) {
      // Force interaction refresh using vanilla method
      // DetermineInteractionStateByTask() queues DetermineInteractionState() via DelaySystem,
      // which calls GetValidChoices() to rebuild interaction menu
      npcPuppet.DetermineInteractionStateByTask();
      BNDebug("BreachPenalty", "Queued interaction state refresh for NPC");
    }
  } else {
    BNDebug("BreachPenalty", "ApplyFailurePenalty(NPC overload): npcPuppet not defined");
  }

  // Trigger position reveal trace
  TriggerTraceAttempt(player, gameInstance);
}

/*
 * ApplyBreachFailurePenaltyVFX() - Visual Penalty Effect
 *
 * Applies red VFX effect when breach fails.
 * Extracted as separate function for reusability across different breach types.
 *
 * VFX: disabling_connectivity_glitch_red (red, 2-3 seconds)
 *
 * @param player Player reference
 * @param gameInstance Game instance
 */
private static func ApplyBreachFailurePenaltyVFX(
  player: ref<PlayerPuppet>,
  gameInstance: GameInstance
) -> Void {
  GameObjectEffectHelper.StartEffectEvent(
    player,
    n"disabling_connectivity_glitch_red",
    false  // Not looping
  );
}

/*
 * Records breach failure timestamp on device-side persistent storage for AP breach.
 *
 * Processing:
 * - Validates devicePS can be cast to SharedGameplayPS
 * - Records current timestamp on m_betterNetrunningAPBreachFailedTimestamp
 * - Returns success/failure status
 *
 * Device-side persistent fields (SharedGameplayPS) correctly persist across save/load
 * unlike PlayerPuppet fields. Uses type-safe casting with IsDefined() check, single
 * responsibility (only timestamp recording), early return on validation failure.
 *
 * @param devicePS Device persistent state
 * @param gameInstance Game instance
 * @return True if timestamp recorded successfully, false if cast failed
 */
private static func RecordBreachFailureTimestamp(
  devicePS: ref<ScriptableDeviceComponentPS>,
  gameInstance: GameInstance
) -> Bool {
  let sharedPS: ref<SharedGameplayPS> = devicePS;
  if !IsDefined(sharedPS) {
    BNDebug("BreachPenalty", "RecordBreachFailureTimestamp(AP): SharedGameplayPS cast failed");
    return false;
  }

  let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
  sharedPS.m_betterNetrunningAPBreachFailedTimestamp = currentTime;
  BNDebug("BreachPenalty", "Recorded AP breach failure timestamp: " + ToString(currentTime));
  return true;
}

/*
 * RecordBreachFailureTimestamp() overload for NPC breach using ScriptedPuppetPS.
 *
 * Processing:
 * - Validates npcPS is defined
 * - Records current timestamp on m_betterNetrunningNPCBreachFailedTimestamp
 * - Returns success/failure status
 *
 * ScriptedPuppetPS persistent fields correctly persist across save/load. Same pattern
 * as AP breach for consistency (DRY principle). Uses type-safe validation with
 * IsDefined() check, single responsibility (only timestamp recording), early return
 * on validation failure.
 *
 * Note: ScriptedPuppetPS is sibling class to ScriptableDeviceComponentPS (cannot cast
 * between them).
 *
 * @param npcPS NPC persistent state
 * @param gameInstance Game instance
 * @return True if timestamp recorded successfully, false if npcPS not defined
 */
private static func RecordBreachFailureTimestamp(
  npcPS: ref<ScriptedPuppetPS>,
  gameInstance: GameInstance
) -> Bool {
  if !IsDefined(npcPS) {
    BNDebug("BreachPenalty", "RecordBreachFailureTimestamp(NPC): ScriptedPuppetPS not defined");
    return false;
  }

  let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
  npcPS.m_betterNetrunningNPCBreachFailedTimestamp = currentTime;
  BNDebug("BreachPenalty", "Recorded NPC breach failure timestamp: " + ToString(currentTime));
  return true;
}

/*
 * Dispatches breach failure recording to appropriate system based on breach type.
 * Acts as coordinator only - delegates actual recording to specialized systems.
 *
 * Delegation strategy:
 * - RemoteBreach → RemoteBreachLockSystem.RecordRemoteBreachFailure()
 * - AP/NPC → Should not reach here (handled in ApplyFailurePenalty directly)
 * - Unknown types → Fallback to RemoteBreach behavior
 *
 * BreachPenaltySystem no longer knows RemoteBreach internal implementation details -
 * each breach type's lock management is fully encapsulated in its own system. Uses
 * type-based dispatch pattern (coordinator role), delegation to specialized systems,
 * guard clause for invalid types.
 *
 * @param player Player reference
 * @param devicePS Device persistent state
 * @param failedPosition Position where breach failed
 * @param gameInstance Game instance
 * @param breachType Type of breach that failed
 */
private static func RecordBreachFailureByType(
  player: ref<PlayerPuppet>,
  devicePS: ref<ScriptableDeviceComponentPS>,
  failedPosition: Vector4,
  gameInstance: GameInstance,
  breachType: BreachType
) -> Void {
  // RemoteBreach: delegate to RemoteBreachLockSystem (timestamp + range lock)
  if Equals(breachType, BreachType.RemoteBreach) {
    RemoteBreachLockSystem.RecordRemoteBreachFailure(player, devicePS, failedPosition, gameInstance);
    return;
  }

  // AP/NPC: Should not reach here (handled in ApplyFailurePenalty directly)
  if Equals(breachType, BreachType.AccessPoint) || Equals(breachType, BreachType.UnconsciousNPC) {
    BNError("BreachPenalty", "AP/NPC breach incorrectly routed to position recording");
    return;
  }

  // Unknown type: fallback to RemoteBreach behavior
  BNWarn("BreachPenalty", "Unknown breach type - fallback to RemoteBreach recording");
  RemoteBreachLockSystem.RecordRemoteBreachFailure(player, devicePS, failedPosition, gameInstance);
}

/*
 * Triggers position reveal trace attempt after breach failure using vanilla
 * NPCPuppet.RevealPlayerPositionIfNeeded(). Requires TracePositionOverhaul MOD for
 * real netrunner detection.
 *
 * Trace characteristics:
 * - 60s upload time
 * - Interruptible by NPC death/combat/HackInterrupt StatusEffect
 * - No virtual netrunner fallback (maintains immersion by requiring actual NPC source)
 *
 * Advantages over instant alert: 60s delay, interruptible, preserves stealth during upload.
 *
 * @param player Player reference
 * @param gameInstance Game instance
 */
private static func TriggerTraceAttempt(
  player: ref<PlayerPuppet>,
  gameInstance: GameInstance
) -> Void {
  // Validation: Skip if player state prevents trace
  if !IsDefined(player) {
    BNError("BreachPenalty", "Player not found, cannot trigger trace");
    return;
  }

  if player.IsBeingRevealed() {
    BNDebug("BreachPenalty", "Player already being traced, skipping duplicate trace");
    return;
  }

  if player.IsInCombat() {
    BNDebug("BreachPenalty", "Player in combat, trace would be interrupted immediately - skipping");
    return;
  }

  // TracePositionOverhaul integration: Find real netrunner if available
  // Note: Gating function always available but returns null if TracePositionOverhaul not installed
  let searchRadius: Float = GetRadialBreachRange(gameInstance);
  let netrunner: wref<NPCPuppet> = TracePositionOverhaulGating.FindNearestValidTraceSource(player, gameInstance, searchRadius);
  if IsDefined(netrunner) {
    // Real netrunner found - use vanilla RevealPlayerPositionIfNeeded
    let result: Bool = NPCPuppet.RevealPlayerPositionIfNeeded(
      netrunner,
      player.GetEntityID(),
      false
    );
    if result {
      BNInfo("BreachPenalty", "Trace initiated via real netrunner (ID: " + ToString(netrunner.GetEntityID()) + ")");
      return;
    }
  }

  // No netrunner found - trace penalty skipped
  // Note: RemoteBreach locking still applied (non-trace penalty remains active)
  BNDebug("BreachPenalty", "No netrunner found - trace penalty skipped");
}

/*
 * Prevents lock bypass on save/load by intercepting SetHasPersonalLinkSlot() calls.
 *
 * Vanilla behavior: Device.OnGameAttached() calls SetHasPersonalLinkSlot(true) when
 * device has m_personalLinkComponent, unconditionally enabling JackIn interaction.
 *
 * Problem: Save/Load restores JackIn interaction even when device is locked by AP
 * breach failure penalty, bypassing the lock system.
 *
 * Solution: Intercept SetHasPersonalLinkSlot(true) calls and check breach lock status.
 * If device is locked, force isPersonalLinkSlotPresent = false to keep JackIn disabled.
 *
 * Architecture:
 * - @wrapMethod for compatibility with other mods
 * - Early return pattern for non-enable calls (false parameter)
 * - Lock check only when attempting to enable (true parameter)
 *
 * Persistence: Ensures penalty state survives save/load cycles by intercepting load-time
 * JackIn restoration in Device.OnGameAttached().
 *
 * @param isPersonalLinkSlotPresent Whether to enable/disable JackIn
 */
@wrapMethod(ScriptableDeviceComponentPS)
public func SetHasPersonalLinkSlot(isPersonalLinkSlotPresent: Bool) -> Void {
  // If disabling JackIn, pass through immediately (no lock check needed)
  if !isPersonalLinkSlotPresent {
    wrappedMethod(isPersonalLinkSlotPresent);
    return;
  }

  // Enabling JackIn - check if device is locked by AP breach failure
  let isLocked: Bool = BreachLockUtils.IsJackInLockedByAPBreachFailure(this);
  BNDebug("BreachPenalty", "SetHasPersonalLinkSlot(true) called - Lock status: " + ToString(isLocked));

  if isLocked {
    // Device is locked - force disable JackIn to maintain penalty
    wrappedMethod(false);
    BNInfo("BreachPenalty", "Prevented JackIn restoration on load (device locked by AP breach failure)");
    return;
  }

  // Not locked - allow normal enable
  wrappedMethod(isPersonalLinkSlotPresent);
}
