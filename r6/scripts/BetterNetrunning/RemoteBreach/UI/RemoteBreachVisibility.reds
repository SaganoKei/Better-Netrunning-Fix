// ============================================================================
// RemoteBreach Visibility Management Module
// ============================================================================
// This module manages RemoteBreach action visibility based on device unlock state.
//
// RESPONSIBILITIES:
// - RemoteBreach visibility control (show/hide based on device state)
// - RemoteBreach action injection (Computer, Vehicle, Device)
// - Device unlock state detection (daemon flags + RemoteBreach daemon completion)
// - RemoteBreach action removal from unlocked devices
//
// VISIBILITY RULES:
// RemoteBreach is hidden when ANY of the following conditions are met:
//   1. Device unlocked via daemon (UnlockQuickhacks/Camera/Turret)
//   2. RemoteBreach completed ANY daemon (Basic/NPC/Camera/Turret)
// Both conditions use OR logic.
//
// ARCHITECTURE:
// - AccessPointBreach: Dynamic filtering via vanilla hooks (betterNetrunning.reds)
// - RemoteBreach: Static definition via CustomHackingSystem (CustomHacking/*.reds)
// - RemoteBreachVisibility: Visibility management bridge (this file)
//
// DESIGN PATTERN:
// - Early Return: Prevent RemoteBreach addition if device already unlocked
// - Defense-in-Depth: Fallback removal if RemoteBreach slips through
// - Separation of Concerns: Focused on visibility logic only
//
// ============================================================================

module BetterNetrunning.RemoteBreach.UI
import BetterNetrunning.Core.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.RemoteBreach.Common.*
import BetterNetrunning.RemoteBreach.Actions.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Breach.*
import BetterNetrunning.*
import BetterNetrunningConfig.*

/*
 * Checks if device is already unlocked via daemon or CustomHackingSystem breach.
 *
 * Returns true if device unlocked via daemon (UnlockQuickhacks/Camera/Turret) OR completed
 * any RemoteBreach daemon (Basic/NPC/Camera/Turret). Prevents unnecessary RemoteBreach action
 * creation and UI flash.
 *
 * @return True if device is unlocked via daemon or CustomHackingSystem breach
 */
@addMethod(ScriptableDeviceComponentPS)
public final func IsDeviceAlreadyUnlocked() -> Bool {
  let sharedPS: ref<SharedGameplayPS> = this;
  if !IsDefined(sharedPS) {
    return false;
  }

  // Check 1: Vehicle-specific unlock (via UnlockQuickhacks daemon)
  if IsDefined(this as VehicleComponentPS) {
    return BreachStatusUtils.IsBasicBreached(sharedPS);
  }

  // Check 2: Camera-specific unlock (via UnlockCameraQuickhacks daemon)
  if DaemonFilterUtils.IsCamera(this) {
    return BreachStatusUtils.IsCamerasBreached(sharedPS);
  }

  // Check 3: Turret-specific unlock (via UnlockTurretQuickhacks daemon)
  if DaemonFilterUtils.IsTurret(this) {
    return BreachStatusUtils.IsTurretsBreached(sharedPS);
  }

  // Check 4a: Basic device unlock (via UnlockQuickhacks daemon)
  if BreachStatusUtils.IsBasicBreached(sharedPS) {
    return true;
  }

  // Check 4b: CustomHackingSystem RemoteBreach state
  let deviceEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  if IsDefined(deviceEntity) {
    let stateSystem: ref<DeviceRemoteBreachStateSystem> =
      GameInstance.GetScriptableSystemsContainer(this.GetGameInstance())
        .Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as DeviceRemoteBreachStateSystem;

    if IsDefined(stateSystem) {
      return stateSystem.IsDeviceBreached(deviceEntity.GetEntityID());
    }
  }

  return false;
}

/*
 * Tries to add Custom RemoteBreach action (Computer, Vehicle, or Device)
 * Only compiled when HackingExtensions module exists
 *
 * @param outActions - Array of device quickhacks (modified in-place)
 */
