module BetterNetrunning

import BetterNetrunning.Logging.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Integration.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.RemoteBreach.Actions.*
import BetterNetrunning.Minigame.*
import BetterNetrunning.Systems.*
import BetterNetrunning.RadialUnlock.*
import BetterNetrunningConfig.*

// ============================================================================
// BetterNetrunning - Main Entry Point
// ============================================================================
//
// PURPOSE:
// Module imports and minigame daemon filtering integration
//
// FUNCTIONALITY:
// - Protects BN subnet daemons from vanilla filtering rules
// - Applies custom filtering for breach context
// - Integrates DNR (Daemon Netrunning Revamp) compatibility
//
// ARCHITECTURE:
// - @wrapMethod on FilterPlayerPrograms for daemon protection
// - Extract → vanilla filter → restore pattern
// - Helper methods for subnet daemon identification
// ============================================================================

/*
 * Controls which breach programs (daemons) appear in minigame
 *
 * Processing:
 * - Adds BN subnet daemons with custom filtering
 * - Pre-extracts BN daemons (protect from vanilla rules)
 * - Calls wrappedMethod() on remaining programs
 * - Post-restores and injects protected daemons
 */
@wrapMethod(MinigameGenerationRuleScalingPrograms)
public final func FilterPlayerPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {
  // Store hacking target entity in minigame blackboard
  this.m_blackboardSystem.Get(GetAllBlackboardDefs().HackingMinigame).SetVariant(GetAllBlackboardDefs().HackingMinigame.Entity, ToVariant(this.m_entity));

  // Step 1: Extract BN subnet daemons (protect from vanilla Rule 3/4)
  let protectedPrograms: array<MinigameProgramData>;
  this.ExtractBetterNetrunningDaemons(programs, protectedPrograms);

  BNTrace("FilterPlayerPrograms",
    "Extracted " + ToString(ArraySize(protectedPrograms)) + " BN daemons, " +
    ToString(ArraySize(Deref(programs))) + " programs remain for vanilla filtering");

  // Step 2: Call vanilla filtering (Rule 1-5) on non-BN programs
  wrappedMethod(programs);

  // Step 3: Apply network connectivity filter (Rule 5) to protected BN daemons
  ApplyNetworkConnectivityFilter(this.m_entity, protectedPrograms);

  BNTrace("FilterPlayerPrograms",
    "After Rule 5 filtering: " + ToString(ArraySize(protectedPrograms)) + " BN daemons survived");

  // Step 4: Restore filtered BN daemons to program list
  this.RestoreBetterNetrunningDaemons(programs, protectedPrograms);

  BNTrace("FilterPlayerPrograms",
    "After restoration: " + ToString(ArraySize(Deref(programs))) + " total programs");

  // Step 5: Inject BN programs (PING, Datamine bonuses, etc.)
  this.InjectBetterNetrunningPrograms(programs);

  // Step 6: Apply BN custom filtering
  let initialProgramCount: Int32 = ArraySize(Deref(programs));

  // Remove already-breached subnet daemons
  let i: Int32 = ArraySize(Deref(programs)) - 1;
  while i >= 0 {
    if ShouldRemoveBreachedPrograms(Deref(programs)[i].actionID, this.m_entity as GameObject) {
      ArrayErase(Deref(programs), i);
    }
    i -= 1;
  }

  // Apply Better Netrunning custom filtering rules
  let connectedToNetwork: Bool;
  let data: ConnectedClassTypes;
  let devPS: ref<SharedGameplayPS>; // Used for subnet breach tracking and DNR gating

  // Get network connection status and available device types
  if (this.m_entity as GameObject).IsPuppet() {
    connectedToNetwork = true;
    data = (this.m_entity as ScriptedPuppet).GetMasterConnectedClassTypes();
    devPS = (this.m_entity as ScriptedPuppet).GetPS().GetDeviceLink();
  } else {
    // Access Points are always connected (they ARE the network)
    let isAccessPoint: Bool = IsDefined(this.m_entity as AccessPoint);
    if isAccessPoint {
      connectedToNetwork = true;
    } else {
      connectedToNetwork = (this.m_entity as Device).GetDevicePS().IsConnectedToPhysicalAccessPoint();
    }
    data = (this.m_entity as Device).GetDevicePS().CheckMasterConnectedClassTypes();
    devPS = (this.m_entity as Device).GetDevicePS();
  }

  // Track removed programs for detailed logging
  let removedPrograms: array<TweakDBID>;
  let removedCount: Int32 = 0;

  // Filter programs in reverse order to safely remove elements
  i = ArraySize(Deref(programs)) - 1;
  while i >= 0 {
    let actionID: TweakDBID = Deref(programs)[i].actionID;
    let miniGameActionRecord: wref<MinigameAction_Record> = TweakDBInterface.GetMinigameActionRecord(actionID);
    let programCountBefore: Int32 = ArraySize(Deref(programs));
    let shouldRemove: Bool = false;
    let filterName: String = "";

    // Check each filter and log which one removed the program
    if ShouldRemoveNetworkPrograms(actionID, connectedToNetwork) {
      shouldRemove = true;
      filterName = "NetworkFilter";
    } else if ShouldRemoveDeviceBackdoorPrograms(actionID, this.m_entity as GameObject) {
      shouldRemove = true;
      filterName = "DeviceBackdoorFilter";
    } else if ShouldRemoveAccessPointPrograms(actionID, miniGameActionRecord, this.m_isRemoteBreach) {
      shouldRemove = true;
      filterName = "AccessPointFilter";
    } else if ShouldRemoveNonNetrunnerPrograms(actionID, miniGameActionRecord, this.m_isRemoteBreach, this.m_entity as GameObject) {
      shouldRemove = true;
      filterName = "NonNetrunnerFilter";
    } else if ShouldRemoveDeviceTypePrograms(actionID, miniGameActionRecord, data) {
      shouldRemove = true;
      filterName = "DeviceTypeFilter";
    } else if ShouldRemoveDataminePrograms(actionID) {
      shouldRemove = true;
      filterName = "DatamineFilter";
    } else if ShouldRemoveOutOfRangeDevicePrograms(actionID, (this.m_entity as GameObject).GetGame(), this.GetBreachPositionForFiltering(), this.m_entity as GameObject) {
      shouldRemove = true;
      filterName = "PhysicalRangeFilter";
    }

    if shouldRemove {
      ArrayErase(Deref(programs), i);
      ArrayPush(removedPrograms, actionID);
      removedCount += 1;
      DebugUtils.LogProgramFilteringStep(filterName, programCountBefore, ArraySize(Deref(programs)), actionID, "[FilterPlayerPrograms]");
    }
    i -= 1;
  };

  // Apply DNR (Daemon Netrunning Revamp) daemon gating
  ApplyDNRDaemonGating(programs, devPS, this.m_isRemoteBreach, this.m_player as PlayerPuppet, this.m_entity);

  // Count final programs after DNR gating
  let finalProgramCount: Int32 = ArraySize(Deref(programs));

  // Log detailed filtering summary
  DebugUtils.LogFilteringSummary(initialProgramCount, finalProgramCount, removedPrograms, "[FilterPlayerPrograms]");

  // Store displayed daemons for statistics collection
  // CRITICAL: Must be done here (FilterPlayerPrograms end) not in RefreshSlaves
  // ActivePrograms is not populated until minigame completion, but we need to know
  // which daemons were DISPLAYED to the player (not just which succeeded)
  let displayedDaemons: array<TweakDBID>;
  let i_store: Int32 = 0;
  while i_store < ArraySize(Deref(programs)) {
    ArrayPush(displayedDaemons, Deref(programs)[i_store].actionID);
    i_store += 1;
  }
  let stateSystem: ref<DisplayedDaemonsStateSystem> = GameInstance.GetScriptableSystemsContainer(this.m_player.GetGame())
    .Get(BNConstants.CLASS_DISPLAYED_DAEMONS_STATE_SYSTEM()) as DisplayedDaemonsStateSystem;
  if IsDefined(stateSystem) {
    stateSystem.SetDisplayedDaemons(displayedDaemons);
  }
}

