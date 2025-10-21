// ============================================================================
// BetterNetrunning - Bonus Daemon Utilities
// ============================================================================
// Shared utility functions for applying bonus daemons to breach programs
//
// FEATURES:
// - Auto-execute PING quickhack on breach target (AutoExecutePingOnSuccess setting)
// - Auto-apply Datamine based on success count (AutoDatamineBySuccessCount setting)
// - Centralized program detection (HasProgram, HasAnyDatamineProgram)
// - Success count calculation (CountNonDataminePrograms)
//
// PING IMPLEMENTATION:
// - Uses vanilla QuickHack system (t"QuickHack.BasePingHack")
// - Single-device PING (no network propagation)
// - Works for all breach types: Access Point, Unconscious NPC, RemoteBreach
// - Advantage: Avoids PingDevice daemon's network-wide propagation issue
//
// USAGE:
// - AccessPoint breach: BreachProcessing.reds
// - RemoteBreach: RemoteBreachNetworkUnlock.reds / RemoteBreachSystem.reds
// - UnconsciousNPC breach: RemoteBreachNetworkUnlock.reds
//
// DESIGN:
// - Global functions (no class dependency)
// - DRY principle (single source of truth)
// - Type-safe TweakDBID handling
// ============================================================================

module BetterNetrunning.Utils

import BetterNetrunning.Core.*
import BetterNetrunning.Utils.DaemonFilterUtils
import BetterNetrunningConfig.*

// ============================================================================
// BONUS DAEMON APPLICATION
// ============================================================================

