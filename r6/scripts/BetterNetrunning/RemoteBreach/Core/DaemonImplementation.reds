// -----------------------------------------------------------------------------
// RemoteBreach Daemon Implementation
// -----------------------------------------------------------------------------
// Implements daemon action classes (DeviceDaemonAction, VehicleDaemonAction)
// and their execution logic for RemoteBreach minigames.
//
// RESPONSIBILITIES:
// - Define DeviceDaemonAction class (Computer + Generic Device + Vehicle handling)
// - Define VehicleDaemonAction class (Vehicle-specific handling)
// - Implement ExecuteProgramSuccess() for each daemon type
// - Update device unlock state and StateSystem tracking
// - Trigger network unlock cascades
//
// DAEMON EXECUTION FLOW:
// 1. Player completes daemon in RemoteBreach minigame
// 2. ExecuteProgramSuccess() called
// 3. Detect target type (Computer/Device/Vehicle)
// 4. Apply daemon effects (set flags, unlock network)
// 5. Mark device as breached in StateSystem
//
// NOTE: Daemon registration is in DaemonRegistration.reds
// -----------------------------------------------------------------------------

module BetterNetrunning.RemoteBreach.Core

import BetterNetrunning.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Logging.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

// -----------------------------------------------------------------------------
// Common Daemon Execution Utilities
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public abstract class DaemonExecutionUtils {

    /*
     * Template Method for daemon execution shared by DeviceDaemonAction and VehicleDaemonAction
     *
     * VANILLA DIFF: Uses Template Method pattern with Strategy pattern for unlock logic
     * @param sourcePS - Source Device persistent state (Access Point or Vehicle)
     * @param gameInstance - Game instance for system access
     * @param strategy - IDaemonUnlockStrategy implementation (Computer/Device/Vehicle)
     * @param daemonTypeStr - Daemon type identifier (Basic/NPC/Camera/Turret)
     */
    public static func ProcessDaemonWithStrategy(
        sourcePS: ref<DeviceComponentPS>,
        gameInstance: GameInstance,
        strategy: ref<IDaemonUnlockStrategy>,
        daemonTypeStr: String
    ) -> Void {
        // Step 1: Get SharedGameplayPS for breach flag management
        let sharedPS: ref<SharedGameplayPS> = sourcePS as SharedGameplayPS;
        if !IsDefined(sharedPS) {
            BNError("ProcessDaemonWithStrategy", "Cannot cast to SharedGameplayPS");
            return;
        }

        // Step 2: Determine device type for timestamp selection
        // BUG FIX (2025-10-20): Use daemon type instead of source device type for timestamp assignment
        // - RATIONALE: sourcePS is always Access Point, cannot determine actual target device type
        // - IMPLEMENTATION: Map daemon type string directly to TargetType enum for correct field selection
        let TargetType: TargetType = DaemonExecutionUtils.GetDeviceTypeFromDaemonType(daemonTypeStr);

        // Step 3: Set breach timestamp for this daemon's device type
        let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
        TimeUtils.SetDeviceUnlockTimestamp(sharedPS, TargetType, currentTime);

        // Step 4: Mark device as breached in StateSystem (for persistence)
        let stateSystem: ref<IScriptable> = strategy.GetStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            strategy.MarkBreached(stateSystem, sourcePS.GetID(), gameInstance);
        }

        // Step 5: Execute unlock logic (varies by target type - delegated to Strategy)
        strategy.ExecuteUnlock(daemonTypeStr, TargetType, sourcePS, gameInstance);
    }

    /*
     * Maps daemon type string to TargetType enum for timestamp field selection.
     *
     * BUG FIX (2025-10-20): Access Point device type cannot identify actual target.
     * RATIONALE: sourcePS is always Access Point, so we cannot determine actual
     * target device type.
     *
     * @param daemonTypeStr - Daemon type string (NPC/Camera/Turret/Basic)
     * @return TargetType enum value for timestamp assignment
     */
    public static func GetDeviceTypeFromDaemonType(daemonTypeStr: String) -> TargetType {
        let TargetType: TargetType;

        if Equals(daemonTypeStr, DaemonTypes.NPC()) {
            TargetType = TargetType.NPC;
        } else if Equals(daemonTypeStr, DaemonTypes.Camera()) {
            TargetType = TargetType.Camera;
        } else if Equals(daemonTypeStr, DaemonTypes.Turret()) {
            TargetType = TargetType.Turret;
        } else {
            // Basic daemon or unknown
            TargetType = TargetType.Basic;
        }

        BNDebug("DaemonTypeMapping", s"Mapped daemon type '\(daemonTypeStr)' to TargetType.\(ToString(TargetType))");
        return TargetType;
    }
}

