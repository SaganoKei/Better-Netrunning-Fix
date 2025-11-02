// ============================================================================
// BetterNetrunning - RemoteBreach Action (Device)
// ============================================================================
//
// PURPOSE:
// Generic device RemoteBreach action implementation for regular devices
//
// FUNCTIONALITY:
// - Extends BaseRemoteBreachAction for generic devices (TV, Jukebox, etc)
// - HackingExtensions MOD integration
// - Device-specific StateSystem target management
//
// ARCHITECTURE:
// - Inherits Template Method pattern from BaseRemoteBreachAction
// - Conditional compilation for HackingExtensions dependency
// - Generic device handling for non-specialized devices
//

module BetterNetrunning.RemoteBreach.Actions

import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Breach.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

@if(ModuleExists("HackingExtensions"))
public class DeviceRemoteBreachAction extends BaseRemoteBreachAction {
    private let m_devicePS: ref<ScriptableDeviceComponentPS>;

    public func GetInteractionDescription() -> String {
        return "Remote Breach";
    }

    public func GetTweakDBChoiceRecord() -> String {
        return "Remote Breach";
    }

    public func SetDevicePS(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
        this.m_devicePS = devicePS;
    }

    public func InitializePrograms() -> Void {

        if !IsDefined(this.m_devicePS) {
            return;
        }

        let gameInstance: GameInstance = this.m_devicePS.GetGameInstance();
        let stateSystem: ref<DeviceRemoteBreachStateSystem> = StateSystemUtils.GetDeviceStateSystem(gameInstance);

        if IsDefined(stateSystem) {
            let availableDaemons: String = this.GetAvailableDaemonsForDevice();
            stateSystem.SetCurrentDevice(this.m_devicePS, availableDaemons);
        }
    }

    private func GetAvailableDaemonsForDevice() -> String {

        // Camera: basic + camera daemon
        if DaemonFilterUtils.IsCamera(this.m_devicePS) {
            return "basic,camera";
        }

        // Turret: basic + turret daemon
        if DaemonFilterUtils.IsTurret(this.m_devicePS) {
            return "basic,turret";
        }

        // Terminal: basic + npc daemon
        if IsDefined(this.m_devicePS as TerminalControllerPS) {
            return "basic,npc";
        }

        // Default: basic only
        return "basic";
    }
}

// -----------------------------------------------------------------------------
// Device Extensions
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func ActionCustomDeviceRemoteBreach() -> ref<DeviceRemoteBreachAction> {
    let action: ref<DeviceRemoteBreachAction> = new DeviceRemoteBreachAction();
    action.SetDevicePS(this);
    RemoteBreachActionHelper.Initialize(action, this, n"DeviceRemoteBreach");

    // Set Device-specific minigame ID
    let difficulty: GameplayDifficulty = RemoteBreachActionHelper.GetCurrentDifficulty();
    RemoteBreachActionHelper.SetMinigameDefinition(action, MinigameTargetType.Device, difficulty, this);

    // Check executability with vanilla-compatible LocKeys:
    // - LocKey#27398: "RAM insufficient"
    // - LocKey#7021: "Network breach failure"
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let canExecute: Bool;
    let inactiveReason: String = RemoteBreachLockUtils.GetRemoteBreachInactiveReason(action, this, player, canExecute);

    // SetInactiveWithReason: Only call if action cannot be executed
    // - 1st arg: isActiveIf (false = mark as inactive, true = keep active)
    // - 2nd arg: LocKey string (reason for being inactive)
    if !canExecute {
      action.SetInactiveWithReason(false, inactiveReason);
    }

    // Directly call InitializePrograms() on the concrete type
    action.InitializePrograms();

    // CRITICAL: Register with CustomHackingSystem
    let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance());
    let hackSystem: ref<CustomHackingSystem> = container.Get(BNConstants.CLASS_CUSTOM_HACKING_SYSTEM()) as CustomHackingSystem;

    if IsDefined(hackSystem) {
        hackSystem.RegisterDeviceAction(action);
    }

    return action;
}

/*
 * Adds Device RemoteBreach action to QuickHack menu when eligible.
 *
 * VANILLA DIFF: Appends custom RemoteBreach after vanilla generation, removes
 * TweakDB-injected duplicate.
 *
 * @param actions - Output action list (will be appended when eligible)
 * @param context - GetActionsContext for quickhack evaluation
 */
@if(ModuleExists("HackingExtensions"))
@wrapMethod(ScriptableDeviceComponentPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
    wrappedMethod(actions, context);
    RemoteBreachActionHelper.RemoveTweakDBRemoteBreach(actions, n"DeviceRemoteBreachAction");

    // Guard 1: Exclude Computer and Vehicle (handled by dedicated wrappers)
    if DaemonFilterUtils.IsComputer(this) || IsDefined(this as VehicleComponentPS) {
        return;
    }

    // Guard 2: Check if RadialUnlock mode is active
    if BetterNetrunningSettings.UnlockIfNoAccessPoint() {
        return;
    }

    // Guard 3: Check device-specific RemoteBreach settings
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
        if !BetterNetrunningSettings.RemoteBreachEnabledDevice() {
            return;
        }
    }

    // Guard 4: Check if RemoteBreach is locked due to breach failure
    if BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(this) {
        return;
    }

    // Guard 5: Validate device entity
    let deviceEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(deviceEntity) {
        return;
    }

    // Guard 6: Check if device is already breached
    let deviceID: EntityID = deviceEntity.GetEntityID();
    let stateSystem: ref<DeviceRemoteBreachStateSystem> = StateSystemUtils.GetDeviceStateSystem(this.GetGameInstance());

    if IsDefined(stateSystem) && stateSystem.IsDeviceBreached(deviceID) {
        return;
    }

    let breachAction: ref<DeviceRemoteBreachAction> = this.ActionCustomDeviceRemoteBreach();
    ArrayPush(actions, breachAction);
}
