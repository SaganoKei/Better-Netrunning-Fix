// ============================================================================
// Breach Penalty System - Breach Failure Penalty Handler
// ============================================================================
//
// PURPOSE:
// Apply penalties when players fail breach protocol minigames to maintain
// game balance and provide meaningful feedback for player actions.
//
// FUNCTIONALITY:
// - Failure Detection: Detect when breach minigame fails (HackingMinigameState.Failed)
// - VFX Application: Apply red visual effects for failure scenarios
// - Lock Recording: Type-specific (deviceID/timestamp/position)
// - Trace Trigger: Initiate position reveal trace via real netrunner (if TracePositionOverhaul)
//
// PENALTIES (Failure Only):
// - Red VFX (2-3 seconds, disabling_connectivity_glitch_red)
// - Type-specific lock (10 minutes default):
//   - AccessPoint: Device PersistentID lock (specific device only)
//   - UnconsciousNPC: Timestamp on ScriptedPuppetPS (specific NPC only)
//   - RemoteBreach: Hybrid lock (network hierarchy + radial scan, range configurable)
// - Position reveal trace (60s upload, requires real netrunner NPC via TracePositionOverhaul)
//
// SKIP vs FAILURE:
// - Currently: Both skip (ESC key) and failure (timeout) are treated as "Failed"
// - No differentiation: All Failed states receive full penalty
// - Rationale: HackingMinigameState enum has no "Skipped" state, TimerLeftPercent unreliable
//
// ARCHITECTURE:
// - Single @wrapMethod on FinalizeNetrunnerDive() covers all breach types
// - Type-specific lock recording strategy (3 mechanisms)
// - Guard Clause pattern for validation
// - Max nesting depth: 2 levels
//
// DEPENDENCIES:
// - BetterNetrunningConfig: Settings control (Enabled, LockDuration)
// - Core/DeviceUnlockUtils: Timestamp management
// - Breach/BreachLockSystem: Lock checking infrastructure
// - Integration/TracePositionOverhaulGating: Position reveal trace
// ============================================================================

module BetterNetrunning.Breach
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Integration.*
import BetterNetrunning.RemoteBreach.*

// ============================================================================
// Breach Type Enum
// ============================================================================
//
// FUNCTIONALITY:
// - Identifies breach context for type-specific penalty application
// - Enables individual penalty toggles per breach type
//
// VALUES:
// - Unknown: Default/fallback (applies unified penalty)
// - AccessPoint: Physical Access Point breach (MasterControllerPS)
// - UnconsciousNPC: Unconscious NPC breach (ScriptedPuppetPS)
// - RemoteBreach: RemoteBreach feature (RemoteBreachProgram)
// ============================================================================

public enum BreachType {
  Unknown = 0,
  AccessPoint = 1,
  UnconsciousNPC = 2,
  RemoteBreach = 3
}

// ============================================================================
// FinalizeNetrunnerDive() - Apply Breach Failure Penalties
// ============================================================================
//
// Wraps game's base breach completion handler to inject penalty logic for all
// breach types (AP Breach, Unconscious NPC Breach, Remote Breach).
//
// PROCESSING:
// 1. Check if breach failed (state == HackingMinigameState.Failed)
// 2. Check if penalty enabled in settings
// 3. Apply full failure penalty (VFX + RemoteBreach lock + trace attempt)
// 4. Call wrappedMethod() for base game processing
//
// STATE HANDLING:
// - HackingMinigameState.Succeeded → Early return, no penalty (wrappedMethod only)
// - HackingMinigameState.Failed → Full penalty applied (skip and timeout both)
// - HackingMinigameState.Unknown/InProgress → Early return (should not occur)
//
// PENALTIES (All Failed States):
// - Red VFX (2-3 seconds)
// - RemoteBreach lock (10 minutes, 50m radius)
// - Position reveal trace (60s upload, requires real netrunner NPC)
//
// COVERAGE:
// - AP Breach: AccessPointControllerPS.FinalizeNetrunnerDive() → Covered
// - Unconscious NPC Breach: AccessBreach.CompleteAction() → FinalizeNetrunnerDive() → Covered
// - Remote Breach: RemoteBreachProgram explicitly calls FinalizeNetrunnerDive() → Covered
// ============================================================================

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

