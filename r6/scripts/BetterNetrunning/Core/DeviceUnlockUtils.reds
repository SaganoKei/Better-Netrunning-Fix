// -----------------------------------------------------------------------------
// Device Unlock Utilities (Shared by AP Breach & RemoteBreach)
// -----------------------------------------------------------------------------
//
// PURPOSE:
//   Provides radius-based device/vehicle/NPC unlock logic shared across breach types
//
// FUNCTIONALITY:
//   - Radial unlock: Processes entities within breach radius
//   - NPC unlock: Handles standalone NPC targeting and unlock
//   - Vehicle unlock: Distance-based vehicle unlock logic
//   - Entity processing: Template Method Pattern for unified unlock flow
//
// ARCHITECTURE:
//   - Single Responsibility: Targeting system radius search
//   - DRY Principle: Shared unlock logic for AP Breach and RemoteBreach
//   - Module Independence: Both breach types can use without coupling
//   - Template Method Pattern: EntityUnlockProcessor base with 3 derived processors
//

module BetterNetrunning.Core

import BetterNetrunningConfig.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Integration.*
import BetterNetrunning.Utils.*

// Helper struct for targeting setup
public struct TargetingSetup {
    public let isValid: Bool;
    public let breachRadius: Float;
    public let sourcePos: Vector4;
    public let originType: String;           // "NPC" or "Device"
    public let player: wref<PlayerPuppet>;
    public let targetingSystem: ref<TargetingSystem>;
    public let query: TargetSearchQuery;
}

// Helper struct for vehicle processing result
public struct VehicleProcessResult {
    public let vehicleFound: Bool;
    public let unlocked: Bool;
}

/*
 * Network classification types for entities
 *
 * FUNCTIONALITY:
 * - BreachedNetwork: Already processed via AccessPoint network traversal
 * - CrossNetwork: Connected to different network (GetAccessPoints() > 0)
 * - PureStandalone: No network connection (always unlock)
 */
enum NetworkClassification {
    BreachedNetwork = 0,
    CrossNetwork = 1,
    PureStandalone = 2
}

// ============================================================================
// Template Method Pattern - Entity Unlock Processor
// ============================================================================

/*
 * Abstract base class for entity unlock processing using Template Method pattern
 *
 * PURPOSE:
 * - Provides common processing flow for Device/Vehicle/NPC processors
 * - Centralizes common logic (entity extraction, network classification, counting)
 * - Enables easy addition of new entity types via inheritance
 *
 * ARCHITECTURE:
 * - ProcessEntity(): Template method defining common processing flow
 * - Hook methods: CastToSpecificType(), ClassifyNetwork(), UnlockEntity()
 * - Stats tracking: Standalone/CrossNetwork counts and unlock success counts
 */
public abstract class EntityUnlockProcessor {
    // Context parameters (set via Initialize())
    protected let m_origin: Vector4;
    protected let m_radiusSq: Float;
    protected let m_breachedAPID: PersistentID;
    protected let m_gameInstance: GameInstance;
    protected let m_unlockFlags: BreachUnlockFlags;

    // Statistics (accumulated during processing)
    protected let m_standaloneCount: Int32;
    protected let m_crossNetworkCount: Int32;
    protected let m_standaloneUnlocked: Int32;
    protected let m_crossNetworkUnlocked: Int32;

    /*
     * Initializes processor with context parameters
     *
     * @param origin Breach origin position
     * @param radiusSq Squared breach radius (for DistanceSquared2D optimization)
     * @param breachedAPID PersistentID of breached AccessPoint
     * @param gameInstance Game instance
     * @param unlockFlags Unlock configuration flags
     */
    public func Initialize(
        origin: Vector4,
        radiusSq: Float,
        breachedAPID: PersistentID,
        gameInstance: GameInstance,
        unlockFlags: BreachUnlockFlags
    ) -> Void {
        this.m_origin = origin;
        this.m_radiusSq = radiusSq;
        this.m_breachedAPID = breachedAPID;
        this.m_gameInstance = gameInstance;
        this.m_unlockFlags = unlockFlags;

        this.m_standaloneCount = 0;
        this.m_crossNetworkCount = 0;
        this.m_standaloneUnlocked = 0;
        this.m_crossNetworkUnlocked = 0;
    }

