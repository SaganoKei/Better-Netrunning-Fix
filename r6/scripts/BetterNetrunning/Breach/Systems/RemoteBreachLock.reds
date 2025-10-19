// ============================================================================
// Remote Breach Lock System - Position-Based RemoteBreach Locking
// ============================================================================
//
// PURPOSE:
// Prevent RemoteBreach usage in 50m radius around breach failure locations
// for configurable duration (default 10 minutes) to balance RemoteBreach
// risk-free gameplay.
//
// FUNCTIONALITY:
// - Failure Position Recording: Store breach failure positions and timestamps
// - Lock Range Check: Determine if device is within 50m of any failure position
// - Lock Expiration: Auto-expire locks after configurable duration (default 10 minutes)
// - QuickHack Filtering: Remove RemoteBreach actions from locked devices
//
// LOCK SCOPE:
// - Only affects RemoteBreach actions (RemoteBreachAction, DeviceRemoteBreachAction, VehicleRemoteBreachAction)
// - Does NOT affect: AP Breach, Unconscious NPC Breach, other quickhacks
//
// ARCHITECTURE:
// - Persistent fields on PlayerPuppet (survive save/load)
// - Helper function for lock checking (IsRemoteBreachLockedForDevice)
// - @wrapMethod on GetQuickHackActions() for action filtering
// - Max nesting depth: 2 levels
//
// DEPENDENCIES:
// - BetterNetrunningConfig: Settings control (RemoteBreachLockDurationMinutes)
// - Common/Logger.reds: Debug logging (BNLog)
// - Breach/BreachPenaltySystem.reds: Failure position recording
// ============================================================================

module BetterNetrunning.Breach.Systems
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*

// ============================================================================
// PlayerPuppet Extensions - Persistent Failure Position Storage
// ============================================================================
//
// Store breach failure positions and timestamps for RemoteBreach locking.
// Uses persistent fields to survive save/load cycles.
//
// FIELDS:
// - m_betterNetrunning_remoteBreachFailedPositions: Array of failure positions (Vector4)
// - m_betterNetrunning_remoteBreachFailedTimestamps: Array of failure times (Float)
//
// ARRAY MANAGEMENT:
// - ArrayPush() adds new failures (BreachPenaltySystem.reds)
// - Expired entries cleaned up during lock checks
// ============================================================================

@addField(PlayerPuppet)
public persistent let m_betterNetrunning_remoteBreachFailedPositions: array<Vector4>;

@addField(PlayerPuppet)
public persistent let m_betterNetrunning_remoteBreachFailedTimestamps: array<Float>;

// ============================================================================
// RemoteBreachLockUtils - Static Helper Class for Lock Checking
// ============================================================================
//
// Provides public static methods for RemoteBreach lock checks that can be
// called from other modules (e.g., RemoteBreachVisibility).
//
// ARCHITECTURE:
// - Static class (no instantiation required)
// - Public interface for lock checking logic
// - Wraps private implementation
// ============================================================================

public class RemoteBreachLockUtils {
  // Public static wrapper for IsRemoteBreachLockedForDevice
  public static func IsRemoteBreachLockedForDevice(
    player: ref<PlayerPuppet>,
    devicePosition: Vector4,
    gameInstance: GameInstance
  ) -> Bool {
    // Validate arrays exist and have matching sizes
    if !IsDefined(player) {
      BNError("RemoteBreachLock", "Player not defined");
      return false;
    }

    let positionsSize: Int32 = ArraySize(player.m_betterNetrunning_remoteBreachFailedPositions);
    let timestampsSize: Int32 = ArraySize(player.m_betterNetrunning_remoteBreachFailedTimestamps);

    if positionsSize != timestampsSize {
      BNError("RemoteBreachLock", "Array size mismatch (positions: " + IntToString(positionsSize) + ", timestamps: " + IntToString(timestampsSize) + ")");
      // Clear both arrays to reset state
      ArrayClear(player.m_betterNetrunning_remoteBreachFailedPositions);
      ArrayClear(player.m_betterNetrunning_remoteBreachFailedTimestamps);
      return false;
    }

    if positionsSize == 0 {
      // No failures recorded, not locked
      return false;
    }

    let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
    let lockDurationSeconds: Float = Cast<Float>(
      BetterNetrunningSettings.RemoteBreachLockDurationMinutes() * 60
    );
    let lockRange: Float = DeviceTypeUtils.GetRadialBreachRange(gameInstance);

    let i: Int32 = 0;
    while i < ArraySize(player.m_betterNetrunning_remoteBreachFailedPositions) {
      let failedPosition: Vector4 = player.m_betterNetrunning_remoteBreachFailedPositions[i];
      let failedTime: Float = player.m_betterNetrunning_remoteBreachFailedTimestamps[i];

      if currentTime - failedTime > lockDurationSeconds {
        ArrayErase(player.m_betterNetrunning_remoteBreachFailedPositions, i);
        ArrayErase(player.m_betterNetrunning_remoteBreachFailedTimestamps, i);
      } else {
        let distance: Float = Vector4.Distance(devicePosition, failedPosition);
        if distance <= lockRange {
          BNDebug(
            "RemoteBreachLock",
            "Device locked (distance: "
            + FloatToString(distance)
            + "m, time since failure: "
            + FloatToString(currentTime - failedTime)
            + "s)"
          );
          return true;
        }
        i += 1;
      }
    }
    return false;
  }

