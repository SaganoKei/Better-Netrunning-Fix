// ============================================================================
// BetterNetrunning - Device Progressive Unlock
// ============================================================================
//
// PURPOSE:
// Manages device quickhack availability based on breach status and progression
//
// FUNCTIONALITY:
// - Progressive unlock restrictions (Cyberdeck tier, Intelligence stat)
// - Standalone device support via radial breach system (50m radius)
// - Network isolation detection with auto-unlock for unsecured networks
// - Device-type-specific permissions (Camera, Turret, Basic)
// - Special always-allowed quickhacks (Ping, Distraction)
//
// ARCHITECTURE:
// - Extract Method pattern with shallow nesting (max 2 levels)
// - Clear separation of concerns between entry points
// - Unified permission calculation system
//

module BetterNetrunning.Devices
import BetterNetrunning.Logging.*

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Systems.*
import BetterNetrunning.Breach.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.RadialUnlock.*

// ============================================================================
// Progressive Unlock System
// ============================================================================

/*
 * Checks if device is breached with expiration support
 *
 * Features:
 * - Returns true if device has valid (non-expired) breach timestamp
 * - Supports permanent unlock (duration = 0)
 * - Supports temporary unlock with expiration check
 * - Applies to all breach types (AP/NPC/Remote)
 */
@addMethod(ScriptableDeviceComponentPS)
public final func IsBreached() -> Bool {
  let sharedPS: ref<SharedGameplayPS> = this;
  if !IsDefined(sharedPS) {
    return false;
  }

  // Check all device types with expiration
  let gameInstance: GameInstance = this.GetGameInstance();

  // Check Basic subnet (most common)
  if BreachStatusUtils.IsBreachedWithExpiration(sharedPS.m_betterNetrunningUnlockTimestampBasic, gameInstance) {
    return true;
  }

  // Check Camera subnet
  if BreachStatusUtils.IsBreachedWithExpiration(sharedPS.m_betterNetrunningUnlockTimestampCameras, gameInstance) {
    return true;
  }

  // Check Turret subnet
  if BreachStatusUtils.IsBreachedWithExpiration(sharedPS.m_betterNetrunningUnlockTimestampTurrets, gameInstance) {
    return true;
  }

  // Check NPC subnet
  if BreachStatusUtils.IsBreachedWithExpiration(sharedPS.m_betterNetrunningUnlockTimestampNPCs, gameInstance) {
    return true;
  }

  return false;
}

/*
 * Applies progressive unlock restrictions to device quickhacks before breach
 *
 * Operations:
 * - Checks player progression (Cyberdeck tier, Intelligence stat)
 * - Checks device type to determine available quickhacks
 * - Uses shallow nesting (max 2 levels) via Extract Method pattern
 */
@addMethod(ScriptableDeviceComponentPS)
public final func SetActionsInactiveUnbreached(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Step 1: Get device classification
  let deviceInfo: DeviceBreachInfo = this.GetDeviceBreachInfo();

  // Step 2: Update standalone device breach state (radial unlock)
  this.UpdateStandaloneDeviceBreachState(deviceInfo);

  // Step 3: Calculate device permissions based on breach state + progression
  let permissions: DevicePermissions = this.CalculateDevicePermissions(deviceInfo);

  // Step 4: Apply permissions to all actions
  this.ApplyPermissionsToActions(actions, deviceInfo, permissions);
}

/*
 * Gets device classification and network status
 *
 * @return DeviceBreachInfo with device type flags and network status
 */
@addMethod(ScriptableDeviceComponentPS)
private final func GetDeviceBreachInfo() -> DeviceBreachInfo {
  let info: DeviceBreachInfo;
  info.isCamera = DaemonFilterUtils.IsCamera(this);
  info.isTurret = DaemonFilterUtils.IsTurret(this);

  let sharedPS: ref<SharedGameplayPS> = this;
  if IsDefined(sharedPS) {
    let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
    info.isStandaloneDevice = ArraySize(apControllers) == 0;
  }

  // DEBUG: Log device type for vehicle debugging
  let isVehicle: Bool = IsDefined(this as VehicleComponentPS);
  if isVehicle {
    BNDebug("SetActionsInactiveUnbreached", "Vehicle detected - breachedBasic: " + ToString(BreachStatusUtils.IsBasicBreached(sharedPS)));
  }

  return info;
}