// Apply bonus daemons based on settings and success count
// - Auto-execute PING if any daemon succeeded (AutoExecutePingOnSuccess)
// - Auto-apply Datamine based on success count (AutoDatamineBySuccessCount)
//
// Parameters:
//   activePrograms: Array of successfully uploaded daemon programs (modified in-place)
//   gi: GameInstance for settings access
//   logContext: Optional context string for logging (e.g., "[RemoteBreach]", "[AccessPoint]")
public func ApplyBonusDaemons(
  activePrograms: script_ref<array<TweakDBID>>,
  gi: GameInstance,
  opt logContext: String
) -> Void {
  let successCount: Int32 = ArraySize(Deref(activePrograms));

  if NotEquals(logContext, "") {
    // Log all programs BEFORE bonus daemon processing with readable names
    let i: Int32 = 0;
    while i < successCount {
      let programName: String = DaemonFilterUtils.GetDaemonDisplayName(Deref(activePrograms)[i]);
      BNTrace(logContext, "[BEFORE] Program " + ToString(i + 1) + ": " + programName + " (" + TDBID.ToStringDEBUG(Deref(activePrograms)[i]) + ")");
      i += 1;
    }
  }

  if successCount == 0 {
    return; // No successful daemons
  }

  // Feature 1: Auto-execute PING quickhack on breach target
  // IMPLEMENTATION: Uses vanilla QuickHack system (single-device PING)
  // RATIONALE: Avoids PingDevice daemon's network-wide propagation
  let pingEnabled: Bool = BetterNetrunningSettings.AutoExecutePingOnSuccess();

  if pingEnabled {
    // Get target entity from Blackboard
    let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().HackingMinigame);

    // Try HackingMinigame.Entity first (works for all breach types including UnconsciousNPC)
    let targetEntity: wref<Entity> = FromVariant<wref<Entity>>(
      minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity)
    );

    if NotEquals(logContext, "") && IsDefined(targetEntity) {
      BNTrace(logContext, "[PING] Found target entity: " + NameToString(targetEntity.GetClassName()));

      // Check if target is NPC or Device
      let targetNPC: ref<ScriptedPuppet> = targetEntity as ScriptedPuppet;
      let targetDevice: ref<Device> = targetEntity as Device;

      if IsDefined(targetNPC) {
        BNTrace(logContext, "[PING] Target is NPC: " + targetNPC.GetDisplayName());
      } else if IsDefined(targetDevice) {
        BNTrace(logContext, "[PING] Target is Device: " + targetDevice.GetDeviceName());
      } else {
        BNTrace(logContext, "[PING] Target is unknown entity type");
      }
    }

    if IsDefined(targetEntity) {
      ExecutePingQuickHackOnTarget(targetEntity, gi, logContext);
    }
  }

  // Feature 2: Auto-apply Datamine based on success count
  let datamineEnabled: Bool = BetterNetrunningSettings.AutoDatamineBySuccessCount();

  if datamineEnabled {
    let nonDatamineCount: Int32 = CountNonDataminePrograms(Deref(activePrograms));
    let hasDatamine: Bool = HasAnyDatamineProgram(Deref(activePrograms));

    if NotEquals(logContext, "") {
      BNTrace(logContext, "Non-Datamine daemon count: " + ToString(nonDatamineCount) + ", Has Datamine: " + ToString(hasDatamine));
    }

    if nonDatamineCount > 0 && !hasDatamine {
      let datamineToAdd: TweakDBID;
      let logMessage: String;

      if nonDatamineCount >= 3 {
        datamineToAdd = BNConstants.PROGRAM_DATAMINE_MASTER();
        logMessage = "DatamineV3 (3+ daemons succeeded)";
      } else if nonDatamineCount == 2 {
        datamineToAdd = BNConstants.PROGRAM_DATAMINE_ADVANCED();
        logMessage = "DatamineV2 (2 daemons succeeded)";
      } else if nonDatamineCount == 1 {
        datamineToAdd = BNConstants.PROGRAM_DATAMINE_BASIC();
        logMessage = "DatamineV1 (1 daemon succeeded)";
      }

      ArrayPush(Deref(activePrograms), datamineToAdd);

      if NotEquals(logContext, "") {
        BNDebug(logContext, "Bonus Daemon: Auto-added " + logMessage);
      }
    }
  }

  // Log all programs AFTER bonus daemon processing
  if NotEquals(logContext, "") {
    let finalCount: Int32 = ArraySize(Deref(activePrograms));
    BNTrace(logContext, "Final program count: " + ToString(finalCount));

    let i: Int32 = 0;
    while i < finalCount {
      let programName: String = DaemonFilterUtils.GetDaemonDisplayName(Deref(activePrograms)[i]);
      BNTrace(logContext, "[AFTER] Program " + ToString(i + 1) + ": " + programName + " (" + TDBID.ToStringDEBUG(Deref(activePrograms)[i]) + ")");
      i += 1;
    }
  }
}

// ============================================================================
// PROGRAM DETECTION UTILITIES
// ============================================================================

// Check if programs array contains a specific program
public func HasProgram(programs: array<TweakDBID>, programID: TweakDBID) -> Bool {
  let i: Int32 = 0;
  while i < ArraySize(programs) {
    if Equals(programs[i], programID) {
      return true;
    }
    i += 1;
  }
  return false;
}

// Count non-Datamine programs (for auto-datamine feature)
// Returns the number of daemons that are NOT Datamine programs
public func CountNonDataminePrograms(programs: array<TweakDBID>) -> Int32 {
  let count: Int32 = 0;
  let i: Int32 = 0;

  while i < ArraySize(programs) {
    let programID: TweakDBID = programs[i];

    // Exclude Datamine programs
    if programID != BNConstants.PROGRAM_DATAMINE_BASIC()
       && programID != BNConstants.PROGRAM_DATAMINE_ADVANCED()
       && programID != BNConstants.PROGRAM_DATAMINE_MASTER() {
      count += 1;
    }

    i += 1;
  }

  return count;
}

// Check if any Datamine program exists in array
public func HasAnyDatamineProgram(programs: array<TweakDBID>) -> Bool {
  let i: Int32 = 0;
  while i < ArraySize(programs) {
    let programID: TweakDBID = programs[i];

    if programID == BNConstants.PROGRAM_DATAMINE_BASIC()
       || programID == BNConstants.PROGRAM_DATAMINE_ADVANCED()
       || programID == BNConstants.PROGRAM_DATAMINE_MASTER() {
      return true;
    }

    i += 1;
  }
  return false;
}

