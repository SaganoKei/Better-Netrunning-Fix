// -----------------------------------------------------------------------------
// RemoteBreach Helper Utilities
// -----------------------------------------------------------------------------
// Utility classes and callbacks for RemoteBreach functionality.
//
// CONTENTS:
// - RemoteBreachUtils: RemoteBreach-specific position recording & network unlock
// - ComputerRemoteBreachUtils: Computer-specific network unlock
// - MinigameIDHelper: Minigame definition selection
// - RemoteBreachActionHelper: Action initialization helpers
// - OnRemoteBreachSucceeded: Success callback with statistics collection
// - OnRemoteBreachFailed: Failure callback
// - JackIn interaction control functions
//
// ARCHITECTURE:
// - OnRemoteBreachSucceeded.Execute() collects statistics and outputs via LogBreachSummary()
// - Statistics include: device counts, unlock flags, network size, breach target
// - Common device/vehicle/NPC unlock logic shared with AccessPoint breach via DeviceUnlockUtils.reds
// -----------------------------------------------------------------------------

module BetterNetrunning.RemoteBreach.Core

import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.RadialUnlock.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.Programs.*

public abstract class DaemonTypes {
    public static func Basic() -> String { return "MinigameAction.UnlockQuickhacks"; }
    public static func NPC() -> String { return "MinigameAction.UnlockNPCQuickhacks"; }
    public static func Camera() -> String { return "MinigameAction.UnlockCameraQuickhacks"; }
    public static func Turret() -> String { return "MinigameAction.UnlockTurretQuickhacks"; }
    public static func PING() -> String { return "MinigameAction.NetworkPingHack"; }
}

@if(ModuleExists("HackingExtensions"))
public abstract class StateSystemUtils {
    public static func GetComputerStateSystem(gameInstance: GameInstance) -> ref<RemoteBreachStateSystem> {
        return GameInstance.GetScriptableSystemsContainer(gameInstance).Get(BNConstants.CLASS_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
    }

    public static func GetDeviceStateSystem(gameInstance: GameInstance) -> ref<DeviceRemoteBreachStateSystem> {
        return GameInstance.GetScriptableSystemsContainer(gameInstance).Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as DeviceRemoteBreachStateSystem;
    }

    public static func GetVehicleStateSystem(gameInstance: GameInstance) -> ref<VehicleRemoteBreachStateSystem> {
        return GameInstance.GetScriptableSystemsContainer(gameInstance).Get(BNConstants.CLASS_VEHICLE_REMOTE_BREACH_STATE_SYSTEM()) as VehicleRemoteBreachStateSystem;
    }

    public static func GetCustomHackingSystem(gameInstance: GameInstance) -> ref<CustomHackingSystem> {
        return GameInstance.GetScriptableSystemsContainer(gameInstance).Get(BNConstants.CLASS_CUSTOM_HACKING_SYSTEM()) as CustomHackingSystem;
    }
}

@if(ModuleExists("HackingExtensions"))
public abstract class ProgramIDUtils {
    public static func ApplyProgramToSharedPS(programID: TweakDBID, sharedPS: ref<SharedGameplayPS>, gameInstance: GameInstance) -> Void {
        let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);

        if programID == BNConstants.PROGRAM_UNLOCK_QUICKHACKS() {
            sharedPS.m_betterNetrunningUnlockTimestampBasic = currentTime;
        } else if programID == BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS() {
            sharedPS.m_betterNetrunningUnlockTimestampNPCs = currentTime;
        } else if programID == BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS() {
            sharedPS.m_betterNetrunningUnlockTimestampCameras = currentTime;
        } else if programID == BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS() {
            sharedPS.m_betterNetrunningUnlockTimestampTurrets = currentTime;
        }
    }

    public static func IsAnyDaemonCompleted(sharedPS: ref<SharedGameplayPS>) -> Bool {
        return BreachStatusUtils.IsBasicBreached(sharedPS)
            || BreachStatusUtils.IsNPCsBreached(sharedPS)
            || BreachStatusUtils.IsCamerasBreached(sharedPS)
            || BreachStatusUtils.IsTurretsBreached(sharedPS);
    }

    public static func CreateBreachEventFromProgram(programID: TweakDBID, gameInstance: GameInstance) -> ref<SetBreachedSubnet> {
        let event: ref<SetBreachedSubnet> = new SetBreachedSubnet();
        let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);

