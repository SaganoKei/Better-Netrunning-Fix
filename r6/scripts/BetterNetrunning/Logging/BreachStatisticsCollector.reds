// -----------------------------------------------------------------------------
// Breach Statistics Collector - Unified Statistics Collection
// -----------------------------------------------------------------------------
//
// PURPOSE:
// Centralizes breach statistics collection logic shared across breach types
//
// FUNCTIONALITY:
// - Network device statistics: Counts and classifies network-connected devices
// - Radial unlock statistics: Tracks standalone devices/NPCs unlocked within radius
// - Daemon classification: Identifies executed Subnet and Normal daemons
//
// ARCHITECTURE:
// - Static utility class (no instantiation required)
// - Two primary methods: CollectNetworkDeviceStats() and CollectRadialUnlockStats()
// - Helper method: ProcessNetworkDevice() for device type classification
//

module BetterNetrunning.Logging

import BetterNetrunning.*
import BetterNetrunning.Core.*
import BetterNetrunning.Minigame.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Logging.*

public abstract class BreachStatisticsCollector {
    // ============================================================================
    // Network Device Statistics Collection
    // ============================================================================

    /*
     * Collects statistics for network-connected devices accessed via AccessPoint
     *
     * ARCHITECTURE: Single-pass iteration with device type classification via DeviceTypeUtils
     * @param networkDevices - Array of network-connected devices from AccessPoint.GetChildren()
     * @param unlockFlags - Unlock flags determining which device types to unlock
     * @param stats - Statistics object to update with device counts
     */
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
    // Radial Unlock Statistics Collection
    // ============================================================================

    /*
     * Collects statistics for standalone devices unlocked via radial unlock (50m radius)
     *
     * FUNCTIONALITY:
     * - Basic Daemon: Unlocks standalone devices + vehicles within 50m radius
     * - NPC Daemon: Unlocks NPCs within 50m radius (separate flag)
     * - Counts unlocked entities by type
     * - Updates BreachSessionStats with radial unlock counts
     *
     * ARCHITECTURE:
     * - Single-pass classification: Devices categorized in one GetTargetParts() call
     * - Network connectivity check: Separates pure standalone from cross-network devices
     * - Excludes breached network devices: Avoids double-counting with NETWORK DEVICES section
     * - Uses Template Method Pattern with polymorphic processors
     *
     * @param sourceDevice - Device from which radial unlock originates (position reference)
     * @param breachedAPID - PersistentID of breached AccessPoint
     * @param unlockFlags - Unlock flags determining which entity types to unlock
     * @param stats - Statistics object to update
     * @param gameInstance - Game instance for accessing game systems
     */
    public static func CollectRadialUnlockStats(
        sourceDevice: ref<ScriptableDeviceComponentPS>,
        breachedAPID: PersistentID,
        unlockFlags: BreachUnlockFlags,
        stats: ref<BreachSessionStats>,
        gameInstance: GameInstance
    ) -> Void {
        // Capture origin information from targeting setup
        let deviceEntity: wref<GameObject> = sourceDevice.GetOwnerEntityWeak() as GameObject;
        if IsDefined(deviceEntity) {
            let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupDeviceTargeting(deviceEntity, gameInstance);
            if targetingSetup.isValid {
                stats.originPosition = targetingSetup.sourcePos;
                stats.originType = targetingSetup.originType;
                stats.radialUnlockRange = targetingSetup.breachRadius;
            }
        }

        // Single-pass collection: Count and classify devices by network connectivity
        // ARCHITECTURE: Uses Template Method Pattern with polymorphic processors
        let standaloneCount: Int32 = 0;
        let crossNetworkCount: Int32 = 0;
        let standaloneUnlocked: Int32 = 0;
        let crossNetworkUnlocked: Int32 = 0;

        // Get all target parts in one call
        let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupDeviceTargeting(deviceEntity, gameInstance);
        if targetingSetup.isValid {
            let parts: array<TS_TargetPartInfo>;
            targetingSetup.targetingSystem.GetTargetParts(targetingSetup.player, targetingSetup.query, parts);

            // Process all entities with processor pattern (single call, no loop needed)
            let radiusSq: Float = targetingSetup.breachRadius * targetingSetup.breachRadius;
            DeviceUnlockUtils.ProcessEntityInRadius(
                parts,
                targetingSetup.sourcePos,
                radiusSq,
                breachedAPID,
                gameInstance,
                unlockFlags,
                standaloneCount,
                crossNetworkCount,
                standaloneUnlocked,
                crossNetworkUnlocked
            );
        }

        // Store collected statistics
        stats.standaloneDeviceCount = standaloneCount;
        stats.crossNetworkDeviceCount = crossNetworkCount;
        stats.vehicleCount = standaloneCount;  // Vehicles are counted as standalone
        stats.standaloneUnlocked = standaloneUnlocked;
        stats.standaloneSkipped = standaloneCount - standaloneUnlocked;
        stats.crossNetworkUnlocked = crossNetworkUnlocked;
        stats.crossNetworkSkipped = crossNetworkCount - crossNetworkUnlocked;
        stats.vehicleUnlocked = standaloneUnlocked;  // Vehicles are included in standalone
        stats.vehicleSkipped = standaloneCount - standaloneUnlocked;

        // NPC Daemon: Single-pass collection with network classification
        let npcPureStandaloneCount: Int32 = 0;
        let npcCrossNetworkCount: Int32 = 0;
        let npcPureStandaloneUnlocked: Int32 = 0;
        let npcCrossNetworkUnlocked: Int32 = 0;
        DeviceUnlockUtils.ProcessNPCsInRadius(
            sourceDevice, breachedAPID, unlockFlags,
            npcPureStandaloneCount, npcCrossNetworkCount,
            npcPureStandaloneUnlocked, npcCrossNetworkUnlocked,
            gameInstance
        );

        stats.npcPureStandaloneCount = npcPureStandaloneCount;
        stats.npcCrossNetworkCount = npcCrossNetworkCount;
        stats.npcPureStandaloneUnlocked = npcPureStandaloneUnlocked;
        stats.npcPureStandaloneSkipped = npcPureStandaloneCount - npcPureStandaloneUnlocked;
        stats.npcCrossNetworkUnlocked = npcCrossNetworkUnlocked;
        stats.npcCrossNetworkSkipped = npcCrossNetworkCount - npcCrossNetworkUnlocked;
    }

