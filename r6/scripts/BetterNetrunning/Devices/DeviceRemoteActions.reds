module BetterNetrunning.Devices

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Systems.*
import BetterNetrunning.Breach.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.RemoteBreach.Actions.*
import BetterNetrunning.RadialUnlock.*


// ==================== Remote Actions ====================

/*
 * Provides device quickhack actions based on breach status and player progression
 *
 * VANILLA DIFF: Replaces SetActionsInactiveAll() with SetActionsInactiveUnbreached() for progressive unlock
 * FIXED: Always apply progressive unlock restrictions in Progressive Mode (don't rely on IsQuickHacksExposed)
 * FIXED: Auto-unlock networks without access points when UnlockIfNoAccessPoint is false
 *
 * ARCHITECTURE:
 * - Progressive unlock via SetActionsInactiveUnbreached() (checks Cyberdeck tier, Intelligence)
 * - Standalone device support via radial breach system (50m radius)
 * - Network centroid calculation for isolated NPC auto-unlock
 */
@replaceMethod(ScriptableDeviceComponentPS)
public final func GetRemoteActions(out outActions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
  // Early exit if quickhacks are disabled or device is not functional
  if this.m_disableQuickHacks || this.IsDisabled() {
    return;
  }

  // Get quickhack actions from device
  this.GetQuickHackActions(outActions, context);

  // CRITICAL FIX: Some devices (Jukebox, NetrunnerChair, DisposalDevice) override GetQuickHackActions()
  // without calling wrappedMethod(), causing TweakDB RemoteBreach to not be removed.
  // Remove ALL vanilla RemoteBreach actions here as a final cleanup step.
  let i: Int32 = ArraySize(outActions) - 1;
  let hasCustomRemoteBreach: Bool = false;

  while i >= 0 {
    let action: ref<DeviceAction> = outActions[i];
    // Use constant instead of magic string
    if IsDefined(action) && Equals(action.actionName, BNConstants.ACTION_REMOTE_BREACH()) {
      let className: CName = action.GetClassName();

      if IsCustomRemoteBreachAction(className) {
        hasCustomRemoteBreach = true;
      } else {
        ArrayErase(outActions, i);
      }
    }
    i -= 1;
  }

  // CRITICAL FIX: Add Custom RemoteBreach if not present (for devices that don't call wrappedMethod)
  // This ensures NetrunnerChair, Jukebox, DisposalDevice, TV, etc. get Custom RemoteBreach
  if !hasCustomRemoteBreach && !BetterNetrunningSettings.UnlockIfNoAccessPoint() {
    this.TryAddMissingCustomRemoteBreachWrapper(outActions);
  }

  // NEW REQUIREMENT: Remove Custom RemoteBreach if device is already unlocked (except Vehicles)
  // Vehicles always show RemoteBreach regardless of unlock state
  this.RemoveCustomRemoteBreachIfUnlocked(outActions);

  // Check if network has no access points (unsecured network)
  let sharedPS: ref<SharedGameplayPS> = this;
  let hasAccessPoint: Bool = true;
  let apCount: Int32 = 0;
  if IsDefined(sharedPS) {
    let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
    apCount = ArraySize(apControllers);
    hasAccessPoint = apCount > 0;
  }

  // CRITICAL FIX: Correct logic for unsecured network
  // UnlockIfNoAccessPoint = true -> Devices without AP are always unlocked (no restrictions)
  // UnlockIfNoAccessPoint = false -> Devices without AP require breach (restrictions apply)
  let isUnsecuredNetwork: Bool = !hasAccessPoint && BetterNetrunningSettings.UnlockIfNoAccessPoint();

  // Check if RemoteBreach is locked due to breach failure
  let isRemoteBreachLocked: Bool = BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(this);

  // Handle sequencer lock or breach state
  if this.IsLockedViaSequencer() {
    // Sequencer locked: only allow RemoteBreach action
    // Use vanilla lock message when RemoteBreach is also locked (breach failure)
    if isRemoteBreachLocked {
      ScriptableDeviceComponentPS.SetActionsInactiveAll(outActions, BNConstants.LOCKEY_NO_NETWORK_ACCESS(), BNConstants.ACTION_REMOTE_BREACH());
    } else {
      ScriptableDeviceComponentPS.SetActionsInactiveAll(outActions, LocKeyToString(BNConstants.LOCKEY_QUICKHACKS_LOCKED()), BNConstants.ACTION_REMOTE_BREACH());
    }
    // Sequencer Lock: Apply RAM check to RemoteBreach (SetActionsInactiveAll doesn't check RAM)
    RemoteBreachRAMUtils.CheckAndLockRemoteBreachRAM(outActions);
  } else if !BetterNetrunningSettings.EnableClassicMode() && !isUnsecuredNetwork {
    // Progressive Mode: apply device-type-specific unlock restrictions (unless unsecured network)
    this.SetActionsInactiveUnbreached(outActions);
  }

  // If isUnsecuredNetwork == true, all quickhacks remain active (no restrictions applied)
}

/*
 * Allows quickhack menu to open when devices are not connected to an access point
 * VANILLA DIFF: Simplified from branching logic - equivalent to vanilla when QuickHacksExposedByDefault() is true
 * Removes the IsConnectedToBackdoorDevice() check that vanilla uses when QuickHacksExposedByDefault() is false
 */
@replaceMethod(Device)
public const func CanRevealRemoteActionsWheel() -> Bool {
  return this.ShouldRegisterToHUD() && !this.GetDevicePS().IsDisabled() && this.GetDevicePS().HasPlaystyle(EPlaystyle.NETRUNNER);
}