        if programID == BNConstants.PROGRAM_UNLOCK_QUICKHACKS() {
            event.unlockTimestampBasic = currentTime;
        } else if programID == BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS() {
            event.unlockTimestampNPCs = currentTime;
        } else if programID == BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS() {
            event.unlockTimestampCameras = currentTime;
        } else if programID == BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS() {
            event.unlockTimestampTurrets = currentTime;
        }

        return event;
    }
}

// -----------------------------------------------------------------------------
// Helper Structures for Reduced Nesting
// -----------------------------------------------------------------------------

// Targeting setup information (reduces parameter passing)
// Using struct instead of class to avoid ref<> requirement
@if(ModuleExists("HackingExtensions"))
public struct TargetingSetup {
    let isValid: Bool;
    let player: ref<PlayerPuppet>;
    let targetingSystem: ref<TargetingSystem>;
    let query: TargetSearchQuery;
    let sourcePos: Vector4;
    let breachRadius: Float;
}

// Unlock flags bundle (reduces parameter count)
// Using struct instead of class to avoid ref<> requirement
@if(ModuleExists("HackingExtensions"))
public struct UnlockFlags {
    let unlockBasic: Bool;
    let unlockNPCs: Bool;
    let unlockCameras: Bool;
    let unlockTurrets: Bool;
}

// Vehicle processing result (reduces nesting in UnlockVehiclesInRadius)
@if(ModuleExists("HackingExtensions"))
public struct VehicleProcessResult {
    let vehicleFound: Bool;
    let unlocked: Bool;
}

