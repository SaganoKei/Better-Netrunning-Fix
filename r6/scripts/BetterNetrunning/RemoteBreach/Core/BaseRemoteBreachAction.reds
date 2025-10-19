// -----------------------------------------------------------------------------
// RemoteBreach System - Base RemoteBreach Action
// -----------------------------------------------------------------------------
// Core infrastructure for RemoteBreach functionality using CustomHackingSystem.
//
// ARCHITECTURE:
// RemoteBreach uses CustomHackingSystem (HackingExtensions MOD) instead of the
// vanilla MinigameGenerationRuleScalingPrograms pipeline. This means:
//
// 1. DAEMON LISTS ARE STATIC
//    - Defined in remoteBreach.lua at game initialization
//    - ComputerRemoteBreach: Basic + Camera (always)
//    - DeviceRemoteBreach: Basic only (always)
//    - VehicleRemoteBreach: All 4 daemon types (always)
//
// 2. NO DYNAMIC FILTERING
//    - FilterPlayerPrograms() is NOT called for RemoteBreach
//    - PhysicalRangeFilter does NOT apply
//    - AccessPointFilter does NOT apply
//    - Daemon availability is determined by target TYPE, not network composition
//
// 3. DESIGN RATIONALE
//    - Daemons represent CAPABILITIES granted by breaching that target type
//    - Computer = "access point control" → Basic + Camera make semantic sense
//    - Not based on actual devices present in the network (by design)
//
// LIMITATION:
// Cannot be changed without modifying CustomHackingSystem API or creating
// 48+ minigame variants (2^4 device types × 3 difficulties).
// -----------------------------------------------------------------------------

module BetterNetrunning.RemoteBreach.Core

import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.RadialUnlock.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

// -----------------------------------------------------------------------------
// Base RemoteBreach Action with Dynamic RAM Cost Support
// -----------------------------------------------------------------------------

// Base class for all RemoteBreach actions with dynamic RAM cost calculation
@if(ModuleExists("HackingExtensions"))
public abstract class BaseRemoteBreachAction extends CustomAccessBreach {
    public let m_calculatedRAMCost: Int32; // Dynamic RAM cost

    // ============================================================================
    // SetProperties Override: Set StateSystem target BEFORE minigame starts
    // ============================================================================
    //
    // CRITICAL: This is called BEFORE CompleteAction(), allowing us to set up
    // StateSystem target for DeviceDaemonAction.ExecuteProgramSuccess() to retrieve.
    // ============================================================================
    public func SetProperties(networkName: String, npcCount: Int32, attemptsCount: Int32, isRemote: Bool, isSuicide: Bool, minigameDefinition: TweakDBID, targetHack: ref<IScriptable>) -> Void {
        // Call parent implementation to set all fields
        super.SetProperties(networkName, npcCount, attemptsCount, isRemote, isSuicide, minigameDefinition, targetHack);

        // Set StateSystem target BEFORE minigame starts
        // We need GameInstance, but it's not available here
        // Solution: Store target reference and set StateSystem in CompleteAction()
    }

    // ============================================================================
    // CompleteAction Override: Set StateSystem target and register callbacks
    // ============================================================================
    //
    // Sets StateSystem target, then starts minigame with success/failure callbacks.
    // This is based on CustomAccessBreach.CompleteAction() but uses callbacks.
    // ============================================================================
    public func CompleteAction(gameInstance: GameInstance) -> Void {
        // CRITICAL: Set StateSystem target BEFORE minigame starts
        // Reason: DeviceDaemonAction.ExecuteProgramSuccess() retrieves target from StateSystem
        this.SetStateSystemTarget(gameInstance);

        // Get CustomHackingSystem
        let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);
        let customHackSystem: ref<CustomHackingSystem> = container.Get(BNConstants.CLASS_CUSTOM_HACKING_SYSTEM()) as CustomHackingSystem;

