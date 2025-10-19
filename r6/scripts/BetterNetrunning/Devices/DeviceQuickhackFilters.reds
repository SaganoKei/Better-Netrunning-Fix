module BetterNetrunning.Devices

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Progression.*
import BetterNetrunning.Breach.Systems.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.RemoteBreach.Actions.*
import BetterNetrunning.RemoteBreach.UI.*
import BetterNetrunning.RadialUnlock.Core.*


// ==================== Post-Processing Filters ====================

/*
 * Applies Better Netrunning enhancements after base game processing
 *
 * FUNCTIONALITY:
 * - Replaces vanilla RemoteBreach with CustomAccessBreach (if HackingExtensions installed)
 * - Removes RemoteBreach if device already unlocked (Progressive Unlock integration)
 *
 * ARCHITECTURE:
 * - Conditional compilation at method level (separate implementations)
 * - Type-based action detection (RemoteBreach class check)
 */
@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func ApplyBetterNetrunningDeviceFilters(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Filter 1: Replace vanilla RemoteBreach with CustomAccessBreach
  this.ReplaceVanillaRemoteBreachWithCustom(outActions);

  // Filter 2: Remove RemoteBreach if device already unlocked
  this.RemoveRemoteBreachIfUnlocked(outActions);
}

@if(!ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func ApplyBetterNetrunningDeviceFilters(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Filter: Remove RemoteBreach if device already unlocked (fallback mode)
  this.RemoveRemoteBreachIfUnlocked(outActions);
}/*
 * Replaces vanilla RemoteBreach with CustomAccessBreach
 * Only compiled when HackingExtensions module exists
 *
 * ARCHITECTURE:
 * - Type-based detection: IsDefined(action as RemoteBreach)
 * - Removes vanilla RemoteBreach from actions array
 * - Adds CustomAccessBreach via TryAddCustomRemoteBreach()
 */
@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func ReplaceVanillaRemoteBreachWithCustom(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Guard 1: Device already breached - remove vanilla RemoteBreach only
  if this.IsBreached() {
    this.RemoveVanillaRemoteBreachActions(outActions);
    return;
  }

  // Guard 2: Device locked by breach failure - remove all RemoteBreach actions
  if this.IsDeviceLockedByBreachFailure() {
    this.RemoveAllRemoteBreachActions(outActions);
    return;
  }

  // Step 1: Remove vanilla RemoteBreach (if present)
  let i: Int32 = ArraySize(Deref(outActions)) - 1;
  let vanillaRemoteBreachFound: Bool = false;

  while i >= 0 {
    let action: ref<DeviceAction> = Deref(outActions)[i];
    // Type-based detection: Check if action is vanilla RemoteBreach
    if IsDefined(action as RemoteBreach) {
      ArrayErase(Deref(outActions), i);
      vanillaRemoteBreachFound = true;
      BNDebug("ReplaceVanillaRemoteBreachWithCustom", "Removed vanilla RemoteBreach");
    }
    i -= 1;
  }

  // Step 2: Add BetterNetrunning RemoteBreach action (if device is connected to backdoor network)
  if vanillaRemoteBreachFound && this.IsConnectedToBackdoorDevice() {
    let beforeSize: Int32 = ArraySize(Deref(outActions));
    BNDebug("ReplaceVanillaRemoteBreachWithCustom", "Before TryAddCustomRemoteBreach: " + IntToString(beforeSize) + " actions");

    this.TryAddCustomRemoteBreach(outActions);

    let afterSize: Int32 = ArraySize(Deref(outActions));
    BNDebug("ReplaceVanillaRemoteBreachWithCustom", "After TryAddCustomRemoteBreach: " + IntToString(afterSize) + " actions");

    if afterSize > beforeSize {
      BNDebug("ReplaceVanillaRemoteBreachWithCustom", "Added BetterNetrunning RemoteBreach (RemoteBreachAction/VehicleRemoteBreachAction/DeviceRemoteBreachAction)");
    } else {
      BNDebug("ReplaceVanillaRemoteBreachWithCustom", "BetterNetrunning RemoteBreach NOT added (locked or other reason)");
    }
  }
}

/*
 * Removes RemoteBreach/CustomAccessBreach if device already unlocked
 * Prevents redundant breach action when device quickhacks are already available
 *
 * ARCHITECTURE:
 * - Type-based detection: Checks RemoteBreach (vanilla) and CustomAccessBreach (custom)
 * - HackingExtensions version: Handles both types
 */
@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func RemoveRemoteBreachIfUnlocked(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Check if device is already unlocked (breached)
  if !this.IsBreached() {
    return; // Device not yet breached, keep RemoteBreach action
  }

  // Remove RemoteBreach/CustomAccessBreach from actions
  let i: Int32 = ArraySize(Deref(outActions)) - 1;
  while i >= 0 {
    let action: ref<DeviceAction> = Deref(outActions)[i];

    // Check vanilla RemoteBreach
    if IsDefined(action as RemoteBreach) {
      ArrayErase(Deref(outActions), i);
      BNDebug("RemoveRemoteBreachIfUnlocked", "Removed vanilla RemoteBreach (device already breached)");
    }

    // Check CustomAccessBreach
    let customBreachAction: ref<CustomAccessBreach> = action as CustomAccessBreach;
    if IsDefined(customBreachAction) {
      ArrayErase(Deref(outActions), i);
      BNDebug("RemoveRemoteBreachIfUnlocked", "Removed CustomAccessBreach (device already breached)");
    }

    i -= 1;
  }
}

/*
 * Removes RemoteBreach if device already unlocked (Fallback version)
 * Only handles vanilla RemoteBreach (no CustomAccessBreach)
 */
@if(!ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func RemoveRemoteBreachIfUnlocked(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Check if device is already unlocked (breached)
  if !this.IsBreached() {
    return; // Device not yet breached, keep RemoteBreach action
  }

  // Remove vanilla RemoteBreach from actions
  let i: Int32 = ArraySize(Deref(outActions)) - 1;
  while i >= 0 {
    let action: ref<DeviceAction> = Deref(outActions)[i];

    // Check vanilla RemoteBreach
    if IsDefined(action as RemoteBreach) {
      ArrayErase(Deref(outActions), i);
      BNDebug("RemoveRemoteBreachIfUnlocked", "Removed vanilla RemoteBreach (device already breached)");
    }

    i -= 1;
  }
}// ==================== Helper Methods (Shared Logic) ====================

/*
 * Wrapper for TryAddMissingCustomRemoteBreach (conditional compilation support)
 * Only compiled when HackingExtensions module exists
 */
@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func TryAddMissingCustomRemoteBreachWrapper(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  this.TryAddMissingCustomRemoteBreach(outActions);
}

/*
 * Stub wrapper when HackingExtensions module does not exist
 */
@if(!ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func TryAddMissingCustomRemoteBreachWrapper(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // No-op: CustomHackingSystem not installed
}

/*
 * Common early exit checks for FinalizeGetQuickHackActions
 * Returns true if processing should continue, false if should exit early
 */
@addMethod(ScriptableDeviceComponentPS)
private final func ShouldProcessQuickHackActions(outActions: script_ref<array<ref<DeviceAction>>>) -> Bool {
  // Early exit if device is not in nominal state
  if NotEquals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL) {
    return false;
  }
  // Early exit if quickhacks are disabled
  if this.m_disableQuickHacks {
    if ArraySize(Deref(outActions)) > 0 {
      ArrayClear(Deref(outActions));
    }
    return false;
  }
  return true;
}

/*
 * Adds Ping action to backdoor device
 * Common logic shared by both conditional compilation versions
 */
@addMethod(ScriptableDeviceComponentPS)
private final func AddPingAction(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let currentAction: ref<ScriptableDeviceAction> = this.ActionPing();
  currentAction.SetInactiveWithReason(!this.GetNetworkSystem().HasActivePing(this.GetMyEntityID()), BNConstants.LOCKEY_ACTIVATE_NETWORK_DEVICE());
  ArrayPush(Deref(outActions), currentAction);
}

/*
 * Override MarkActionsAsQuickHacks to support CustomAccessBreach
 * CRITICAL FIX: CustomAccessBreach extends PuppetAction, not ScriptableDeviceAction,
 * so base game MarkActionsAsQuickHacks skips it. This causes RemoteBreach to not appear in UI.
 *
 * MOD COMPATIBILITY: Changed from @replaceMethod to @wrapMethod for better compatibility.
 * Base game processing is preserved, CustomAccessBreach support is added as extension.
 */
@if(ModuleExists("HackingExtensions"))
@wrapMethod(ScriptableDeviceComponentPS)
protected final func MarkActionsAsQuickHacks(actionsToMark: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Execute base game logic first (handles all ScriptableDeviceAction)
  wrappedMethod(actionsToMark);

  // EXTENSION: Add CustomAccessBreach support (BetterNetrunning-specific)
  let i: Int32 = 0;
  while i < ArraySize(Deref(actionsToMark)) {
    // CRITICAL: Also check for CustomAccessBreach (CustomHackingSystem actions)
    // CustomAccessBreach extends PuppetAction, not ScriptableDeviceAction
    let customBreachAction: ref<CustomAccessBreach> = Deref(actionsToMark)[i] as CustomAccessBreach;
    if IsDefined(customBreachAction) {
      // CustomAccessBreach extends PuppetAction, so we can directly use it
      customBreachAction.SetAsQuickHack();
    }

    i += 1;
  }
}

/*
 * Applies common quickhack restrictions (power state, RPG checks, illegality)
 * Common logic shared by both conditional compilation versions
 */
@addMethod(ScriptableDeviceComponentPS)
private final func ApplyCommonQuickHackRestrictions(outActions: script_ref<array<ref<DeviceAction>>>, const context: script_ref<GetActionsContext>) -> Void {
  // Disable all actions if device is unpowered
  if this.IsUnpowered() {
    ScriptableDeviceComponentPS.SetActionsInactiveAll(outActions, BNConstants.LOCKEY_NOT_POWERED());
  }

  // Apply RPG system restrictions (skill checks, illegality, equipment check, etc.)
  this.EvaluateActionsRPGAvailabilty(outActions, context);
  this.SetActionIllegality(outActions, this.m_illegalActions.quickHacks);
  this.MarkActionsAsQuickHacks(outActions);
  this.SetActionsQuickHacksExecutioner(outActions);

  // NEW REQUIREMENT: Remove Custom RemoteBreach if device is already unlocked
  // This must be called AFTER all actions are added to prevent re-adding
  this.RemoveCustomRemoteBreachIfUnlocked(outActions);

  // NOTE: MoveVehicleRemoteBreachToBottom is NOT called here
  // It must be called AFTER TryAddCustomRemoteBreach in FinalizeGetQuickHackActions
}

