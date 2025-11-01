// ============================================================================
// BetterNetrunning - Unlock Expiration Management
// ============================================================================
//
// PURPOSE:
// Manages time-based expiration of device quickhack unlocks
//
// FUNCTIONALITY:
// - Timestamp expiration calculation for 4 device types (Vehicle/Camera/Turret/Basic)
// - Automatic timestamp reset on expiration
// - Device type-specific timestamp field management
//
// ARCHITECTURE:
// - Single Responsibility: Expiration checking only (no JackIn control, no action removal)
// - Strategy Pattern: Device type-specific expiration logic
// - Shallow nesting (max 2 levels) using Extract Method pattern
//

module BetterNetrunning.RemoteBreach.Common

import BetterNetrunning.Core.TimeUtils
import BetterNetrunning.Utils.*
import BetterNetrunningConfig.*

// ============================================================================
// Expiration Check Result
// ============================================================================

/*
 * Result of unlock expiration check for a device.
 *
 * Fields:
 * - isUnlocked: Device is currently unlocked (timestamp valid + within duration)
 * - wasExpired: Device timestamp expired during this check (one-time transition)
 * - expiredDeviceType: Type of device that expired (for logging/debugging)
 */
public struct UnlockExpirationResult {
  public let isUnlocked: Bool;
  public let wasExpired: Bool;
  public let expiredDeviceType: CName;
}

// ============================================================================
// Expiration Utilities
// ============================================================================

public abstract class UnlockExpirationUtils {

  /*
   * Checks unlock expiration for device and resets timestamp if expired.
   *
   * Processing steps:
   * - Reads device type-specific timestamp field
   * - Calculates elapsed time vs configured duration
   * - Resets timestamp to 0.0 on expiration (one-time state mutation)
   * - Returns structured result for caller orchestration
   *
   * Uses Strategy Pattern with 4 device type branches.
   */
  public static func CheckUnlockExpiration(devicePS: ref<ScriptableDeviceComponentPS>) -> UnlockExpirationResult {
    let result: UnlockExpirationResult;
    result.isUnlocked = false;
    result.wasExpired = false;
    result.expiredDeviceType = n"";

    let unlockDurationHours: Int32 = BetterNetrunningSettings.QuickhackUnlockDurationHours();
    let gameInstance: GameInstance = devicePS.GetGameInstance();

    // Check 1: Vehicle-specific unlock (via UnlockQuickhacks daemon)
    if IsDefined(devicePS as VehicleComponentPS) {
      UnlockExpirationUtils.CheckVehicleExpiration(devicePS, unlockDurationHours, gameInstance, result);
    }
    // Check 2: Camera-specific unlock (via UnlockCameraQuickhacks daemon)
    else if DaemonFilterUtils.IsCamera(devicePS) {
      UnlockExpirationUtils.CheckCameraExpiration(devicePS, unlockDurationHours, gameInstance, result);
    }
    // Check 3: Turret-specific unlock (via UnlockTurretQuickhacks daemon)
    else if DaemonFilterUtils.IsTurret(devicePS) {
      UnlockExpirationUtils.CheckTurretExpiration(devicePS, unlockDurationHours, gameInstance, result);
    }
    // Check 4: Basic device unlock (via UnlockQuickhacks daemon)
    else {
      UnlockExpirationUtils.CheckBasicDeviceExpiration(devicePS, unlockDurationHours, gameInstance, result);
    }

    return result;
  }

  /*
   * Checks vehicle unlock expiration (UnlockQuickhacks daemon).
   * Uses early return pattern with timestamp validation.
   */
  private static func CheckVehicleExpiration(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockDurationHours: Int32,
    gameInstance: GameInstance,
    out result: UnlockExpirationResult
  ) -> Void {
    let timestamp: Float = devicePS.m_betterNetrunningUnlockTimestampBasic;

    // Early return: Already expired or never unlocked
    if timestamp == 0.0 { return; }

    // Permanent unlock (duration = 0)
    if unlockDurationHours == 0 {
      result.isUnlocked = true;
      return;
    }

    // Time-limited unlock - check expiration
    let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
    let elapsedTime: Float = currentTime - timestamp;
    let durationSeconds: Float = Cast<Float>(unlockDurationHours) * 3600.0;

    if elapsedTime > durationSeconds {
      // Expired - reset timestamp (one-time state mutation)
      devicePS.m_betterNetrunningUnlockTimestampBasic = 0.0;
      result.wasExpired = true;
      result.expiredDeviceType = n"Vehicle";
    } else {
      result.isUnlocked = true;
    }
  }