    /*
     * Template Method: Processes single entity with common flow
     *
     * ARCHITECTURE: Defines processing flow with hook methods for customization
     *
     * FLOW:
     * 1. ExtractAndValidateEntity() - Entity extraction + distance check
     * 2. CastToSpecificType() - Entity-specific type casting
     * 3. ClassifyNetwork() - Network classification
     * 4. Count and unlock based on classification
     */
    public func ProcessEntity(part: TS_TargetPartInfo) -> Void {
        // Guard: Extract entity and validate distance
        let entity: wref<GameObject>;
        if !DeviceUnlockUtils.ExtractAndValidateEntity(
            part, this.m_origin, this.m_radiusSq, entity
        ) { return; }

        // Guard: Cast to entity-specific type
        if !this.CastToSpecificType(entity) { return; }

        // Classify network connectivity
        let classification: NetworkClassification = this.ClassifyNetwork();

        // Process based on classification
        switch classification {
            case NetworkClassification.BreachedNetwork:
                return; // Skip (already processed)
            case NetworkClassification.CrossNetwork:
                this.m_crossNetworkCount += 1;
                if this.ShouldUnlockCrossNetwork() {
                    if this.UnlockEntity() {
                        this.m_crossNetworkUnlocked += 1;
                    }
                }
                break;
            case NetworkClassification.PureStandalone:
                this.m_standaloneCount += 1;
                if this.ShouldUnlockStandalone() {
                    if this.UnlockEntity() {
                        this.m_standaloneUnlocked += 1;
                    }
                }
                break;
        }
    }

    /*
     * Hook: Casts GameObject to entity-specific type
     *
     * @param entity Generic GameObject from TargetingSystem
     * @return True if cast succeeded, false otherwise
     */
    protected func CastToSpecificType(entity: wref<GameObject>) -> Bool;

    /*
     * Hook: Classifies entity's network connectivity
     *
     * @return NetworkClassification enum value
     */
    protected func ClassifyNetwork() -> NetworkClassification;

    /*
     * Hook: Unlocks entity (entity-specific unlock logic)
     *
     * @return True if unlock succeeded, false otherwise
     */
    protected func UnlockEntity() -> Bool;

    /*
     * Hook with default: Determines if cross-network entities should be unlocked
     *
     * @return True if should unlock, false otherwise
     */
    protected func ShouldUnlockCrossNetwork() -> Bool {
        return this.m_unlockFlags.unlockBasic;
    }

    /*
     * Hook with default: Determines if standalone entities should be unlocked
     *
     * @return True if should unlock, false otherwise
     */
    protected func ShouldUnlockStandalone() -> Bool {
        return this.m_unlockFlags.unlockBasic;
    }

    // Statistics getters
    public func GetStandaloneCount() -> Int32 { return this.m_standaloneCount; }
    public func GetCrossNetworkCount() -> Int32 { return this.m_crossNetworkCount; }
    public func GetStandaloneUnlocked() -> Int32 { return this.m_standaloneUnlocked; }
    public func GetCrossNetworkUnlocked() -> Int32 { return this.m_crossNetworkUnlocked; }
}

/*
 * Device-specific entity unlock processor
 *
 * PURPOSE:
 * - Implements Device-specific hook methods for EntityUnlockProcessor
 * - Handles Device type casting, network classification, and unlock
 *
 * ARCHITECTURE:
 * - CastToSpecificType(): Casts to Device → DevicePS → SharedGameplayPS
 * - ClassifyNetwork(): Uses ClassifyDeviceNetwork() helper
 * - UnlockEntity(): Calls UnlockDeviceInRadius()
 */
public class DeviceUnlockProcessor extends EntityUnlockProcessor {
    // Device-specific references (cached during CastToSpecificType)
    private let m_device: ref<Device>;
    private let m_devicePS: ref<ScriptableDeviceComponentPS>;

    /*
     * Casts GameObject to Device and extracts power states
     *
     * @param entity Generic GameObject from TargetingSystem
     * @return True if all casts succeeded, false otherwise
     */
    protected func CastToSpecificType(entity: wref<GameObject>) -> Bool {
        // Guard: Cast to Device
        this.m_device = entity as Device;
        if !IsDefined(this.m_device) { return false; }

        // Guard: Get DevicePS
        this.m_devicePS = this.m_device.GetDevicePS();
        return IsDefined(this.m_devicePS);
    }

    /*
     * Classifies device's network connectivity
     *
     * @return NetworkClassification enum value
     */
    protected func ClassifyNetwork() -> NetworkClassification {
        return DeviceUnlockUtils.ClassifyDeviceNetwork(
            this.m_devicePS,
            this.m_breachedAPID
        );
    }