/*
 * Updates breach flags for standalone devices within radial breach radius.
 *
 * CRITICAL FIX: Only persists timestamps already set by daemon unlock.
 * Timestamps are persistent (@persistent in SharedGameplayPS).
 *
 * @param deviceInfo - Device classification info
 */
@addMethod(ScriptableDeviceComponentPS)
private final func UpdateStandaloneDeviceBreachState(deviceInfo: DeviceBreachInfo) -> Void {
  // Only process standalone devices that are within radial breach radius
  if !deviceInfo.isStandaloneDevice || !ShouldUnlockStandaloneDevice(this, this.GetGameInstance()) {
    return;
  }

  // PERSISTENCE FIX: Mark device as permanently breached to survive save/load
  // CRITICAL FIX (Problem ②): Only persist timestamps that were ALREADY SET by daemon unlock
  // REASON: This ensures save/load compatibility while respecting daemon unlock restrictions
  //
  // OLD LOGIC (INCORRECT):
  //   Set timestamp to current time for ALL standalone devices within radius (ignored daemon flags)
  //
  // NEW LOGIC (CORRECT):
  //   Timestamps are already persistent and set by daemon unlock
  //   Only ensures timestamps remain > 0.0 after save/load (daemon unlock is authoritative)
  //
  // Scenario: NPC Subnet breach + vehicle within 50m
  //   - Daemon unlock sets m_betterNetrunningUnlockTimestampNPCs = currentTime (NPCs only)
  //   - This method does NOT set m_betterNetrunningUnlockTimestampBasic (vehicle stays locked)
  //   - After save/load, vehicle remains correctly locked (timestamp = 0.0)

  // No action needed - timestamps are already persistent (@persistent in SharedGameplayPS)
  // This method now serves as documentation for the radial unlock discovery mechanism
}

/*
 * Calculates permissions based on breach state and player progression.
 * Device is permitted if breached OR progression requirements met for each device type.
 *
 * @param deviceInfo - Device classification info
 * @return DevicePermissions with calculated permission flags
 */
@addMethod(ScriptableDeviceComponentPS)
private final func CalculateDevicePermissions(deviceInfo: DeviceBreachInfo) -> DevicePermissions {
  let permissions: DevicePermissions;
  let gameInstance: GameInstance = this.GetGameInstance();
  let sharedPS: ref<SharedGameplayPS> = this;

  // Device-type permissions: Breached OR progression requirements met
  permissions.allowCameras = BreachStatusUtils.IsCamerasBreached(sharedPS) || ShouldUnlockHackDevice(gameInstance, BetterNetrunningSettings.AlwaysCameras(), BetterNetrunningSettings.ProgressionCyberdeckCameras(), BetterNetrunningSettings.ProgressionIntelligenceCameras());
  permissions.allowTurrets = BreachStatusUtils.IsTurretsBreached(sharedPS) || ShouldUnlockHackDevice(gameInstance, BetterNetrunningSettings.AlwaysTurrets(), BetterNetrunningSettings.ProgressionCyberdeckTurrets(), BetterNetrunningSettings.ProgressionIntelligenceTurrets());
  permissions.allowBasicDevices = BreachStatusUtils.IsBasicBreached(sharedPS) || ShouldUnlockHackDevice(gameInstance, BetterNetrunningSettings.AlwaysBasicDevices(), BetterNetrunningSettings.ProgressionCyberdeckBasicDevices(), BetterNetrunningSettings.ProgressionIntelligenceBasicDevices());

  // Special always-allowed quickhacks
  permissions.allowPing = BetterNetrunningSettings.AlwaysAllowPing();
  permissions.allowDistraction = BetterNetrunningSettings.AlwaysAllowDistract();

  return permissions;
}

/*
 * Applies calculated permissions to all actions.
 * Iterates actions and sets inactive state with reason if not allowed.
 *
 * @param actions - Array of DeviceAction refs to process
 * @param deviceInfo - Device classification info
 * @param permissions - Calculated DevicePermissions
 */