@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
public final func TryAddCustomRemoteBreach(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // EARLY EXIT: Device already unlocked, don't add RemoteBreach
  // This prevents UI flash of RemoteBreach before it gets removed
  if this.IsDeviceAlreadyUnlocked() {
    return;
  }

  // EARLY EXIT: Device locked by RemoteBreach failure penalty (50m radius, 10 minutes)
  if BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(this) {
    return;
  }

  // Check if Custom RemoteBreach already exists
  let hasCustomRemoteBreach: Bool = false;
  let i: Int32 = 0;
  while i < ArraySize(Deref(outActions)) {
    let action: ref<DeviceAction> = Deref(outActions)[i];
    if IsCustomRemoteBreachAction(action) {
      hasCustomRemoteBreach = true;
      break;
    }
    i += 1;
  }

  // Only add if Custom RemoteBreach doesn't exist
  if !hasCustomRemoteBreach {
    // Determine which type of Custom RemoteBreach to add
    let isComputer: Bool = DaemonFilterUtils.IsComputer(this);
    let isVehicle: Bool = IsDefined(this as VehicleComponentPS);

    if isComputer {
      // Check if Computer RemoteBreach is enabled
      if !BetterNetrunningSettings.RemoteBreachEnabledComputer() {
        return;
      }
      let computerPS: ref<ComputerControllerPS> = this as ComputerControllerPS;
      let breachAction: ref<RemoteBreachAction> = computerPS.ActionCustomRemoteBreach();
      ArrayPush(Deref(outActions), breachAction);
    } else if isVehicle {
      // Check if Vehicle RemoteBreach is enabled
      if !BetterNetrunningSettings.RemoteBreachEnabledVehicle() {
        return;
      }
      let vehiclePS: ref<VehicleComponentPS> = this as VehicleComponentPS;
      let breachAction: ref<VehicleRemoteBreachAction> = vehiclePS.ActionCustomVehicleRemoteBreach();
      ArrayPush(Deref(outActions), breachAction);
    } else {
      // Check Device RemoteBreach settings based on device type
      let isCamera: Bool = DeviceTypeUtils.IsCameraDevice(this);
      let isTurret: Bool = DeviceTypeUtils.IsTurretDevice(this);

      if isCamera {
        if !BetterNetrunningSettings.RemoteBreachEnabledCamera() {
          return;
        }
      } else if isTurret {
        if !BetterNetrunningSettings.RemoteBreachEnabledTurret() {
          return;
        }
      } else {
        // Other devices (Terminal, Door, etc.)
        if !BetterNetrunningSettings.RemoteBreachEnabledDevice() {
          return;
        }
      }

      let breachAction: ref<DeviceRemoteBreachAction> = this.ActionCustomDeviceRemoteBreach();
      ArrayPush(Deref(outActions), breachAction);
    }
  }
}

/*
 * Adds missing Custom RemoteBreach to devices that override GetQuickHackActions() without
 * calling wrappedMethod() (NetrunnerChair, Jukebox, DisposalDevice).
 *
 * Only compiled when HackingExtensions module exists.
 *
 * @param outActions - Array of device quickhacks (modified in-place)
 */
@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
public final func TryAddMissingCustomRemoteBreach(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // EARLY EXIT: Device already unlocked, don't add RemoteBreach
  // This prevents RemoteBreach from appearing on devices unlocked via network breach
  if this.IsDeviceAlreadyUnlocked() {
    return;
  }

  // EARLY EXIT: Device locked by RemoteBreach failure penalty
  if BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(this) {
    // Remove existing DeviceRemoteBreachAction if present (added before breach failure)
    let i: Int32 = ArraySize(Deref(outActions)) - 1;
    while i >= 0 {
      let action: ref<DeviceAction> = Deref(outActions)[i];
      let className: CName = action.GetClassName();
      if IsCustomRemoteBreachAction(className) || IsDefined(action as RemoteBreach) {
        ArrayErase(Deref(outActions), i);
      }
      i -= 1;
    }
    return;  // Don't show minigame entry when unlocked
  }

  // Skip Computer and Vehicle (they have specialized implementations)
  let isComputer: Bool = DaemonFilterUtils.IsComputer(this);
  let isVehicle: Bool = IsDefined(this as VehicleComponentPS);

  if !isComputer && !isVehicle {
    // Check Device RemoteBreach settings based on device type
    let isCamera: Bool = DeviceTypeUtils.IsCameraDevice(this);
    let isTurret: Bool = DeviceTypeUtils.IsTurretDevice(this);

    if isCamera {
      if !BetterNetrunningSettings.RemoteBreachEnabledCamera() {
        return;
      }
    } else if isTurret {
      if !BetterNetrunningSettings.RemoteBreachEnabledTurret() {
        return;
      }
    } else {
      // Other devices (Terminal, Door, etc.)
      if !BetterNetrunningSettings.RemoteBreachEnabledDevice() {
        return;
      }
    }
    let breachAction: ref<DeviceRemoteBreachAction> = this.ActionCustomDeviceRemoteBreach();
    ArrayPush(Deref(outActions), breachAction);
  }
}