    /*
     * Unlocks device using existing unlock function
     *
     * @return True if unlock succeeded, false otherwise
     */
    protected func UnlockEntity() -> Bool {
        return DeviceUnlockUtils.UnlockDeviceInRadius(
            this.m_devicePS,
            this.m_unlockFlags,
            this.m_gameInstance
        );
    }
}

/*
 * Vehicle-specific entity unlock processor
 *
 * PURPOSE:
 * - Implements Vehicle-specific hook methods for EntityUnlockProcessor
 * - Handles Vehicle type casting, network classification, and unlock
 *
 * ARCHITECTURE:
 * - CastToSpecificType(): Casts to VehicleObject
 * - ClassifyNetwork(): Always returns PureStandalone (vehicles have no network)
 * - UnlockEntity(): Calls TryUnlockVehicle()
 */
public class VehicleUnlockProcessor extends EntityUnlockProcessor {
    // Vehicle-specific reference (cached during CastToSpecificType)
    private let m_vehicle: ref<VehicleObject>;

    /*
     * Casts GameObject to VehicleObject
     *
     * @param entity Generic GameObject from TargetingSystem
     * @return True if cast succeeded, false otherwise
     */
    protected func CastToSpecificType(entity: wref<GameObject>) -> Bool {
        this.m_vehicle = entity as VehicleObject;
        return IsDefined(this.m_vehicle);
    }

    /*
     * Classifies vehicle's network connectivity
     *
     * @return Always NetworkClassification.PureStandalone
     */
    protected func ClassifyNetwork() -> NetworkClassification {
        // Vehicles have no network connection
        return NetworkClassification.PureStandalone;
    }

    /*
     * Unlocks vehicle using existing unlock function
     *
     * @return True if unlock succeeded, false otherwise
     */
    protected func UnlockEntity() -> Bool {
        return DeviceUnlockUtils.TryUnlockVehicle(
            this.m_vehicle,
            this.m_gameInstance
        );
    }
}

/*
 * NPC-specific entity unlock processor
 *
 * PURPOSE:
 * - Implements NPC-specific hook methods for EntityUnlockProcessor
 * - Handles ScriptedPuppet type casting, network classification, and unlock
 *
 * ARCHITECTURE:
 * - CastToSpecificType(): Casts to ScriptedPuppet, gets ScriptedPuppetPS
 * - ClassifyNetwork(): Uses ClassifyNPCNetwork() helper
 * - UnlockEntity(): Calls UnlockStandaloneNPC()
 */
public class NPCUnlockProcessor extends EntityUnlockProcessor {
    // NPC-specific references (cached during CastToSpecificType)
    private let m_puppet: ref<ScriptedPuppet>;
    private let m_npcPS: ref<ScriptedPuppetPS>;

    /*
     * Casts GameObject to ScriptedPuppet and extracts power state
     *
     * @param entity Generic GameObject from TargetingSystem
     * @return True if all casts succeeded, false otherwise
     */
    protected func CastToSpecificType(entity: wref<GameObject>) -> Bool {
        // Guard: Cast to ScriptedPuppet
        this.m_puppet = entity as ScriptedPuppet;
        if !IsDefined(this.m_puppet) { return false; }

        // Guard: Get ScriptedPuppetPS
        this.m_npcPS = this.m_puppet.GetPS();
        return IsDefined(this.m_npcPS);
    }

    /*
     * Classifies NPC's network connectivity
     *
     * @return NetworkClassification enum value
     */
    protected func ClassifyNetwork() -> NetworkClassification {
        return DeviceUnlockUtils.ClassifyNPCNetwork(
            this.m_puppet,
            this.m_breachedAPID,
            this.m_gameInstance
        );
    }

    /*
     * Unlocks NPC using existing unlock function
     *
     * @return True if unlock succeeded, false otherwise
     */
    protected func UnlockEntity() -> Bool {
        return DeviceUnlockUtils.UnlockStandaloneNPC(this.m_puppet);
    }

    /*
     * Hook override: Cross-network NPCs require RadialUnlockCrossNetwork setting
     *
     * @return True if should unlock, false otherwise
     */
    protected func ShouldUnlockCrossNetwork() -> Bool {
        return this.m_unlockFlags.unlockNPCs && BetterNetrunningSettings.RadialUnlockCrossNetwork();
    }

