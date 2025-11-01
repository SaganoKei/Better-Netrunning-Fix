// ============================================================================
// BetterNetrunning - Daemon Unlock Strategy
// ============================================================================
//
// PURPOSE:
// Abstraction layer for daemon unlock execution using Strategy Pattern
//
// FUNCTIONALITY:
// - Strategy Pattern implementation for target-specific unlock algorithms
// - Template Method pattern for common unlock workflow
// - Unified daemon processing logic for all target types
// - Extensible design for new daemon types
//
// ARCHITECTURE:
// - IDaemonUnlockStrategy interface for unlock algorithms
// - Concrete strategies: ComputerUnlockStrategy, DeviceUnlockStrategy, VehicleUnlockStrategy
// - Template Method in ProcessDaemonBase() for common workflow
// - Open/Closed Principle for easy extension
//
module BetterNetrunning.RemoteBreach.Core

import BetterNetrunning.*
import BetterNetrunning.Core.*
import BetterNetrunning.Integration.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Utils.*

// Abstract interface for daemon unlock execution
public abstract class IDaemonUnlockStrategy {

  /*
   * ExecuteUnlock() - Daemon Unlock Execution
   *
   * Executes unlock logic for specific daemon type.
   *
   * @param daemonType Daemon type identifier
   * @param TargetType Target device type
   * @param sourcePS Source device PS
   * @param gameInstance Game instance
   */
  public func ExecuteUnlock(
    daemonType: String,
    TargetType: TargetType,
    sourcePS: ref<DeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Void {}

  // Gets StateSystem for breach tracking
  public func GetStateSystem(gameInstance: GameInstance) -> ref<IScriptable> {
    return null;
  }

  // Marks device as breached in StateSystem
  // Implementation varies by target type
  public func MarkBreached(stateSystem: ref<IScriptable>, deviceID: PersistentID, gameInstance: GameInstance) -> Void {}

  /*
   * Construct Unlock Flags from Bool Parameters
   *
   * ARCHITECTURE: Centralized flag construction used by all strategies
   * @param unlockBasic Whether to unlock basic devices
   * @param unlockNPCs Whether to unlock NPCs
   * @param unlockCameras Whether to unlock cameras
   * @param unlockTurrets Whether to unlock turrets
   * @return BreachUnlockFlags structure with appropriate flags set
   */
  public static func BuildUnlockFlags(unlockBasic: Bool, unlockNPCs: Bool, unlockCameras: Bool, unlockTurrets: Bool) -> BreachUnlockFlags {
    let flags: BreachUnlockFlags;
    flags.unlockBasic = unlockBasic;
    flags.unlockNPCs = unlockNPCs;
    flags.unlockCameras = unlockCameras;
    flags.unlockTurrets = unlockTurrets;
    return flags;
  }

  /*
   * ExecuteUnlockBase() - Template Method for Common Unlock Sequence
   *
   * ARCHITECTURE: Template Method Pattern
   * Defines common unlock workflow with hook for strategy-specific network unlock.
   *
   * FUNCTIONALITY:
   * - Step 1: Unlock devices in radius (all daemon types)
   * - Step 2: Unlock vehicles (Basic daemon only)
   * - Step 3: Network unlock (strategy-specific - calls UnlockNetwork hook)
   * - Step 4: Unlock NPCs in radius (NPC daemon only)
   * - Step 5: Record breach position for radial unlock
   *
   * @param sourcePS Source device PS (any DeviceComponentPS subclass)
   * @param flags Unlock flags (from BuildUnlockFlags)
   * @param gameInstance Game instance
   */
  protected func ExecuteUnlockBase(
    sourcePS: ref<DeviceComponentPS>,
    flags: BreachUnlockFlags,
    gameInstance: GameInstance
  ) -> Void {
    let devicePS: ref<ScriptableDeviceComponentPS> = sourcePS as ScriptableDeviceComponentPS;
    if !IsDefined(devicePS) {
      return;
    }

    // Step 1: Network unlock (strategy-specific implementation)
    // NOTE: Radial unlock (standalone devices/vehicles/NPCs) is handled separately in RemoteBreachHelpers.reds
    // via BreachStatisticsCollector.CollectRadialUnlockStats() to avoid duplication
    this.UnlockNetwork(sourcePS, flags, gameInstance);

    // Step 2: Record breach position for radial unlock
    RemoteBreachUtils.RecordBreachPosition(devicePS, gameInstance);
  }

  /*
   * UnlockNetwork() - Hook Method for Strategy-Specific Network Unlock
   *
   * ARCHITECTURE: Template Method hook (Open/Closed Principle)
   * Override in subclasses to implement target-specific network unlock logic.
   *
   * NOTE: Redscript does not support abstract methods.
   * This base implementation provides empty default behavior (no-op).
   * Subclasses must override to implement actual network unlock logic.
   *
   * @param sourcePS Source device PS
   * @param flags Unlock flags
   * @param gameInstance Game instance
   */
  protected func UnlockNetwork(
    sourcePS: ref<DeviceComponentPS>,
    flags: BreachUnlockFlags,
    gameInstance: GameInstance
  ) -> Void {}
}

// ============================================================================
// Computer Unlock Strategy
// ============================================================================

@if(ModuleExists("HackingExtensions"))
public class ComputerUnlockStrategy extends IDaemonUnlockStrategy {