// -----------------------------------------------------------------------------
// RemoteBreach Utils - RemoteBreach-specific utilities
// -----------------------------------------------------------------------------
// NOTE (2025-10-19):
// Common unlock logic (UnlockDevicesInRadius, UnlockVehiclesInRadius, UnlockNPCsInRadius)
// moved to Core/DeviceUnlockUtils.reds for sharing with AP Breach.
//
// This class now contains RemoteBreach-specific logic only:
// - RecordBreachPosition: Position tracking for radial unlock
// - UnlockNearbyNetworkDevices: Network device unlock helper
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public abstract class RemoteBreachUtils {
    public static func RecordBreachPosition(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Void {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return;
        }

        let devicePos: Vector4 = deviceEntity.GetWorldPosition();
        RecordAccessPointBreachByPosition(devicePos, gameInstance);
    }

    // Overload for VehicleComponentPS
    public static func RecordBreachPosition(vehiclePS: ref<VehicleComponentPS>, gameInstance: GameInstance) -> Void {
        let vehicleEntity: wref<GameObject> = vehiclePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(vehicleEntity) {
            return;
        }

        let vehiclePos: Vector4 = vehicleEntity.GetWorldPosition();
        RecordAccessPointBreachByPosition(vehiclePos, gameInstance);
    }

    // Unlock nearby network-connected devices (shared logic for Device and Vehicle RemoteBreach)
    // RETURNS: RadialUnlockResult with device counts and unlock statistics
    public static func UnlockNearbyNetworkDevices(sourceEntity: wref<GameObject>, gameInstance: GameInstance, unlockBasic: Bool, unlockNPCs: Bool, unlockCameras: Bool, unlockTurrets: Bool, logPrefix: String) -> RadialUnlockResult {
        let result: RadialUnlockResult;

        if !IsDefined(sourceEntity) {
            return result;
        }

        let targetingSetup: TargetingSetup = RemoteBreachUtils.SetupDeviceTargeting(sourceEntity, gameInstance);
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
            let deviceResult: RadialUnlockResult = RemoteBreachUtils.ProcessNetworkDevice(parts[i], targetingSetup, unlockFlags);
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

    // Setup targeting for Device search (internal helper for UnlockNearbyNetworkDevices)
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

    // Process network-connected device (reduce nesting in UnlockNearbyNetworkDevices)
    // RETURNS: RadialUnlockResult with device type counts
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
        let unlocked: Bool = RemoteBreachUtils.UnlockDeviceByType(devicePS, flags);

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

    // Unlock device by type with flags (reduce nesting)
    // RETURNS: true if device was unlocked, false if skipped
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
}

@if(ModuleExists("HackingExtensions"))
public abstract class ComputerRemoteBreachUtils {
    // Architecture: Shallow nesting (max 2 levels) using helper methods
    public static func UnlockNetworkDevices(computerPS: ref<ComputerControllerPS>, unlockBasic: Bool, unlockNPCs: Bool, unlockCameras: Bool, unlockTurrets: Bool) -> Void {
        let sharedPS: ref<SharedGameplayPS> = computerPS;
        if !IsDefined(sharedPS) {
            return;
        }

        let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
        if ArraySize(apControllers) == 0 {
            return;  // Standalone computer, no network devices
        }

        let flags: UnlockFlags;
        flags.unlockBasic = unlockBasic;
        flags.unlockNPCs = unlockNPCs;
        flags.unlockCameras = unlockCameras;
        flags.unlockTurrets = unlockTurrets;

        let i: Int32 = 0;
        while i < ArraySize(apControllers) {
            ComputerRemoteBreachUtils.ProcessAccessPointDevices(apControllers[i], flags);
            i += 1;
        }
    }

    // ============================================================================
    // ProcessAccessPointDevices - Network Device Processing
    // ============================================================================
    // ARCHITECTURE: Extract Method pattern (max 2-level nesting)
    // Separated device processing logic into dedicated helper
    private static func ProcessAccessPointDevices(apPS: ref<AccessPointControllerPS>, flags: UnlockFlags) -> Void {
        if !IsDefined(apPS) {
            return;
        }

        let devices: array<ref<DeviceComponentPS>>;
        apPS.GetChildren(devices);

        let setBreachedEvent: ref<SetBreachedSubnet> = ComputerRemoteBreachUtils.CreateBreachEvent(apPS.GetGameInstance(), flags);

        let j: Int32 = 0;
        while j < ArraySize(devices) {
            ComputerRemoteBreachUtils.ProcessNetworkConnectedDevice(devices[j], apPS, setBreachedEvent, flags);
            j += 1;
        }
    }

    // Helper: Create SetBreachedSubnet event with timestamps
    private static func CreateBreachEvent(gameInstance: GameInstance, flags: UnlockFlags) -> ref<SetBreachedSubnet> {
        let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
        let event: ref<SetBreachedSubnet> = new SetBreachedSubnet();
        event.unlockTimestampBasic = flags.unlockBasic ? currentTime : 0.0;
        event.unlockTimestampNPCs = flags.unlockNPCs ? currentTime : 0.0;
        event.unlockTimestampCameras = flags.unlockCameras ? currentTime : 0.0;
        event.unlockTimestampTurrets = flags.unlockTurrets ? currentTime : 0.0;
        return event;
    }

    // Helper: Process single network-connected device (2-level nesting)
    private static func ProcessNetworkConnectedDevice(
        device: ref<DeviceComponentPS>,
        apPS: ref<AccessPointControllerPS>,
        setBreachedEvent: ref<SetBreachedSubnet>,
        flags: UnlockFlags
    ) -> Void {
        if !IsDefined(device) {
            return;
        }

        // Queue breach event for this device
        apPS.QueuePSEvent(device, setBreachedEvent);

        // Determine device type and check if should unlock
        let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);
        let shouldUnlock: Bool = ComputerRemoteBreachUtils.ShouldUnlockDeviceType(deviceType, flags);

        if shouldUnlock {
            apPS.QueuePSEvent(device, apPS.ActionSetExposeQuickHacks());
        }
    }

    // Helper: Check if device type should be unlocked based on flags
    private static func ShouldUnlockDeviceType(deviceType: DeviceType, flags: UnlockFlags) -> Bool {
        switch deviceType {
            case DeviceType.NPC:
                return flags.unlockNPCs;
            case DeviceType.Camera:
                return flags.unlockCameras;
            case DeviceType.Turret:
                return flags.unlockTurrets;
            case DeviceType.Basic:
                return flags.unlockBasic;
            default:
                return false;
        }
    }
}

// -----------------------------------------------------------------------------
// Minigame Definition Helper - Target-specific minigame IDs
// -----------------------------------------------------------------------------
// Provides difficulty-based minigame IDs for Computer/Device/Vehicle targets
// Centralizes minigame selection logic for consistent behavior across modules
// -----------------------------------------------------------------------------