    /*
     * Hook override: Standalone NPCs always unlock when flag is set
     *
     * @return True if should unlock, false otherwise
     */
    protected func ShouldUnlockStandalone() -> Bool {
        return this.m_unlockFlags.unlockNPCs;
    }
}

public abstract class DeviceUnlockUtils {
    // ============================================================================
    // Public API - NPC Processing (Single-pass)
    // ============================================================================

    /*
     * Processes NPCs within radius with network classification and conditional unlock
     *
     * ARCHITECTURE: Template Method Pattern with NPCUnlockProcessor
     * - Uses TargetingSystem for all radius NPCs
     * - Classifies NPCs by network connectivity (Pure Standalone vs Cross-Network)
     * - Conditionally unlocks based on unlockFlags.unlockNPCs and RadialUnlockCrossNetwork setting
     *
     * @param devicePS Device initiating operation (typically AccessPointControllerPS)
     * @param breachedAPID PersistentID of breached AccessPoint for network classification
     * @param unlockFlags Flags indicating whether to unlock NPCs
     * @param npcPureStandaloneCount Output: Pure standalone NPCs (no DeviceLink)
     * @param npcCrossNetworkCount Output: Cross-network NPCs (has DeviceLink, other network)
     * @param npcPureStandaloneUnlocked Output: Pure standalone NPCs unlocked
     * @param npcCrossNetworkUnlocked Output: Cross-network NPCs unlocked
     * @param gameInstance Game instance for system access
     */
    public static func ProcessNPCsInRadius(
        devicePS: ref<ScriptableDeviceComponentPS>,
        breachedAPID: PersistentID,
        unlockFlags: BreachUnlockFlags,
        out npcPureStandaloneCount: Int32,
        out npcCrossNetworkCount: Int32,
        out npcPureStandaloneUnlocked: Int32,
        out npcCrossNetworkUnlocked: Int32,
        gameInstance: GameInstance
    ) -> Void {
        npcPureStandaloneCount = 0;
        npcCrossNetworkCount = 0;
        npcPureStandaloneUnlocked = 0;
        npcCrossNetworkUnlocked = 0;

        // Validate device entity
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return;
        }

        // Setup targeting parameters
        let origin: Vector4 = deviceEntity.GetWorldPosition();
        let radius: Float = GetRadialBreachRange(gameInstance);
        let radiusSq: Float = radius * radius;

        // Setup targeting
        let player: wref<PlayerPuppet> = GetPlayer(gameInstance);
        if !IsDefined(player) { return; }

