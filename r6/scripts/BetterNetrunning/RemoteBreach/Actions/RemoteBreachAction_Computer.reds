// -----------------------------------------------------------------------------
// RemoteBreach Action - Computer
// -----------------------------------------------------------------------------
// Computer-specific RemoteBreach action implementation.
// Defines RemoteBreachAction class for Computer devices.
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// Computer Remote Breach Action
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public class RemoteBreachAction extends BaseRemoteBreachAction {
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

    public func SetComputerPS(computerPS: ref<ComputerControllerPS>) -> Void {
        this.m_devicePS = computerPS;
    }

    public func InitializePrograms() -> Void {

        if !IsDefined(this.m_devicePS) {
            return;
        }

        let computerPS: ref<ComputerControllerPS> = this.m_devicePS as ComputerControllerPS;

        if !IsDefined(computerPS) {
            return;
        }

        let gameInstance: GameInstance = computerPS.GetGameInstance();
        let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);

        if IsDefined(stateSystem) {
            stateSystem.SetCurrentComputer(computerPS);
        }
    }
}

// -----------------------------------------------------------------------------
// Computer Controller Extensions
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
@addMethod(ComputerControllerPS)
private final func ActionCustomRemoteBreach() -> ref<RemoteBreachAction> {
    let action: ref<RemoteBreachAction> = new RemoteBreachAction();
    action.SetComputerPS(this);
    RemoteBreachActionHelper.Initialize(action, this, BNConstants.ACTION_REMOTE_BREACH());

    // Set Computer-specific minigame ID
    let difficulty: GameplayDifficulty = RemoteBreachActionHelper.GetCurrentDifficulty();
    RemoteBreachActionHelper.SetMinigameDefinition(action, MinigameTargetType.Computer, difficulty, this);

    // Check executability with vanilla-compatible LocKeys:
    // - LocKey#27398: "RAM insufficient"
    // - LocKey#7021: "Network breach failure"
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let canExecute: Bool;
    let inactiveReason: String = RemoteBreachLockUtils.GetRemoteBreachInactiveReason(action, this, player, canExecute);

    // SetInactiveWithReason: Only call if action should be inactive
    // - 1st arg: inactive flag (true = inactive, false = active)
    // - 2nd arg: LocKey string (reason for being inactive)
    if !canExecute {
      action.SetInactiveWithReason(true, inactiveReason);
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
 * Adds Computer RemoteBreach action to QuickHack menu if conditions are met
 *
 * RATIONALE: Enables remote breaching of Computers without physical proximity
 * ARCHITECTURE: Guard Clause pattern (max 1-level nesting)
 *
 * CONDITIONS CHECKED:
 * - Computer RemoteBreach feature enabled (settings)
 * - RadialUnlock mode active (UnlockIfNoAccessPoint disabled)
 * - RemoteBreach not locked due to breach failure penalty
 * - Computer not already breached via RemoteBreach
 */
@if(ModuleExists("HackingExtensions"))
@wrapMethod(ComputerControllerPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
    wrappedMethod(actions, context);
    RemoteBreachActionHelper.RemoveTweakDBRemoteBreach(actions, n"RemoteBreachAction");

    // Guard 1: Check if Computer RemoteBreach is enabled AND UnlockIfNoAccessPoint is disabled
    if !BetterNetrunningSettings.RemoteBreachEnabledComputer() || BetterNetrunningSettings.UnlockIfNoAccessPoint() {
        return;
    }

    // Guard 2: Check if RemoteBreach is locked due to breach failure
    if BreachLockUtils.IsDeviceLockedByRemoteBreachFailure(this) {
        return;
    }

    // Guard 3: Check if this computer is already breached via RemoteBreach StateSystem
    let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(this.GetGameInstance());

    if IsDefined(stateSystem) && stateSystem.IsComputerBreached(this.GetID()) {
        return;
    }

    let breachAction: ref<RemoteBreachAction> = this.ActionCustomRemoteBreach();
    ArrayPush(actions, breachAction);
}