// ============================================================================
// AccessPointControllerPS.FinalizeNetrunnerDive() - Disable NPC Alert on Failure
// ============================================================================
//
// VANILLA BEHAVIOR:
// AccessPointControllerPS.FinalizeNetrunnerDive(Failed) calls SendMinigameFailedToAllNPCs(),
// which sends MinigameFailEvent to all NPCs. ScriptedPuppet.OnMinigameFailEvent() then calls
// NPCStatesComponent.AlertPuppet(this), causing immediate hostile state.
//
// RATIONALE:
// Better Netrunning replaces instant alert with delayed traceback system (30-60s upload,
// interruptible). Vanilla alert behavior breaks stealth gameplay and removes tactical choices.
//
// IMPLEMENTATION:
// Wrap AccessPointControllerPS.FinalizeNetrunnerDive() to skip SendMinigameFailedToAllNPCs()
// on failure. Success path remains unchanged (calls super.FinalizeNetrunnerDive()).
//
// COVERAGE:
// - AP Breach: ✓ Covered (no alert on failure)
// - Unconscious NPC Breach: ✓ Covered (BreachHelpers.reds already disables ALARM)
// - Remote Breach: ✓ Not affected (uses CustomAccessBreach, no MinigameFailEvent)
// ============================================================================

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

// ============================================================================
// AccessPointControllerPS.OnNPCBreachEvent() - Disable NPC Alert on Unconscious NPC Breach Failure
// ============================================================================
//
// VANILLA BEHAVIOR:
// AccessPointControllerPS.OnNPCBreachEvent(Failed) calls SendMinigameFailedToAllNPCs(),
// which sends MinigameFailEvent to all NPCs. This triggers NPCStatesComponent.AlertPuppet().
//
// RATIONALE:
// Same as FinalizeNetrunnerDive() - replace instant alert with delayed traceback system.
// Maintains consistency across all breach types (AP, Unconscious NPC, Remote).
//
// IMPLEMENTATION:
// Wrap OnNPCBreachEvent() to skip SendMinigameFailedToAllNPCs() on failure.
// Success path calls SetIsBreached(true) and RefreshSlaves_Event() as vanilla.
//
// COVERAGE:
// - AP Breach: ✓ Covered by FinalizeNetrunnerDive() wrap
// - Unconscious NPC Breach: ✓ Covered by this wrap (OnNPCBreachEvent)
// - Remote Breach: ✓ Not affected (uses CustomAccessBreach, no NPCBreachEvent)
// ============================================================================

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

// ============================================================================
// Helper: DetectBreachType() - Identify Breach Context
// ============================================================================
//
// FUNCTIONALITY:
// - Detects breach context using blacklist + fallback strategy
// - Enables type-specific penalty application
//
// DETECTION STRATEGY (Blacklist + Fallback):
// 1. RemoteBreach detection (PRIORITY): Check state systems (Computer/Device/Vehicle)
// 2. AccessPoint detection: Check JackIn capability (HasPersonalLinkSlot)
// 3. Fallback: Default to RemoteBreach (safer than AccessPoint)
//
// RATIONALE:
// - State system check is most reliable for RemoteBreach detection
// - HasPersonalLinkSlot() supports dynamic m_personalLinkComponent setup
// - Fallback to RemoteBreach prevents incorrect AP penalty application
// ============================================================================

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

