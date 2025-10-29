// -----------------------------------------------------------------------------
// Device Unlock Utilities (Shared by AP Breach & RemoteBreach)
// -----------------------------------------------------------------------------
// Provides radius-based device/vehicle/NPC unlock logic shared across breach types.
//
// DESIGN RATIONALE:
// - Single Responsibility: Targeting system radius search + timestamp management
// - DRY Principle: Eliminates duplicate unlock logic between AP Breach and RemoteBreach
// - Module Independence: Both breach types can use without coupling to RemoteBreach
//
// ARCHITECTURE:
// This module extracts common unlock logic previously in RemoteBreachUtils,
// making it available to both AccessPoint Breach and RemoteBreach implementations.
// Time utilities (GetCurrentTimestamp, SetDeviceUnlockTimestamp) migrated from
// TimeUtils.reds (single-method file consolidation).
//
// USAGE:
// DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
// DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);
// DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);
// DeviceUnlockUtils.GetCurrentTimestamp(gameInstance);
// DeviceUnlockUtils.SetDeviceUnlockTimestamp(sharedPS, deviceType, timestamp);
// -----------------------------------------------------------------------------

module BetterNetrunning.Core

import BetterNetrunning.Integration.*
import BetterNetrunning.Logging.*
import BetterNetrunning.RadialUnlock.*
import BetterNetrunning.Utils.*

// Helper struct for targeting setup
public struct TargetingSetup {
    public let isValid: Bool;
    public let breachRadius: Float;
    public let sourcePos: Vector4;
    public let player: wref<PlayerPuppet>;
    public let targetingSystem: ref<TargetingSystem>;
    public let query: TargetSearchQuery;
}

// Helper struct for unlock flags
public struct UnlockFlags {
    public let unlockBasic: Bool;
    public let unlockNPCs: Bool;
    public let unlockCameras: Bool;
    public let unlockTurrets: Bool;
}

// Helper struct for vehicle processing result
public struct VehicleProcessResult {
    public let vehicleFound: Bool;
    public let unlocked: Bool;
}

// Radial unlock statistics result
// Tracks device counts and unlock success for 50m radius breach operations
public struct RadialUnlockResult {
    public let basicCount: Int32;
    public let cameraCount: Int32;
    public let turretCount: Int32;
    public let npcCount: Int32;
    public let basicUnlocked: Int32;
    public let cameraUnlocked: Int32;
    public let turretUnlocked: Int32;
    public let npcUnlocked: Int32;
}

public abstract class DeviceUnlockUtils {
    // ============================================================================
    // UnlockNPCsInRadius - Radial NPC Unlock
    // ============================================================================
    /*
     * Unlock NPCs in 50m radius using hybrid collection strategy
     *
     * PURPOSE:
     * Unlock NPCs within radius by firing SetExposeQuickHacks events
     *
     * FUNCTIONALITY:
     * - Uses hybrid collection (GetPuppets + TargetingSystem)
     * - Fires SetExposeQuickHacks event for each NPC (triggers timestamp validation)
     * - Returns count of successfully unlocked standalone NPCs
     *
     * ARCHITECTURE:
     * Collects network + standalone NPCs, then unlocks standalone NPCs only
     *
     * RATIONALE:
     * Leverages hybrid collection for performance (30-83% TargetingSystem reduction)
     * Caller only needs standalone unlock count (network NPCs ignored)
     *
     * @param devicePS - Device initiating the unlock (typically AccessPointControllerPS)
     * @param gameInstance - Game instance for system access
     * @return Number of standalone NPCs successfully unlocked
     */
    public static func UnlockNPCsInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Int32 {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return 0;
        }

        let origin: Vector4 = deviceEntity.GetWorldPosition();
        let radius: Float = GetRadialBreachRange(gameInstance);

        // Cast to AccessPointControllerPS for hybrid collection
        let accessPoint: ref<AccessPointControllerPS> = devicePS as AccessPointControllerPS;

        // Collect standalone NPCs via hybrid strategy
        let processedIDs: array<PersistentID>;
        if IsDefined(accessPoint) {
            DeviceUnlockUtils.CollectNetworkNPCsFromAccessPoint(
                accessPoint, origin, radius, processedIDs
            );
        }

        let standalonePuppets: array<ref<ScriptedPuppet>> = DeviceUnlockUtils.CollectStandaloneNPCsInRadius(
            origin, radius, gameInstance, processedIDs
        );

        // Unlock standalone NPCs (fire SetExposeQuickHacks events)
        let unlockedCount: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(standalonePuppets) {
            if DeviceUnlockUtils.UnlockStandaloneNPC(standalonePuppets[i]) {
                unlockedCount += 1;
            }
            i += 1;
        }

