module BetterNetrunning

import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Integration.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.RemoteBreach.Actions.*
import BetterNetrunning.Minigame.*
import BetterNetrunning.Systems.*
import BetterNetrunning.RadialUnlock.*
import BetterNetrunningConfig.*

// ==================== MODULE ARCHITECTURE ====================
//
// BETTER NETRUNNING - MODULAR ARCHITECTURE
//
// This file serves as the main entry point and coordination layer.
// Core functionality has been split into specialized modules:
//
// BREACH MINIGAME:
// - Minigame/ProgramFiltering.reds: Daemon filtering logic (ShouldRemove* functions)
// - Minigame/ProgramInjection.reds: Progressive unlock program injection
// - Breach/BreachProcessing.reds: RefreshSlaves() and breach completion handlers
// - Breach/BreachHelpers.reds: Network hierarchy and minigame status handlers
//
// DEVICE QUICKHACKS:
// - Devices/DeviceQuickhacks.reds: Progressive unlock, action finalization, remote actions
//
// NPC QUICKHACKS:
// - NPCs/NPCQuickhacks.reds: Progressive unlock, permission calculation
// - NPCs/NPCLifecycle.reds: Incapacitation handling, unconscious breach
//
// PROGRESSION SYSTEM:
// - Progression/ProgressionSystem.reds: Cyberdeck, Intelligence, Enemy Rarity checks
//
// COMMON UTILITIES:
// - Common/Events.reds: Persistent field definitions, breach events
// - Common/DaemonUtils.reds: Daemon filtering utilities
// - Common/DeviceTypeUtils.reds: Device type detection
// - Common/Logger.reds: Debug logging
//
// INTEGRATION (External MOD Dependencies):
// - Integration/DNRGating.reds: Daemon Netrunning Revamp MOD integration
// - Integration/TracePositionOverhaulGating.reds: TracePositionOverhaul MOD integration
// - Integration/RadialBreachGating.reds: RadialBreach MOD integration
//
// RADIAL UNLOCK SYSTEM:
// - RadialUnlock/RadialUnlockSystem.reds: Position-based breach tracking (50m radius)
// - RadialUnlock/RemoteBreachNetworkUnlock.reds: RemoteBreach network unlock
//
// CUSTOM HACKING SYSTEM:
// - CustomHacking/*: RemoteBreach integration (9 files)
//
// DESIGN PHILOSOPHY:
// - Single Responsibility: Each module handles one aspect of functionality
// - Composed Method: Large functions broken into small, focused helpers
// - MOD COMPATIBILITY: Uses @wrapMethod where possible instead of @replaceMethod
// - Clear Dependencies: Import statements make module relationships explicit

// ==================== MAIN COORDINATION FUNCTION ====================
//
// Controls which breach programs (daemons) appear in the minigame
//
// FUNCTIONALITY:
// - Adds new custom daemons (unlock programs for cameras, turrets, NPCs)
// - Optionally allows access to all daemons through access points
// - Optionally removes Datamine V1 and V2 daemons from access points
// - Filters programs based on network device types (cameras, turrets, NPCs)
// - DNR (Daemon Netrunning Revamp) compatibility layer
//
// ARCHITECTURE - PROTECT/RESTORE PATTERN:
// BetterNetrunning subnet daemons (type="MinigameAction.Both") bypass vanilla
// Rule 3/4 but also skip Rule 5 (network connectivity check). To fix:
// 1. Extract BN daemons before wrappedMethod() → protected array
// 2. Execute vanilla filtering on remaining programs
// 3. Apply manual Rule 5 to protected daemons → ProgramFilteringRules
// 4. Restore filtered daemons to main program list
// 5. Continue existing BN filtering (Datamine, physical range, etc.)
//
// MOD COMPATIBILITY: @wrapMethod allows other mods to also hook this function
@wrapMethod(MinigameGenerationRuleScalingPrograms)
public final func FilterPlayerPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {
  // Store the hacking target entity in minigame blackboard (used for access point logic)
  this.m_blackboardSystem.Get(GetAllBlackboardDefs().HackingMinigame).SetVariant(GetAllBlackboardDefs().HackingMinigame.Entity, ToVariant(this.m_entity));

  // PHASE 1: Extract BN subnet daemons (protect from vanilla Rule 3/4)
  let protectedPrograms: array<MinigameProgramData>;
  this.ExtractBetterNetrunningDaemons(programs, protectedPrograms);

  BNTrace("FilterPlayerPrograms",
    "Extracted " + ToString(ArraySize(protectedPrograms)) + " BN daemons, " +
    ToString(ArraySize(Deref(programs))) + " programs remain for vanilla filtering");

  // PHASE 2: Call vanilla filtering (Rule 1-5) on non-BN programs
  wrappedMethod(programs);

  // PHASE 3: Apply network connectivity filter (Rule 5) to protected BN daemons
  ApplyNetworkConnectivityFilter(this.m_entity, protectedPrograms);

  BNTrace("FilterPlayerPrograms",
    "After Rule 5 filtering: " + ToString(ArraySize(protectedPrograms)) + " BN daemons survived");

  // PHASE 4: Restore filtered BN daemons to program list
  this.RestoreBetterNetrunningDaemons(programs, protectedPrograms);

  BNTrace("FilterPlayerPrograms",
    "After restoration: " + ToString(ArraySize(Deref(programs))) + " total programs");

  // PHASE 5: Inject BN programs (PING, Datamine bonuses, etc.)
  // CRITICAL: Inject AFTER restoration to ensure proper program order
  this.InjectBetterNetrunningPrograms(programs);

  // PHASE 6: Apply BN custom filtering (existing logic)
  let initialProgramCount: Int32 = ArraySize(Deref(programs));

  // CRITICAL: Remove already-breached programs
  // This ensures we don't show subnet unlock daemons for already-unlocked subnets
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
    // CRITICAL FIX: Access Points are always connected to network (they ARE the network)
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
      LogProgramFilteringStep(filterName, programCountBefore, ArraySize(Deref(programs)), actionID, "[FilterPlayerPrograms]");
    }
    i -= 1;
  };

  // Apply DNR (Daemon Netrunning Revamp) daemon gating
  // This integrates DNR's advanced daemon system with Better Netrunning's subnet-based progression
  ApplyDNRDaemonGating(programs, devPS, this.m_isRemoteBreach, this.m_player as PlayerPuppet, this.m_entity);

  // CRITICAL: Count programs AFTER DNR gating (may add/remove programs)
  let finalProgramCount: Int32 = ArraySize(Deref(programs));

  // Log detailed filtering summary
  LogFilteringSummary(initialProgramCount, finalProgramCount, removedPrograms, "[FilterPlayerPrograms]");
}