        if IsDefined(customHackSystem) {
            // Create empty additionalData array
            let emptyData: array<Variant>;

            // Create success and failure callbacks
            let onSucceed: ref<OnRemoteBreachSucceeded> = new OnRemoteBreachSucceeded();
            let onFailed: ref<OnRemoteBreachFailed> = new OnRemoteBreachFailed();

            // Call StartNewQuickhackInstance WITH CALLBACKS to support bonus daemons
            let success: Bool = customHackSystem.StartNewQuickhackInstance(
                this.m_networkName,      // Network name
                this,                    // This action
                this.m_minigameDefinition, // Minigame def
                this.m_targetHack,       // Target hack
                emptyData,               // additionalData (empty array)
                onSucceed,               // onSucceed callback
                onFailed                 // onFailed callback
            );

            if !success {
                BNError("RemoteBreach", "StartNewQuickhackInstance FAILED");
            }
        } else {
            BNError("RemoteBreach", "CustomHackingSystem not found - bonus daemons will not execute");
        }

        // Initialize blackboard (same as parent CustomAccessBreach)
        let blackboard: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gameInstance).Get(GetAllBlackboardDefs().NetworkBlackboard);
        blackboard.SetInt(GetAllBlackboardDefs().NetworkBlackboard.DevicesCount, this.m_npcCount);
        blackboard.SetBool(GetAllBlackboardDefs().NetworkBlackboard.OfficerBreach, false);
        blackboard.SetBool(GetAllBlackboardDefs().NetworkBlackboard.RemoteBreach, true);
        blackboard.SetBool(GetAllBlackboardDefs().NetworkBlackboard.SuicideBreach, false);
        blackboard.SetVariant(GetAllBlackboardDefs().NetworkBlackboard.MinigameDef, ToVariant(this.m_minigameDefinition), true);
        blackboard.SetString(GetAllBlackboardDefs().NetworkBlackboard.NetworkName, this.m_networkName, true);
        blackboard.SetEntityID(GetAllBlackboardDefs().NetworkBlackboard.DeviceID, GetPlayer(gameInstance).GetEntityID(), true);
        blackboard.SetInt(GetAllBlackboardDefs().NetworkBlackboard.Attempt, this.m_attempt);

        // CRITICAL FIX: Set HackingMinigame.Entity for auto-PING feature
        // BonusDaemonUtils.ApplyBonusDaemons() reads this to execute PING QuickHack
        // Without this, auto-PING is skipped in RemoteBreach (only AccessPoint has entity set)
        let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gameInstance).Get(GetAllBlackboardDefs().HackingMinigame);

        // RemoteBreach: m_targetHack is ScriptableDeviceComponentPS (PersistentState), not Entity
        // Need to get Entity from PS using GetOwnerEntityWeak()
        let targetEntity: wref<Entity>;

        // Try direct Entity cast first (for future compatibility)
        targetEntity = this.m_targetHack as Entity;

        if !IsDefined(targetEntity) {
            // If direct cast fails, try getting Entity from DevicePS
            let devicePS: ref<ScriptableDeviceComponentPS> = this.m_targetHack as ScriptableDeviceComponentPS;
            if IsDefined(devicePS) {
                targetEntity = devicePS.GetOwnerEntityWeak() as Entity;
                if !IsDefined(targetEntity) {
                    BNWarn("RemoteBreach", "GetOwnerEntityWeak() returned null - auto-PING will not work");
                }
            } else {
                BNWarn("RemoteBreach", "m_targetHack is not DevicePS - auto-PING will not work");
            }
        }

        // Set entity in blackboard if we have it
        if IsDefined(targetEntity) {
            minigameBB.SetVariant(GetAllBlackboardDefs().HackingMinigame.Entity, ToVariant(targetEntity));
        }

        // Send PSM event (from parent's implementation)
        let psmEvent: ref<PSMPostponedParameterBool> = new PSMPostponedParameterBool();
        psmEvent.id = n"NanoWireRemoteBreach";
        psmEvent.value = true;
        GameInstance.GetPlayerSystem(gameInstance).GetLocalPlayerMainGameObject().QueueEvent(psmEvent);
    }

    // ============================================================================
    // GetCost Override: Return calculated RAM cost
    // ============================================================================
    // Override GetCost to return calculated RAM cost
    public func GetCost() -> Int32 {
        // Always return the calculated cost (or 0 if not set)
        return this.m_calculatedRAMCost;
    }

    // Override PayCost to consume RAM
    public func PayCost(opt checkForOverclockedState: Bool) -> Bool {
        if this.m_calculatedRAMCost <= 0 {
            return true; // No cost to pay
        }

        let executor: ref<GameObject> = this.GetExecutor();
        if !IsDefined(executor) {
            return false;
        }

        let statPoolSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(executor.GetGame());
        let executorID: StatsObjectID = Cast<StatsObjectID>(executor.GetEntityID());
        let currentRAM: Float = statPoolSystem.GetStatPoolValue(executorID, gamedataStatPoolType.Memory, false);
        let costFloat: Float = Cast<Float>(this.m_calculatedRAMCost);

        // Check if player has enough RAM
        if currentRAM < costFloat {
            return false;
        }

        // Deduct RAM
        let newRAM: Float = currentRAM - costFloat;
        statPoolSystem.RequestSettingStatPoolValue(executorID, gamedataStatPoolType.Memory, newRAM, executor, false);

        return true;
    }

    // Override CanPayCost to check if player has enough RAM
    public func CanPayCost(opt user: ref<GameObject>, opt checkForOverclockedState: Bool) -> Bool {
        if this.m_calculatedRAMCost <= 0 {
            return true; // No cost required
        }

        let executor: ref<GameObject>;
        if IsDefined(user) {
            executor = user;
        } else {
            executor = this.GetExecutor();
        }

        if !IsDefined(executor) {
            return false;
        }

        let statPoolSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(executor.GetGame());
        let executorID: StatsObjectID = Cast<StatsObjectID>(executor.GetEntityID());
        let currentRAM: Float = statPoolSystem.GetStatPoolValue(executorID, gamedataStatPoolType.Memory, false);

        return currentRAM >= Cast<Float>(this.m_calculatedRAMCost);
    }

    // Override IsPossible to lock action when insufficient RAM
    public func IsPossible(target: wref<GameObject>, opt actionRecord: wref<ObjectAction_Record>, opt objectActionsCallbackController: wref<gameObjectActionsCallbackController>) -> Bool {
        // First check base prerequisites
        if !super.IsPossible(target, actionRecord, objectActionsCallbackController) {
            return false;
        }

        // Then check if player has enough RAM
        return this.CanPayCost();
    }

    // Get target device (for callback access)
    public func GetTargetDevice() -> wref<ScriptableDeviceComponentPS> {
        // m_targetHack is inherited from CustomAccessBreach
        // It's a GameObject reference to the target
        if IsDefined(this.m_targetHack) {
            let device: ref<Device> = this.m_targetHack as Device;
            if IsDefined(device) {
                return device.GetDevicePS();
            }
        }
        return null;
    }

    // Set StateSystem target for DeviceDaemonAction to retrieve
    // This is CRITICAL for Basic/NPC/Camera/Turret daemon execution
    //
    // ARCHITECTURE: Extract Method pattern to reduce nesting (max 2 levels)
    // Each target type handled by dedicated helper method with early returns
    private func SetStateSystemTarget(gameInstance: GameInstance) -> Void {
        if !IsDefined(this.m_targetHack) {
            BNWarn("RemoteBreach", "m_targetHack not defined - cannot set StateSystem target");
            return;
        }

        let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);

        // Try setting target as PersistentState (most common for RemoteBreach)
        if this.TrySetPersistentStateTarget(container) {
            return;
        }

        // Try setting target as Device (Computer or generic Device)
        if this.TrySetDeviceTarget(container) {
            return;
        }

        // Try setting target as Vehicle
        if this.TrySetVehicleTarget(container) {
            return;
        }

        BNError("RemoteBreach", "Failed to set StateSystem target - unknown target type");
    }

    // Helper: Try to set StateSystem target as PersistentState
    // Returns true if successful, false otherwise
    private func TrySetPersistentStateTarget(container: ref<ScriptableSystemsContainer>) -> Bool {
        let devicePS: ref<ScriptableDeviceComponentPS> = this.m_targetHack as ScriptableDeviceComponentPS;
        if !IsDefined(devicePS) {
            return false;
        }

        // Try Computer first
        if this.TrySetComputerTarget(container, devicePS) {
            return true;
        }

        // Fall back to generic Device
        return this.TrySetGenericDeviceTarget(container, devicePS);
    }

    // Helper: Try to set StateSystem target as Device (Computer or generic)
    // Returns true if successful, false otherwise
    private func TrySetDeviceTarget(container: ref<ScriptableSystemsContainer>) -> Bool {
        let device: ref<Device> = this.m_targetHack as Device;
        if !IsDefined(device) {
            return false;
        }

        let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
        if !IsDefined(devicePS) {
            BNError("RemoteBreach", "GetDevicePS() returned null");
            return false;
        }

        // Try Computer first
        if this.TrySetComputerTarget(container, devicePS) {
            return true;
        }

        // Fall back to generic Device
        return this.TrySetGenericDeviceTarget(container, devicePS);
    }

    // Helper: Try to set StateSystem target as Computer
    private func TrySetComputerTarget(
        container: ref<ScriptableSystemsContainer>,
        devicePS: ref<ScriptableDeviceComponentPS>
    ) -> Bool {
        let computerPS: ref<ComputerControllerPS> = devicePS as ComputerControllerPS;
        if !IsDefined(computerPS) {
            return false;
        }

        let computerStateSystem: ref<RemoteBreachStateSystem> = container.Get(BNConstants.CLASS_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
        if !IsDefined(computerStateSystem) {
            BNError("RemoteBreach", "RemoteBreachStateSystem not found");
            return false;
        }

        computerStateSystem.SetCurrentComputer(computerPS);
        return true;
    }

    // Helper: Try to set StateSystem target as generic Device
    private func TrySetGenericDeviceTarget(
        container: ref<ScriptableSystemsContainer>,
        devicePS: ref<ScriptableDeviceComponentPS>
    ) -> Bool {
        let deviceStateSystem: ref<DeviceRemoteBreachStateSystem> = container.Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as DeviceRemoteBreachStateSystem;
        if !IsDefined(deviceStateSystem) {
            BNError("RemoteBreach", "DeviceRemoteBreachStateSystem not found");
            return false;
        }

        deviceStateSystem.SetCurrentDevice(devicePS, this.m_networkName);
        return true;
    }

    // Helper: Try to set StateSystem target as Vehicle
    private func TrySetVehicleTarget(container: ref<ScriptableSystemsContainer>) -> Bool {
        let vehicle: ref<VehicleObject> = this.m_targetHack as VehicleObject;
        if !IsDefined(vehicle) {
            return false;
        }

        let vehiclePS: ref<VehicleComponentPS> = vehicle.GetVehiclePS();
        if !IsDefined(vehiclePS) {
            BNError("RemoteBreach", "GetVehiclePS() returned null");
            return false;
        }

        let vehicleStateSystem: ref<VehicleRemoteBreachStateSystem> = container.Get(BNConstants.CLASS_VEHICLE_REMOTE_BREACH_STATE_SYSTEM()) as VehicleRemoteBreachStateSystem;
        if !IsDefined(vehicleStateSystem) {
            return false;
        }

        vehicleStateSystem.SetCurrentVehicle(vehiclePS, this.m_networkName);
        return true;
    }
}