public abstract class MinigameIDHelper {
    // Get minigame ID based on target type and difficulty
    // Returns appropriate TweakDBID for Computer/Device/Vehicle RemoteBreach
    public static func GetMinigameID(targetType: MinigameTargetType, difficulty: GameplayDifficulty, opt devicePS: ref<ScriptableDeviceComponentPS>) -> TweakDBID {
        switch targetType {
            case MinigameTargetType.Computer:
                return MinigameIDHelper.GetComputerMinigameID(difficulty);
            case MinigameTargetType.Device:
                return MinigameIDHelper.GetDeviceMinigameID(difficulty, devicePS);
            case MinigameTargetType.Vehicle:
                return MinigameIDHelper.GetVehicleMinigameID(difficulty);
            default:
                BNWarn("CustomHacking", "Unknown target type - defaulting to Device Medium");
                return BNConstants.MINIGAME_DEVICE_BREACH_MEDIUM();
        }
    }

    // Computer RemoteBreach: Basic + Camera daemons
    private static func GetComputerMinigameID(difficulty: GameplayDifficulty) -> TweakDBID {
        switch difficulty {
            case GameplayDifficulty.Easy:
                return BNConstants.MINIGAME_COMPUTER_BREACH_EASY();
            case GameplayDifficulty.Hard:
                return BNConstants.MINIGAME_COMPUTER_BREACH_HARD();
            default:
                return BNConstants.MINIGAME_COMPUTER_BREACH_MEDIUM();
        }
    }

    // Device RemoteBreach: Device-type-specific daemons
    // Generic devices: Basic only
    // Camera devices: Basic + Camera
    // Turret devices: Basic + Turret
    private static func GetDeviceMinigameID(difficulty: GameplayDifficulty, devicePS: ref<ScriptableDeviceComponentPS>) -> TweakDBID {
        // Determine device type and select appropriate minigame
        let minigameBase: String;

        if DaemonFilterUtils.IsCamera(devicePS) {
            minigameBase = "CameraRemoteBreach";
        } else if DaemonFilterUtils.IsTurret(devicePS) {
            minigameBase = "TurretRemoteBreach";
        } else {
            minigameBase = "DeviceRemoteBreach";
        }

        // Select difficulty-specific variant
        switch difficulty {
            case GameplayDifficulty.Easy:
                return TDBID.Create("Minigame." + minigameBase + "Easy");
            case GameplayDifficulty.Hard:
                return TDBID.Create("Minigame." + minigameBase + "Hard");
            default:
                return TDBID.Create("Minigame." + minigameBase + "Medium");
        }
    }

    // Vehicle RemoteBreach: Basic daemon only (fixed difficulty - same treatment as Basic devices)
    private static func GetVehicleMinigameID(difficulty: GameplayDifficulty) -> TweakDBID {
        // Vehicle uses fixed minigame regardless of difficulty setting
        return BNConstants.MINIGAME_VEHICLE_BREACH();
    }
}

// Difficulty enum for minigame selection
enum GameplayDifficulty {
    Easy = 0,
    Medium = 1,
    Hard = 2
}

// Target type enum for minigame selection
enum MinigameTargetType {
    Computer = 0,
    Device = 1,
    Vehicle = 2
}

// -----------------------------------------------------------------------------
// RemoteBreach Action Helper - Common initialization logic
// -----------------------------------------------------------------------------
// Centralizes RemoteBreachAction setup to ensure consistent behavior
// across Computer/Device/Vehicle modules
// -----------------------------------------------------------------------------

public abstract class RemoteBreachActionHelper {
    // Initialize RemoteBreachAction with proper minigame ID and dynamic RAM cost
    // Note: Uses CustomAccessBreach base class to support RemoteBreachAction, DeviceRemoteBreachAction, VehicleRemoteBreachAction
    public static func Initialize(action: ref<CustomAccessBreach>, devicePS: ref<ScriptableDeviceComponentPS>, actionName: CName) -> Void {
        action.clearanceLevel = DefaultActionsParametersHolder.GetInteractiveClearance();
        action.SetUp(devicePS);
        action.AddDeviceName(devicePS.GetDeviceName());

        // CRITICAL: Set ObjectActionID before CreateInteraction()
        // This registers the action with the device system
        action.SetObjectActionID(BNConstants.DEVICE_ACTION_REMOTE_BREACH());

        action.CreateInteraction();

        // Set action name for identification
        action.actionName = actionName;

        // Set dynamic RAM cost (1/3 of player's max RAM)
        RemoteBreachActionHelper.SetDynamicRAMCost(action, devicePS);
    }

