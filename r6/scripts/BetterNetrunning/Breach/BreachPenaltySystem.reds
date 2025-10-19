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
// - RemoteBreach Lock Recording: Record failure position for RemoteBreach locking system
// - Trace Trigger: Initiate position reveal trace via real netrunner (if TracePositionOverhaul)
//
// PENALTIES (Failure Only):
// - Red VFX (2-3 seconds, disabling_connectivity_glitch_red)
// - RemoteBreach lock (10 minutes default, 50m radius)
// - Position reveal trace (60s upload, requires real netrunner NPC via TracePositionOverhaul)
//
// SKIP vs FAILURE:
// - Currently: Both skip (ESC key) and failure (timeout) are treated as "Failed"
// - No differentiation: All Failed states receive full penalty
// - Rationale: HackingMinigameState enum has no "Skipped" state, TimerLeftPercent unreliable
//
// ARCHITECTURE:
// - Single @wrapMethod on FinalizeNetrunnerDive() covers all breach types
// - Early Return pattern for clean control flow
// - Max nesting depth: 2 levels
//
// DEPENDENCIES:
// - BetterNetrunningConfig: Settings control (Enabled, LockDuration)
// - Common/Logger.reds: Debug logging (BNLog)
// - Common/DeviceTypeUtils.reds: GetRadialBreachRange() for alert radius
// ============================================================================

module BetterNetrunning.Breach
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Integration.*

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

  // Penalty enabled and breach failed - apply appropriate penalty
  let gameInstance: GameInstance = this.GetGameInstance();
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    BNError("BreachPenalty", "Player not found, skipping penalty");
    wrappedMethod(state);
    return;
  }

  // Apply full failure penalty (VFX + RemoteBreach lock + trace attempt)
  // state == HackingMinigameState.Failed is already guaranteed by early return
  ApplyFailurePenalty(player, this, gameInstance);

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

    // SKIP: SendMinigameFailedToAllNPCs() - prevents MinigameFailEvent → AlertPuppet()
    BNInfo("BreachPenalty", "Unconscious NPC breach failed - NPC alert suppressed (SendMinigameFailedToAllNPCs skipped)");
    return EntityNotificationType.DoNotNotifyEntity;
  }

  // Unknown/InProgress states: Pass through
  return wrappedMethod(evt);
}

// ============================================================================
// Helper: ApplyFailurePenalty() - Full Penalty for Failure
// ============================================================================
//
// Apply full penalty when player fails minigame (ran out of time or gave up).
//
// PENALTIES:
// - VFX: disabling_connectivity_glitch_red (red, 2-3 seconds)
// - RemoteBreach Lock: Record failure position for dynamic radius lock (10 minutes)
// - Trace Attempt: Trigger position reveal trace (30-60s delay, interruptible)
//
// ARCHITECTURE:
// Unified penalty application for all breach types (Device, NPC, Vehicle)
// Accepts either DeviceComponentPS or GameObject as source entity
// ============================================================================

public static func ApplyFailurePenalty(
  player: ref<PlayerPuppet>,
  devicePS: ref<ScriptableDeviceComponentPS>,
  gameInstance: GameInstance
) -> Void {
  // Apply visual penalty effect
  ApplyBreachFailurePenaltyVFX(player, gameInstance);

  // Record failure position for RemoteBreach locking
  let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
  if IsDefined(deviceEntity) {
    RecordRemoteBreachFailure(player, deviceEntity.GetWorldPosition(), gameInstance);
  }

  // Trigger position reveal trace
  TriggerTraceAttempt(player, gameInstance);
}

// Overload: Accept GameObject directly (for NPC breaches)
public static func ApplyFailurePenalty(
  player: ref<PlayerPuppet>,
  sourceEntity: ref<GameObject>,
  gameInstance: GameInstance
) -> Void {
  // Apply visual penalty effect
  ApplyBreachFailurePenaltyVFX(player, gameInstance);

  // Record failure position for RemoteBreach locking
  if IsDefined(sourceEntity) {
    RecordRemoteBreachFailure(player, sourceEntity.GetWorldPosition(), gameInstance);
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
// Helper: RecordRemoteBreachFailure() - Record Failure Position
// ============================================================================
//
// Record breach failure position and timestamp for RemoteBreach locking.
// Used by RemoteBreachLock system to prevent RemoteBreach within 50m radius
// for 10 minutes (configurable).
//
// RECORDING:
// - Failure position: Breach source entity world position
// - Timestamp: Current simulation time
// - Storage: PlayerPuppet persistent fields (survive save/load)
//
// ARCHITECTURE:
// Simplified signature - accepts position directly instead of devicePS
// Works for all breach types (Device, NPC, Vehicle)
// ============================================================================

private static func RecordRemoteBreachFailure(
  player: ref<PlayerPuppet>,
  failedPosition: Vector4,
  gameInstance: GameInstance
) -> Void {
  let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);

  // Record failure position and timestamp
  ArrayPush(player.m_betterNetrunning_remoteBreachFailedPositions, failedPosition);
  ArrayPush(player.m_betterNetrunning_remoteBreachFailedTimestamps, currentTime);

  BNDebug(
    "BreachPenalty",
    "Recorded RemoteBreach failure position: "
    + ToString(failedPosition)
    + " at time "
    + FloatToString(currentTime)
  );
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
  let searchRadius: Float = DeviceTypeUtils.GetRadialBreachRange(gameInstance);
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