// -----------------------------------------------------------------------------
// Device Daemon Program Actions (Computer + Generic Devices)
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions.Programs"))
public class DeviceDaemonAction extends HackProgramAction {
    private let m_daemonTypeStr: String;

    /*
     * Sets daemon type identifier for execution
     *
     * @param daemonTypeStr - Daemon type string (Basic/NPC/Camera/Turret)
     */
    public func SetDaemonType(daemonTypeStr: String) -> Void {
        this.m_daemonTypeStr = daemonTypeStr;
    }

    /*
     * Executes daemon on successful minigame completion
     *
     * VANILLA DIFF: Uses unified Template Method Pattern with Strategy pattern
     * ARCHITECTURE: Tries Computer -> Device -> Vehicle in priority order, delegates to Strategy
     */
    protected func ExecuteProgramSuccess() -> Void {
        let player: ref<PlayerPuppet> = this.GetPlayer();
        if !IsDefined(player) {
            BNError("DeviceDaemonAction", "Player not defined");
            return;
        }

        let gameInstance: GameInstance = player.GetGame();
        BNDebug("DeviceDaemonAction", "Executing daemon: " + this.m_daemonTypeStr);

        // Try each target type in priority order: Computer -> Device -> Vehicle
        let computerPS: wref<ComputerControllerPS> = this.GetComputerFromStateSystem(gameInstance);
        if IsDefined(computerPS) {
            this.ProcessDaemonWithStrategy(computerPS, gameInstance, ComputerUnlockStrategy.Create());
            return;
        }

        let devicePS: wref<ScriptableDeviceComponentPS> = this.GetDeviceFromStateSystem(gameInstance);
        if IsDefined(devicePS) {
            let TargetType: TargetType = DeviceTypeUtils.GetDeviceType(devicePS);
            this.ProcessDaemonWithStrategy(devicePS, gameInstance, DeviceUnlockStrategy.Create());
            return;
        }

        let vehiclePS: wref<VehicleComponentPS> = this.GetVehicleFromStateSystem(gameInstance);
        if IsDefined(vehiclePS) {
            this.ProcessDaemonWithStrategy(vehiclePS, gameInstance, VehicleUnlockStrategy.Create());
            return;
        }

        BNError("DeviceDaemonAction", "No valid target found");
    }

    /*
     * Delegates daemon execution to DaemonExecutionUtils with Strategy pattern
     *
     * @param sourcePS - Source Device persistent state
     * @param gameInstance - Game instance for system access
     * @param strategy - IDaemonUnlockStrategy implementation
     */
    private func ProcessDaemonWithStrategy(
        sourcePS: ref<DeviceComponentPS>,
        gameInstance: GameInstance,
        strategy: ref<IDaemonUnlockStrategy>
    ) -> Void {
        DaemonExecutionUtils.ProcessDaemonWithStrategy(sourcePS, gameInstance, strategy, this.m_daemonTypeStr);
    }

