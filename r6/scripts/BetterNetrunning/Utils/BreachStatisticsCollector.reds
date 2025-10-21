// -----------------------------------------------------------------------------
// Breach Statistics Collector - Unified Statistics Collection
// -----------------------------------------------------------------------------
// Centralizes breach statistics collection logic to eliminate code duplication
// across AccessPoint breach, UnconsciousNPC breach, and RemoteBreach handlers.
//
// ARCHITECTURE:
// - Static utility class (no instantiation required)
// - Two primary methods: CollectNetworkDeviceStats() and CollectRadialUnlockStats()
// - Reduces 150+ lines of duplicated code across 3 files to 80 lines + 6 lines of calls
//
// USAGE EXAMPLE:
// ```
// let stats: ref<BreachSessionStats> = BreachSessionStats.Create("AccessPoint", deviceName);
// let unlockFlags: BreachUnlockFlags = DaemonFilterUtils.ExtractUnlockFlags(programs);
//
// // Collect network device statistics
// BreachStatisticsCollector.CollectNetworkDeviceStats(networkDevices, unlockFlags, stats);
//
// // Collect radial unlock statistics
// BreachStatisticsCollector.CollectRadialUnlockStats(device, unlockFlags, stats, gameInstance);
// ```
//
// DEPENDENCIES:
// - BreachSessionStats: Statistics data structure
// - BreachUnlockFlags: Unlock flags (Basic, Cameras, Turrets, NPCs)
// - DeviceTypeUtils: Device type classification
// - DeviceUnlockUtils: Radial unlock execution
// -----------------------------------------------------------------------------

module BetterNetrunning.Utils

import BetterNetrunning.*
import BetterNetrunning.Core.*

public abstract class BreachStatisticsCollector {
    // ============================================================================
    // CollectNetworkDeviceStats - Network-Connected Device Statistics
    // ============================================================================
    // PURPOSE:
    // Collects statistics for network-connected devices (accessed via AccessPoint)
    //
    // FUNCTIONALITY:
    // - Counts devices by type (Basic, Camera, Turret, NPC)
    // - Tracks unlocked vs skipped devices based on unlock flags
    // - Updates BreachSessionStats with device counts
    //
    // PARAMETERS:
    // - networkDevices: Array of network-connected devices from AccessPoint.GetChildren()
    // - unlockFlags: Unlock flags determining which device types to unlock
    // - stats: Statistics object to update
    //
    // ARCHITECTURE:
    // - Single-pass iteration with early continue for undefined devices
    // - Device type classification via DeviceTypeUtils
    // - Unlock decision via DeviceTypeUtils.ShouldUnlockByFlags()
    //
    // EXAMPLE:
    // ```
    // let networkDevices: array<ref<DeviceComponentPS>>;
    // accessPointPS.GetChildren(networkDevices);
    // BreachStatisticsCollector.CollectNetworkDeviceStats(networkDevices, unlockFlags, stats);
    // ```
    // ============================================================================
    public static func CollectNetworkDeviceStats(
        networkDevices: array<ref<DeviceComponentPS>>,
        unlockFlags: BreachUnlockFlags,
        stats: ref<BreachSessionStats>
    ) -> Void {
        // Set network device count
        stats.networkDeviceCount = ArraySize(networkDevices);

        // Early return if no devices
        if ArraySize(networkDevices) == 0 {
            return;
        }

        // Count device types and track unlock status
        let i: Int32 = 0;
        while i < ArraySize(networkDevices) {
            let device: ref<DeviceComponentPS> = networkDevices[i];

            // Process device statistics (skip undefined devices)
            if IsDefined(device) {
                BreachStatisticsCollector.ProcessNetworkDevice(device, unlockFlags, stats);
            }

            i += 1;
        }
    }

