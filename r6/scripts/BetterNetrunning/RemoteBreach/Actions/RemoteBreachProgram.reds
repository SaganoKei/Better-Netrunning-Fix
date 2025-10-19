// -----------------------------------------------------------------------------
// RemoteBreach Program
// -----------------------------------------------------------------------------
// RemoteBreach program action implementations.
//
// CONTENTS:
// - RemoteBreachProgramActionBase: Base class for all RemoteBreach programs
// - RemoteBreachProgramAction: Easy difficulty program
// - RemoteBreachProgramActionMedium: Medium difficulty program
// - RemoteBreachProgramActionHard: Hard difficulty program
// - CustomHackingSystem initialization hooks
// -----------------------------------------------------------------------------

module BetterNetrunning.RemoteBreach.Actions

import BetterNetrunning.*
import BetterNetrunning.Core.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.Utils.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

// -----------------------------------------------------------------------------
// Program Actions
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions.Programs"))
public abstract class RemoteBreachProgramActionBase extends HackProgramAction {
    private let m_devicePS: ref<ScriptableDeviceComponentPS>;
    private let m_lastBreachRange: Float;

    protected func GetBreachRangeForDifficulty() -> Float {
        let player: ref<PlayerPuppet> = this.GetPlayer();
        if !IsDefined(player) {
            return 50.0; // Fallback if player not available
        }
        return DeviceTypeUtils.GetRadialBreachRange(player.GetGame());
    }

    protected func ExecuteProgramSuccess() -> Void {

        let player: ref<PlayerPuppet> = this.GetPlayer();
        if !IsDefined(player) {
            return;
        }

        let gameInstance: GameInstance = player.GetGame();
        if !GameInstance.IsValid(gameInstance) {
            return;
        }

        this.m_devicePS = this.GetHackedDevice();

        if !IsDefined(this.m_devicePS) {
            let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
            if IsDefined(stateSystem) {
                stateSystem.ClearCurrentComputer();
            }
            return;
        }

        this.m_lastBreachRange = this.GetBreachRangeForDifficulty();

        let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            stateSystem.ClearCurrentComputer();
        }

        // Finalize breach with success state to trigger BreachPenaltySystem
        this.m_devicePS.FinalizeNetrunnerDive(HackingMinigameState.Succeeded);
    }

    protected func ExecuteProgramFailure() -> Void {
        let player: ref<PlayerPuppet> = this.GetPlayer();
        if !IsDefined(player) {
            return;
        }

        let gameInstance: GameInstance = player.GetGame();
        if !GameInstance.IsValid(gameInstance) {
            return;
        }

        let devicePS: ref<ScriptableDeviceComponentPS> = this.GetHackedDevice();

        if IsDefined(devicePS) {
            // Finalize breach with failure state to trigger BreachPenaltySystem
            // This will apply skip/failure penalties (VFX, Stun, RemoteBreach lock)
            devicePS.FinalizeNetrunnerDive(HackingMinigameState.Failed);
        }

        // Clear current computer from state system
        let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            stateSystem.ClearCurrentComputer();
        }
    }

    // ============================================================================
    // Device Retrieval (Early Return Pattern - Max 2 Nesting Levels)
    // ============================================================================
    protected func GetHackedDevice() -> ref<ScriptableDeviceComponentPS> {
        if IsDefined(this.m_devicePS) {
            return this.m_devicePS;
        }

        let computerPS: ref<ComputerControllerPS> = this.TryGetComputerFromStateSystem();
        if IsDefined(computerPS) {
            return computerPS;
        }

        return null;
    }

    private func TryGetComputerFromStateSystem() -> ref<ComputerControllerPS> {
        let player: ref<PlayerPuppet> = this.GetPlayer();
        if !IsDefined(player) {
            return null;
        }

        let gameInstance: GameInstance = player.GetGame();
        let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
        if !IsDefined(stateSystem) {
            return null;
        }

        return stateSystem.GetCurrentComputer();
    }
}

// -----------------------------------------------------------------------------
// Difficulty-specific Program Actions
// All difficulties now use the same RadialBreach range (no difficulty-based adjustments)
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions.Programs"))
public class RemoteBreachEasyProgramAction extends RemoteBreachProgramActionBase {
    // Uses base implementation (RadialBreach range)
}

@if(ModuleExists("HackingExtensions.Programs"))
public class RemoteBreachMediumProgramAction extends RemoteBreachProgramActionBase {
    // Uses base implementation (RadialBreach range)
}

@if(ModuleExists("HackingExtensions.Programs"))
public class RemoteBreachHardProgramAction extends RemoteBreachProgramActionBase {
    // Uses base implementation (RadialBreach range)
}

// -----------------------------------------------------------------------------
// System Initialization
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
    wrappedMethod();

    let hackSystem: ref<CustomHackingSystem> = StateSystemUtils.GetCustomHackingSystem(this.GetGame());

    if IsDefined(hackSystem) {
        hackSystem.AddProgramAction(
            BNConstants.PROGRAM_ACTION_REMOTE_BREACH_EASY(),
            new RemoteBreachEasyProgramAction()
        );

        hackSystem.AddProgramAction(
            BNConstants.PROGRAM_ACTION_REMOTE_BREACH_MEDIUM(),
            new RemoteBreachMediumProgramAction()
        );

        hackSystem.AddProgramAction(
            BNConstants.PROGRAM_ACTION_REMOTE_BREACH_HARD(),
            new RemoteBreachHardProgramAction()
        );

        let basicDaemon: ref<BetterNetrunningDaemonAction> = new BetterNetrunningDaemonAction();
        basicDaemon.SetDaemonType(DaemonTypes.Basic());
        hackSystem.AddProgramAction(
            BNConstants.PROGRAM_UNLOCK_QUICKHACKS(),
            basicDaemon
        );

        let npcDaemon: ref<BetterNetrunningDaemonAction> = new BetterNetrunningDaemonAction();
        npcDaemon.SetDaemonType(DaemonTypes.NPC());
        hackSystem.AddProgramAction(
            BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS(),
            npcDaemon
        );

        let cameraDaemon: ref<BetterNetrunningDaemonAction> = new BetterNetrunningDaemonAction();
        cameraDaemon.SetDaemonType(DaemonTypes.Camera());
        hackSystem.AddProgramAction(
            BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS(),
            cameraDaemon
        );

        let turretDaemon: ref<BetterNetrunningDaemonAction> = new BetterNetrunningDaemonAction();
        turretDaemon.SetDaemonType(DaemonTypes.Turret());
        hackSystem.AddProgramAction(
            BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS(),
            turretDaemon
        );
    }

    return true;
}