    // ============================================================================
    // Internal Helpers
    // ============================================================================

    /*
     * Processes single network device for statistics collection
     *
     * ARCHITECTURE: Device type classification via DeviceTypeUtils
     * @param device - Device component to process
     * @param unlockFlags - Unlock flags determining which device types to unlock
     * @param stats - Statistics object to update with device counts
     */
    private static func ProcessNetworkDevice(
        device: ref<DeviceComponentPS>,
        unlockFlags: BreachUnlockFlags,
        stats: ref<BreachSessionStats>
    ) -> Void {
        // Classify device type
        let TargetType: TargetType = DeviceTypeUtils.GetDeviceType(device);

        // Determine if device should be unlocked
        let shouldUnlock: Bool = DeviceTypeUtils.ShouldUnlockByFlags(TargetType, unlockFlags);

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
    // Daemon Classification
    // ============================================================================

    /*
     * Collects displayed daemon statistics from ActivePrograms Blackboard BEFORE filtering
     *
     * TIMING: Called BEFORE wrappedMethod() to capture all injected daemons
     * ARCHITECTURE: Early Return + Guard Clauses (0-level nesting)
     * @param minigamePrograms - ActivePrograms array from HackingMinigame Blackboard
     * @param stats - Statistics object to populate (displayedSubnetDaemons, displayedNormalDaemons)
     */
    public static func CollectDisplayedDaemons(
        minigamePrograms: array<TweakDBID>,
        stats: ref<BreachSessionStats>
    ) -> Void {
        let i: Int32 = 0;
        while i < ArraySize(minigamePrograms) {
            let programID: TweakDBID = minigamePrograms[i];

            if DaemonFilterUtils.IsSubnetDaemon(programID) {
                ArrayPush(stats.displayedSubnetDaemons, programID);
            } else {
                ArrayPush(stats.displayedNormalDaemons, programID);
            }

            i += 1;
        }
    }

    /*
     * Collects executed daemon statistics from ActivePrograms Blackboard AFTER minigame
     *
     * TIMING: Called AFTER wrappedMethod() to capture successfully executed daemons
     * ARCHITECTURE: Early Return + Guard Clauses (0-level nesting)
     * @param minigamePrograms - ActivePrograms array from HackingMinigame Blackboard
     * @param stats - Statistics object to populate (executedSubnetDaemons, executedNormalDaemons, executedBonusDaemons)
     */
    public static func CollectExecutedDaemons(
        minigamePrograms: array<TweakDBID>,
        stats: ref<BreachSessionStats>
    ) -> Void {
        let i: Int32 = 0;
        while i < ArraySize(minigamePrograms) {
            let programID: TweakDBID = minigamePrograms[i];

            // Record bonus daemons (auto-added Datamine) separately
            if BonusDaemonUtils.IsDatamineDaemon(programID) {
                ArrayPush(stats.executedBonusDaemons, programID);
                i += 1;
            } else if DaemonFilterUtils.IsSubnetDaemon(programID) {
                ArrayPush(stats.executedSubnetDaemons, programID);
                i += 1;
            } else {
                ArrayPush(stats.executedNormalDaemons, programID);
                i += 1;
            }
        }
    }
}

// ============================================================================
// DisplayedDaemons State Management
// ============================================================================
// Stores displayed daemons from FilterPlayerPrograms for statistics collection
// in RefreshSlaves. Solves timing issue where ActivePrograms only contains
// successfully executed daemons after minigame completion.

public class DisplayedDaemonsStateSystem extends ScriptableSystem {
    private let m_displayedDaemons: array<TweakDBID>;

    public func SetDisplayedDaemons(daemons: array<TweakDBID>) -> Void {
        ArrayClear(this.m_displayedDaemons);
        let i: Int32 = 0;
        while i < ArraySize(daemons) {
            ArrayPush(this.m_displayedDaemons, daemons[i]);
            i += 1;
        }
    }

    public func GetDisplayedDaemons() -> array<TweakDBID> {
        return this.m_displayedDaemons;
    }

    public func ClearDisplayedDaemons() -> Void {
        ArrayClear(this.m_displayedDaemons);
    }
}
