// -----------------------------------------------------------------------------
// Device Unlock Utilities (Shared by AP Breach & RemoteBreach)
// -----------------------------------------------------------------------------
// Provides radius-based device/vehicle/NPC unlock logic shared across breach types.
//
// DESIGN RATIONALE:
// - Single Responsibility: Targeting system radius search
// - DRY Principle: Eliminates duplicate unlock logic between AP Breach and RemoteBreach
// - Module Independence: Both breach types can use without coupling to RemoteBreach
//
// ARCHITECTURE:
// This module extracts common unlock logic previously in RemoteBreachUtils,
// making it available to both AccessPoint Breach and RemoteBreach implementations.
//
// USAGE:
// DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
// DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);
// DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);
// -----------------------------------------------------------------------------

module BetterNetrunning.Core

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

public abstract class DeviceUnlockUtils {
    // ============================================================================
    // UnlockNPCsInRadius - Radial NPC Unlock
    // ============================================================================
    /*
     * Unlock NPCs in 50m radius via TargetingSystem
     * ARCHITECTURE: Sets m_quickHacksExposed = true for NPCs in range
     */
    public static func UnlockNPCsInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Void {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return;
        }

        let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupNPCTargeting(deviceEntity, gameInstance);
        if !targetingSetup.isValid {
            return;
        }

        let parts: array<TS_TargetPartInfo>;
        targetingSetup.targetingSystem.GetTargetParts(targetingSetup.player, targetingSetup.query, parts);

        let idx: Int32 = 0;
        while idx < ArraySize(parts) {
            DeviceUnlockUtils.ProcessAndUnlockNPC(parts[idx], targetingSetup.sourcePos, targetingSetup.breachRadius);
            idx += 1;
        }
    }

    // ============================================================================
    // UnlockDevicesInRadius - Radial Standalone Device Unlock
    // ============================================================================
    /*
     * Unlock standalone devices in 50m radius via TargetingSystem
     * ARCHITECTURE: Uses TargetingSystem to find devices without network connections
     */
    public static func UnlockDevicesInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Void {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return;
        }

        let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupDeviceTargeting(deviceEntity, gameInstance);
        if !targetingSetup.isValid {
            return;
        }

        let parts: array<TS_TargetPartInfo>;
        targetingSetup.targetingSystem.GetTargetParts(targetingSetup.player, targetingSetup.query, parts);

        let idx: Int32 = 0;
        while idx < ArraySize(parts) {
            DeviceUnlockUtils.ProcessAndUnlockStandaloneDevice(parts[idx], targetingSetup.sourcePos, targetingSetup.breachRadius);
            idx += 1;
        }
    }

    // ============================================================================
    // UnlockVehiclesInRadius - Radial Vehicle Unlock
    // ============================================================================
    /*
     * Unlock vehicles in 50m radius via TargetingSystem
     * ARCHITECTURE: Uses TargetingSystem to find VehicleObject entities
     */
    public static func UnlockVehiclesInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Void {
        let targetingSetup: TargetingSetup = DeviceUnlockUtils.SetupVehicleTargeting(devicePS, gameInstance);
        if !targetingSetup.isValid {
            return;
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
    }

    // ============================================================================
    // Private Helper Methods - Targeting Setup
    // ============================================================================

    // Setup targeting for NPC search (reduce code duplication)
    private static func SetupNPCTargeting(sourceEntity: wref<GameObject>, gameInstance: GameInstance) -> TargetingSetup {
        let setup: TargetingSetup;
        setup.isValid = false;
        setup.breachRadius = DeviceTypeUtils.GetRadialBreachRange(gameInstance);
        setup.sourcePos = sourceEntity.GetWorldPosition();

        setup.player = GetPlayer(gameInstance);
        if !IsDefined(setup.player) {
            return setup;
        }

        setup.targetingSystem = GameInstance.GetTargetingSystem(gameInstance);
        if !IsDefined(setup.targetingSystem) {
            return setup;
        }

        setup.query.searchFilter = TSF_And(TSF_All(TSFMV.Obj_Puppet), TSF_Not(TSFMV.Obj_Player));
        setup.query.testedSet = TargetingSet.Complete;
        setup.query.maxDistance = setup.breachRadius * 2.0;
        setup.query.filterObjectByDistance = true;
        setup.query.includeSecondaryTargets = false;
        setup.query.ignoreInstigator = true;

        setup.isValid = true;
        return setup;
    }

    // Setup targeting for Device search (reduce code duplication)
    private static func SetupDeviceTargeting(sourceEntity: wref<GameObject>, gameInstance: GameInstance) -> TargetingSetup {
        let setup: TargetingSetup;
        setup.isValid = false;
        setup.breachRadius = DeviceTypeUtils.GetRadialBreachRange(gameInstance);
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
        setup.breachRadius = DeviceTypeUtils.GetRadialBreachRange(gameInstance);

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

    // Process and unlock NPC (reduce nesting in UnlockNPCsInRange)
    private static func ProcessAndUnlockNPC(part: TS_TargetPartInfo, sourcePos: Vector4, breachRadius: Float) -> Void {
        let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(part).GetEntity() as GameObject;
        if !IsDefined(entity) {
            return;
        }

        let puppet: ref<NPCPuppet> = entity as NPCPuppet;
        if !IsDefined(puppet) {
            return;
        }

        let distance: Float = Vector4.Distance(sourcePos, puppet.GetWorldPosition());
        if distance > breachRadius {
            return;
        }

        let npcPS: ref<ScriptedPuppetPS> = puppet.GetPS();
        if IsDefined(npcPS) {
            npcPS.m_quickHacksExposed = true;
        }
    }

    // Process and unlock standalone device (reduce nesting in UnlockDevicesInRadius)
    private static func ProcessAndUnlockStandaloneDevice(part: TS_TargetPartInfo, sourcePos: Vector4, breachRadius: Float) -> Void {
        let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(part).GetEntity() as GameObject;
        if !IsDefined(entity) {
            return;
        }

        let device: ref<Device> = entity as Device;
        if !IsDefined(device) {
            return;
        }

        let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
        if !IsDefined(devicePS) {
            return;
        }

        let distance: Float = Vector4.Distance(sourcePos, entity.GetWorldPosition());
        if distance > breachRadius {
            return;
        }

        DeviceUnlockUtils.UnlockStandaloneDevice(devicePS);
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
        let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);

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

        let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
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
        let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);

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
}
