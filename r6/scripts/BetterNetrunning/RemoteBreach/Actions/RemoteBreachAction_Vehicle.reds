// ============================================================================
// BetterNetrunning - RemoteBreach Action (Vehicle)
// ============================================================================
//
// PURPOSE:
// Vehicle-specific RemoteBreach action implementation
//
// FUNCTIONALITY:
// - Extends BaseRemoteBreachAction for Vehicle devices
// - HackingExtensions MOD integration
// - Vehicle-specific StateSystem target management
//
// ARCHITECTURE:
// - Inherits Template Method pattern from BaseRemoteBreachAction
// - Conditional compilation for HackingExtensions dependency
// - Vehicle-specific device handling
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
public class VehicleRemoteBreachAction extends BaseRemoteBreachAction {
    private let m_vehiclePS: ref<VehicleComponentPS>;

    public func GetInteractionDescription() -> String {
        return "Remote Breach";
    }

    public func GetTweakDBChoiceRecord() -> String {
        return "Remote Breach";
    }

    public func SetVehiclePS(vehiclePS: ref<VehicleComponentPS>) -> Void {
        this.m_vehiclePS = vehiclePS;
    }

    public func InitializePrograms() -> Void {

        if !IsDefined(this.m_vehiclePS) {
            return;
        }

        let gameInstance: GameInstance = this.m_vehiclePS.GetGameInstance();
        let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);
        let stateSystem: ref<VehicleRemoteBreachStateSystem> = StateSystemUtils.GetVehicleStateSystem(gameInstance);

        if IsDefined(stateSystem) {
            let availableDaemons: String = "basic";
            stateSystem.SetCurrentVehicle(this.m_vehiclePS, availableDaemons);
        }
    }
}

// -----------------------------------------------------------------------------
// Vehicle Component Extensions
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
@addMethod(VehicleComponentPS)
private final func ActionCustomVehicleRemoteBreach() -> ref<VehicleRemoteBreachAction> {
    let action: ref<VehicleRemoteBreachAction> = new VehicleRemoteBreachAction();
    action.SetVehiclePS(this);
    RemoteBreachActionHelper.Initialize(action, this, n"VehicleRemoteBreach");

    // Set Vehicle-specific minigame ID (Basic daemon only)
    let difficulty: GameplayDifficulty = RemoteBreachActionHelper.GetCurrentDifficulty();
    RemoteBreachActionHelper.SetMinigameDefinition(action, MinigameTargetType.Vehicle, difficulty, this);

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
 * Adds Vehicle RemoteBreach action to QuickHack menu when eligible.
 *
 * Vanilla diff: Appends custom RemoteBreach after vanilla generation and removes
 * TweakDB-injected duplicate.
 *
 * Implementation: @wrapMethod - wrappedMethod() → remove TweakDB RemoteBreach →
 * guard checks → push custom action.
 *
 * @param actions - Output action list (will be appended when eligible)
 * @param context - GetActionsContext for quickhack evaluation
 */
@if(ModuleExists("HackingExtensions"))
@wrapMethod(VehicleComponentPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
    wrappedMethod(actions, context);
    RemoteBreachActionHelper.RemoveTweakDBRemoteBreach(actions, n"VehicleRemoteBreachAction");

    // Guard 1: Check if Vehicle RemoteBreach is enabled AND UnlockIfNoAccessPoint is disabled
    if !BetterNetrunningSettings.RemoteBreachEnabledVehicle() || BetterNetrunningSettings.UnlockIfNoAccessPoint() {
        return;
    }

    // Guard 2: Check if RemoteBreach is locked due to breach failure
    if BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(this) {
        return;
    }

    // Guard 3: Validate vehicle entity
    let vehicleEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(vehicleEntity) {
        return;
    }

    // Guard 4: Check if vehicle is already breached
    let vehicleID: EntityID = vehicleEntity.GetEntityID();
    let stateSystem: ref<VehicleRemoteBreachStateSystem> = StateSystemUtils.GetVehicleStateSystem(this.GetGameInstance());

    if IsDefined(stateSystem) && stateSystem.IsVehicleBreached(vehicleID) {
        return;
    }

    let breachAction: ref<VehicleRemoteBreachAction> = this.ActionCustomVehicleRemoteBreach();
    ArrayPush(actions, breachAction);
}