    // ============================================================================
    // CollectRadialUnlockStats - Radial Unlock Statistics (50m radius)
    // ============================================================================
    // PURPOSE:
    // Collects statistics for standalone devices unlocked via radial unlock (50m radius)
    //
    // FUNCTIONALITY:
    // - Basic Daemon: Unlocks standalone devices + vehicles within 50m radius
    // - NPC Daemon: Unlocks NPCs within 50m radius (separate flag)
    // - Counts unlocked entities by type
    // - Updates BreachSessionStats with radial unlock counts
    //
    // PARAMETERS:
    // - sourceDevice: Device from which radial unlock originates (position reference)
    // - unlockFlags: Unlock flags determining which entity types to unlock
    //   - unlockBasic: Standalone devices + vehicles
    //   - unlockNPCs: NPCs (separate from Basic)
    // - stats: Statistics object to update
    // - gameInstance: Game instance for accessing game systems
    //
    // ARCHITECTURE:
    // - Basic Daemon and NPC Daemon are independent (separate flag checks)
    // - Uses DeviceUnlockUtils for actual unlock execution
    // - Sets skipped counts to 0 (all found entities are unlocked when flag is true)
    //
    // EXAMPLE:
    // ```
    // BreachStatisticsCollector.CollectRadialUnlockStats(
    //     accessPointPS,
    //     unlockFlags,
    //     stats,
    //     this.GetGameInstance()
    // );
    // ```
    // ============================================================================
    public static func CollectRadialUnlockStats(
        sourceDevice: ref<ScriptableDeviceComponentPS>,
        unlockFlags: BreachUnlockFlags,
        stats: ref<BreachSessionStats>,
        gameInstance: GameInstance
    ) -> Void {
        // Basic Daemon: Count standalone devices + vehicles (always count, unlock only if daemon executed)
        let standaloneCount: Int32 = DeviceUnlockUtils.CountDevicesInRadius(sourceDevice, gameInstance);
        let vehicleCount: Int32 = DeviceUnlockUtils.CountVehiclesInRadius(sourceDevice, gameInstance);

        stats.standaloneDeviceCount = standaloneCount;
        stats.vehicleCount = vehicleCount;

        if unlockFlags.unlockBasic {
            // Unlock devices and vehicles
            let unlockedDevices: Int32 = DeviceUnlockUtils.UnlockDevicesInRadius(sourceDevice, gameInstance);
            let unlockedVehicles: Int32 = DeviceUnlockUtils.UnlockVehiclesInRadius(sourceDevice, gameInstance);

            stats.standaloneUnlocked = unlockedDevices;
            stats.standaloneSkipped = standaloneCount - unlockedDevices;

            stats.vehicleUnlocked = unlockedVehicles;
            stats.vehicleSkipped = vehicleCount - unlockedVehicles;
        } else {
            // Basic Daemon not executed - all devices/vehicles skipped
            stats.standaloneUnlocked = 0;
            stats.standaloneSkipped = standaloneCount;

            stats.vehicleUnlocked = 0;
            stats.vehicleSkipped = vehicleCount;
        }

        // NPC Daemon: Count NPCs in radius (always count, unlock only if daemon executed)
        stats.npcStandaloneCount = DeviceUnlockUtils.CountNPCsInRadius(sourceDevice, gameInstance);

        if unlockFlags.unlockNPCs {
            // NPC Daemon executed - unlock NPCs
            stats.npcStandaloneUnlocked = DeviceUnlockUtils.UnlockNPCsInRadius(sourceDevice, gameInstance);
            stats.npcStandaloneSkipped = stats.npcStandaloneCount - stats.npcStandaloneUnlocked;
        } else {
            // NPC Daemon not executed - all NPCs skipped
            stats.npcStandaloneUnlocked = 0;
            stats.npcStandaloneSkipped = stats.npcStandaloneCount;
        }
    }

    // ============================================================================
    // ProcessNetworkDevice - Internal Helper for Network Device Processing
    // ============================================================================
    // PURPOSE:
    // Processes single network device for statistics collection
    //
    // FUNCTIONALITY:
    // - Classifies device type (Camera, Turret, NPC, Basic)
    // - Determines if device should be unlocked based on flags
    // - Updates statistics counters by device type
    //
    // ARCHITECTURE:
    // - Private helper method (not exposed in public API)
    // - Device type classification via DeviceTypeUtils
    // - Unlock decision via DeviceTypeUtils.ShouldUnlockByFlags()
    // ============================================================================
    private static func ProcessNetworkDevice(
        device: ref<DeviceComponentPS>,
        unlockFlags: BreachUnlockFlags,
        stats: ref<BreachSessionStats>
    ) -> Void {
        // Classify device type
        let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

        // Determine if device should be unlocked
        let shouldUnlock: Bool = DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags);

        // Update statistics based on device type
        if DeviceTypeUtils.IsCameraDevice(device) {
            stats.cameraCount += 1;
            if shouldUnlock {
                stats.cameraUnlocked += 1;
            } else {
                stats.cameraSkipped += 1;
            }
        } else if DeviceTypeUtils.IsTurretDevice(device) {
            stats.turretCount += 1;
            if shouldUnlock {
                stats.turretUnlocked += 1;
            } else {
                stats.turretSkipped += 1;
            }
        } else if DeviceTypeUtils.IsNPCDevice(device) {
            stats.npcNetworkCount += 1;
            if shouldUnlock {
                stats.npcNetworkUnlocked += 1;
            } else {
                stats.npcNetworkSkipped += 1;
            }
        } else {
            stats.basicCount += 1;
            if shouldUnlock {
                stats.basicUnlocked += 1;
            } else {
                stats.basicSkipped += 1;
            }
        }

        // Update total unlocked/skipped counts
        if shouldUnlock {
            stats.devicesUnlocked += 1;
        } else {
            stats.devicesSkipped += 1;
        }
    }

    // ============================================================================
    // CollectExecutedDaemons - Executed Daemon Classification
    // ============================================================================
    // PURPOSE:
    // Collects executed daemon information from ActivePrograms for detailed logging
    //
    // FUNCTIONALITY:
    // - Classifies daemons into Subnet Daemons (Basic/Camera/Turret/NPC)
    // - Identifies Normal Daemons (PING, Datamine, vanilla special daemons, etc.)
    // - Stores TweakDBIDs for later display
    //
    // ARCHITECTURE: Early Return + Guard Clauses (0-level nesting)
    //
    // PARAMETERS:
    // - minigamePrograms: ActivePrograms array from HackingMinigame Blackboard
    // - stats: Statistics object to populate (displayedSubnetDaemons, executedSubnetDaemons, displayedNormalDaemons)
    public static func CollectExecutedDaemons(
        minigamePrograms: array<TweakDBID>,
        stats: ref<BreachSessionStats>
    ) -> Void {
        let i: Int32 = 0;
        while i < ArraySize(minigamePrograms) {
            let programID: TweakDBID = minigamePrograms[i];

            // Subnet Daemons classification
            if DaemonFilterUtils.IsSubnetDaemon(programID) {
                ArrayPush(stats.displayedSubnetDaemons, programID);  // Track all displayed Subnet daemons
                ArrayPush(stats.executedSubnetDaemons, programID);   // Track successfully executed Subnet daemons
            }
            // Normal Daemons classification (= NOT Subnet System)
            else {
                ArrayPush(stats.displayedNormalDaemons, programID);  // Track all displayed Normal daemons
            }

            i += 1;
        }
    }
}
