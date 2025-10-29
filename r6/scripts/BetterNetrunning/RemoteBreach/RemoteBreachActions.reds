// ============================================================================
// RemoteBreach - ScriptableDeviceAction Extensions
// ============================================================================
//
// PURPOSE:
// Extends RemoteBreach QuickHack with BetterNetrunning functionality
// by wrapping parent class (ScriptableDeviceAction) virtual methods.
//
// FUNCTIONALITY:
// - GetCost(): Dynamic RAM cost calculation based on Memory stat
// - IsPossible(): RAM availability check + RemoteBreach lock validation
// - CompleteAction(): RemoteBreach target tracking for network unlock
//
// ARCHITECTURE:
// - @wrapMethod(ScriptableDeviceAction) pattern for parent class extension
// - IsA(n"RemoteBreach") check for targeted processing (<1% overhead)
// - Early return pattern for non-RemoteBreach actions (mod compatibility)
// - Composed Method pattern with focused helper functions
//
// DEPENDENCIES:
// - BetterNetrunning.RemoteBreach.RemoteBreachCostCalculator (RAM cost)
// - BetterNetrunning.RemoteBreach.RemoteBreachLockSystem (lock check)
// - BetterNetrunning.RemoteBreach.RemoteBreachStateSystem (state)
// - BetterNetrunningConfig.* (settings)
//
// TECHNICAL NOTES:
// - RemoteBreach class has NO methods (only SetProperties)
// - GetCost/IsPossible/CompleteAction inherited from ScriptableDeviceAction
// - Must wrap parent class and use IsA() for RemoteBreach identification
// - wrappedMethod() preserves vanilla behavior + other mods' extensions
// ============================================================================

module BetterNetrunning.RemoteBreach

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Breach.*
import BetterNetrunning.Utils.*

// ============================================================================
// ScriptableDeviceAction Extensions for RemoteBreach
// ============================================================================

/*
 * Calculates RAM cost for RemoteBreach action with dynamic scaling
 *
 * VANILLA DIFF: RemoteBreach.GetCost() returns 0 (no RAM cost)
 * RATIONALE: Introduce dynamic cost scaling based on Memory stat and device type
 * ARCHITECTURE: Early return pattern (max 1 nesting level), single responsibility
 */
@wrapMethod(ScriptableDeviceAction)
public func GetCost() -> Int32 {
    // Early return: Not RemoteBreach action
    if !this.IsA(n"RemoteBreach") {
        return wrappedMethod();
    }

    // Calculate RAM cost as percentage of max RAM
    let player: ref<GameObject> = this.GetExecutor();
    let gameInstance: GameInstance = player.GetGame();

    return RemoteBreachCostCalculator.CalculateCost(player, gameInstance);
}

/*
 * Validates RemoteBreach execution prerequisites
 *
 * VANILLA DIFF: Adds RAM availability check + RemoteBreach lock validation
 * RATIONALE: Prevent RemoteBreach spam, enforce cooldown period after breach failure
 * ARCHITECTURE: Guard clause pattern (max 2 nesting levels)
 */
@wrapMethod(BaseScriptableAction)
public func IsPossible(target: wref<GameObject>, opt actionRecord: wref<ObjectAction_Record>, opt objectActionsCallbackController: wref<gameObjectActionsCallbackController>) -> Bool {
    // Early return: Not RemoteBreach action
    if !this.IsA(n"RemoteBreach") {
        return wrappedMethod(target, actionRecord, objectActionsCallbackController);
    }

    // Call vanilla IsPossible checks
    let isPossible: Bool = wrappedMethod(target, actionRecord, objectActionsCallbackController);

    // Guard: Vanilla rejection takes priority
    if !isPossible {
        return false;
    }

    // Check RAM availability
    if !this.CanPayRemoteBreachCost() {
        return false;
    }

    // Check RemoteBreach lock (timestamp-based cooldown)
    if !this.IsRemoteBreachUnlocked() {
        return false;
    }

    return true;
}

/*
 * Tracks RemoteBreach target for network unlock processing
 *
 * VANILLA DIFF: Applies BetterNetrunning extensions via shared BreachHelpers
 * RATIONALE: DRY compliance - reuses BreachHelpers.ApplyBreachExtensions()
 * ARCHITECTURE: Template Method pattern via BreachHelpers
 */
@wrapMethod(ScriptableDeviceAction)
public func CompleteAction(gameInstance: GameInstance) -> Void {
    // Early return: Not RemoteBreach action
    if !this.IsA(n"RemoteBreach") {
        wrappedMethod(gameInstance);
        return;
    }

    // Call vanilla CompleteAction
    wrappedMethod(gameInstance);

    BNDebug("RemoteBreachActions", "RemoteBreach completed - applying extensions");

    // Apply RemoteBreach extensions
    this.ApplyRemoteBreachExtensions(gameInstance);

    // Register RemoteBreach target in state system (for RefreshSlaves processing)
    this.RegisterRemoteBreachTarget(gameInstance);
}