    /*
     * Retrieves Computer persistent state from RemoteBreachStateSystem
     *
     * @param gameInstance - Game instance for system access
     * @return ComputerControllerPS if set in StateSystem, null otherwise
     */
    private func GetComputerFromStateSystem(gameInstance: GameInstance) -> wref<ComputerControllerPS> {
        let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            return stateSystem.GetCurrentComputer();
        }
        return null;
    }

    /*
     * Retrieves Device persistent state from DeviceRemoteBreachStateSystem
     *
     * @param gameInstance - Game instance for system access
     * @return ScriptableDeviceComponentPS if set in StateSystem, null otherwise
     */
    private func GetDeviceFromStateSystem(gameInstance: GameInstance) -> wref<ScriptableDeviceComponentPS> {
        let stateSystem: ref<DeviceRemoteBreachStateSystem> = StateSystemUtils.GetDeviceStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            return stateSystem.GetCurrentDevice();
        }
        return null;
    }

    /*
     * Retrieves Vehicle persistent state from VehicleRemoteBreachStateSystem
     *
     * @param gameInstance - Game instance for system access
     * @return VehicleComponentPS if set in StateSystem, null otherwise
     */
    private func GetVehicleFromStateSystem(gameInstance: GameInstance) -> wref<VehicleComponentPS> {
        let stateSystem: ref<VehicleRemoteBreachStateSystem> = StateSystemUtils.GetVehicleStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            return stateSystem.GetCurrentVehicle();
        }
        return null;
    }

    /*
     * Handles minigame failure.
     * Silent failure - StateSystem remains for potential retry.
     */
    protected func ExecuteProgramFailure() -> Void {
        // Silent failure - StateSystem remains for potential retry
    }
}

@if(ModuleExists("HackingExtensions.Programs"))
public class BetterNetrunningDaemonAction extends DeviceDaemonAction {}

// -----------------------------------------------------------------------------
// Vehicle Daemon Program Actions
// -----------------------------------------------------------------------------
// NOTE: VehicleDaemonAction uses the SAME Strategy Pattern as DeviceDaemonAction
// The only difference is ExecuteProgramSuccess() retrieves VehiclePS from VehicleStateSystem
// All unlock logic is delegated to VehicleUnlockStrategy

@if(ModuleExists("HackingExtensions.Programs"))
public class VehicleDaemonAction extends HackProgramAction {
    private let m_daemonTypeStr: String;

    /*
     * Sets daemon type identifier for execution
     *
     * @param daemonTypeStr - Daemon type string (Basic/NPC/Camera/Turret)
     */
    public func SetDaemonType(daemonTypeStr: String) -> Void {
        this.m_daemonTypeStr = daemonTypeStr;
    }

    /*
     * Executes daemon on successful minigame completion.
     *
     * VANILLA DIFF: Retrieves VehiclePS from VehicleStateSystem, delegates unlock
     * to Strategy. Same Strategy Pattern as DeviceDaemonAction.
     */
    protected func ExecuteProgramSuccess() -> Void {
        let player: ref<PlayerPuppet> = this.GetPlayer();
        if !IsDefined(player) {
            BNError("VehicleDaemonAction", "Player not defined");
            return;
        }

        let gameInstance: GameInstance = player.GetGame();
        BNDebug("VehicleDaemonAction", "Executing daemon: " + this.m_daemonTypeStr);

        let stateSystem: ref<VehicleRemoteBreachStateSystem> = StateSystemUtils.GetVehicleStateSystem(gameInstance);

        if !IsDefined(stateSystem) {
            BNError("VehicleDaemonAction", "VehicleStateSystem not found");
            return;
        }

        let vehiclePS: wref<VehicleComponentPS> = stateSystem.GetCurrentVehicle();
        if !IsDefined(vehiclePS) {
            BNError("VehicleDaemonAction", "Vehicle not found in StateSystem");
            return;
        }

        // Delegate to Strategy Pattern (same as DeviceDaemonAction)
        this.ProcessDaemonWithStrategy(vehiclePS, gameInstance, VehicleUnlockStrategy.Create());
    }

    /*
     * Delegates daemon execution to DaemonExecutionUtils with Strategy pattern.
     * Shared logic with DeviceDaemonAction.
     *
     * @param sourcePS - Source Device persistent state (Vehicle)
     * @param gameInstance - Game instance for system access
     * @param strategy - VehicleUnlockStrategy implementation
     */
    private func ProcessDaemonWithStrategy(
        sourcePS: ref<DeviceComponentPS>,
        gameInstance: GameInstance,
        strategy: ref<IDaemonUnlockStrategy>
    ) -> Void {
        DaemonExecutionUtils.ProcessDaemonWithStrategy(sourcePS, gameInstance, strategy, this.m_daemonTypeStr);
    }

    /*
     * Handles minigame failure.
     * Silent failure - StateSystem remains for potential retry.
     */
    protected func ExecuteProgramFailure() -> Void {
        // Silent failure - StateSystem remains for potential retry
    }
}