        return unlockedCount;
    }

    // ============================================================================
    // CountNPCsInRadius - Count NPCs (No Unlock)
    // ============================================================================
    /*
     * Count NPCs in radius without unlocking using hybrid collection strategy
     *
     * PURPOSE:
     * Count standalone NPCs in radius without unlocking (read-only operation)
     *
     * FUNCTIONALITY:
     * - Uses hybrid collection (GetPuppets + TargetingSystem)
     * - Network NPCs: Collected via GetPuppets() (used for duplicate detection)
     * - Standalone NPCs: Collected via TargetingSystem (counted and returned)
     * - Null AccessPoint handling: Uses devicePS cast to AccessPointControllerPS
     *
     * ARCHITECTURE:
     * Collects network NPCs for duplicate detection, then counts standalone NPCs
     *
     * RATIONALE:
     * Leverages hybrid collection for performance (30-83% TargetingSystem reduction)
     * Caller only needs standalone count (network NPCs ignored)
     *
     * @param devicePS - Device initiating the count (typically AccessPointControllerPS)
     * @param gameInstance - Game instance for system access
     * @return Number of standalone NPCs found in radius
     */
    public static func CountNPCsInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Int32 {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return 0;
        }

        let origin: Vector4 = deviceEntity.GetWorldPosition();
        let radius: Float = GetRadialBreachRange(gameInstance);

        // Cast to AccessPointControllerPS for hybrid collection
        let accessPoint: ref<AccessPointControllerPS> = devicePS as AccessPointControllerPS;

        // Collect network NPCs for duplicate detection
        let processedIDs: array<PersistentID>;
        if IsDefined(accessPoint) {
            DeviceUnlockUtils.CollectNetworkNPCsFromAccessPoint(
                accessPoint, origin, radius, processedIDs
            );
        }

        // Count standalone NPCs
        let standalonePuppets: array<ref<ScriptedPuppet>> = DeviceUnlockUtils.CollectStandaloneNPCsInRadius(
            origin, radius, gameInstance, processedIDs
        );

        return ArraySize(standalonePuppets);
    }

    // ============================================================================
    // UnlockDevicesInRadius - Radial Standalone Device Unlock
    // ============================================================================
    /*
     * Unlock standalone devices in 50m radius via TargetingSystem
     * ARCHITECTURE: Uses TargetingSystem to find devices without network connections
     * RETURNS: Number of devices unlocked
     */
    public static func UnlockDevicesInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Int32 {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return 0;
        }

        let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupDeviceTargeting(deviceEntity, gameInstance);
        if !targetingSetup.isValid {
            return 0;
        }

        let parts: array<TS_TargetPartInfo>;
        targetingSetup.targetingSystem.GetTargetParts(targetingSetup.player, targetingSetup.query, parts);

        let deviceCount: Int32 = 0;
        let idx: Int32 = 0;
        while idx < ArraySize(parts) {
            if DeviceUnlockUtils.ProcessAndUnlockStandaloneDevice(parts[idx], targetingSetup.sourcePos, targetingSetup.breachRadius) {
                deviceCount += 1;
            }
            idx += 1;
        }

        return deviceCount;
    }

    // ============================================================================
    // CountDevicesInRadius - Count Standalone Devices (No Unlock)
    // ============================================================================
    // PURPOSE: Count standalone devices in radius without unlocking
    // FUNCTIONALITY: Same as UnlockDevicesInRadius but only counts
    // ARCHITECTURE: Reuses targeting setup, skips unlock operation
    // RETURNS: Number of standalone devices detected
    public static func CountDevicesInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Int32 {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return 0;
        }

        let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupDeviceTargeting(deviceEntity, gameInstance);
        if !targetingSetup.isValid {
            return 0;
        }

        let parts: array<TS_TargetPartInfo>;
        targetingSetup.targetingSystem.GetTargetParts(targetingSetup.player, targetingSetup.query, parts);

        let deviceCount: Int32 = 0;
        let idx: Int32 = 0;
        while idx < ArraySize(parts) {
            if DeviceUnlockUtils.IsValidStandaloneDevice(parts[idx], targetingSetup.sourcePos, targetingSetup.breachRadius) {
                deviceCount += 1;
            }
            idx += 1;
        }

        return deviceCount;
    }

    // ============================================================================
    // UnlockVehiclesInRadius - Radial Vehicle Unlock
    // ============================================================================
    /*
     * Unlock vehicles in 50m radius via TargetingSystem
     * ARCHITECTURE: Uses TargetingSystem to find VehicleObject entities
     * RETURNS: Number of vehicles unlocked
     */
    public static func UnlockVehiclesInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Int32 {
        let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupVehicleTargeting(devicePS, gameInstance);
        if !targetingSetup.isValid {
            return 0;
        }

        let parts: array<TS_TargetPartInfo>;
        targetingSetup.targetingSystem.GetTargetParts(targetingSetup.player, targetingSetup.query, parts);

        let idx: Int32 = 0;
        let vehicleCount: Int32 = 0;
        let unlockedCount: Int32 = 0;
        while idx < ArraySize(parts) {
            let result: VehicleProcessResult = DeviceUnlockUtils.ProcessAndUnlockVehicle(parts[idx], targetingSetup.sourcePos, targetingSetup.breachRadius, gameInstance);
            vehicleCount += result.vehicleFound ? 1 : 0;
            unlockedCount += result.unlocked ? 1 : 0;
            idx += 1;
        }

        return vehicleCount;
    }

    // ============================================================================
    // CountVehiclesInRadius - Count Vehicles (No Unlock)
    // ============================================================================
    // PURPOSE: Count vehicles in radius without unlocking
    // FUNCTIONALITY: Same as UnlockVehiclesInRadius but only counts
    // ARCHITECTURE: Reuses targeting setup, skips unlock operation
    // RETURNS: Number of vehicles detected
    public static func CountVehiclesInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Int32 {
        let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupVehicleTargeting(devicePS, gameInstance);
        if !targetingSetup.isValid {
            return 0;
        }

        let parts: array<TS_TargetPartInfo>;
        targetingSetup.targetingSystem.GetTargetParts(targetingSetup.player, targetingSetup.query, parts);

        let idx: Int32 = 0;
        let vehicleCount: Int32 = 0;
        while idx < ArraySize(parts) {
            if DeviceUnlockUtils.IsValidVehicle(parts[idx], targetingSetup.sourcePos, targetingSetup.breachRadius) {
                vehicleCount += 1;
            }
            idx += 1;
        }

        return vehicleCount;
    }

    // ============================================================================
    // Private Helper Methods - Targeting Setup
    // ============================================================================

    // Setup targeting for Device search (reduce code duplication)
    private static func SetupDeviceTargeting(sourceEntity: wref<GameObject>, gameInstance: GameInstance) -> TargetingSetup {
        let setup: TargetingSetup;
        setup.isValid = false;
        setup.breachRadius = GetRadialBreachRange(gameInstance);
        setup.sourcePos = sourceEntity.GetWorldPosition();

        setup.player = GetPlayer(gameInstance);
        if !IsDefined(setup.player) {
            return setup;
        }

        setup.targetingSystem = GameInstance.GetTargetingSystem(gameInstance);
        if !IsDefined(setup.targetingSystem) {
            return setup;
        }

        setup.query.searchFilter = TSF_All(TSFMV.Obj_Device);
        setup.query.testedSet = TargetingSet.Complete;
        setup.query.maxDistance = setup.breachRadius * 2.0;
        setup.query.filterObjectByDistance = true;
        setup.query.includeSecondaryTargets = false;
        setup.query.ignoreInstigator = true;

        setup.isValid = true;
        return setup;
    }

    // Setup targeting for Vehicle search
    private static func SetupVehicleTargeting(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> TargetingSetup {
        let setup: TargetingSetup;
        setup.isValid = false;

        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            BNError("DeviceUnlockUtils", "deviceEntity not defined");
            return setup;
        }

        setup.sourcePos = deviceEntity.GetWorldPosition();
        setup.breachRadius = GetRadialBreachRange(gameInstance);

        setup.player = GetPlayer(gameInstance);
        if !IsDefined(setup.player) {
            BNError("DeviceUnlockUtils", "player not defined");
            return setup;
        }

        setup.targetingSystem = GameInstance.GetTargetingSystem(gameInstance);
        if !IsDefined(setup.targetingSystem) {
            BNError("DeviceUnlockUtils", "targetingSystem not defined");
            return setup;
        }

        setup.query.testedSet = TargetingSet.Complete;
        setup.query.maxDistance = setup.breachRadius;
        setup.query.filterObjectByDistance = true;
        setup.query.includeSecondaryTargets = false;
        setup.query.ignoreInstigator = true;

        setup.isValid = true;
        return setup;
    }

    // ============================================================================
    // Private Helper Methods - Entity Processing
    // ============================================================================

    // Unlock network NPC (via PuppetDeviceLinkPS)
    // RETURNS: True if unlock event was fired successfully
    private static func UnlockNetworkNPC(puppetLink: ref<PuppetDeviceLinkPS>) -> Bool {
        if !IsDefined(puppetLink) {
            return false;
        }

        let npcObject: wref<GameObject> = puppetLink.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(npcObject) {
            return false;
        }

        let puppet: ref<ScriptedPuppet> = npcObject as ScriptedPuppet;
        if !IsDefined(puppet) {
            return false;
        }

        let npcPS: ref<ScriptedPuppetPS> = puppet.GetPS();
        if !IsDefined(npcPS) {
            return false;
        }

        // Fire SetExposeQuickHacks event (triggers timestamp validation)
        let exposeEvent: ref<SetExposeQuickHacks> = new SetExposeQuickHacks();
        exposeEvent.isRemote = true;
        npcPS.GetPersistencySystem().QueueEntityEvent(PersistentID.ExtractEntityID(npcPS.GetID()), exposeEvent);

        return true;
    }

    // Unlock standalone NPC (via ScriptedPuppet)
    // RETURNS: True if unlock event was fired successfully
    private static func UnlockStandaloneNPC(puppet: ref<ScriptedPuppet>) -> Bool {
        if !IsDefined(puppet) {
            return false;
        }

        let npcPS: ref<ScriptedPuppetPS> = puppet.GetPS();
        if !IsDefined(npcPS) {
            return false;
        }

        // Fire SetExposeQuickHacks event (triggers timestamp validation)
        let exposeEvent: ref<SetExposeQuickHacks> = new SetExposeQuickHacks();
        exposeEvent.isRemote = true;
        npcPS.GetPersistencySystem().QueueEntityEvent(PersistentID.ExtractEntityID(npcPS.GetID()), exposeEvent);

        return true;
    }

    // Process and unlock standalone device (reduce nesting in UnlockDevicesInRadius)
    // RETURNS: True if device was unlocked, false otherwise
    private static func ProcessAndUnlockStandaloneDevice(part: TS_TargetPartInfo, sourcePos: Vector4, breachRadius: Float) -> Bool {
        let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(part).GetEntity() as GameObject;
        if !IsDefined(entity) {
            return false;
        }

        let device: ref<Device> = entity as Device;
        if !IsDefined(device) {
            return false;
        }

        let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
        if !IsDefined(devicePS) {
            return false;
        }

        let distance: Float = Vector4.Distance(sourcePos, entity.GetWorldPosition());
        if distance > breachRadius {
            return false;
        }

        DeviceUnlockUtils.UnlockStandaloneDevice(devicePS);
        return true;
    }

    // Check if device is valid standalone device (no unlock, used for counting)
    // RETURNS: True if device is valid standalone device, false otherwise
    private static func IsValidStandaloneDevice(part: TS_TargetPartInfo, sourcePos: Vector4, breachRadius: Float) -> Bool {
        let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(part).GetEntity() as GameObject;
        if !IsDefined(entity) {
            return false;
        }

        let device: ref<Device> = entity as Device;
        if !IsDefined(device) {
            return false;
        }

        let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
        if !IsDefined(devicePS) {
            return false;
        }

        let distance: Float = Vector4.Distance(sourcePos, entity.GetWorldPosition());
        if distance > breachRadius {
            return false;
        }

        let sharedPS: ref<SharedGameplayPS> = devicePS;
        if !IsDefined(sharedPS) {
            return false;
        }

        let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
        if ArraySize(apControllers) > 0 {
            return false;  // Network-connected device, skip
        }

        return true;
    }

    // Unlock standalone device by type (reduce nesting)
    private static func UnlockStandaloneDevice(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
        let sharedPS: ref<SharedGameplayPS> = devicePS;
        if !IsDefined(sharedPS) {
            return;
        }

        let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
        if ArraySize(apControllers) > 0 {
            return;  // Network-connected device, skip
        }

        // Prepare timestamp recording
        let gameInstance: GameInstance = devicePS.GetGameInstance();
        let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(gameInstance);

        // Unlock based on device type - set timestamp directly
        if DaemonFilterUtils.IsCamera(devicePS) {
            sharedPS.m_betterNetrunningUnlockTimestampCameras = currentTime;
        } else if DaemonFilterUtils.IsTurret(devicePS) {
            sharedPS.m_betterNetrunningUnlockTimestampTurrets = currentTime;
        } else {
            sharedPS.m_betterNetrunningUnlockTimestampBasic = currentTime;
        }
    }

    // Process and unlock vehicle (2-level nesting max)
    private static func ProcessAndUnlockVehicle(
        part: TS_TargetPartInfo,
        sourcePos: Vector4,
        breachRadius: Float,
        gameInstance: GameInstance
    ) -> VehicleProcessResult {
        let result: VehicleProcessResult;
        result.vehicleFound = false;
        result.unlocked = false;

        let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(part).GetEntity() as GameObject;
        if !IsDefined(entity) {
            return result;
        }

        let vehicle: ref<VehicleObject> = entity as VehicleObject;
        if !IsDefined(vehicle) {
            return result;
        }

        result.vehicleFound = true;
        result.unlocked = DeviceUnlockUtils.TryUnlockVehicle(vehicle, sourcePos, breachRadius, gameInstance);
        return result;
    }

    // Check if vehicle is valid (no unlock, used for counting)
    // RETURNS: True if vehicle is valid and within range, false otherwise
    private static func IsValidVehicle(part: TS_TargetPartInfo, sourcePos: Vector4, breachRadius: Float) -> Bool {
        let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(part).GetEntity() as GameObject;
        if !IsDefined(entity) {
            return false;
        }

        let vehicle: ref<VehicleObject> = entity as VehicleObject;
        if !IsDefined(vehicle) {
            return false;
        }

        let vehPS: ref<VehicleComponentPS> = vehicle.GetVehiclePS();
        if !IsDefined(vehPS) {
            return false;
        }

        let entityPos: Vector4 = vehicle.GetWorldPosition();
        let distance: Float = Vector4.Distance(sourcePos, entityPos);

        if distance > breachRadius {
            return false;
        }

        return true;
    }

    // Attempt to unlock vehicle if within range
    private static func TryUnlockVehicle(
        vehicle: ref<VehicleObject>,
        sourcePos: Vector4,
        breachRadius: Float,
        gameInstance: GameInstance
    ) -> Bool {
        let vehPS: ref<VehicleComponentPS> = vehicle.GetVehiclePS();
        if !IsDefined(vehPS) {
            BNError("DeviceUnlockUtils", "VehiclePS not defined for vehicle");
            return false;
        }

        let entityPos: Vector4 = vehicle.GetWorldPosition();
        let distance: Float = Vector4.Distance(sourcePos, entityPos);

        if distance > breachRadius {
            return false;
        }

        let vehSharedPS: ref<SharedGameplayPS> = vehPS;
        if !IsDefined(vehSharedPS) {
            BNError("DeviceUnlockUtils", "vehSharedPS cast failed");
            return false;
        }

        let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(gameInstance);
        vehSharedPS.m_betterNetrunningUnlockTimestampBasic = currentTime;
        return true;
    }

    // ============================================================================
    // ApplyTimestampUnlock - Shared timestamp setting logic
    // ============================================================================
    /*
     * Apply timestamp-based unlock to device based on type and flags
     * ARCHITECTURE: Centralized timestamp setting logic shared across all breach types
     *
     * USAGE:
     * DeviceUnlockUtils.ApplyTimestampUnlock(device, gameInstance, true, false, false, false);
     *
     * NOTE: This eliminates duplicate timestamp setting logic in:
     * - DaemonUnlockStrategy.ApplyUnlockToDevice()
     * - BreachProcessing.UnlockDeviceWithStats()
     * - RemoteBreachHelpers.UnlockDeviceByType()
     */
    public static func ApplyTimestampUnlock(
        device: ref<DeviceComponentPS>,
        gameInstance: GameInstance,
        unlockBasic: Bool,
        unlockNPCs: Bool,
        unlockCameras: Bool,
        unlockTurrets: Bool
    ) -> Void {
        let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
        if !IsDefined(sharedPS) {
            return;
        }

        let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);
        let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(gameInstance);

        switch deviceType {
            case DeviceType.NPC:
                if unlockNPCs {
                    sharedPS.m_betterNetrunningUnlockTimestampNPCs = currentTime;
                }
                break;
            case DeviceType.Camera:
                if unlockCameras {
                    sharedPS.m_betterNetrunningUnlockTimestampCameras = currentTime;
                }
                break;
            case DeviceType.Turret:
                if unlockTurrets {
                    sharedPS.m_betterNetrunningUnlockTimestampTurrets = currentTime;
                }
                break;
            default: // DeviceType.Basic
                if unlockBasic {
                    sharedPS.m_betterNetrunningUnlockTimestampBasic = currentTime;
                }
                break;
        }
    }

    // ============================================================================
    // CollectNetworkNPCsFromAccessPoint - Network NPC Collection via GetPuppets()
    // ============================================================================
    /*
     * Collect network-connected NPCs within radius using vanilla's GetPuppets() method
     *
     * PURPOSE:
     * Retrieve NPCs from AccessPoint's network graph (efficient, uses existing device tree)
     *
     * FUNCTIONALITY:
     * - Calls AccessPointControllerPS.GetPuppets() to get all PuppetDeviceLinkPS
     * - Validates connection state via IsConnected() check
     * - Filters by distance (50m radius check from breach origin)
     * - Tracks PersistentID for duplicate detection
     *
     * ARCHITECTURE:
     * Uses vanilla's network graph traversal (GetAllDescendants + type cast)
     * Avoids TargetingSystem overhead for network NPCs
     *
     * RATIONALE:
     * Leverages vanilla's optimized network tracking instead of TargetingSystem scans
     * Reduces performance cost for network-connected NPCs (guards, gang members)
     *
     * @param accessPoint - AccessPoint containing network NPCs
     * @param origin - Breach position (center of radius check)
     * @param radius - Maximum distance in meters (50m default)
     * @param processedIDs - Output array of PersistentIDs (for duplicate detection)
     * @return Array of PuppetDeviceLinkPS within radius (network NPCs only)
     */
    private static func CollectNetworkNPCsFromAccessPoint(
        accessPoint: ref<AccessPointControllerPS>,
        origin: Vector4,
        radius: Float,
        out processedIDs: array<PersistentID>
    ) -> array<ref<PuppetDeviceLinkPS>> {
        let result: array<ref<PuppetDeviceLinkPS>>;

        // Guard: Null AccessPoint check
        if !IsDefined(accessPoint) {
            return result;
        }

        // Get all network-connected NPCs via vanilla's GetPuppets()
        let puppets: array<ref<PuppetDeviceLinkPS>> = accessPoint.GetPuppets();

        let radiusSq: Float = radius * radius;
        let i: Int32 = 0;
        while i < ArraySize(puppets) {
            let puppetLink: ref<PuppetDeviceLinkPS> = puppets[i];

            // Validate connection state (vanilla pattern from AcquirePuppetDeviceLink)
            if IsDefined(puppetLink) && puppetLink.IsConnected() {
                // Get GameObject entity
                let npcObject: wref<GameObject> = puppetLink.GetOwnerEntityWeak() as GameObject;
                if IsDefined(npcObject) && npcObject.IsActive() {
                    // Distance check (squared distance to avoid sqrt)
                    let npcPos: Vector4 = npcObject.GetWorldPosition();
                    let distSq: Float = Vector4.DistanceSquared2D(origin, npcPos);
                    if distSq <= radiusSq {
                        // Add to results and track PersistentID
                        ArrayPush(result, puppetLink);
                        ArrayPush(processedIDs, puppetLink.GetID());
                    }
                }
            }

            i += 1;
        }

        return result;
    }

    // ============================================================================
    // CollectStandaloneNPCsInRadius - Standalone NPC Collection via TargetingSystem
    // ============================================================================
    /*
     * Collect standalone NPCs (no DeviceLink) within radius using TargetingSystem
     *
     * PURPOSE:
     * Retrieve NPCs without network connections (civilians, isolated entities)
     *
     * FUNCTIONALITY:
     * - Uses TargetingSystem.GetTargetParts() for Puppet entities
     * - Excludes NPCs in processedIDs (already handled via GetPuppets)
     * - Validates no DeviceLink exists (defensive duplicate check)
     * - Filters by distance (50m radius check)
     *
     * ARCHITECTURE:
     * Inline TargetingSystem setup (query configuration for Puppet search)
     * Duplicate detection via PersistentID array check
     *
     * RATIONALE:
     * TargetingSystem required for NPCs without network connections
     * Excludes network NPCs to prevent double-counting
     *
     * @param origin - Breach position (center of radius check)
     * @param radius - Maximum distance in meters
     * @param gameInstance - Game instance for TargetingSystem access
     * @param excludeIDs - PersistentIDs to skip (network NPCs)
     * @return Array of ScriptedPuppet (standalone NPCs only)
     */
    private static func CollectStandaloneNPCsInRadius(
        origin: Vector4,
        radius: Float,
        gameInstance: GameInstance,
        excludeIDs: array<PersistentID>
    ) -> array<ref<ScriptedPuppet>> {
        let result: array<ref<ScriptedPuppet>>;

        // Setup TargetingSystem query (reuse existing logic)
        let player: wref<PlayerPuppet> = GetPlayer(gameInstance);
        if !IsDefined(player) {
            return result;
        }

        let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);
        if !IsDefined(targetingSystem) {
            return result;
        }

        let query: TargetSearchQuery;
        query.searchFilter = TSF_And(TSF_All(TSFMV.Obj_Puppet), TSF_Not(TSFMV.Obj_Player));
        query.testedSet = TargetingSet.Complete;
        query.maxDistance = radius * 2.0;
        query.filterObjectByDistance = true;
        query.includeSecondaryTargets = false;
        query.ignoreInstigator = true;

        let parts: array<TS_TargetPartInfo>;
        targetingSystem.GetTargetParts(player, query, parts);

        let radiusSq: Float = radius * radius;
        let i: Int32 = 0;
        while i < ArraySize(parts) {
            let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(parts[i]).GetEntity() as GameObject;
            if IsDefined(entity) {
                let puppet: ref<ScriptedPuppet> = entity as ScriptedPuppet;
                if IsDefined(puppet) {
                    // Duplicate detection: Skip if already processed via GetPuppets
                    let npcID: PersistentID = puppet.GetPersistentID();
                    if !ArrayContains(excludeIDs, npcID) {
                        // Defensive check: Verify no DeviceLink (should never have DeviceLink at this point)
                        let npcPS: ref<ScriptedPuppetPS> = puppet.GetPS();
                        if IsDefined(npcPS) {
                            let deviceLink: ref<PuppetDeviceLinkPS> = npcPS.GetDeviceLink();
                            if !IsDefined(deviceLink) {
                                // Distance check
                                let npcPos: Vector4 = puppet.GetWorldPosition();
                                let distSq: Float = Vector4.DistanceSquared2D(origin, npcPos);
                                if distSq <= radiusSq {
                                    // Add to results (standalone NPC confirmed)
                                    ArrayPush(result, puppet);
                                }
                            } else {
                                BNWarn("CollectStandaloneNPCsInRadius", "Found network NPC in standalone collection - duplicate detection failed");
                            }
                        }
                    }
                }
            }

            i += 1;
        }

        return result;
    }

    // ============================================================================
    // RemoteBreach Position Recording & Network Unlock
    // ============================================================================
    // Migrated from RemoteBreachHelpers.reds (RemoteBreachUtils class)
    // Purpose: Support RemoteBreach radial unlock functionality
    // ============================================================================

    /*
     * Records breach position for radial unlock tracking
     * Overload for ScriptableDeviceComponentPS
     */
    public static func RecordBreachPosition(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Void {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return;
        }

        let devicePos: Vector4 = deviceEntity.GetWorldPosition();
        RecordAccessPointBreachByPosition(devicePos, gameInstance);
    }

    /*
     * Records breach position for radial unlock tracking
     * Overload for VehicleComponentPS
     */
    public static func RecordBreachPosition(vehiclePS: ref<VehicleComponentPS>, gameInstance: GameInstance) -> Void {
        let vehicleEntity: wref<GameObject> = vehiclePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(vehicleEntity) {
            return;
        }

        let vehiclePos: Vector4 = vehicleEntity.GetWorldPosition();
        RecordAccessPointBreachByPosition(vehiclePos, gameInstance);
    }

    /*
     * Unlocks nearby network-connected devices within radius
     * Shared logic for Device and Vehicle RemoteBreach
     *
     * @param sourceEntity - Entity initiating unlock (typically player)
     * @param gameInstance - Game instance
     * @param unlockBasic - Unlock basic devices
     * @param unlockNPCs - Unlock NPC quickhacks
     * @param unlockCameras - Unlock camera devices
     * @param unlockTurrets - Unlock turret devices
     * @param logPrefix - Prefix for debug logging
     * @return RadialUnlockResult with device counts and unlock statistics
     */
    public static func UnlockNearbyNetworkDevices(
        sourceEntity: wref<GameObject>,
        gameInstance: GameInstance,
        unlockBasic: Bool,
        unlockNPCs: Bool,
        unlockCameras: Bool,
        unlockTurrets: Bool,
        logPrefix: String
    ) -> RadialUnlockResult {
        let result: RadialUnlockResult;

        if !IsDefined(sourceEntity) {
            return result;
        }

        let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupDeviceTargeting(sourceEntity, gameInstance);
        if !targetingSetup.isValid {
            return result;
        }

        let parts: array<TS_TargetPartInfo>;
        targetingSetup.targetingSystem.GetTargetParts(targetingSetup.player, targetingSetup.query, parts);

        let unlockFlags: UnlockFlags;
        unlockFlags.unlockBasic = unlockBasic;
        unlockFlags.unlockNPCs = unlockNPCs;
        unlockFlags.unlockCameras = unlockCameras;
        unlockFlags.unlockTurrets = unlockTurrets;

        let i: Int32 = 0;
        while i < ArraySize(parts) {
            let deviceResult: RadialUnlockResult = DeviceUnlockUtils.ProcessNetworkDevice(parts[i], targetingSetup, unlockFlags);
            result.basicCount += deviceResult.basicCount;
            result.cameraCount += deviceResult.cameraCount;
            result.turretCount += deviceResult.turretCount;
            result.npcCount += deviceResult.npcCount;
            result.basicUnlocked += deviceResult.basicUnlocked;
            result.cameraUnlocked += deviceResult.cameraUnlocked;
            result.turretUnlocked += deviceResult.turretUnlocked;
            result.npcUnlocked += deviceResult.npcUnlocked;
            i += 1;
        }

        return result;
    }

    /*
     * Setup targeting for device search (internal helper)
     * Configures TargetingSystem query for network device detection
     */
    private static func SetupDeviceTargeting(sourceEntity: wref<GameObject>, gameInstance: GameInstance) -> TargetingSetup {
        let setup: TargetingSetup;
        setup.isValid = false;
        setup.breachRadius = GetRadialBreachRange(gameInstance);
        setup.sourcePos = sourceEntity.GetWorldPosition();

        setup.player = GetPlayer(gameInstance);
        if !IsDefined(setup.player) {
            return setup;
        }

        setup.targetingSystem = GameInstance.GetTargetingSystem(gameInstance);
        if !IsDefined(setup.targetingSystem) {
            return setup;
        }

        setup.query.searchFilter = TSF_All(TSFMV.Obj_Device);
        setup.query.testedSet = TargetingSet.Complete;
        setup.query.maxDistance = setup.breachRadius * 2.0;
        setup.query.filterObjectByDistance = true;
        setup.query.includeSecondaryTargets = false;
        setup.query.ignoreInstigator = true;

        setup.isValid = true;
        return setup;
    }

    /*
     * Process network-connected device (reduce nesting in UnlockNearbyNetworkDevices)
     * Returns device type counts and unlock success
     */
    private static func ProcessNetworkDevice(part: TS_TargetPartInfo, setup: TargetingSetup, flags: UnlockFlags) -> RadialUnlockResult {
        let result: RadialUnlockResult;

        let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(part).GetEntity() as GameObject;
        if !IsDefined(entity) {
            return result;
        }

        let device: ref<Device> = entity as Device;
        if !IsDefined(device) {
            return result;
        }

        let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
        if !IsDefined(devicePS) {
            return result;
        }

        let sharedPS: ref<SharedGameplayPS> = devicePS;
        if !IsDefined(sharedPS) {
            return result;
        }

        // Check if network-connected
        let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
        if ArraySize(apControllers) == 0 {
            return result;  // Not network-connected
        }

        // Check distance
        let distance: Float = Vector4.Distance(setup.sourcePos, entity.GetWorldPosition());
        if distance > setup.breachRadius {
            return result;
        }

        // Determine device type and update counts
        let isCamera: Bool = DeviceTypeUtils.IsCameraDevice(devicePS);
        let isTurret: Bool = DeviceTypeUtils.IsTurretDevice(devicePS);
        let isNPC: Bool = DeviceTypeUtils.IsNPCDevice(devicePS);

        if isCamera {
            result.cameraCount = 1;
        } else if isTurret {
            result.turretCount = 1;
        } else if isNPC {
            result.npcCount = 1;
        } else {
            result.basicCount = 1;
        }

        // Unlock based on device type
        let unlocked: Bool = DeviceUnlockUtils.UnlockDeviceByType(devicePS, flags);

        // Update unlocked counts if successful
        if unlocked {
            if isCamera {
                result.cameraUnlocked = 1;
            } else if isTurret {
                result.turretUnlocked = 1;
            } else if isNPC {
                result.npcUnlocked = 1;
            } else {
                result.basicUnlocked = 1;
            }
        }

        return result;
    }

    /*
     * Unlock device by type with flags (reduce nesting)
     * Returns true if device was unlocked, false if skipped
     */
    private static func UnlockDeviceByType(devicePS: ref<ScriptableDeviceComponentPS>, flags: UnlockFlags) -> Bool {
        let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(devicePS);

        // Check if device should be unlocked based on flags
        let unlockFlags: BreachUnlockFlags;
        unlockFlags.unlockBasic = flags.unlockBasic;
        unlockFlags.unlockNPCs = flags.unlockNPCs;
        unlockFlags.unlockCameras = flags.unlockCameras;
        unlockFlags.unlockTurrets = flags.unlockTurrets;

        if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
            return false;  // Device type not allowed by flags
        }

        // Use centralized timestamp unlock logic from DeviceUnlockUtils
        DeviceUnlockUtils.ApplyTimestampUnlock(
            devicePS,
            devicePS.GetGameInstance(),
            flags.unlockBasic,
            flags.unlockNPCs,
            flags.unlockCameras,
            flags.unlockTurrets
        );

        return true;  // Successfully unlocked
    }

    // ==================== Time Utilities ====================
    // (Migrated from TimeUtils.reds - single-method file consolidation)

    // Get current game timestamp
    // Replaces scattered "let timeSystem: ref<TimeSystem> = GameInstance.GetTimeSystem(gi); timeSystem.GetGameTimeStamp()"
    public static func GetCurrentTimestamp(gameInstance: GameInstance) -> Float {
        let timeSystem: ref<TimeSystem> = GameInstance.GetTimeSystem(gameInstance);
        return timeSystem.GetGameTimeStamp();
    }

    // Set unlock timestamp for device based on device type
    // Centralized logic to avoid switch statement duplication
    public static func SetDeviceUnlockTimestamp(
        sharedPS: ref<SharedGameplayPS>,
        deviceType: DeviceType,
        timestamp: Float
    ) -> Void {
        switch deviceType {
            case DeviceType.NPC:
                sharedPS.m_betterNetrunningUnlockTimestampNPCs = timestamp;
                break;
            case DeviceType.Camera:
                sharedPS.m_betterNetrunningUnlockTimestampCameras = timestamp;
                break;
            case DeviceType.Turret:
                sharedPS.m_betterNetrunningUnlockTimestampTurrets = timestamp;
                break;
            default: // DeviceType.Basic
                sharedPS.m_betterNetrunningUnlockTimestampBasic = timestamp;
                break;
        }
    }

}