@addMethod(ScriptableDeviceComponentPS)
private final func ApplyPermissionsToActions(actions: script_ref<array<ref<DeviceAction>>>, deviceInfo: DeviceBreachInfo, permissions: DevicePermissions) -> Void {
  // Check if RemoteBreach is locked due to breach failure
  let isRemoteBreachLocked: Bool = BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(this);

  // Check RemoteBreach RAM availability (centralized in RemoteBreachRAMUtils)
  RemoteBreachRAMUtils.CheckAndLockRemoteBreachRAM(actions);

  let i: Int32 = 0;
  while i < ArraySize(Deref(actions)) {
    let sAction: ref<ScriptableDeviceAction> = (Deref(actions)[i] as ScriptableDeviceAction);

    // Standard permission check
    if IsDefined(sAction) && !this.ShouldAllowAction(sAction, deviceInfo.isCamera, deviceInfo.isTurret, permissions.allowCameras, permissions.allowTurrets, permissions.allowBasicDevices, permissions.allowPing, permissions.allowDistraction) {
      sAction.SetInactive();

      // Use vanilla lock message when RemoteBreach is locked (breach failure penalty)
      // Otherwise use Better Netrunning's custom message
      if isRemoteBreachLocked {
        sAction.SetInactiveReason(BNConstants.LOCKEY_NO_NETWORK_ACCESS());  // "No network access rights"
      } else {
        sAction.SetInactiveReason(LocKeyToString(BNConstants.LOCKEY_QUICKHACKS_LOCKED()));
      }
    }

    i += 1;
  }
}

/*
 * Determines if an action should be allowed based on device type and progression.
 * Centralized permission logic for all quickhack actions.
 *
 * @param action - DeviceAction to check
 * @param isCamera - True if device is camera
 * @param isTurret - True if device is turret
 * @param allowCameras - Permission flag for cameras
 * @param allowTurrets - Permission flag for turrets
 * @param allowBasicDevices - Permission flag for basic devices
 * @param allowPing - Permission flag for Ping
 * @param allowDistraction - Permission flag for Distraction
 * @return True if action is allowed, false otherwise
 */
@addMethod(ScriptableDeviceComponentPS)
private final func ShouldAllowAction(action: ref<ScriptableDeviceAction>, isCamera: Bool, isTurret: Bool, allowCameras: Bool, allowTurrets: Bool, allowBasicDevices: Bool, allowPing: Bool, allowDistraction: Bool) -> Bool {
  let className: CName = action.GetClassName();

  // RemoteBreachAction must ALWAYS be allowed (CustomHackingSystem integration)
  if IsCustomRemoteBreachAction(className) {
    return true;
  }

  // Always-allowed quickhacks
  if Equals(className, BNConstants.ACTION_PING_DEVICE()) && allowPing {
    return true;
  }
  if Equals(className, BNConstants.ACTION_DISTRACTION()) && allowDistraction {
    return true;
  }

  // Device-type-specific permissions
  if isCamera && allowCameras {
    return true;
  }
  if isTurret && allowTurrets {
    return true;
  }
  if !isCamera && !isTurret && allowBasicDevices {
    return true;
  }

  return false;
}

// ============================================================================
// Helper Methods: Device Lock State
// ============================================================================


/*
 * Removes only vanilla RemoteBreach actions.
 * Cleans up vanilla RemoteBreach when device is already breached.
 * Uses Extract Method pattern with clear single responsibility.
 *
 * @param outActions - Array of DeviceAction refs to process
 */
@addMethod(ScriptableDeviceComponentPS)
private final func RemoveVanillaRemoteBreachActions(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let i: Int32 = ArraySize(Deref(outActions)) - 1;

  while i >= 0 {
    let action: ref<DeviceAction> = Deref(outActions)[i];

    if IsDefined(action as RemoteBreach) {
      ArrayErase(Deref(outActions), i);
      BNDebug("RemoveVanillaRemoteBreachActions", "Removed vanilla RemoteBreach (device already breached)");
    }

    i -= 1;
  }
}

// ============================================================================
// Quickhack Finalization
// ============================================================================

/*
 * Finalizes device quickhack actions before presenting to the player.
 *
 * VANILLA DIFF: Applies post-processing to replace/remove RemoteBreach while
 * preserving Ping and vanilla restrictions.
 *
 * @param outActions - Array of DeviceAction refs to finalize
 * @param context - GetActionsContext for quickhack evaluation
 */
@wrapMethod(ScriptableDeviceComponentPS)
protected final func FinalizeGetQuickHackActions(outActions: script_ref<array<ref<DeviceAction>>>, const context: script_ref<GetActionsContext>) -> Void {
  // Pre-processing: Early exit checks (before base game processing)
  if !this.ShouldProcessQuickHackActions(outActions) {
    return;
  }

  // Base game processing: Generate RemoteBreach + Ping + Apply restrictions
  wrappedMethod(outActions, context);

  // Post-processing: Apply Better Netrunning enhancements
  this.ApplyBetterNetrunningDeviceFilters(outActions);
}
