module BetterNetrunning.Devices

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Systems.*
import BetterNetrunning.Breach.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.RadialUnlock.*

/*
 * ============================================================================
 * DEVICE QUICKHACKS MODULE
 * ============================================================================
 *
 * PURPOSE:
 * Manages device quickhack availability based on breach status and player
 * progression requirements.
 *
 * FUNCTIONALITY:
 * - Progressive unlock restrictions (Cyberdeck tier, Intelligence stat)
 * - Standalone device support via radial breach system (50m radius)
 * - Network isolation detection -> auto-unlock for unsecured networks
 * - Device-type-specific permissions (Camera, Turret, Basic)
 * - Special always-allowed quickhacks (Ping, Distraction)
 *
 * ARCHITECTURE:
 * - SetActionsInactiveUnbreached(): Main entry point for progressive unlock
 * - FinalizeGetQuickHackActions(): Finalizes actions before presenting to player
 * - GetRemoteActions(): Provides device quickhack actions based on breach status
 * - CanRevealRemoteActionsWheel(): Controls quickhack menu visibility
 *
 * ARCHITECTURE:
 * - Shallow nesting (max 2 levels) using Extract Method pattern
 * - Clear separation of concerns
 *
 * ============================================================================
 */

// ==================== Progressive Unlock System ====================

/*
 * Checks if device is breached with expiration support
 * Overrides vanilla IsBreached() to support temporary unlock feature
 *
 * FUNCTIONALITY:
 * - Returns true if device has valid (non-expired) breach timestamp
 * - Supports permanent unlock (duration = 0)
 * - Supports temporary unlock with expiration check
 *
 * APPLIES TO: All breach types (AP Breach, Unconscious NPC Breach, RemoteBreach)
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
 * Checks player progression (Cyberdeck tier, Intelligence stat) and device type
 * to determine which quickhacks should be available before successful breach
 *
 * ARCHITECTURE: Shallow nesting (max 2 levels) using Extract Method pattern for clarity
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

// Helper: Gets device classification and network status
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

// Helper: Updates breach flags for standalone devices within radial breach radius
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
  // EXAMPLE: NPC Subnet breach + vehicle within 50m
  //   - Daemon unlock sets m_betterNetrunningUnlockTimestampNPCs = currentTime (NPCs only)
  //   - This method does NOT set m_betterNetrunningUnlockTimestampBasic (vehicle stays locked)
  //   - After save/load, vehicle remains correctly locked (timestamp = 0.0)

  // No action needed - timestamps are already persistent (@persistent in SharedGameplayPS)
  // This method now serves as documentation for the radial unlock discovery mechanism
}

// Helper: Calculates permissions based on breach state and player progression
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

// Helper: Applies calculated permissions to all actions
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

// Helper: Determines if an action should be allowed based on device type and progression
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

// ==================== Helper Methods: Device Lock State ====================


/**
 * RemoveVanillaRemoteBreachActions - Remove only vanilla RemoteBreach actions
 *
 * PURPOSE: Clean up vanilla RemoteBreach when device is already breached
 * ARCHITECTURE: Extract Method pattern with clear single responsibility
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

// ==================== Quickhack Finalization ====================

/*
 * Finalizes device quickhack actions before presenting to player
 *
 * BETTER NETRUNNING ENHANCEMENTS:
 * - Replaces vanilla RemoteBreach with CustomAccessBreach (when HackingExtensions installed)
 * - Removes RemoteBreach if device already unlocked (Progressive Unlock integration)
 * - Preserves base game Ping and restrictions logic
 *
 * MOD COMPATIBILITY:
 * - Uses @wrapMethod for better compatibility with other device quickhack mods
 * - Base game processing happens first, then Better Netrunning applies post-processing filters
 *
 * ARCHITECTURE: Hybrid @wrapMethod with conditional post-processing
 * - Base game execution via wrappedMethod() (RemoteBreach + Ping + Restrictions)
 * - Post-processing: Replace base game RemoteBreach with CustomAccessBreach (if HackingExtensions)
 * - Post-processing: Remove RemoteBreach if device already unlocked
 */
@wrapMethod(ScriptableDeviceComponentPS)
protected final func FinalizeGetQuickHackActions(outActions: script_ref<array<ref<DeviceAction>>>, const context: script_ref<GetActionsContext>) -> Void {
  // Pre-processing: Early exit checks (before base game processing)
  if !this.ShouldProcessQuickHackActions(outActions) {
    return;
  }

  // DEBUG: Log device breach state
  let sharedPS: ref<SharedGameplayPS> = this;
  if IsDefined(sharedPS) {
    BNTrace("DeviceQuickhacks", s"FinalizeGetQuickHackActions - Timestamps: Basic=\(ToString(sharedPS.m_betterNetrunningUnlockTimestampBasic)), " +
      s"Camera=\(ToString(sharedPS.m_betterNetrunningUnlockTimestampCameras)), " +
      s"Turret=\(ToString(sharedPS.m_betterNetrunningUnlockTimestampTurrets)), " +
      s"NPC=\(ToString(sharedPS.m_betterNetrunningUnlockTimestampNPCs))");
  }

  BNDebug("DeviceQuickhacks", s"FinalizeGetQuickHackActions: Before wrappedMethod, actions=\(ArraySize(Deref(outActions)))");

  // Base game processing: Generate RemoteBreach + Ping + Apply restrictions
  wrappedMethod(outActions, context);

  // Post-processing: Apply Better Netrunning enhancements
  this.ApplyBetterNetrunningDeviceFilters(outActions);
}

