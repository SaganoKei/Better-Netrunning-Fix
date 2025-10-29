// ============================================================================
// RemoteBreach Lock System - Timestamp-Based Lock Management
// ============================================================================
//
// PURPOSE:
// Manages RemoteBreach failure locks with timestamp-based tracking.
// Prevents re-attempts on failed RemoteBreach targets for configurable duration
// (default 10 minutes) to balance risk-free gameplay.
//
// FUNCTIONALITY:
// - Timestamp Recording: Store RemoteBreach failure timestamps on device PS
// - Hybrid Locking: Network hierarchy (no distance limit) + radial scan (configurable range)
// - Lock Expiration: Auto-expire locks after configurable duration
// - JackIn Management: Disable/Enable JackIn interaction via DeviceInteractionUtils
//
// RATIONALE:
// RemoteBreach-specific functionality belongs in RemoteBreach/Core/ directory
// following Better Netrunning's architectural principle of module separation.
// Generic breach penalty logic remains in Breach/Systems/BreachLockSystem.reds.
//
// ARCHITECTURE:
// - Static class (no instantiation required)
// - Persistent fields on SharedGameplayPS (survive save/load)
// - Unified with AP/NPC breach (timestamp-based locking)
// - Max nesting depth: 2 levels
//
// DEPENDENCIES:
// - BetterNetrunningConfig: Settings control (BreachPenaltyDurationMinutes)
// - Core/DeviceUnlockUtils: Timestamp management
// - Core/DeviceTypeUtils.reds: Radial breach range configuration
// - Core/Logger.reds: Debug logging
// - Utils/DeviceInteractionUtils.reds: JackIn interaction management
// ============================================================================

module BetterNetrunning.RemoteBreach
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Integration.*
import BetterNetrunning.Breach.*

// ============================================================================
// RemoteBreachLockSystem - Timestamp-Based Lock Management
// ============================================================================
//
// Provides RemoteBreach-specific lock management functionality.
//
// ARCHITECTURE:
// - Static class (no instantiation required)
// - Timestamp-based locking (unified with AP/NPC breach)
// - Hybrid locking: Network hierarchy + radial scan (range depends on RadialBreach MOD settings)
// - JackIn state management via DeviceInteractionUtils
// ============================================================================

public class RemoteBreachLockSystem {
  // ============================================================================
  // GetNetworkDevices() - Network Device Discovery (Shared Logic)
  // ============================================================================
  //
  // FUNCTIONALITY:
  // Discovers all network-connected devices for a given source device.
  // Shared by both unlock (success) and lock (failure) operations.
  //
  // STRATEGY:
  // 1. Get all AccessPoint parents via SharedGameplayPS.GetAccessPoints()
  // 2. For each AccessPoint, get all children via AccessPoint.GetChildren()
  // 3. If no AccessPoint parent, check if device is MasterControllerPS and get children
  // 4. No distance filtering (network hierarchy only)
  //
  // COVERAGE:
  // - Device with AccessPoint parent: Get all siblings from parent(s)
  // - Standalone AccessPoint/Computer/Terminal: Get all children
  // - Standalone device without network: Returns empty array
  //
  // PARAMETERS:
  // - sourceDevicePS: Source device (failed device for lock, breached device for unlock)
  // - excludeSource: If true, exclude source device from results
  //
  // RETURNS:
  // - Array of all network-connected devices (ScriptableDeviceComponentPS only)
  //
  // USAGE:
  // ```
  // // Lock operation (exclude failed device)
  // let devices = RemoteBreachLockSystem.GetNetworkDevices(failedDevicePS, true);
  //
  // // Unlock operation (include all devices)
  // let devices = RemoteBreachLockSystem.GetNetworkDevices(breachedDevicePS, false);
  // ```
  // ============================================================================

  public static func GetNetworkDevices(
    sourceDevicePS: ref<ScriptableDeviceComponentPS>,
    excludeSource: Bool
  ) -> array<ref<ScriptableDeviceComponentPS>> {
    let result: array<ref<ScriptableDeviceComponentPS>>;

    // Guard: Source device validation
    if !IsDefined(sourceDevicePS) {
      return result;
    }

    // Strategy: Get devices via AccessPoint hierarchy
    let sharedPS: ref<SharedGameplayPS> = sourceDevicePS;

    if IsDefined(sharedPS) {
      let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();

      if ArraySize(apControllers) > 0 {
        // Device has AccessPoint parent(s) - iterate ALL AccessPoints (not just first)
        let i: Int32 = 0;
        while i < ArraySize(apControllers) {
          let apPS: ref<AccessPointControllerPS> = apControllers[i];
          if IsDefined(apPS) {
            let networkDevices: array<ref<DeviceComponentPS>>;
            apPS.GetChildren(networkDevices);

            // Add all children
            let j: Int32 = 0;
            while j < ArraySize(networkDevices) {
              let devicePS: ref<ScriptableDeviceComponentPS> = networkDevices[j] as ScriptableDeviceComponentPS;

              // Skip non-ScriptableDeviceComponentPS
              if !IsDefined(devicePS) {
                j += 1;
              } else if excludeSource && devicePS == sourceDevicePS {
                // Skip source device if requested
                j += 1;
              } else {
                ArrayPush(result, devicePS);
                j += 1;
              }
            }
          }
          i += 1;
        }
      } else {
        // Standalone device (no AccessPoint parent) - check if device itself is MasterControllerPS
        let masterPS: ref<MasterControllerPS> = sourceDevicePS as MasterControllerPS;
        if IsDefined(masterPS) {
          // Device is AccessPoint/Computer/Terminal - get its children
          let networkDevices: array<ref<DeviceComponentPS>>;
          masterPS.GetChildren(networkDevices);

          // Add all children (source device is parent, never in children array)
          let k: Int32 = 0;
          while k < ArraySize(networkDevices) {
            let devicePS: ref<ScriptableDeviceComponentPS> = networkDevices[k] as ScriptableDeviceComponentPS;

            // Skip non-ScriptableDeviceComponentPS
            if IsDefined(devicePS) {
              ArrayPush(result, devicePS);
            }

            k += 1;
          }
        }
      }
    }

    return result;
  }