/*
 * Removes RemoteBreach action from unlocked devices as defensive cleanup.
 *
 * Note: Primary check is IsDeviceAlreadyUnlocked() in TryAddCustomRemoteBreach()
 *
 * Processing steps:
 * 1. Checks unlock timestamp expiration via UnlockExpirationUtils
 * 2. Re-enables JackIn if expired
 * 3. Queries DeviceRemoteBreachStateSystem for CustomHackingSystem breach state (Basic devices only)
 * 4. Removes action if unlocked
 *
 * @param outActions Array of device quickhacks (modified in-place)
 */
@addMethod(ScriptableDeviceComponentPS)
public final func RemoveCustomRemoteBreachIfUnlocked(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Step 1: Check timestamp expiration for device type
  let expirationResult: UnlockExpirationResult = UnlockExpirationUtils.CheckUnlockExpiration(this);

  // Step 2: Re-enable JackIn if unlock expired
  if expirationResult.wasExpired {
    DeviceInteractionUtils.EnableJackInInteractionForAccessPoint(this);
  }

  // Step 3: Check CustomHackingSystem RemoteBreach state (Basic devices only)
  let isUnlocked: Bool = expirationResult.isUnlocked;
  if !isUnlocked && !expirationResult.wasExpired && !DaemonFilterUtils.IsCamera(this) && !DaemonFilterUtils.IsTurret(this) && !IsDefined(this as VehicleComponentPS) {
    isUnlocked = this.IsBasicDeviceBreachedByCustomHackingSystem();
  }

  // Step 4: Remove CustomAccessBreach action if unlocked
  if isUnlocked {
    this.RemoveCustomRemoteBreachAction(outActions);
  }
}

/*
 * Checks if basic device is breached via CustomHackingSystem RemoteBreach. Queries
 * DeviceRemoteBreachStateSystem for breach state, only applies to basic devices (Computer,
 * TV, etc.). Early return pattern with type-safe casting.
 *
 * @return True if device breached via CustomHackingSystem RemoteBreach
 */
@addMethod(ScriptableDeviceComponentPS)
private final func IsBasicDeviceBreachedByCustomHackingSystem() -> Bool {
  let deviceEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(deviceEntity) { return false; }

  let deviceID: EntityID = deviceEntity.GetEntityID();
  let stateSystem: ref<DeviceRemoteBreachStateSystem> =
    GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as DeviceRemoteBreachStateSystem;

  if !IsDefined(stateSystem) { return false; }

  return stateSystem.IsDeviceBreached(deviceID);
}

/*
 * Removes CustomAccessBreach action from action list. Finds first CustomAccessBreach action
 * in list, removes action and exits (assumes max 1 RemoteBreach per device). Forward iteration
 * with early break.
 *
 * @param outActions Array of device quickhacks (modified in-place)
 */
@addMethod(ScriptableDeviceComponentPS)
private final func RemoveCustomRemoteBreachAction(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let i: Int32 = 0;
  while i < ArraySize(Deref(outActions)) {
    let action: ref<DeviceAction> = Deref(outActions)[i];
    if IsCustomRemoteBreachAction(action) {
      ArrayErase(Deref(outActions), i);
      break;
    }
    i += 1;
  }
}