// ============================================================================
// PING QUICKHACK EXECUTION
// ============================================================================

// Execute PING quickhack on breach target entity
// Works for all breach types: Access Point, Unconscious NPC, RemoteBreach (Computer/Device/Vehicle)
public func ExecutePingQuickHackOnTarget(targetEntity: wref<Entity>, gi: GameInstance, opt logContext: String) -> Void {
  if !IsDefined(targetEntity) {
    if NotEquals(logContext, "") {
      BNError(logContext, "[PING] Target entity not defined");
    }
    return;
  }

  // DEBUG: Log target entity details
  if NotEquals(logContext, "") {
    BNTrace(logContext, "[PING] Target entity class: " + NameToString(targetEntity.GetClassName()) + ", ID: " + EntityID.ToDebugString(targetEntity.GetEntityID()));
  }

  // Get player for executor context
  let player: ref<PlayerPuppet> = GetPlayer(gi);
  if !IsDefined(player) {
    if NotEquals(logContext, "") {
      BNError(logContext, "[PING] Player not found");
    }
    return;
  }

  // Determine target type and execute appropriate PING quickhack
  let targetDevice: ref<Device> = targetEntity as Device;
  let targetNPC: ref<ScriptedPuppet> = targetEntity as ScriptedPuppet;

  if IsDefined(targetDevice) {
    if NotEquals(logContext, "") {
      BNDebug(logContext, "[PING] Executing PING on Device: " + NameToString(targetDevice.GetClassName()));
    }
    ExecutePingQuickHackOnDevice(targetDevice, player, logContext);
  } else if IsDefined(targetNPC) {
    if NotEquals(logContext, "") {
      BNDebug(logContext, "[PING] Executing PING on NPC: " + NameToString(targetNPC.GetClassName()));
    }
    ExecutePingQuickHackOnNPC(targetNPC, player, logContext);
  } else {
    if NotEquals(logContext, "") {
      BNError(logContext, "[PING] Unknown target type (not Device or NPC)");
    }
  }
}

// Execute PING quickhack on Device (Access Point, Camera, Turret, Computer, Vehicle, etc.)
private func ExecutePingQuickHackOnDevice(targetDevice: ref<Device>, player: ref<PlayerPuppet>, opt logContext: String) -> Void {
  let devicePS: ref<ScriptableDeviceComponentPS> = targetDevice.GetDevicePS();
  if !IsDefined(devicePS) {
    if NotEquals(logContext, "") {
      BNError(logContext, "[PING] Device PS not found");
    }
    return;
  }

  // Get PING action from device
  let pingAction: ref<ScriptableDeviceAction> = devicePS.ActionPing();
  if !IsDefined(pingAction) {
    if NotEquals(logContext, "") {
      BNDebug(logContext, "[PING] PING quickhack not available on this device");
    }
    return;
  }

  // Set executor and requester (Vanilla pattern)
  pingAction.SetExecutor(player);
  pingAction.RegisterAsRequester(targetDevice.GetEntityID());  // Device is the requester (target of QuickHack)

  // Execute PING action via ProcessRPGAction (Vanilla-compliant flow)
  let gi: GameInstance = targetDevice.GetGame();

  if NotEquals(logContext, "") {
    BNTrace(logContext, "[PING] Executing auto-PING on device via ProcessRPGAction: " + NameToString(targetDevice.GetClassName()));
  }

  // Enable cost skipping for auto-PING (free execution)
  // WARNING: ProcessRPGAction still grants QuickHack experience (Vanilla API limitation)
  pingAction.SetCanSkipPayCost(true);

  // Execute via ProcessRPGAction (complete Vanilla flow)
  // For Devices, this should trigger OnActionPing() → PulseNetwork() → RevealNetworkGridOnPulse
  // Therefore, manual RevealNetworkGridOnPulse is likely redundant for Devices (but harmless)
  // NOTE: Device does not have GetGameplayRoleComponent(), so we call ProcessRPGAction without it
  pingAction.ProcessRPGAction(gi);

  if NotEquals(logContext, "") {
    BNDebug(logContext, "[PING] Auto-PING completed on device");
  }
}