    // Calculate and set RAM cost based on configurable percentage of player's maximum RAM
    private static func SetDynamicRAMCost(action: ref<CustomAccessBreach>, devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
        let player: ref<PlayerPuppet> = GetPlayer(devicePS.GetGameInstance());
        if !IsDefined(player) {
            BNError("CustomHacking", "Player not found - using default RAM cost");
            return;
        }

        let statPoolSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(devicePS.GetGameInstance());
        if !IsDefined(statPoolSystem) {
            BNError("CustomHacking", "StatPoolsSystem not found - using default RAM cost");
            return;
        }

        let playerID: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());

        // Get current RAM and max RAM capacity
        let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(devicePS.GetGameInstance());

        let currentRAM: Float = statPoolSystem.GetStatPoolValue(playerID, gamedataStatPoolType.Memory, false);
        let maxRAMCap: Float = statsSystem.GetStatValue(playerID, gamedataStatType.Memory);

        // Get configured percentage from settings (default: 35%)
        let costPercent: Int32 = BetterNetrunningSettings.RemoteBreachRAMCostPercent();
        let ramCost: Float = maxRAMCap * (Cast<Float>(costPercent) / 100.0);

        // Round to nearest integer
        let roundedCost: Int32 = Cast<Int32>(ramCost + 0.5);

        // Ensure minimum cost of 1
        if roundedCost < 1 {
            roundedCost = 1;
        }

        // Store the calculated cost (works for all BaseRemoteBreachAction subclasses)
        let remoteBreachAction: ref<BaseRemoteBreachAction> = action as BaseRemoteBreachAction;
        if IsDefined(remoteBreachAction) {
            remoteBreachAction.m_calculatedRAMCost = roundedCost;
        }
    }

    // Set minigame definition based on target type and difficulty
    public static func SetMinigameDefinition(action: ref<CustomAccessBreach>, targetType: MinigameTargetType, difficulty: GameplayDifficulty, devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
        let minigameID: TweakDBID = MinigameIDHelper.GetMinigameID(targetType, difficulty, devicePS);

        // Critical: Call SetProperties() to properly initialize CustomAccessBreach
        // This is required for the action to appear in quickhack menu
        action.SetProperties(
            devicePS.GetDeviceName(),  // networkName
            1,                         // npcCount
            0,                         // attemptsCount
            true,                      // isRemote
            false,                     // isSuicide
            minigameID,               // minigameDefinition
            devicePS                   // targetHack
        );

        // Note: CreateInteraction() is already called in Initialize()
        // Calling it again here might cause issues
    }

    // Get current game difficulty (placeholder - expand if difficulty detection needed)
    public static func GetCurrentDifficulty() -> GameplayDifficulty {
        // TODO: Implement difficulty detection from game settings
        // For now, default to Medium
        return GameplayDifficulty.Medium;
    }

    // Remove TweakDB-defined RemoteBreach from action list
    public static func RemoveTweakDBRemoteBreach(actions: script_ref<array<ref<DeviceAction>>>, actionName: CName) -> Void {
        let actionsArray: array<ref<DeviceAction>> = Deref(actions);
        let i: Int32 = ArraySize(actionsArray) - 1;

        while i >= 0 {
            let action: ref<DeviceAction> = actionsArray[i];
            if IsDefined(action) && Equals(action.actionName, actionName) {
                ArrayErase(actionsArray, i);
            }
            i -= 1;
        }

        actions = actionsArray;
    }
}

// -----------------------------------------------------------------------------
// RemoteBreach Success Callback
// -----------------------------------------------------------------------------
// ARCHITECTURE: Extract Method + Guard Clauses (max 2-level nesting)
// Separated into focused helper methods for device retrieval and program execution

@if(ModuleExists("HackingExtensions"))
public class OnRemoteBreachSucceeded extends OnCustomHackingSucceeded {
    // ============================================================================
    // Execute - Main Callback
    // ============================================================================
    public func Execute() -> Void {
        let activePrograms: array<TweakDBID> = this.GetActiveProgramsWithBonusDaemons();
        let device: wref<ScriptableDeviceComponentPS> = this.RetrieveTargetDevice();

        if !IsDefined(device) {
            BNError("RemoteBreach", "No device found - cannot execute programs");
            return;
        }

        this.ExecuteProgramsAndRewardsWithStats(activePrograms, device);
    }