  // ============================================================================
  // Shared logic for checking RemoteBreach action executability.
  //
  // Combines RAM cost check with breach failure lock check.
  //
  // PARAMETERS:
  // - action: RemoteBreach action to validate
  // - devicePS: Device providing action
  // - player: Player attempting action
  //
  // RETURNS:
  // - true if action can execute (sufficient RAM, not locked)
  // - false if action should be grayed out
  //
  // DEPRECATED: Use GetRemoteBreachInactiveReason() for LocKey support.
  // This method returns Bool only - new code should use the LocKey variant.
  // ============================================================================
  public static func CanExecuteRemoteBreachAction(
    action: ref<BaseScriptableAction>,
    devicePS: ref<ScriptableDeviceComponentPS>,
    player: ref<PlayerPuppet>
  ) -> Bool {
    // First check: Can player afford the RAM cost?
    if !action.CanPayCost(player) {
      return false;
    }

    // Second check: Is breach failure penalty enabled?
    if !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
      return true;
    }

    // Third check: Is device within breach failure lock range?
    let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(deviceEntity) {
      return true;
    }

    let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
    if RemoteBreachLockUtils.IsRemoteBreachLockedForDevice(player, devicePosition, devicePS.GetGameInstance()) {
      return false;
    }

    return true;
  }

  // ============================================================================
  // Get RemoteBreach inactive reason with vanilla-compatible LocKeys.
  //
  // Checks RAM cost and position penalty, returns appropriate LocKey for
  // SetInactiveWithReason() display.
  //
  // PARAMETERS:
  // - action: RemoteBreach action to validate
  // - devicePS: Device providing action
  // - player: Player attempting action
  // - out canExecute: [OUTPUT] true if action is executable
  //
  // RETURNS:
  // - "" (empty) if canExecute=true
  // - "LocKey#27398" if RAM insufficient (バニラ: "RAM不足")
  // - "LocKey#7021" if position penalty (バニラ: "ネットワークのブリーチ失敁E)
  //
  // USAGE:
  // ```
  // let canExecute: Bool;
  // let reason: String = RemoteBreachLockUtils.GetRemoteBreachInactiveReason(
  //   action, this, player, canExecute
  // );
  // action.SetInactiveWithReason(canExecute, reason);
  // ```
  // ============================================================================
  public static func GetRemoteBreachInactiveReason(
    action: ref<BaseScriptableAction>,
    devicePS: ref<ScriptableDeviceComponentPS>,
    player: ref<PlayerPuppet>,
    out canExecute: Bool
  ) -> String {
    canExecute = true;

    // Check 1: RAM insufficient (highest priority)
    if !action.CanPayCost(player) {
      canExecute = false;
      return BNConstants.LOCKEY_RAM_INSUFFICIENT();
    }

    // Check 2: Breach failure penalty (only if enabled in settings)
    if !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
      return ""; // No penalty, action executable
    }

    // Check 3: Position-based lock (within 50m of failure)
    let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(deviceEntity) {
      return ""; // No device entity, action executable
    }

    let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
    if RemoteBreachLockUtils.IsRemoteBreachLockedForDevice(player, devicePosition, devicePS.GetGameInstance()) {
      canExecute = false;
      return BNConstants.LOCKEY_NO_NETWORK_ACCESS(); // "ネットワークのブリーチ失敁E
    }

    return ""; // All checks passed, action executable
  }
}