// Helper: Check if ANY device is being breached via RemoteBreach
// RATIONALE: Extensible detection covering all RemoteBreach state systems
//   - ComputerControllerPS: RemoteBreachStateSystem (Computer-specific)
//   - TerminalControllerPS: DeviceRemoteBreachStateSystem (generic device)
//   - VehicleComponentPS: VehicleRemoteBreachStateSystem (vehicle-specific)
//   - Future devices: Automatically covered by adding new state system checks
// DEFENSIVE: Returns false if state systems unavailable (safer than assuming RemoteBreach)
@addMethod(ScriptableDeviceComponentPS)
private func IsRemoteBreachingAnyDevice() -> Bool {
  let gameInstance: GameInstance = this.GetGameInstance();
  let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);

  // Defensive: If container unavailable, cannot determine state → return false
  if !IsDefined(container) {
    return false;
  }

  // Check 0: RemoteBreach (RemoteBreachStateSystem)
  let remoteBreachSystem: ref<RemoteBreachStateSystem> = container.Get(
    n"BetterNetrunning.RemoteBreach.RemoteBreachStateSystem"
  ) as RemoteBreachStateSystem;
  if IsDefined(remoteBreachSystem) && remoteBreachSystem.HasPendingRemoteBreach() {
    let target: wref<ScriptableDeviceComponentPS> = remoteBreachSystem.GetRemoteBreachTarget();
    if IsDefined(target) && target == this {
      return true;
    }
  }

  // Check 1: Computer RemoteBreach (RemoteBreachStateSystem)
  let computerPS: ref<ComputerControllerPS> = this as ComputerControllerPS;
  if IsDefined(computerPS) {
    let computerSystem: ref<RemoteBreachStateSystem> = container.Get(BNConstants.CLASS_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
    if IsDefined(computerSystem) {
      let currentComputer: wref<ComputerControllerPS> = computerSystem.GetRemoteBreachTarget() as ComputerControllerPS;
      if IsDefined(currentComputer) && currentComputer == computerPS {
        return true;
      }
    }
  }

  // Check 2: Terminal/Camera/Turret/Other RemoteBreach (RemoteBreachStateSystem)
  let deviceSystem: ref<RemoteBreachStateSystem> = container.Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
  if IsDefined(deviceSystem) {
    let currentDevice: wref<ScriptableDeviceComponentPS> = deviceSystem.GetRemoteBreachTarget();
    if IsDefined(currentDevice) && currentDevice == this {
      return true;
    }
  }

  // Check 3: Vehicle RemoteBreach
  // ARCHITECTURE: Uses unified RemoteBreachStateSystem (VehicleComponentPS extends ScriptableDeviceComponentPS)
  let vehiclePS: ref<VehicleComponentPS> = this as VehicleComponentPS;
  if IsDefined(vehiclePS) {
    let deviceSystem: ref<RemoteBreachStateSystem> = container.Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
    if IsDefined(deviceSystem) {
      let currentVehicle: wref<VehicleComponentPS> = deviceSystem.GetRemoteBreachTarget() as VehicleComponentPS;
      if IsDefined(currentVehicle) && currentVehicle == vehiclePS {
        return true;
      }
    }
  }

  // Not in any RemoteBreach state
  return false;
}

// ============================================================================
// Helper: IsBreachPenaltyEnabledForType() - Type-Specific Penalty Check
// ============================================================================
//
// FUNCTIONALITY:
// - Checks if penalty is enabled for specific breach type
// - Individual toggles per breach type (AP, NPC, RemoteBreach)
//
// ARCHITECTURE:
// - Guard Clause pattern for early return
// - Type-specific settings from config.reds
// ============================================================================

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

// ============================================================================
// Helper: ApplyFailurePenalty() - Type-Specific Penalty Application
// ============================================================================
//
// FUNCTIONALITY:
// - Applies penalty based on breach type
// - VFX: All breach types (unified)
// - Lock Recording: Type-specific (deviceID for AP, timestamp for NPC, position for RemoteBreach)
// - Trace: All breach types (unified)
//
// PENALTY BREAKDOWN:
// - AccessPoint: VFX + Device Lock (PersistentID) + Trace
// - UnconsciousNPC: VFX + NPC Lock (timestamp on PS) + Trace
// - RemoteBreach: VFX + Position Lock (50m radius) + Trace
//
// ARCHITECTURE:
// - Type-specific lock recording (deviceID/timestamp/position)
// - Guard Clause pattern for entity validation
// - Unified VFX and trace application
// ============================================================================

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
      BreachLockUtils.SetJackInInteractionState(devicePS, false);
      BNDebug("BreachPenalty", "Disabled JackIn interaction for failed AP breach");
    }
  }
  // Note: UnconsciousNPC breach uses separate overload (ApplyFailurePenalty with ScriptedPuppet parameter)
  // to avoid sibling class casting issues (PuppetDeviceLinkPS ↔ ScriptableDeviceComponentPS)

  // Trigger position reveal trace (all types)
  TriggerTraceAttempt(player, gameInstance);
}