  // ============================================================================
  // RemoteBreach Lock Check - Timestamp-Based
  // ============================================================================
  //
  // FUNCTIONALITY:
  // Checks if device is locked by RemoteBreach failure timestamp.
  // Auto-expires locks after configurable duration (default 10 minutes).
  //
  // ARCHITECTURE:
  // - Uses BreachLockSystem.IsLockedByTimestamp() helper (DRY pattern)
  // - Guard Clause pattern (max nesting: 1 level)
  // - QuickHack menu filtering via RemoteBreachVisibility.reds
  //
  // PARAMETERS:
  // - devicePS: Device to check for RemoteBreach lock
  // - gameInstance: Game instance for timestamp/settings access
  //
  // RETURNS:
  // - true if locked (RemoteBreach hidden from QuickHack menu)
  // - false if accessible (lock expired or never locked)
  //
  // NOTE:
  // This check ONLY affects QuickHack menu visibility for RemoteBreach actions.
  // JackIn operation (AP Breach) is independent and unaffected by RemoteBreach locks.
  // ============================================================================
  public static func IsRemoteBreachLockedByTimestamp(
    devicePS: ref<ScriptableDeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Bool {
    if !IsDefined(devicePS) {
      return false;
    }

    // Access timestamp field (ScriptableDeviceComponentPS extends SharedGameplayPS)
    let shouldClear: Bool;
    let isLocked: Bool = BreachLockSystem.IsLockedByTimestamp(
      devicePS.m_betterNetrunningRemoteBreachFailedTimestamp,
      gameInstance,
      shouldClear
    );

    if shouldClear {
      devicePS.m_betterNetrunningRemoteBreachFailedTimestamp = 0.0;
    }

    return isLocked;
  }

  // ============================================================================
  // RemoteBreach Failure Recording - Hybrid Lock Strategy (Network + Standalone + Vehicles)
  // ============================================================================
  //
  // FUNCTIONALITY:
  // Records RemoteBreach failure on device PS (persistent timestamp).
  // Applies hybrid locking using network hierarchy + spatial radius:
  // - Step 1: Lock failed device itself
  // - Step 2: Lock network-connected devices (via GetNetworkDevices, NO distance limit)
  // - Step 3: Lock standalone/network devices in radius (via TargetingSystem, configurable range)
  // - Step 3B: Lock vehicles in radius (via TargetingSystem, configurable range)
  //
  // CONSISTENCY WITH UNLOCK (DaemonUnlockStrategy):
  // - Network Lock: Uses shared GetNetworkDevices() function
  //   - Iterates ALL AccessPoints (not just first)
  //   - No distance filtering (network hierarchy only)
  //   - Unlock affects entire network ↁELock must affect entire network
  // - Radial Lock (Standalone/Network/Vehicle): Distance-limited (range depends on RadialBreach MOD)
  //   - Standalone devices: Lock them
  //   - Network-connected devices in range: Lock them (handles standalone failure + nearby network devices)
  //   - Vehicles: Lock them
  //   - Distance limit prevents excessive locking
  //
  // RATIONALE:
  // TSF_All(TSFMV.Obj_Device) excludes VehicleObject entities.
  // Vehicles require separate scan with no searchFilter (detects all GameObject types).
  // VehicleComponentPS extends ScriptableDeviceComponentPS, supports timestamp field.
  //
  // ARCHITECTURE:
  // - Guard Clause pattern (max nesting: 2 levels)
  // - DRY principle: Reuses FindNearbyDevices() and FindNearbyVehicles()
  // - Mathematical guarantee: Network ∩ Standalone ∩ Vehicles = ∁E(mutually exclusive)
  // - Minimal deduplication: Only check failed device PersistentID (O(1))
  //
  // PARAMETERS:
  // - player: Player reference for TargetingSystem spatial scan
  // - failedDevicePS: Failed breach target device PS
  // - failedPosition: World position of failed device
  // - gameInstance: Game instance for timestamp/entity lookup
  //
  // NOTE:
  // This method ONLY records timestamps for QuickHack menu filtering.
  // JackIn operation (AP Breach) is independent and unaffected by RemoteBreach locks.
  // ============================================================================
  public static func RecordRemoteBreachFailure(
    player: ref<PlayerPuppet>,
    failedDevicePS: ref<ScriptableDeviceComponentPS>,
    failedPosition: Vector4,
    gameInstance: GameInstance
  ) -> Void {
    // Guard: Device validation
    if !IsDefined(failedDevicePS) {
      BNError("RemoteBreachLock", "RecordRemoteBreachFailure called with null device PS");
      return;
    }

    let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(gameInstance);
    let failedDeviceID: PersistentID = failedDevicePS.GetID();

    // Step 1: Lock failed device itself (guaranteed)
    if IsDefined(failedDevicePS) {
      failedDevicePS.m_betterNetrunningRemoteBreachFailedTimestamp = currentTime;
      let entityID: EntityID = PersistentID.ExtractEntityID(failedDeviceID);
      BNDebug("RemoteBreachLock", "Step 1: Locked failed device: " + EntityID.ToDebugString(entityID));
    } else {
      BNError("RemoteBreachLock", "Failed device is not SharedGameplayPS - cannot lock");
      return;
    }

    let radiusMeters: Float = GetRadialBreachRange(gameInstance);
    let networkLockedCount: Int32 = 0;
    let standaloneLockedCount: Int32 = 0;

    // Step 2: Lock network-connected devices (entire network, NO distance limit)
    // Uses shared GetNetworkDevices() - excludeSource=true to skip failed device (already locked in Step 1)
    let networkDevices: array<ref<ScriptableDeviceComponentPS>> = RemoteBreachLockSystem.GetNetworkDevices(
      failedDevicePS,
      true  // excludeSource: Failed device is locked separately in Step 1
    );

    let i: Int32 = 0;
    while i < ArraySize(networkDevices) {
      let devicePS: ref<ScriptableDeviceComponentPS> = networkDevices[i];

      if IsDefined(devicePS) {
        devicePS.m_betterNetrunningRemoteBreachFailedTimestamp = currentTime;
        networkLockedCount += 1;
      }

      i += 1;
    }

    // Step 3: Lock devices in radius (TargetingSystem spatial scan)
    // Locks both standalone and network-connected devices within configurable range
    let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);
    if IsDefined(targetingSystem) {
      let nearbyDevices: array<ref<ScriptableDeviceComponentPS>> = player.FindNearbyDevices(targetingSystem);

      let j: Int32 = 0;
      while j < ArraySize(nearbyDevices) {
        let devicePS: ref<ScriptableDeviceComponentPS> = nearbyDevices[j];
        let sharedPS: ref<SharedGameplayPS> = devicePS;

        if IsDefined(sharedPS) {
          let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();

          if ArraySize(apControllers) == 0 {
            // Standalone device
            if NotEquals(devicePS.GetID(), failedDeviceID) {
              sharedPS.m_betterNetrunningRemoteBreachFailedTimestamp = currentTime;
              standaloneLockedCount += 1;
            }
          } else {
            // Network-connected device in radius
            if NotEquals(devicePS.GetID(), failedDeviceID) {
              sharedPS.m_betterNetrunningRemoteBreachFailedTimestamp = currentTime;
              networkLockedCount += 1;
            }
          }
        }

        j += 1;
      }
    }

    // Step 3B: Lock vehicles in radius (VehicleObject-specific scan)
    let vehicleLockedCount: Int32 = 0;
    if IsDefined(targetingSystem) {
      let nearbyVehicles: array<ref<VehicleComponentPS>> = player.FindNearbyVehicles(targetingSystem);

      let k: Int32 = 0;
      while k < ArraySize(nearbyVehicles) {
        let vehiclePS: ref<VehicleComponentPS> = nearbyVehicles[k];

        if IsDefined(vehiclePS) {
          // Skip failed device if it's a vehicle (minimal deduplication - O(1))
          if NotEquals(vehiclePS.GetID(), failedDeviceID) {
            vehiclePS.m_betterNetrunningRemoteBreachFailedTimestamp = currentTime;
            vehicleLockedCount += 1;
          }
        }

        k += 1;
      }
    }

    // Final summary log
    // - Network: Step 2 (connected network) + Step 3 (network devices in radius)
    // - Standalone: Step 3 (standalone devices in radius)
    // - Vehicles: Step 3B (vehicles in radius)
    let totalLocked: Int32 = 1 + networkLockedCount + standaloneLockedCount + vehicleLockedCount; // 1 = failed device
    BNInfo("RemoteBreachLock", "Locked " + IntToString(totalLocked) + " devices " +
           "(Network: " + IntToString(networkLockedCount) + " [connected network], " +
           "Standalone: " + IntToString(standaloneLockedCount) + " [" + FloatToString(radiusMeters) + "m], " +
           "Vehicles: " + IntToString(vehicleLockedCount) + " [" + FloatToString(radiusMeters) + "m])");
  }
}