    // ============================================================================
    // Helper: Get active programs with bonus daemons applied
    // ============================================================================
    private func GetActiveProgramsWithBonusDaemons() -> array<TweakDBID> {
        let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
        let activePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms));

        let activeProgramsRef: script_ref<array<TweakDBID>> = activePrograms;
        ApplyBonusDaemons(activeProgramsRef, GetGameInstance(), "[RemoteBreach]");

        minigameBB.SetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms, ToVariant(activePrograms), true);

        return activePrograms;
    }

    // ============================================================================
    // Helper: Retrieve target device (2-level nesting max)
    // ============================================================================
    private func RetrieveTargetDevice() -> wref<ScriptableDeviceComponentPS> {
        // Try hackInstanceSettings first (most reliable)
        if IsDefined(this.hackInstanceSettings) && IsDefined(this.hackInstanceSettings.hackedTarget) {
            let device: wref<ScriptableDeviceComponentPS> = this.TryGetDeviceFromHackInstanceSettings();
            if IsDefined(device) {
                return device;
            }
        }

        // Fallback: Try state systems
        return this.TryGetDeviceFromStateSystems();
    }

    // Helper: Try to get device from hackInstanceSettings.hackedTarget
    private func TryGetDeviceFromHackInstanceSettings() -> wref<ScriptableDeviceComponentPS> {
        // Try direct cast first
        let device: wref<ScriptableDeviceComponentPS> = this.hackInstanceSettings.hackedTarget as ScriptableDeviceComponentPS;
        if IsDefined(device) {
            return device;
        }

        // Try cast to GameObject and get DevicePS
        let targetObj: ref<GameObject> = this.hackInstanceSettings.hackedTarget as GameObject;
        if !IsDefined(targetObj) {
            return null;
        }

        let deviceObj: ref<Device> = targetObj as Device;
        if !IsDefined(deviceObj) {
            return null;
        }

        device = deviceObj.GetDevicePS();
        return device;
    }

    // Helper: Try to get device from state systems
    private func TryGetDeviceFromStateSystems() -> wref<ScriptableDeviceComponentPS> {
        let deviceStateSystem: ref<DeviceRemoteBreachStateSystem> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as DeviceRemoteBreachStateSystem;
        if IsDefined(deviceStateSystem) {
            let device: wref<ScriptableDeviceComponentPS> = deviceStateSystem.GetCurrentDevice();
            if IsDefined(device) {
                return device;
            }
        }

        let computerStateSystem: ref<RemoteBreachStateSystem> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(BNConstants.CLASS_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
        if IsDefined(computerStateSystem) {
            let computerPS: wref<ComputerControllerPS> = computerStateSystem.GetCurrentComputer();
            if IsDefined(computerPS) {
                return computerPS;
            }
        }

        return null;
    }

    // ============================================================================
    // Helper: Execute programs and rewards with statistics collection
    // ============================================================================
    private func ExecuteProgramsAndRewardsWithStats(activePrograms: array<TweakDBID>, device: wref<ScriptableDeviceComponentPS>) -> Void {
        // Initialize statistics
        let stats: ref<BreachSessionStats> = BreachSessionStats.Create("RemoteBreach", device.GetDeviceName());
        stats.minigameSuccess = true;
        stats.programsInjected = ArraySize(activePrograms);

        // Parse unlock flags from active programs
        let unlockFlags: BreachUnlockFlags = DaemonFilterUtils.ExtractUnlockFlags(activePrograms);
        stats.unlockBasic = unlockFlags.unlockBasic;
        stats.unlockCameras = unlockFlags.unlockCameras;
        stats.unlockTurrets = unlockFlags.unlockTurrets;
        stats.unlockNPCs = unlockFlags.unlockNPCs;

        // Collect executed daemon information for display
        BreachStatisticsCollector.CollectExecutedDaemons(activePrograms, stats);

        // Get network devices for statistics
        // IMPLEMENTATION: Supports both MasterControllerPS (Computer/AccessPoint) and child devices (Speaker/Camera/Turret)
        let networkDevices: array<ref<DeviceComponentPS>>;
        let masterPS: ref<MasterControllerPS> = device as MasterControllerPS;
        if IsDefined(masterPS) {
            // Case 1: Device is MasterControllerPS (Computer, AccessPoint) - direct GetChildren
            masterPS.GetChildren(networkDevices);
        } else {
            // Case 2: Device is child (Speaker, Camera, Turret) - get network via parent AccessPoint
            let sharedPS: ref<SharedGameplayPS> = device;
            if IsDefined(sharedPS) {
                let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
                if ArraySize(apControllers) > 0 {
                    // Network-connected device - get all devices from parent AccessPoint
                    apControllers[0].GetChildren(networkDevices);
                }
                // If ArraySize(apControllers) == 0, device is standalone (networkDevices remains empty)
            }
        }

        // Collect network device statistics using unified collector
        BreachStatisticsCollector.CollectNetworkDeviceStats(networkDevices, unlockFlags, stats);

        let deviceEntity: ref<Device> = GameInstance.FindEntityByID(GetGameInstance(), PersistentID.ExtractEntityID(device.GetID())) as Device;

        // Execute programs (Datamine, etc.)
        ProcessMinigamePrograms(activePrograms, device, GetGameInstance(), stats.executedNormalDaemons, "[RemoteBreach]");

        // Grant vanilla hacking rewards
        RPGManager.GiveReward(GetGameInstance(), t"RPGActionRewards.Hacking", Cast<StatsObjectID>(device.GetMyEntityID()));

        // Disable JackIn interaction
        DisableJackInInteractionForAccessPoint(device);

        // Collect radial unlock statistics using unified collector
        BreachStatisticsCollector.CollectRadialUnlockStats(device, unlockFlags, stats, GetGameInstance());

        // Output statistics summary
        stats.Finalize();
        LogBreachSummary(stats);
    }

    // ============================================================================
    // ExecutePingIfNeeded - REMOVED
    // ============================================================================
    // REASON: Cannot implement single-device PING without extensive vanilla overrides
    // - PingDevice action calls PingDevicesNetwork() in CompleteAction()
    // - Device.PulseNetwork() uses EPingType.SPACE (network-wide)
    // - No vanilla API exists for single-device PING
    // All PING-related functionality has been disabled
    // ============================================================================
}

