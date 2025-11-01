// -----------------------------------------------------------------------------
// RemoteBreach Daemon Registration
// -----------------------------------------------------------------------------
// Registers daemon actions (DeviceDaemonAction, VehicleDaemonAction) with
// CustomHackingSystem during game initialization.
//
// RESPONSIBILITIES:
// - Register 8 daemon actions (4 Device + 4 Vehicle) with CustomHackingSystem
// - Hook PlayerPuppet.OnGameAttached to ensure system initialization order
//
// DAEMON TYPES:
// - Basic: UnlockQuickhacks (devices/vehicles in network)
// - NPC: UnlockNPCQuickhacks (NPCs in range)
// - Camera: UnlockCameraQuickhacks (cameras in network)
// - Turret: UnlockTurretQuickhacks (turrets in network)
//
// NOTE: Daemon implementation is in DaemonImplementation.reds
// -----------------------------------------------------------------------------

module BetterNetrunning.RemoteBreach.Core

import BetterNetrunning.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

// -----------------------------------------------------------------------------
// Register daemon actions after CustomHackingSystem initializes
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
/*
 * Registers Better Netrunning daemon actions after player initialization.
 *
 * VANILLA DIFF: Injects daemon registration during OnGameAttached.
 *
 * @return Bool - result of OnGameAttached (preserves vanilla return value)
 */
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
    wrappedMethod();

    this.RegisterBetterNetrunningDaemons();

    return true;
}

@if(ModuleExists("HackingExtensions"))
@addMethod(PlayerPuppet)
private func RegisterBetterNetrunningDaemons() -> Void {
    let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(this.GetGame());
    let hackingSystem: ref<CustomHackingSystem> = container.Get(BNConstants.CLASS_CUSTOM_HACKING_SYSTEM()) as CustomHackingSystem;

    if !IsDefined(hackingSystem) {
        return;
    }

    // Register Device daemon actions for RemoteBreach minigames
    // Using MinigameProgramAction prefix to match Lua CreateProgramAction() behavior
    let unlockBasicAction: ref<DeviceDaemonAction> = new DeviceDaemonAction();
    unlockBasicAction.SetDaemonType(DaemonTypes.Basic());
    hackingSystem.AddProgramAction(BNConstants.PROGRAM_ACTION_BN_UNLOCK_BASIC(), unlockBasicAction);

    let unlockNPCAction: ref<DeviceDaemonAction> = new DeviceDaemonAction();
    unlockNPCAction.SetDaemonType(DaemonTypes.NPC());
    hackingSystem.AddProgramAction(BNConstants.PROGRAM_ACTION_BN_UNLOCK_NPC(), unlockNPCAction);

    let unlockCameraAction: ref<DeviceDaemonAction> = new DeviceDaemonAction();
    unlockCameraAction.SetDaemonType(DaemonTypes.Camera());
    hackingSystem.AddProgramAction(BNConstants.PROGRAM_ACTION_BN_UNLOCK_CAMERA(), unlockCameraAction);

    let unlockTurretAction: ref<DeviceDaemonAction> = new DeviceDaemonAction();
    unlockTurretAction.SetDaemonType(DaemonTypes.Turret());
    hackingSystem.AddProgramAction(BNConstants.PROGRAM_ACTION_BN_UNLOCK_TURRET(), unlockTurretAction);

    // NOTE: PING daemon registration commented out - now using vanilla NetworkPingHack
    // PINGDaemonAction may be removed after verifying NetworkPingHack works correctly
    // let pingAction: ref<PINGDaemonAction> = new PINGDaemonAction();
    // hackingSystem.AddProgramAction(t"MinigameProgramAction.BN_PING", pingAction);

    // Register Vehicle daemon actions for RemoteBreach minigames
    let vehicleUnlockBasicAction: ref<VehicleDaemonAction> = new VehicleDaemonAction();
    vehicleUnlockBasicAction.SetDaemonType(DaemonTypes.Basic());
    hackingSystem.AddProgramAction(BNConstants.PROGRAM_ACTION_BN_UNLOCK_BASIC(), vehicleUnlockBasicAction);

    let vehicleUnlockNPCAction: ref<VehicleDaemonAction> = new VehicleDaemonAction();
    vehicleUnlockNPCAction.SetDaemonType(DaemonTypes.NPC());
    hackingSystem.AddProgramAction(BNConstants.PROGRAM_ACTION_BN_UNLOCK_NPC(), vehicleUnlockNPCAction);

    let vehicleUnlockCameraAction: ref<VehicleDaemonAction> = new VehicleDaemonAction();
    vehicleUnlockCameraAction.SetDaemonType(DaemonTypes.Camera());
    hackingSystem.AddProgramAction(BNConstants.PROGRAM_ACTION_BN_UNLOCK_CAMERA(), vehicleUnlockCameraAction);

    let vehicleUnlockTurretAction: ref<VehicleDaemonAction> = new VehicleDaemonAction();
    vehicleUnlockTurretAction.SetDaemonType(DaemonTypes.Turret());
    hackingSystem.AddProgramAction(BNConstants.PROGRAM_ACTION_BN_UNLOCK_TURRET(), vehicleUnlockTurretAction);
}
