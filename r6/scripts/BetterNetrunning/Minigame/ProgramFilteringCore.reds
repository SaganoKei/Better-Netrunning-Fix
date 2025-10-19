module BetterNetrunning.Minigame

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Integration.*

/*
 * ============================================================================
 * PROGRAM FILTERING MODULE
 * ============================================================================
 *
 * PURPOSE:
 * Determines which breach programs (daemons) should be available in the
 * breach minigame based on context, settings, and device state.
 *
 * FUNCTIONALITY:
 * - Network connectivity filtering (remove unlock programs if not connected)
 * - Device type filtering (access points vs backdoor devices)
 * - Access point program restrictions (based on user settings)
 * - Non-netrunner NPC restrictions (limit programs for regular NPCs)
 * - Already-breached program removal (prevent re-breach of same type)
 * - Device type availability (remove programs for unavailable device types)
 * - Datamine V1/V2 removal (based on user settings)
 *
 * CRITICAL LIMITATION - CustomHackingSystem RemoteBreach:
 * This filtering applies ONLY to vanilla Access Point and NPC breaches that
 * use MinigameGenerationRuleScalingPrograms.FilterPlayerPrograms().
 *
 * CustomHackingSystem RemoteBreach uses a completely separate pipeline:
 *   - Daemon lists are statically defined in remoteBreach.lua at initialization
 *   - CustomHackingSystem.StartNewHackInstance() bypasses FilterPlayerPrograms()
 *   - Daemon availability is determined by target type (Computer/Device/Vehicle),
 *     NOT by actual network composition
 *   - PhysicalRangeFilter and other dynamic filters do NOT apply to RemoteBreach
 *
 * DESIGN RATIONALE:
 * RemoteBreach daemons represent the CAPABILITIES granted by breaching that
 * target type, not the devices present in the network. This is by design and
 * cannot be changed without modifying CustomHackingSystem API or creating
 * multiple minigame variants per device composition (48+ definitions).
 *
 * MOD COMPATIBILITY:
 * These functions are called from FilterPlayerPrograms() @wrapMethod,
 * ensuring compatibility with other mods that modify breach programs.
 *
 * ============================================================================
 */


// ==================== Network & Device Type Filtering ====================

/*
 * Returns true if unlock programs should be removed (when target is not connected to network)
 *
 * @param actionID - The program's TweakDB ID
 * @param connectedToNetwork - Whether the target is connected to a network
 * @return True if the program should be removed
 */
public func ShouldRemoveNetworkPrograms(actionID: TweakDBID, connectedToNetwork: Bool) -> Bool {
  if connectedToNetwork {
    return false;
  }
  return IsUnlockQuickhackAction(actionID);
}

/*
 * Returns true if device-specific programs should be removed (for non-access-point devices)
 *
 * CRITICAL FIX: Exclude Computers - they should have full network access (same as Access Points)
 *
 * @param actionID - The program's TweakDB ID
 * @param entity - The target entity (device/NPC)
 * @return True if the program should be removed
 */
public func ShouldRemoveDeviceBackdoorPrograms(actionID: TweakDBID, entity: wref<GameObject>) -> Bool {
  // Only applies to non-access-point, non-computer devices (Backdoor devices like Camera/Door)
  if !DaemonFilterUtils.IsRegularDevice(entity) {
    return false;
  }
  return actionID == BNConstants.PROGRAM_DATAMINE_MASTER()
      || actionID == BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()
      || actionID == BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS();
}

// ==================== Access Point & Remote Breach Filtering ====================

/*
 * Returns true if access point programs should be restricted (based on user settings)
 *
 * @param actionID - The program's TweakDB ID
 * @param miniGameActionRecord - The program's record data
 * @param isRemoteBreach - Whether this is a remote breach (CustomHackingSystem)
 * @return True if the program should be removed
 */
public func ShouldRemoveAccessPointPrograms(actionID: TweakDBID, miniGameActionRecord: wref<MinigameAction_Record>, isRemoteBreach: Bool) -> Bool {
  // Allow all programs if remote breach
  if isRemoteBreach {
    return false;
  }
  // Remove non-access-point programs and non-unlock programs
  return NotEquals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.AccessPoint)
      && !IsUnlockQuickhackAction(actionID);
}

// ==================== Non-Netrunner NPC Filtering ====================

/*
 * Returns true if programs should be restricted for non-netrunner NPCs
 *
 * @param actionID - The program's TweakDB ID
 * @param miniGameActionRecord - The program's record data
 * @param isRemoteBreach - Whether this is a remote breach
 * @param entity - The target entity
 * @return True if the program should be removed
 */
public func ShouldRemoveNonNetrunnerPrograms(actionID: TweakDBID, miniGameActionRecord: wref<MinigameAction_Record>, isRemoteBreach: Bool, entity: wref<GameObject>) -> Bool {
  // Only applies to remote breach on non-netrunner NPCs
  if !IsRemoteNonNetrunner(isRemoteBreach, entity) {
    return false;
  }
  // Remove DNR-specific programs if applicable
  if ShouldRemoveDNRNonNetrunnerPrograms(actionID) {
    return true;
  }
  // Remove access point programs and device unlock programs
  return Equals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.AccessPoint)
      || actionID == BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()
      || actionID == BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS();
}

/*
 * Returns true if target is a remote breach on a non-netrunner NPC
 *
 * @param isRemoteBreach - Whether this is a remote breach
 * @param entity - The target entity
 * @return True if remote breach on non-netrunner NPC
 */
public func IsRemoteNonNetrunner(isRemoteBreach: Bool, entity: wref<GameObject>) -> Bool {
  if !isRemoteBreach {
    return false;
  }
  let puppet: wref<ScriptedPuppet> = entity as ScriptedPuppet;
  return IsDefined(puppet) && !puppet.IsNetrunnerPuppet();
}


// ==================== Helper Functions ====================

/*
 * Returns true if action is any type of unlock quickhack program
 *
 * @param actionID - The program's TweakDB ID
 * @return True if the action is an unlock quickhack program
 */
private func IsUnlockQuickhackAction(actionID: TweakDBID) -> Bool {
  return actionID == BNConstants.PROGRAM_UNLOCK_QUICKHACKS()
      || actionID == BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()
      || actionID == BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()
      || actionID == BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS();
}
