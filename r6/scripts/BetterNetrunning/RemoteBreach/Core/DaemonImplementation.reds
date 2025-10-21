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

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

// -----------------------------------------------------------------------------
// Common Daemon Execution Utilities
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public abstract class DaemonExecutionUtils {

    // Template Method for daemon execution (shared by DeviceDaemonAction and VehicleDaemonAction)
    // Eliminates duplicate ProcessDaemonWithStrategy implementations
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
        // - IMPLEMENTATION: Map daemon type string directly to DeviceType enum for correct field selection
        let deviceType: DeviceType = DaemonExecutionUtils.GetDeviceTypeFromDaemonType(daemonTypeStr);

        // Step 3: Set breach timestamp for this daemon's device type
        let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
        TimeUtils.SetDeviceUnlockTimestamp(sharedPS, deviceType, currentTime);

        // Step 4: Mark device as breached in StateSystem (for persistence)
        let stateSystem: ref<IScriptable> = strategy.GetStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            strategy.MarkBreached(stateSystem, sourcePS.GetID(), gameInstance);
        }

        // Step 5: Execute unlock logic (varies by target type - delegated to Strategy)
        strategy.ExecuteUnlock(daemonTypeStr, deviceType, sourcePS, gameInstance);
    }

    // BUG FIX (2025-10-20): Map daemon type string to DeviceType enum
    // FUNCTIONALITY: Converts daemon type to device type for timestamp field selection
    // RATIONALE: Access Point device type cannot identify actual target (NPC/Camera/Turret)
    public static func GetDeviceTypeFromDaemonType(daemonTypeStr: String) -> DeviceType {
        let deviceType: DeviceType;

        if Equals(daemonTypeStr, DaemonTypes.NPC()) {
            deviceType = DeviceType.NPC;
        } else if Equals(daemonTypeStr, DaemonTypes.Camera()) {
            deviceType = DeviceType.Camera;
        } else if Equals(daemonTypeStr, DaemonTypes.Turret()) {
            deviceType = DeviceType.Turret;
        } else {
            // Basic daemon or unknown
            deviceType = DeviceType.Basic;
        }

        BNDebug("DaemonTypeMapping", s"Mapped daemon type '\(daemonTypeStr)' to DeviceType.\(ToString(deviceType))");
        return deviceType;
    }
}

// -----------------------------------------------------------------------------
// Device Daemon Program Actions (Computer + Generic Devices)
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions.Programs"))
public class DeviceDaemonAction extends HackProgramAction {
    private let m_daemonTypeStr: String;

    public func SetDaemonType(daemonTypeStr: String) -> Void {
        this.m_daemonTypeStr = daemonTypeStr;
    }

    // ==================== Template Method Pattern ====================
    // Unified daemon execution flow - eliminates duplicate code in 3 Process* methods

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
            let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(devicePS);
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

    // ==================== Template Method Core ====================
    // Delegates to DaemonExecutionUtils for shared logic
    // Eliminates duplicate code between DeviceDaemonAction and VehicleDaemonAction

    private func ProcessDaemonWithStrategy(
        sourcePS: ref<DeviceComponentPS>,
        gameInstance: GameInstance,
        strategy: ref<IDaemonUnlockStrategy>
    ) -> Void {
        DaemonExecutionUtils.ProcessDaemonWithStrategy(sourcePS, gameInstance, strategy, this.m_daemonTypeStr);
    }

    // ==================== StateSystem Accessors ====================

    private func GetComputerFromStateSystem(gameInstance: GameInstance) -> wref<ComputerControllerPS> {
        let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            return stateSystem.GetCurrentComputer();
        }
        return null;
    }

    private func GetDeviceFromStateSystem(gameInstance: GameInstance) -> wref<ScriptableDeviceComponentPS> {
        let stateSystem: ref<DeviceRemoteBreachStateSystem> = StateSystemUtils.GetDeviceStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            return stateSystem.GetCurrentDevice();
        }
        return null;
    }

    private func GetVehicleFromStateSystem(gameInstance: GameInstance) -> wref<VehicleComponentPS> {
        let stateSystem: ref<VehicleRemoteBreachStateSystem> = StateSystemUtils.GetVehicleStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            return stateSystem.GetCurrentVehicle();
        }
        return null;
    }

    // ==================== Failure Handler ====================

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

    public func SetDaemonType(daemonTypeStr: String) -> Void {
        this.m_daemonTypeStr = daemonTypeStr;
    }

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

    // Delegates to DaemonExecutionUtils for shared logic
    private func ProcessDaemonWithStrategy(
        sourcePS: ref<DeviceComponentPS>,
        gameInstance: GameInstance,
        strategy: ref<IDaemonUnlockStrategy>
    ) -> Void {
        DaemonExecutionUtils.ProcessDaemonWithStrategy(sourcePS, gameInstance, strategy, this.m_daemonTypeStr);
    }

    protected func ExecuteProgramFailure() -> Void {
        // Silent failure - StateSystem remains for potential retry
    }
}

// ============================================================================
// PINGDaemonAction - REMOVED
// ============================================================================
// REASON: Cannot implement single-device PING without extensive vanilla overrides
// - PingDevice action calls PingDevicesNetwork() in CompleteAction()
// - Device.PulseNetwork() uses EPingType.SPACE (network-wide)
// - No vanilla API exists for single-device PING
// All PING-related functionality has been disabled
// ============================================================================