/*
 * Extract BetterNetrunning subnet daemons before vanilla filtering
 *
 * @param programs - Main program array (modified: BN daemons removed)
 * @param protectedPrograms - Output array receiving BN daemons
 */
@addMethod(MinigameGenerationRuleScalingPrograms)
private final func ExtractBetterNetrunningDaemons(
  programs: script_ref<array<MinigameProgramData>>,
  protectedPrograms: script_ref<array<MinigameProgramData>>
) -> Void {
  let i: Int32 = ArraySize(Deref(programs)) - 1;
  while i >= 0 {
    let program: MinigameProgramData = Deref(programs)[i];

    if IsBetterNetrunningSubnetDaemon(program.actionID) {
      BNTrace("ExtractBetterNetrunningDaemons",
        "Extracting daemon: " + TDBID.ToStringDEBUG(program.actionID));

      ArrayPush(Deref(protectedPrograms), program);
      ArrayErase(Deref(programs), i);
    }

    i -= 1;
  }
}

/*
 * Restore filtered BetterNetrunning daemons to program list
 *
 * @param programs - Main program array (modified: BN daemons appended)
 * @param protectedPrograms - Filtered BN daemons to restore
 */
@addMethod(MinigameGenerationRuleScalingPrograms)
private final func RestoreBetterNetrunningDaemons(
  programs: script_ref<array<MinigameProgramData>>,
  protectedPrograms: array<MinigameProgramData>
) -> Void {
  let i: Int32 = 0;
  let count: Int32 = ArraySize(protectedPrograms);

  while i < count {
    BNTrace("RestoreBetterNetrunningDaemons",
      "Restoring daemon: " + TDBID.ToStringDEBUG(protectedPrograms[i].actionID));

    ArrayPush(Deref(programs), protectedPrograms[i]);
    i += 1;
  }
}

// ============================================================================
// Physical Range Filtering Helpers
// ============================================================================

/*
 * Gets the breach position for physical range filtering
 *
 * @return Breach position (or error signal if position unavailable)
 */
@addMethod(MinigameGenerationRuleScalingPrograms)
private final func GetBreachPositionForFiltering() -> Vector4 {
  let targetEntity: wref<GameObject> = this.m_entity as GameObject;

  if IsDefined(targetEntity) {
    let position: Vector4 = targetEntity.GetWorldPosition();
    BNTrace("GetBreachPositionForFiltering", "Using target entity position: " + ToString(position));
    return position;
  }

  // Fallback: player position (should not happen in normal breach scenarios)
  let player: ref<PlayerPuppet> = this.m_player as PlayerPuppet;
  if IsDefined(player) {
    let playerPosition: Vector4 = player.GetWorldPosition();
    BNWarn("GetBreachPositionForFiltering", "Using player position as fallback: " + ToString(playerPosition));
    return playerPosition;
  }

  // Error signal (prevents filtering all devices if position unavailable)
  BNError("GetBreachPositionForFiltering", "Could not get breach position, returning error signal");
  return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
}