  public func ExecuteUnlock(
    daemonType: String,
    TargetType: TargetType,
    sourcePS: ref<DeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Void {
    let computerPS: ref<ComputerControllerPS> = sourcePS as ComputerControllerPS;
    if !IsDefined(computerPS) {
      BNError("DaemonUnlock", "Cannot cast to ComputerControllerPS");
      return;
    }

    this.ExecuteUnlockBase(
      computerPS,
      IDaemonUnlockStrategy.BuildUnlockFlags(
        Equals(daemonType, DaemonTypes.Basic()),
        Equals(daemonType, DaemonTypes.NPC()),
        Equals(daemonType, DaemonTypes.Camera()),
        Equals(daemonType, DaemonTypes.Turret())
      ),
      gameInstance
    );
  }  // Override network unlock hook for Computer-specific logic
  protected func UnlockNetwork(
    sourcePS: ref<DeviceComponentPS>,
    flags: BreachUnlockFlags,
    gameInstance: GameInstance
  ) -> Void {
    let computerPS: ref<ComputerControllerPS> = sourcePS as ComputerControllerPS;
    if !IsDefined(computerPS) {
      return;
    }

    ComputerRemoteBreachUtils.UnlockNetworkDevices(
      computerPS,
      flags.unlockBasic,
      flags.unlockNPCs,
      flags.unlockCameras,
      flags.unlockTurrets
    );
  }

  public func GetStateSystem(gameInstance: GameInstance) -> ref<IScriptable> {
    return StateSystemUtils.GetComputerStateSystem(gameInstance);
  }

  public func MarkBreached(stateSystem: ref<IScriptable>, deviceID: PersistentID, gameInstance: GameInstance) -> Void {
    let remoteBreachSystem: ref<RemoteBreachStateSystem> = stateSystem as RemoteBreachStateSystem;
    if IsDefined(remoteBreachSystem) {
      remoteBreachSystem.MarkComputerBreached(deviceID);
    }
  }

  public static func Create() -> ref<ComputerUnlockStrategy> {
    return new ComputerUnlockStrategy();
  }
}

// ============================================================================
// Device Unlock Strategy
// ============================================================================

@if(ModuleExists("HackingExtensions"))
public class DeviceUnlockStrategy extends IDaemonUnlockStrategy {

  public func ExecuteUnlock(
    daemonType: String,
    TargetType: TargetType,
    sourcePS: ref<DeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Void {
    let devicePS: ref<ScriptableDeviceComponentPS> = sourcePS as ScriptableDeviceComponentPS;
    if !IsDefined(devicePS) {
      BNError("DaemonUnlock", "Cannot cast to ScriptableDeviceComponentPS");
      return;
    }

    this.ExecuteUnlockBase(
      devicePS,
      IDaemonUnlockStrategy.BuildUnlockFlags(
        Equals(daemonType, DaemonTypes.Basic()),
        Equals(daemonType, DaemonTypes.NPC()),
        Equals(daemonType, DaemonTypes.Camera()),
        Equals(daemonType, DaemonTypes.Turret())
      ),
      gameInstance
    );
  }

  // Override network unlock hook for Device-specific logic
  protected func UnlockNetwork(
    sourcePS: ref<DeviceComponentPS>,
    flags: BreachUnlockFlags,
    gameInstance: GameInstance
  ) -> Void {
    let devicePS: ref<ScriptableDeviceComponentPS> = sourcePS as ScriptableDeviceComponentPS;
    if !IsDefined(devicePS) {
      return;
    }

    this.UnlockDevicesInNetwork(devicePS, flags.unlockBasic, flags.unlockNPCs, flags.unlockCameras, flags.unlockTurrets);
  }

  public func GetStateSystem(gameInstance: GameInstance) -> ref<IScriptable> {
    return StateSystemUtils.GetDeviceStateSystem(gameInstance);
  }

  public func MarkBreached(stateSystem: ref<IScriptable>, deviceID: PersistentID, gameInstance: GameInstance) -> Void {
    let deviceBreachSystem: ref<DeviceRemoteBreachStateSystem> = stateSystem as DeviceRemoteBreachStateSystem;
    let deviceEntity: wref<GameObject> = GameInstance.FindEntityByID(
      gameInstance,
      PersistentID.ExtractEntityID(deviceID)
    ) as GameObject;

    if IsDefined(deviceBreachSystem) && IsDefined(deviceEntity) {
      deviceBreachSystem.MarkDeviceBreached(deviceEntity.GetEntityID());
    }
  }

  // Helper: Unlock devices in network (AccessPoint children)
  private func UnlockDevicesInNetwork(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockBasic: Bool,
    unlockNPCs: Bool,
    unlockCameras: Bool,
    unlockTurrets: Bool
  ) -> Void {
    // Use shared GetNetworkDevices() function for DRY principle
    // excludeSource=false: Include source device in unlock (may have been locked previously)
    let networkDevices: array<ref<ScriptableDeviceComponentPS>> = RemoteBreachLockSystem.GetNetworkDevices(devicePS, false);

    // If no network devices found, use radial unlock fallback
    if ArraySize(networkDevices) == 0 {
      let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
      let gameInstance: GameInstance = devicePS.GetGameInstance();
      RemoteBreachUtils.UnlockNearbyNetworkDevices(
        deviceEntity,
        gameInstance,
        unlockBasic,
        unlockNPCs,
        unlockCameras,
        unlockTurrets,
        "UnlockDevicesInNetwork"
      );
      return;
    }

    // Get gameInstance once for all devices
    let gameInstance: GameInstance = devicePS.GetGameInstance();

    // Apply unlock to all network devices
    let i: Int32 = 0;
    while i < ArraySize(networkDevices) {
      let device: ref<ScriptableDeviceComponentPS> = networkDevices[i];
      if IsDefined(device) {
        this.ApplyUnlockToDevice(device, gameInstance, unlockBasic, unlockNPCs, unlockCameras, unlockTurrets);
      }
      i += 1;
    }
  }

  // Helper: Apply unlock to single device based on type
  private func ApplyUnlockToDevice(
    device: ref<DeviceComponentPS>,
    gameInstance: GameInstance,
    unlockBasic: Bool,
    unlockNPCs: Bool,
    unlockCameras: Bool,
    unlockTurrets: Bool
  ) -> Void {
    // Use centralized timestamp unlock logic from DeviceUnlockUtils
    DeviceUnlockUtils.ApplyTimestampUnlock(
      device,
      gameInstance,
      unlockBasic,
      unlockNPCs,
      unlockCameras,
      unlockTurrets
    );
  }

  public static func Create() -> ref<DeviceUnlockStrategy> {
    return new DeviceUnlockStrategy();
  }
}

// ============================================================================
// Vehicle Unlock Strategy
// ============================================================================

@if(ModuleExists("HackingExtensions"))
public class VehicleUnlockStrategy extends IDaemonUnlockStrategy {