        let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);
        if !IsDefined(targetingSystem) { return; }

        let query: TargetSearchQuery;
        query.searchFilter = TSF_And(TSF_All(TSFMV.Obj_Puppet), TSF_Not(TSFMV.Obj_Player));
        query.testedSet = TargetingSet.Complete;
        query.maxDistance = radius * 2.0;
        query.filterObjectByDistance = true;
        query.includeSecondaryTargets = false;
        query.ignoreInstigator = true;

        let parts: array<TS_TargetPartInfo>;
        targetingSystem.GetTargetParts(player, query, parts);

        // Create NPC processor
        let processor: ref<NPCUnlockProcessor> = new NPCUnlockProcessor();
        processor.Initialize(origin, radiusSq, breachedAPID, gameInstance, unlockFlags);

        // Process all NPCs with processor pattern
        let i: Int32 = ArraySize(parts) - 1;
        while i >= 0 {
            processor.ProcessEntity(parts[i]);
            i -= 1;
        }

        // Retrieve results
        npcPureStandaloneCount = processor.GetStandaloneCount();
        npcCrossNetworkCount = processor.GetCrossNetworkCount();
        npcPureStandaloneUnlocked = processor.GetStandaloneUnlocked();
        npcCrossNetworkUnlocked = processor.GetCrossNetworkUnlocked();
    }

    // ============================================================================
    // Private Helper Methods - Targeting Setup
    // ============================================================================

    /*
     * Setup targeting for Device search
     *
     * FUNCTIONALITY:
     * - Configures TargetingSystem query for device detection
     * - Uses NPC position as origin for unconscious NPC breach
     * - Uses device position as origin for other breach types
     *
     * @param sourceEntity Source entity (AccessPoint or operated device)
     * @param gameInstance Game instance
     * @return TargetingSetup Configuration for TargetingSystem query
     */
    public static func SetupDeviceTargeting(sourceEntity: wref<GameObject>, gameInstance: GameInstance) -> TargetingSetup {
        let setup: TargetingSetup;
        setup.isValid = false;
        setup.breachRadius = GetRadialBreachRange(gameInstance);

        // Determine origin position based on breach type
        let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gameInstance)
            .Get(GetAllBlackboardDefs().HackingMinigame);
        let breachEntity: wref<Entity> = FromVariant<wref<Entity>>(
            minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity)
        );
        let npcPuppet: wref<ScriptedPuppet> = breachEntity as ScriptedPuppet;

        if IsDefined(npcPuppet) {
            // Unconscious NPC breach: Use NPC position as origin
            setup.sourcePos = npcPuppet.GetWorldPosition();
            setup.originType = "NPC";
        } else {
            // Normal breach: Use device position as origin
            setup.sourcePos = sourceEntity.GetWorldPosition();
            setup.originType = "Device";
        }

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

    /*
     * Extracts entity from TargetingSystem part and validates distance
     *
     * @param part TS_TargetPartInfo from TargetingSystem query
     * @param sourcePos Origin position for distance calculation
     * @param breachRadius Maximum radius for entity inclusion (meters)
     * @param entity Output parameter - extracted GameObject (valid only if return is true)
     * @return True if entity is valid and within radius, false otherwise
     */
    private static func ExtractAndValidateEntity(
        part: TS_TargetPartInfo,
        sourcePos: Vector4,
        breachRadius: Float,
        out entity: wref<GameObject>
    ) -> Bool {
        // Guard: Extract entity from TargetingSystem part
        entity = TS_TargetPartInfo.GetComponent(part).GetEntity() as GameObject;
        if !IsDefined(entity) {
            return false;
        }

        // Guard: Validate distance (3D distance check using Vector4.Distance)
        let targetPos: Vector4 = entity.GetWorldPosition();
        let distance: Float = Vector4.Distance(sourcePos, targetPos);
        if distance > breachRadius {
            return false;
        }

        return true;
    }

    /*
     * Classifies device by network connectivity
     *
     * FUNCTIONALITY:
     * - BreachedNetwork: Connected to breached AccessPoint (already processed)
     * - CrossNetwork: Connected to different network (GetAccessPoints() > 0)
     * - PureStandalone: No network connection (GetAccessPoints() == 0)
     *
     * @param sharedPS Device's SharedGameplayPS
     * @param breachedAPID PersistentID of breached AccessPoint
     * @return NetworkClassification enum value
     */
    private static func ClassifyDeviceNetwork(
        sharedPS: ref<SharedGameplayPS>,
        breachedAPID: PersistentID
    ) -> NetworkClassification {
        if DeviceUnlockUtils.IsConnectedToBreachedNetwork(sharedPS, breachedAPID) {
            return NetworkClassification.BreachedNetwork;
        } else if ArraySize(sharedPS.GetAccessPoints()) > 0 {
            return NetworkClassification.CrossNetwork;
        }
        return NetworkClassification.PureStandalone;
    }

    /*
     * Classifies NPC by network connectivity
     *
     * FUNCTIONALITY:
     * - BreachedNetwork: Connected to breached AccessPoint (already processed)
     * - CrossNetwork: Has DeviceLink but not on breached network
     * - PureStandalone: No DeviceLink (GetDeviceLink() undefined)
     *
     * @param puppet ScriptedPuppet to classify
     * @param breachedAPID PersistentID of breached AccessPoint
     * @param gameInstance Game instance
     * @return NetworkClassification enum value
     */
    private static func ClassifyNPCNetwork(
        puppet: ref<ScriptedPuppet>,
        breachedAPID: PersistentID,
        gameInstance: GameInstance
    ) -> NetworkClassification {
        let npcPS: ref<ScriptedPuppetPS> = puppet.GetPS();
        if !IsDefined(npcPS) {
            return NetworkClassification.PureStandalone;
        }

        let deviceLink: ref<PuppetDeviceLinkPS> = npcPS.GetDeviceLink();
        if !IsDefined(deviceLink) {
            return NetworkClassification.PureStandalone;
        } else if !DeviceUnlockUtils.IsNPCConnectedToBreachedNetwork(puppet, breachedAPID, gameInstance) {
            return NetworkClassification.CrossNetwork;
        }

        return NetworkClassification.BreachedNetwork;
    }

    /*
     * UnlockNetworkNPC() - Unlock Network NPC
     *
     * @param puppetLink Puppet device link PS
     * @return True if unlock event was fired successfully
     */
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

    /*
     * UnlockStandaloneNPC() - Unlock Standalone NPC
     *
     * @param puppet Scripted puppet
     * @return True if unlock event was fired successfully
     */
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

    /*
     * ShouldApplyCrossNetworkFilter() - Cross-Network Unlock Filter Check
     *
     * Determines if network filter should be applied based on configuration.
     *
     * FUNCTIONALITY:
     * - Checks RadialUnlockCrossNetwork setting
     * - Returns true if device should be filtered out (skip unlock)
     * - Returns false if device should be processed (continue unlock)
     *
     * @param sharedPS Shared device power state
     * @return True if device should be filtered out, false otherwise
     */
    private static func ShouldApplyCrossNetworkFilter(sharedPS: ref<SharedGameplayPS>) -> Bool {
        if !IsDefined(sharedPS) {
            return true;  // Filter out invalid devices
        }

        // Check if Cross-Network Unlock is enabled
        if BetterNetrunningSettings.RadialUnlockCrossNetwork() {
            return false;  // Cross-Network enabled, don't filter
        }

        // Cross-Network disabled, check if device is network-connected
        let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
        if ArraySize(apControllers) > 0 {
            return true;  // Network-connected device, filter out
        }

        return false;  // Standalone device, don't filter
    }

    /*
     * IsConnectedToBreachedNetwork() - Check if Device Belongs to Breached Network
     *
     * Determines if device is connected to the specific AccessPoint being breached.
     *
     * FUNCTIONALITY:
     * - Iterates through device's connected AccessPoints
     * - Compares each AccessPoint ID with breached AccessPoint ID
     * - Returns true if match found (device is part of breached network)
     *
     * @param sharedPS Shared device power state
     * @param breachedAPID PersistentID of the breached AccessPoint
     * @return True if device is connected to breached AccessPoint, false otherwise
     */
    private static func IsConnectedToBreachedNetwork(
        sharedPS: ref<SharedGameplayPS>,
        breachedAPID: PersistentID
    ) -> Bool {
        if !IsDefined(sharedPS) {
            return false;
        }

        // Check if device is connected to the breached AccessPoint
        let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
        let idx: Int32 = 0;
        while idx < ArraySize(apControllers) {
            if PersistentID.IsDefined(apControllers[idx].GetID()) && PersistentID.IsDefined(breachedAPID) {
                if Equals(apControllers[idx].GetID(), breachedAPID) {
                    return true;  // Device belongs to breached network
                }
            }
            idx += 1;
        }

        return false;  // Device not connected to breached network
    }

    /*
     * UnlockDeviceInRadius() - Unlock Device with Type Filtering & Duplicate Prevention
     *
     * FUNCTIONALITY:
     * - Cross-Network filter: Uses ShouldApplyCrossNetworkFilter() helper (DRY compliance)
     * - Device type filtering: Uses DeviceTypeUtils.ShouldUnlockByFlags() (DRY compliance)
     * - Duplicate prevention: Checks existing timestamp before unlock
     *
     * @param devicePS Device to unlock
     * @param unlockFlags Flags indicating which device types to unlock
     * @param gameInstance Game instance
     * @return True if device was unlocked, false if skipped
     */
    private static func UnlockDeviceInRadius(
        devicePS: ref<ScriptableDeviceComponentPS>,
        unlockFlags: BreachUnlockFlags,
        gameInstance: GameInstance
    ) -> Bool {
        let sharedPS: ref<SharedGameplayPS> = devicePS;
        if !IsDefined(sharedPS) {
            return false;
        }

        // Cross-Network Unlock filter check (centralized)
        if DeviceUnlockUtils.ShouldApplyCrossNetworkFilter(sharedPS) {
            return false;
        }

        // Device type classification (uses existing DeviceTypeUtils.GetDeviceType)
        let deviceType: TargetType = DeviceTypeUtils.GetDeviceType(devicePS);

        // Device type filtering (uses existing DeviceTypeUtils.ShouldUnlockByFlags - DRY compliance)
        if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
            return false;  // Device type not in unlockFlags, skip
        }

        // Duplicate prevention: Check existing timestamp
        let currentTimestamp: Float = 0.0;
        if Equals(deviceType, TargetType.Camera) {
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampCameras;
        } else if Equals(deviceType, TargetType.Turret) {
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampTurrets;
        } else {
            currentTimestamp = sharedPS.m_betterNetrunningUnlockTimestampBasic;
        }

        if currentTimestamp > 0.0 {
            return false;  // Already unlocked, skip
        }

        // Unlock device (set timestamp)
        let newTimestamp: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
        if Equals(deviceType, TargetType.Camera) {
            sharedPS.m_betterNetrunningUnlockTimestampCameras = newTimestamp;
        } else if Equals(deviceType, TargetType.Turret) {
            sharedPS.m_betterNetrunningUnlockTimestampTurrets = newTimestamp;
        } else {
            sharedPS.m_betterNetrunningUnlockTimestampBasic = newTimestamp;
        }

        return true;
    }

    // ============================================================================
    // Private Helper Methods - Entity Processing (Radial Unlock)
    // ============================================================================

    /*
     * Processes all entities in radius (unified Device/Vehicle processing)
     *
     * ARCHITECTURE: Template Method Pattern with polymorphic processors
     * - Device processing: Uses DeviceUnlockProcessor
     * - Vehicle processing: Uses VehicleUnlockProcessor
     *
     * @param parts TargetingSystem parts array
     * @param origin Breach origin position
     * @param radiusSq Squared breach radius
     * @param breachedAPID PersistentID of breached AccessPoint
     * @param gameInstance Game instance
     * @param unlockFlags Unlock configuration flags
     * @param standaloneCount Output: Standalone entity count
     * @param crossNetworkCount Output: Cross-network entity count
     * @param standaloneUnlocked Output: Standalone entities unlocked
     * @param crossNetworkUnlocked Output: Cross-network entities unlocked
     */
    public static func ProcessEntityInRadius(
        parts: array<TS_TargetPartInfo>,
        origin: Vector4,
        radiusSq: Float,
        breachedAPID: PersistentID,
        gameInstance: GameInstance,
        unlockFlags: BreachUnlockFlags,
        out standaloneCount: Int32,
        out crossNetworkCount: Int32,
        out standaloneUnlocked: Int32,
        out crossNetworkUnlocked: Int32
    ) -> Void {
        // Create Device processor
        let deviceProcessor: ref<DeviceUnlockProcessor> = new DeviceUnlockProcessor();
        deviceProcessor.Initialize(origin, radiusSq, breachedAPID, gameInstance, unlockFlags);

        // Create Vehicle processor
        let vehicleProcessor: ref<VehicleUnlockProcessor> = new VehicleUnlockProcessor();
        vehicleProcessor.Initialize(origin, radiusSq, breachedAPID, gameInstance, unlockFlags);

        // Process all parts with polymorphic processors
        let i: Int32 = ArraySize(parts) - 1;
        while i >= 0 {
            deviceProcessor.ProcessEntity(parts[i]);
            vehicleProcessor.ProcessEntity(parts[i]);
            i -= 1;
        }

        // Aggregate results from both processors
        standaloneCount = deviceProcessor.GetStandaloneCount() + vehicleProcessor.GetStandaloneCount();
        crossNetworkCount = deviceProcessor.GetCrossNetworkCount() + vehicleProcessor.GetCrossNetworkCount();
        standaloneUnlocked = deviceProcessor.GetStandaloneUnlocked() + vehicleProcessor.GetStandaloneUnlocked();
        crossNetworkUnlocked = deviceProcessor.GetCrossNetworkUnlocked() + vehicleProcessor.GetCrossNetworkUnlocked();
    }

    // Attempt to unlock vehicle (distance check already performed by caller)
    private static func TryUnlockVehicle(
        vehicle: ref<VehicleObject>,
        gameInstance: GameInstance
    ) -> Bool {
        let vehPS: ref<VehicleComponentPS> = vehicle.GetVehiclePS();
        if !IsDefined(vehPS) {
            BNError("DeviceUnlockUtils", "VehiclePS not defined for vehicle");
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

    /*
     * Applies timestamp-based unlock to device based on type and flags.
     * Centralized logic shared across DaemonUnlockStrategy, BreachProcessing, and RemoteBreachHelpers.
     *
     * @param device Device to unlock
     * @param gameInstance Game instance
     * @param unlockBasic Unlock basic devices
     * @param unlockNPCs Unlock NPCs
     * @param unlockCameras Unlock cameras
     * @param unlockTurrets Unlock turrets
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

        let deviceType: TargetType = DeviceTypeUtils.GetDeviceType(device);
        let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);

        switch deviceType {
            case TargetType.NPC:
                if unlockNPCs {
                    sharedPS.m_betterNetrunningUnlockTimestampNPCs = currentTime;
                }
                break;
            case TargetType.Camera:
                if unlockCameras {
                    sharedPS.m_betterNetrunningUnlockTimestampCameras = currentTime;
                }
                break;
            case TargetType.Turret:
                if unlockTurrets {
                    sharedPS.m_betterNetrunningUnlockTimestampTurrets = currentTime;
                }
                break;
            default: // TargetType.Basic
                if unlockBasic {
                    sharedPS.m_betterNetrunningUnlockTimestampBasic = currentTime;
                }
                break;
        }
    }

    // ============================================================================
    // Private Helper Methods - NPC Collection
    // ============================================================================

    /*
     * Collects network-connected NPCs within radius using AccessPointControllerPS.GetPuppets()
     *
     * FUNCTIONALITY:
     * - Uses vanilla network graph traversal to avoid TargetingSystem overhead
     * - Validates connection state and filters by 3D distance check
     * - Populates processedIDs array for duplicate detection in TargetingSystem pass
     *
     * @param accessPoint AccessPoint containing network NPCs
     * @param origin Breach position (center of radius check)
     * @param radius Maximum distance in meters (50m default)
     * @param processedIDs Output array of PersistentIDs for duplicate detection
     */
    private static func CollectNetworkNPCsFromAccessPoint(
        accessPoint: ref<AccessPointControllerPS>,
        origin: Vector4,
        radius: Float,
        out processedIDs: array<PersistentID>
    ) -> Void {
        // Guard: Null AccessPoint check
        if !IsDefined(accessPoint) { return; }

        // Get all network-connected NPCs via vanilla's GetPuppets()
        let puppets: array<ref<PuppetDeviceLinkPS>> = accessPoint.GetPuppets();

        let i: Int32 = 0;
        while i < ArraySize(puppets) {
            let puppetLink: ref<PuppetDeviceLinkPS> = puppets[i];

            // Validate connection state (vanilla pattern from AcquirePuppetDeviceLink)
            if IsDefined(puppetLink) && puppetLink.IsConnected() {
                // Get GameObject entity
                let npcObject: wref<GameObject> = puppetLink.GetOwnerEntityWeak() as GameObject;
                if IsDefined(npcObject) && npcObject.IsActive() {
                    // 3D distance check (unified with ExtractAndValidateEntity)
                    let npcPos: Vector4 = npcObject.GetWorldPosition();
                    let distance: Float = Vector4.Distance(origin, npcPos);
                    if distance <= radius {
                        // Track PersistentID for duplicate detection
                        ArrayPush(processedIDs, puppetLink.GetID());
                    }
                }
            }

            i += 1;
        }
    }

    /*
     * Checks if NPC is connected to the breached network
     *
     * FUNCTIONALITY:
     * - Gets NPC's DeviceLink (PuppetDeviceLinkPS)
     * - Casts to SharedGameplayPS to access GetAccessPoints()
     * - Iterates AccessPoints and compares IDs with breachedAPID
     * - Returns true if match found (NPC is part of breached network)
     *
     * @param npc ScriptedPuppet to check
     * @param breachedAPID PersistentID of breached AccessPoint
     * @param gameInstance Game instance
     * @return True if NPC is connected to breached network, false otherwise
     */
    private static func IsNPCConnectedToBreachedNetwork(
        npc: ref<ScriptedPuppet>,
        breachedAPID: PersistentID,
        gameInstance: GameInstance
    ) -> Bool {
        let npcPS: ref<ScriptedPuppetPS> = npc.GetPS();
        if !IsDefined(npcPS) {
            return false;
        }

        // Get DeviceLink (network connection)
        let deviceLink: ref<PuppetDeviceLinkPS> = npcPS.GetDeviceLink();
        if !IsDefined(deviceLink) {
            return false;  // Standalone NPC (no network connection)
        }

        // Cast to SharedGameplayPS to access GetAccessPoints()
        let sharedPS: ref<SharedGameplayPS> = deviceLink;
        if !IsDefined(sharedPS) {
            return false;
        }

        // Reuse existing IsConnectedToBreachedNetwork() logic
        return DeviceUnlockUtils.IsConnectedToBreachedNetwork(sharedPS, breachedAPID);
    }

}

