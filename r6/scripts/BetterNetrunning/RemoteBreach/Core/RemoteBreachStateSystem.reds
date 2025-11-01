// -----------------------------------------------------------------------------
// RemoteBreach State Management Systems
// -----------------------------------------------------------------------------
// Global state management using ScriptableSystem singleton pattern.
// Stores current breach targets for DeviceDaemonAction to retrieve.
// -----------------------------------------------------------------------------

module BetterNetrunning.RemoteBreach.Core

import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

// -----------------------------------------------------------------------------
// Global State Management Systems (ScriptableSystem Singleton Pattern)
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public class RemoteBreachStateSystem extends ScriptableSystem {
    // Store current computer being remotely breached (weak reference to avoid memory leaks)
    private let m_currentComputerPS: wref<ComputerControllerPS>;

    // Track breached computers
    private let m_breachedComputers: array<PersistentID>;

    // Store ComputerPS reference
    public func SetCurrentComputer(computerPS: wref<ComputerControllerPS>) -> Void {
        this.m_currentComputerPS = computerPS;
    }

    // Retrieve stored ComputerPS reference
    public func GetCurrentComputer() -> wref<ComputerControllerPS> {
        return this.m_currentComputerPS;
    }

    // Clear stored reference
    public func ClearCurrentComputer() -> Void {
        this.m_currentComputerPS = null;
    }

    // Mark computer as breached
    public func MarkComputerBreached(computerID: PersistentID) -> Void {
        if !ArrayContains(this.m_breachedComputers, computerID) {
            ArrayPush(this.m_breachedComputers, computerID);
        }
    }

    // Check if computer is already breached
    public func IsComputerBreached(computerID: PersistentID) -> Bool {
        return ArrayContains(this.m_breachedComputers, computerID);
    }
}

@if(ModuleExists("HackingExtensions"))
public class DeviceRemoteBreachStateSystem extends ScriptableSystem {
    private let m_currentDevicePS: wref<ScriptableDeviceComponentPS>;
    private let m_availableDaemons: String;
    private let m_breachedDevices: array<EntityID>;

    public func SetCurrentDevice(devicePS: ref<ScriptableDeviceComponentPS>, availableDaemons: String) -> Void {
        this.m_currentDevicePS = devicePS;
        this.m_availableDaemons = availableDaemons;
    }

    public func GetCurrentDevice() -> wref<ScriptableDeviceComponentPS> {
        return this.m_currentDevicePS;
    }

    public func GetAvailableDaemons() -> String {
        return this.m_availableDaemons;
    }

    public func ClearCurrentDevice() -> Void {
        this.m_currentDevicePS = null;
        this.m_availableDaemons = "";
    }

    // Track breached devices
    public func MarkDeviceBreached(deviceID: EntityID) -> Void {
        if !ArrayContains(this.m_breachedDevices, deviceID) {
            ArrayPush(this.m_breachedDevices, deviceID);
        }
    }

    public func IsDeviceBreached(deviceID: EntityID) -> Bool {
        return ArrayContains(this.m_breachedDevices, deviceID);
    }
}

@if(ModuleExists("HackingExtensions"))
public class VehicleRemoteBreachStateSystem extends ScriptableSystem {
    private let m_currentVehiclePS: wref<VehicleComponentPS>;
    private let m_availableDaemons: String;
    private let m_breachedVehicles: array<EntityID>;

    public func SetCurrentVehicle(vehiclePS: wref<VehicleComponentPS>, availableDaemons: String) -> Void {
        this.m_currentVehiclePS = vehiclePS;
        this.m_availableDaemons = availableDaemons;
    }

    public func GetCurrentVehicle() -> wref<VehicleComponentPS> {
        return this.m_currentVehiclePS;
    }

    public func GetAvailableDaemons() -> String {
        return this.m_availableDaemons;
    }

    public func ClearCurrentVehicle() -> Void {
        this.m_currentVehiclePS = null;
        this.m_availableDaemons = "";
    }

    public func MarkVehicleBreached(vehicleID: EntityID) -> Void {
        if !ArrayContains(this.m_breachedVehicles, vehicleID) {
            ArrayPush(this.m_breachedVehicles, vehicleID);
        }
    }

    public func IsVehicleBreached(vehicleID: EntityID) -> Bool {
        return ArrayContains(this.m_breachedVehicles, vehicleID);
    }
}