  public func ExecuteUnlock(
    daemonType: String,
    TargetType: TargetType,
    sourcePS: ref<DeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Void {
    let vehiclePS: ref<VehicleComponentPS> = sourcePS as VehicleComponentPS;
    if !IsDefined(vehiclePS) {
      BNError("DaemonUnlock", "Cannot cast to VehicleComponentPS");
      return;
    }

    let vehicleEntity: wref<GameObject> = vehiclePS.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(vehicleEntity) {
      BNError("DaemonUnlock", "Vehicle entity not found");
      return;
    }

    this.ExecuteUnlockBase(
      vehiclePS,
      IDaemonUnlockStrategy.BuildUnlockFlags(
        Equals(daemonType, DaemonTypes.Basic()),
        Equals(daemonType, DaemonTypes.NPC()),
        Equals(daemonType, DaemonTypes.Camera()),
        Equals(daemonType, DaemonTypes.Turret())
      ),
      gameInstance
    );
  }  // Override network unlock hook for Vehicle-specific logic
  protected func UnlockNetwork(
    sourcePS: ref<DeviceComponentPS>,
    flags: BreachUnlockFlags,
    gameInstance: GameInstance
  ) -> Void {
    let vehiclePS: ref<VehicleComponentPS> = sourcePS as VehicleComponentPS;
    if !IsDefined(vehiclePS) {
      return;
    }

    let vehicleEntity: wref<GameObject> = vehiclePS.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(vehicleEntity) {
      return;
    }

    RemoteBreachUtils.UnlockNearbyNetworkDevices(
      vehicleEntity,
      gameInstance,
      flags.unlockBasic,
      flags.unlockNPCs,
      flags.unlockCameras,
      flags.unlockTurrets,
      "UnlockNetworkDevicesFromVehicle"
    );
  }

  public func GetStateSystem(gameInstance: GameInstance) -> ref<IScriptable> {
    return StateSystemUtils.GetVehicleStateSystem(gameInstance);
  }

  public func MarkBreached(stateSystem: ref<IScriptable>, deviceID: PersistentID, gameInstance: GameInstance) -> Void {
    let vehicleBreachSystem: ref<VehicleRemoteBreachStateSystem> = stateSystem as VehicleRemoteBreachStateSystem;
    let vehicleEntity: wref<GameObject> = GameInstance.FindEntityByID(
      gameInstance,
      PersistentID.ExtractEntityID(deviceID)
    ) as GameObject;

    if IsDefined(vehicleBreachSystem) && IsDefined(vehicleEntity) {
      vehicleBreachSystem.MarkVehicleBreached(vehicleEntity.GetEntityID());
    }
  }

  public static func Create() -> ref<VehicleUnlockStrategy> {
    return new VehicleUnlockStrategy();
  }
}