// ==================== DESIGN DOCUMENTATION ====================
//
// DESIGN NOTE: Progressive Unlock Implementation
//
// ARCHITECTURE:
// Better Netrunning maintains vanilla menu visibility behavior while implementing
// progressive unlock through action-level restrictions:
//
// DEVICES (Devices/DeviceQuickhacks.reds):
// - GetRemoteActions(): Main entry point for device quickhacks
// - SetActionsInactiveUnbreached(): Applies progressive restrictions before breach
// - Checks: Cyberdeck tier, Intelligence stat, device type (camera/turret/basic)
//
// NPCs (NPCs/NPCQuickhacks.reds):
// - GetAllChoices(): Main entry point for NPC quickhacks
// - CalculateNPCHackPermissions(): Calculates category-based permissions
// - Checks: Cyberdeck tier, Intelligence stat, Enemy Rarity, hack category
//
// RATIONALE:
// - Menu visibility: Always show quickhack wheel (vanilla behavior)
// - Action availability: Progressively unlock based on player progression
// - Better mod compatibility: Doesn't override menu visibility functions
// - Cleaner separation: Menu display vs action availability are independent
//
// SPECIAL CASES:
// - Tutorial NPCs: Whitelisted (always unlocked for proper tutorial flow)
// - Isolated NPCs: Auto-unlocked (not connected to any network)
// - Unsecured networks: Auto-unlocked (no access points found)
// - Radial breach: Standalone devices within 50m radius auto-unlocked

//
// MODULE REFERENCE GUIDE
//
// FINDING SPECIFIC FUNCTIONALITY:
//
// Breach Minigame Programs:
// - Minigame/ProgramFiltering.reds: Which daemons appear in minigame
// - Minigame/ProgramInjection.reds: Adding custom unlock daemons
//
// Device Quickhacks (Breached/Unbreached States):
// - Devices/DeviceQuickhacks.reds: Main logic
//
// NPC Quickhacks (Breached/Unbreached States):
// - NPCs/NPCQuickhacks.reds: Main logic
// - NPCs/NPCLifecycle.reds: Incapacitation/death handling
//
// Breach Completion:
// - Breach/BreachProcessing.reds: What happens when breach succeeds
// - Breach/BreachHelpers.reds: Network hierarchy and status handlers
//
// Progression Checks:
// - Progression/ProgressionSystem.reds: Cyberdeck/Intelligence/Rarity evaluation
//
// Radial Unlock System (50m breach radius):
// - RadialUnlock/RadialUnlockSystem.reds: Position-based breach tracking
// - RadialUnlock/RemoteBreachNetworkUnlock.reds: RemoteBreach network unlock
//
// Persistent State:
// - Common/Events.reds: Breach state fields and events
//
// MOD INTEGRATIONS (External Dependencies):
// - Integration/DNRGating.reds: Daemon Netrunning Revamp compatibility
// - Integration/TracePositionOverhaulGating.reds: TracePositionOverhaul compatibility
// - Integration/RadialBreachGating.reds: RadialBreach MOD physical range filtering
// - CustomHacking/*: RemoteBreach action integration (9 files)

// ==================== PROTECT/RESTORE PATTERN HELPERS ====================

/*
 * Extract BetterNetrunning subnet daemons before vanilla filtering
 *
 * PURPOSE:
 * Protects BN subnet daemons from vanilla Rule 3/4 deletion by extracting
 * them into a separate array before wrappedMethod() execution.
 *
 * FUNCTIONALITY:
 * - Iterates programs array in reverse order (safe for removal)
 * - Identifies BN subnet daemons via ProgramFilteringRules helper
 * - Moves matching programs to protectedPrograms array
 * - Removes from main programs array
 *
 * RATIONALE:
 * BN daemons have type="MinigameAction.Both", which technically bypasses
 * Rule 3 (!m_isRemoteBreach && Type != AccessPoint) in AP Breach, but
 * triggers Rule 4 (m_isRemoteBreach && Type == AccessPoint) in RemoteBreach.
 * Extraction ensures consistent behavior across all breach types.
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
 * PURPOSE:
 * Merges protected BN daemons back into main program array after vanilla
 * filtering and manual Rule 5 application.
 *
 * FUNCTIONALITY:
 * - Appends all programs from protectedPrograms to main programs array
 * - Order: vanilla programs first, BN daemons last
 *
 * RATIONALE:
 * Vanilla filtering (Rule 1-5) operates on non-BN programs only. After
 * manual Rule 5 on BN daemons, both arrays contain properly filtered
 * programs and can be safely merged.
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

// ==================== PHYSICAL RANGE FILTERING HELPERS ====================

/*
 * Gets the breach position for physical range filtering
 *
 * Returns the position of the target entity (Access Point, Device, or NPC).
 * Used to determine the center point for RadialBreach range scanning.
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