// ============================================================================
// Helper Methods (Private API)
// ============================================================================

/*
 * Apply RemoteBreach-specific extensions
 *
 * PURPOSE: Apply BetterNetrunning breach extensions using shared BreachHelpers
 * ARCHITECTURE: Template Method pattern - delegates to BreachHelpers.ExecuteRadiusUnlocks()
 *
 * PROCESSING ORDER:
 * 1. Extract unlock flags from minigame programs
 * 2. Initialize statistics (if enabled)
 * 3. Apply shared breach extensions via BreachHelpers (Radius/NPC/Position)
 * 4. Network unlock deferred to RefreshSlaves (via RemoteBreachStateSystem)
 *
 * RATIONALE:
 * DRY compliance - eliminates 30 lines of duplicate code
 * Reuses BreachHelpers.ExecuteRadiusUnlocks() (83% code reduction)
 * Single point of change for breach extension logic
 */
@addMethod(ScriptableDeviceAction)
private func ApplyRemoteBreachExtensions(gameInstance: GameInstance) -> Void {
    // Get device PS
    let devicePS: ref<ScriptableDeviceComponentPS> = this.GetOwnerPS(gameInstance);
    if !IsDefined(devicePS) {
        BNError("RemoteBreachActions", "Failed to get device PS");
        return;
    }

    // Get minigame programs from Blackboard
    let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gameInstance)
        .Get(GetAllBlackboardDefs().HackingMinigame);
    let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(
        minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms)
    );

    // Extract unlock flags from minigame programs
    let unlockFlags: BreachUnlockFlags = DaemonFilterUtils.ExtractUnlockFlags(minigamePrograms);

        // Initialize statistics (always enabled for consistency with AccessPoint)
        let stats: ref<BreachSessionStats> = BreachSessionStats.Create(
            BNConstants.BREACH_TYPE_REMOTE_BREACH(),
            devicePS.GetDeviceName()
        );
        BreachStatisticsCollector.CollectExecutedDaemons(minigamePrograms, stats);

    // Apply shared breach extensions (DRY compliance)
    BreachHelpers.ExecuteRadiusUnlocks(devicePS, unlockFlags, stats, gameInstance);

    BNDebug("RemoteBreachActions", "RemoteBreach extensions completed");
}

/*
 * Checks if player has sufficient RAM for RemoteBreach cost
 * Delegates to RemoteBreachCostCalculator for consistent cost logic
 */
@addMethod(BaseScriptableAction)
private func CanPayRemoteBreachCost() -> Bool {
    let cost: Int32 = this.GetCost();
    let player: ref<GameObject> = this.GetExecutor();
    let gameInstance: GameInstance = player.GetGame();

    return RemoteBreachCostCalculator.CanPayCost(player, cost, gameInstance);
}

/*
 * Checks if RemoteBreach is not locked by timestamp-based cooldown
 * Delegates to RemoteBreachLockSystem for centralized lock management
 */
@addMethod(BaseScriptableAction)
private func IsRemoteBreachUnlocked() -> Bool {
    let player: ref<GameObject> = this.GetExecutor();
    let gameInstance: GameInstance = player.GetGame();
    let devicePS: ref<ScriptableDeviceComponentPS> = this.GetOwnerPS(gameInstance) as ScriptableDeviceComponentPS;

    // Guard: Invalid device PS
    if !IsDefined(devicePS) {
        return true; // No lock if device not found
    }

    return !RemoteBreachLockSystem.IsRemoteBreachLockedByTimestamp(
        devicePS,
        gameInstance
    );
}

/*
 * Registers RemoteBreach target in RemoteBreachStateSystem
 * Used by FinalizeNetrunnerDive to apply network unlock effects
 */
@addMethod(ScriptableDeviceAction)
private func RegisterRemoteBreachTarget(gameInstance: GameInstance) -> Void {
    let stateSystem: ref<RemoteBreachStateSystem> = GameInstance
        .GetScriptableSystemsContainer(gameInstance)
        .Get(n"BetterNetrunning.RemoteBreach.RemoteBreachStateSystem") as RemoteBreachStateSystem;

    // Guard: State system not available
    if !IsDefined(stateSystem) {
        return;
    }

    // Get device PS as target identifier
    let devicePS: ref<ScriptableDeviceComponentPS> = this.GetOwnerPS(gameInstance) as ScriptableDeviceComponentPS;

    // Guard: Invalid device PS
    if !IsDefined(devicePS) {
        return;
    }

    // Register target in state system
    stateSystem.RegisterRemoteBreachTarget(devicePS);

    BNDebug(BNConstants.BREACH_TYPE_REMOTE_BREACH(), "RemoteBreach target registered: " + devicePS.GetDeviceName());
}