  /*
   * Checks camera unlock expiration (UnlockCameraQuickhacks daemon).
   * Uses early return pattern with timestamp validation.
   */
  private static func CheckCameraExpiration(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockDurationHours: Int32,
    gameInstance: GameInstance,
    out result: UnlockExpirationResult
  ) -> Void {
    let timestamp: Float = devicePS.m_betterNetrunningUnlockTimestampCameras;

    // Early return: Already expired or never unlocked
    if timestamp == 0.0 { return; }

    // Permanent unlock (duration = 0)
    if unlockDurationHours == 0 {
      result.isUnlocked = true;
      return;
    }

    // Time-limited unlock - check expiration
    let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
    let elapsedTime: Float = currentTime - timestamp;
    let durationSeconds: Float = Cast<Float>(unlockDurationHours) * 3600.0;

    if elapsedTime > durationSeconds {
      // Expired - reset timestamp (one-time state mutation)
      devicePS.m_betterNetrunningUnlockTimestampCameras = 0.0;
      result.wasExpired = true;
      result.expiredDeviceType = n"Camera";
    } else {
      result.isUnlocked = true;
    }
  }

  /*
   * Checks turret unlock expiration (UnlockTurretQuickhacks daemon).
   * Uses early return pattern with timestamp validation.
   */
  private static func CheckTurretExpiration(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockDurationHours: Int32,
    gameInstance: GameInstance,
    out result: UnlockExpirationResult
  ) -> Void {
    let timestamp: Float = devicePS.m_betterNetrunningUnlockTimestampTurrets;

    // Early return: Already expired or never unlocked
    if timestamp == 0.0 { return; }

    // Permanent unlock (duration = 0)
    if unlockDurationHours == 0 {
      result.isUnlocked = true;
      return;
    }

    // Time-limited unlock - check expiration
    let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
    let elapsedTime: Float = currentTime - timestamp;
    let durationSeconds: Float = Cast<Float>(unlockDurationHours) * 3600.0;

    if elapsedTime > durationSeconds {
      // Expired - reset timestamp (one-time state mutation)
      devicePS.m_betterNetrunningUnlockTimestampTurrets = 0.0;
      result.wasExpired = true;
      result.expiredDeviceType = n"Turret";
    } else {
      result.isUnlocked = true;
    }
  }

  /*
   * Checks basic device unlock expiration (UnlockQuickhacks daemon).
   * Uses early return pattern with timestamp validation.
   */
  private static func CheckBasicDeviceExpiration(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockDurationHours: Int32,
    gameInstance: GameInstance,
    out result: UnlockExpirationResult
  ) -> Void {
    let timestamp: Float = devicePS.m_betterNetrunningUnlockTimestampBasic;

    // Early return: Already expired or never unlocked
    if timestamp == 0.0 { return; }

    // Permanent unlock (duration = 0)
    if unlockDurationHours == 0 {
      result.isUnlocked = true;
      return;
    }

    // Time-limited unlock - check expiration
    let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
    let elapsedTime: Float = currentTime - timestamp;
    let durationSeconds: Float = Cast<Float>(unlockDurationHours) * 3600.0;

    if elapsedTime > durationSeconds {
      // Expired - reset timestamp (one-time state mutation)
      devicePS.m_betterNetrunningUnlockTimestampBasic = 0.0;
      result.wasExpired = true;
      result.expiredDeviceType = n"Basic";
    } else {
      result.isUnlocked = true;
    }
  }
}