// -----------------------------------------------------------------------------
// RemoteBreach Failure Callback
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public class OnRemoteBreachFailed extends OnCustomHackingFailed {
    public func Execute() -> Void {
        let device: wref<ScriptableDeviceComponentPS> = this.RetrieveTargetDevice();

        if !IsDefined(device) {
            BNError("RemoteBreach", "No device found - cannot apply failure penalty");
            return;
        }

        // Apply failure penalty using FinalizeNetrunnerDive (calls failure handlers)
        device.FinalizeNetrunnerDive(HackingMinigameState.Failed);
    }

    // Retrieve target device (same logic as OnRemoteBreachSucceeded)
    private func RetrieveTargetDevice() -> wref<ScriptableDeviceComponentPS> {
        if IsDefined(this.hackInstanceSettings) && IsDefined(this.hackInstanceSettings.hackedTarget) {
            let device: wref<ScriptableDeviceComponentPS> = this.TryGetDeviceFromHackInstanceSettings();
            if IsDefined(device) {
                return device;
            }
        }
        return this.TryGetDeviceFromStateSystems();
    }

    private func TryGetDeviceFromHackInstanceSettings() -> wref<ScriptableDeviceComponentPS> {
        // Try direct cast first
        let device: wref<ScriptableDeviceComponentPS> = this.hackInstanceSettings.hackedTarget as ScriptableDeviceComponentPS;
        if IsDefined(device) {
            return device;
        }

        // Try cast to GameObject and get DevicePS
        let targetObj: ref<GameObject> = this.hackInstanceSettings.hackedTarget as GameObject;
        if !IsDefined(targetObj) {
            return null;
        }

        let deviceObj: ref<Device> = targetObj as Device;
        if !IsDefined(deviceObj) {
            return null;
        }

        return deviceObj.GetDevicePS();
    }

    private func TryGetDeviceFromStateSystems() -> wref<ScriptableDeviceComponentPS> {
        let gameInstance: GameInstance = GetGameInstance();

        // Try DeviceRemoteBreachStateSystem first
        let deviceStateSystem: ref<DeviceRemoteBreachStateSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as DeviceRemoteBreachStateSystem;
        if IsDefined(deviceStateSystem) {
            let device: wref<ScriptableDeviceComponentPS> = deviceStateSystem.GetCurrentDevice();
            if IsDefined(device) {
                return device;
            }
        }

        // Try RemoteBreachStateSystem (for Computer)
        let computerStateSystem: ref<RemoteBreachStateSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(BNConstants.CLASS_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
        if IsDefined(computerStateSystem) {
            let computerPS: wref<ComputerControllerPS> = computerStateSystem.GetCurrentComputer();
            if IsDefined(computerPS) {
                return computerPS;
            }
        }

        return null;
    }
}

// ============================================================================
// DisableJackInInteractionForAccessPoint - JackIn Interaction Disabling
// ============================================================================
//
// PURPOSE:
// Disable JackIn interaction for devices after successful RemoteBreach
//
// FUNCTIONALITY:
// - Checks if device supports JackIn (AccessPoint, Computer, Terminal)
// - Sets m_hasPersonalLinkSlot = false (vanilla JackIn disabling mechanism)
// - Same behavior as SpiderbotEnableAccessPoint (vanilla approach)
//
// ARCHITECTURE:
// - Early return pattern for unsupported devices
// - Direct field modification (m_hasPersonalLinkSlot)
// - Vanilla-compatible approach (uses existing mechanism)
//
// DEPENDENCIES:
// - AccessPointControllerPS: Vanilla AccessPoint device class
// - ComputerControllerPS: Vanilla Computer device class (extends TerminalControllerPS)
// - TerminalControllerPS: Vanilla Terminal device class (extends MasterControllerPS)
// - m_hasPersonalLinkSlot: Vanilla JackIn control flag
//
// DESIGN DECISION:
// - Uses vanilla flag instead of custom persistent field
// - Prevents duplicate breach (RemoteBreach + JackIn on same device)
// - Matches vanilla behavior: AP breach disables JackIn, NPC breach disables breach
// - Supports Computer/Terminal devices (they also support JackIn via MasterControllerPS)
// ============================================================================
@if(ModuleExists("HackingExtensions"))
public static func DisableJackInInteractionForAccessPoint(device: ref<ScriptableDeviceComponentPS>) -> Void {
    if !IsDefined(device) {
        BNError("RemoteBreach", "Device PS is undefined - cannot disable JackIn");
        return;
    }

    // Check if device is MasterControllerPS (base class for AccessPoint, Computer, Terminal)
    // All MasterControllerPS devices support JackIn via m_hasPersonalLinkSlot
    let masterController: ref<MasterControllerPS> = device as MasterControllerPS;
    if !IsDefined(masterController) {
        // Not a master controller device - no JackIn interaction to disable
        return;
    }

    // Disable JackIn interaction (vanilla approach - same as SpiderbotEnableAccessPoint)
    masterController.SetHasPersonalLinkSlot(false);
}

// ============================================================================
// EnableJackInInteractionForAccessPoint - JackIn Interaction Re-enabling
// ============================================================================
//
// PURPOSE:
// Re-enables JackIn interaction on devices after unlock expiration.
// Used when temporary unlock expires and device should be re-lockable.
//
// FUNCTIONALITY:
// - Re-enables JackIn on MasterControllerPS devices (AccessPoint, Computer, Terminal)
// - Restores ability to perform physical breach after remote breach expires
// - Complements DisableJackInInteractionForAccessPoint for temporary unlock feature
//
// PARAMETERS:
// - device: Device PS to re-enable JackIn on
//
// DESIGN DECISION:
// - Uses vanilla flag restoration (SetHasPersonalLinkSlot(true))
// - Allows re-breaching expired devices via physical JackIn
// - Supports Computer/Terminal devices (they also support JackIn via MasterControllerPS)
// ============================================================================
@if(ModuleExists("HackingExtensions"))
public static func EnableJackInInteractionForAccessPoint(device: ref<ScriptableDeviceComponentPS>) -> Void {
    if !IsDefined(device) {
        BNError("RemoteBreach", "Device PS is undefined - cannot enable JackIn");
        return;
    }

    // Check if device is MasterControllerPS (base class for AccessPoint, Computer, Terminal)
    // All MasterControllerPS devices support JackIn via m_hasPersonalLinkSlot
    let masterController: ref<MasterControllerPS> = device as MasterControllerPS;
    if !IsDefined(masterController) {
        // Not a master controller device - no JackIn interaction to enable
        return;
    }

    // Re-enable JackIn interaction
    masterController.SetHasPersonalLinkSlot(true);
}