// ============================================================================
// ApplyFailurePenalty() Overload - For UnconsciousNPC Breach
// ============================================================================
//
// FUNCTIONALITY:
// Applies failure penalty for UnconsciousNPC breach using ScriptedPuppet directly.
//
// RATIONALE:
// PuppetDeviceLinkPS and ScriptableDeviceComponentPS are sibling classes (both inherit
// from SharedGameplayPS) and cannot be cast to each other. This overload accepts
// ScriptedPuppet directly to avoid casting issues.
//
// PENALTY COMPONENTS:
// - VFX: Red glitch effect (unified with other breach types)
// - Timestamp: Records on ScriptedPuppetPS.m_betterNetrunningNPCBreachFailedTimestamp
// - Trace: Position reveal attempt (unified)
//
// ARCHITECTURE:
// - Reuses ApplyBreachFailurePenaltyVFX() for DRY principle
// - Reuses TriggerTraceAttempt() for DRY principle
// - Uses RecordBreachFailureTimestamp() for timestamp recording (DRY principle)
// ============================================================================

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

// ============================================================================
// Helper: ApplyBreachFailurePenaltyVFX() - Visual Penalty Effect
// ============================================================================
//
// Applies red VFX effect when breach fails.
// Extracted as separate function for reusability across different breach types.
//
// VFX: disabling_connectivity_glitch_red (red, 2-3 seconds)
// ============================================================================

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

// ============================================================================
// Helper: RecordBreachFailureTimestamp() - AP Breach Timestamp Recording
// ============================================================================
//
// Records breach failure timestamp on device-side persistent storage for AP breach.
//
// FUNCTIONALITY:
// - Validates devicePS can be cast to SharedGameplayPS
// - Records current timestamp on m_betterNetrunningAPBreachFailedTimestamp
// - Returns success/failure status
//
// RATIONALE:
// Device-side persistent fields (SharedGameplayPS) correctly persist across save/load,
// unlike PlayerPuppet fields which do not serialize properly.
//
// ARCHITECTURE:
// - Type-safe casting with IsDefined() check (DEVELOPMENT_GUIDELINES.md compliance)
// - Single Responsibility: Only records timestamp, no side effects
// - Early return on validation failure
// ============================================================================

private static func RecordBreachFailureTimestamp(
  devicePS: ref<ScriptableDeviceComponentPS>,
  gameInstance: GameInstance
) -> Bool {
  let sharedPS: ref<SharedGameplayPS> = devicePS;
  if !IsDefined(sharedPS) {
    BNDebug("BreachPenalty", "RecordBreachFailureTimestamp(AP): SharedGameplayPS cast failed");
    return false;
  }

  let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(gameInstance);
  sharedPS.m_betterNetrunningAPBreachFailedTimestamp = currentTime;
  BNDebug("BreachPenalty", "Recorded AP breach failure timestamp: " + ToString(currentTime));
  return true;
}

// ============================================================================
// Helper: RecordBreachFailureTimestamp() - NPC Breach Timestamp Recording
// ============================================================================
//
// Records breach failure timestamp on NPC-side persistent storage for unconscious NPC breach.
//
// FUNCTIONALITY:
// - Validates npcPS is defined
// - Records current timestamp on m_betterNetrunningNPCBreachFailedTimestamp
// - Returns success/failure status
//
// RATIONALE:
// ScriptedPuppetPS persistent fields correctly persist across save/load.
// Same pattern as AP breach for consistency (DRY principle).
//
// ARCHITECTURE:
// - Type-safe validation with IsDefined() check
// - Single Responsibility: Only records timestamp, no side effects
// - Early return on validation failure
// - Sibling class to ScriptableDeviceComponentPS (cannot cast between them)
// ============================================================================