// Execute PING quickhack on NPC (Unconscious NPC breach)
private func ExecutePingQuickHackOnNPC(targetNPC: ref<ScriptedPuppet>, player: ref<PlayerPuppet>, opt logContext: String) -> Void {
  let npcPS: ref<ScriptedPuppetPS> = targetNPC.GetPuppetPS();
  if !IsDefined(npcPS) {
    if NotEquals(logContext, "") {
      BNError(logContext, "[PING] NPC PS not found");
    }
    return;
  }

  // Generate context for quickhack
  let context: GetActionsContext = npcPS.GenerateContext(
    gamedeviceRequestType.Remote,
    Device.GetInteractionClearance(),
    player,
    targetNPC.GetEntityID()
  );

  // Get all available actions for this NPC
  let actionRecords: array<wref<ObjectAction_Record>>;
  let puppetActions: array<ref<PuppetAction>>;

  targetNPC.GetRecord().ObjectActions(actionRecords);
  npcPS.GetAllChoices(actionRecords, context, puppetActions);

  if NotEquals(logContext, "") {
    BNTrace(logContext, "[PING] Total puppet actions available: " + ToString(ArraySize(puppetActions)));
  }

  // Find PING action
  let pingAction: ref<PuppetAction>;
  let i: Int32 = 0;
  while i < ArraySize(puppetActions) {
    if NotEquals(logContext, "") {
      BNTrace(logContext, "[PING] Checking action " + ToString(i) + ": " + TDBID.ToStringDEBUG(puppetActions[i].GetObjectActionID()));
    }

    if Equals(puppetActions[i].GetObjectActionID(), t"QuickHack.BasePingHack") {
      pingAction = puppetActions[i];
      if NotEquals(logContext, "") {
        BNTrace(logContext, "[PING] Found BasePingHack action!");
      }
      break;
    }
    i += 1;
  }

  if !IsDefined(pingAction) {
    if NotEquals(logContext, "") {
      BNDebug(logContext, "[PING] PING quickhack not available on this NPC");
    }
    return;
  }

  // Set executor and requester (Vanilla pattern)
  pingAction.SetExecutor(player);
  pingAction.RegisterAsRequester(targetNPC.GetEntityID());  // NPC is the requester (target of QuickHack)

  // Execute PING action via ProcessRPGAction (Vanilla-compliant flow)
  let gi: GameInstance = targetNPC.GetGame();

  if NotEquals(logContext, "") {
    BNTrace(logContext, "[PING] Executing auto-PING via ProcessRPGAction - Target: " + ToString(targetNPC.GetEntityID()) + ", Action: " + TDBID.ToStringDEBUG(pingAction.GetObjectActionID()));
  }

  // Enable cost skipping for auto-PING (free execution)
  // NOTE: SetCanSkipPayCost(true) prevents RAM consumption
  // WARNING: ProcessRPGAction still grants QuickHack experience (limitation of Vanilla API)
  //          No built-in flag exists to skip experience award without custom wrapper
  //          This is acceptable for auto-PING: minimal XP reward for automated action
  pingAction.SetCanSkipPayCost(true);

  // Execute via ProcessRPGAction (complete Vanilla flow)
  // This handles:
  //   1. Cost payment (skipped via SetCanSkipPayCost)
  //   2. Status effect application (if any)
  //   3. Upload progress (if activation time > 0)
  //   4. Completion rewards (if any)
  //   5. Experience award (handled by ProcessRPGAction)
  //   6. Network reveal (via internal RevealNetworkGridOnPulse)
  pingAction.ProcessRPGAction(gi, targetNPC.GetGameplayRoleComponent());

  if NotEquals(logContext, "") {
    BNDebug(logContext, "[PING] Auto-PING completed via ProcessRPGAction");
  }
}