private static func RecordBreachFailureTimestamp(
  npcPS: ref<ScriptedPuppetPS>,
  gameInstance: GameInstance
) -> Bool {
  if !IsDefined(npcPS) {
    BNDebug("BreachPenalty", "RecordBreachFailureTimestamp(NPC): ScriptedPuppetPS not defined");
    return false;
  }

  let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(gameInstance);
  npcPS.m_betterNetrunningNPCBreachFailedTimestamp = currentTime;
  BNDebug("BreachPenalty", "Recorded NPC breach failure timestamp: " + ToString(currentTime));
  return true;
}

// ============================================================================
// Helper: RecordBreachFailureByType() - Type-Based Dispatch
// ============================================================================
//
// FUNCTIONALITY:
// Dispatches breach failure recording to appropriate system based on breach type.
// Acts as coordinator only - delegates actual recording to specialized systems.
//
// RECORDING DELEGATION:
// - RemoteBreach: RemoteBreachLockSystem.RecordRemoteBreachFailure()
// - AP/NPC: Should not reach here (handled in ApplyFailurePenalty directly)
// - Unknown types: Fallback to RemoteBreach behavior
//
// RATIONALE:
// BreachPenaltySystem no longer knows RemoteBreach internal implementation details.
// Each breach type's lock management is fully encapsulated in its own system.
//
// ARCHITECTURE:
// - Type-based dispatch pattern (coordinator role)
// - Delegation to specialized systems (RemoteBreachLockSystem)
// - Guard Clause for invalid types
// ============================================================================

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

// ============================================================================
// Helper: TriggerTraceAttempt() - Trigger Position Reveal Trace
// ============================================================================
//
// Triggers position reveal trace attempt (notification sent) after breach failure.
// Uses vanilla NPCPuppet.RevealPlayerPositionIfNeeded() API.
//
// TRACE MECHANISM:
// - Real netrunner only (requires TracePositionOverhaul MOD)
// - Uses FindNearestNetrunner() to search for trace-capable NPCs
// - Upload time: Vanilla 60 seconds (fixed by game engine)
// - Interruptible: NPC death/defeat, combat state change, HackInterrupt StatusEffect
//
// HARD DEPENDENCY: TracePositionOverhaul MOD
//   WITH: FindNearestNetrunner() searches for real NPCs → RevealPlayerPositionIfNeeded()
//   WITHOUT: FindNearestNetrunner() returns null → No trace penalty
//
// ADVANTAGES OVER INSTANT ALERT:
// - 60s delay (player can escape or interrupt)
// - Interruptible (kill netrunner, apply StatusEffect, NPC enters combat)
// - Tactical choices (stealth maintained during trace upload)
// - No immediate AlertPuppet() (NPCs stay in normal patrol state until trace completes)
//
// DESIGN NOTE:
// No virtual netrunner fallback - trace penalty only applies when real netrunner is present.
// This maintains immersion (trace must originate from actual NPC) and provides clear feedback
// (player can see netrunner icon on scanner during trace).
//
// ARCHITECTURE:
// Simplified signature - no longer requires devicePS parameter
// Works for all breach types (Device, NPC, Vehicle)
// ============================================================================

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

// ============================================================================
// ScriptableDeviceComponentPS.SetHasPersonalLinkSlot() - Prevent Lock Bypass on Load
// ============================================================================
//
// VANILLA BEHAVIOR:
// Device.OnGameAttached() calls SetHasPersonalLinkSlot(true) when device has
// m_personalLinkComponent, unconditionally enabling JackIn interaction.
//
// PROBLEM:
// Save/Load restores JackIn interaction even when device is locked by AP
// breach failure penalty, bypassing the lock system.
//
// SOLUTION:
// Intercept SetHasPersonalLinkSlot(true) calls and check breach lock status.
// If device is locked, force isPersonalLinkSlotPresent = false to keep JackIn disabled.
//
// ARCHITECTURE:
// - @wrapMethod for compatibility with other mods
// - Early return pattern for non-enable calls (false parameter)
// - Lock check only when attempting to enable (true parameter)
//
// PERSISTENCE:
// Ensures penalty state survives save/load cycles by intercepting load-time
// JackIn restoration in Device.OnGameAttached().
// ============================================================================

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
