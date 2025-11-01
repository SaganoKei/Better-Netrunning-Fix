// ============================================================================
// BetterNetrunning - Device Distance Utilities
// ============================================================================
//
// PURPOSE:
// Provides unified physical distance calculation for device proximity checks
//
// FUNCTIONALITY:
// - 2D distance calculation using squared distance (sqrt avoidance)
// - Radius-based proximity filtering
// - Device entity position extraction with validation
//
// ARCHITECTURE:
// - Static utility class (no instantiation required)
// - Performance-optimized: Uses Vector4.DistanceSquared2D (O(1), no sqrt)
// - Guard Clause pattern for null safety
// - Used by: RadialUnlockSystem, RemoteBreachLockSystem, PlayerPuppet extensions
//

module BetterNetrunning.Core

public abstract class DeviceDistanceUtils {

  /*
   * Calculates squared 2D distance between two positions
   * @param pos1 - First position
   * @param pos2 - Second position
   * @return Squared distance (avoids sqrt for performance)
   */
  public static func GetDistanceSquared2D(pos1: Vector4, pos2: Vector4) -> Float {
    return Vector4.DistanceSquared2D(pos1, pos2);
  }

  /*
   * Checks if position is within radius
   * @param position - Position to check
   * @param centerPosition - Center point
   * @param radiusMeters - Radius in meters
   * @return True if position is within radius
   */
  public static func IsPositionWithinRadius(
    position: Vector4,
    centerPosition: Vector4,
    radiusMeters: Float
  ) -> Bool {
    let radiusSquared: Float = radiusMeters * radiusMeters;
    let distanceSquared: Float = DeviceDistanceUtils.GetDistanceSquared2D(position, centerPosition);
    return distanceSquared <= radiusSquared;
  }

  /*
   * Extracts world position from device entity
   * @param device - Device persistent state
   * @param gameInstance - Current game instance
   * @return Device position, or error signal (-999999) if not found
   */
  public static func GetDevicePosition(
    device: ref<DeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Vector4 {
    // Guard: Device validation
    if !IsDefined(device) {
      return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
    }

    // Try GetOwnerEntityWeak() first (faster, used by RadialBreachGating)
    let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;
    if IsDefined(deviceEntity) {
      return deviceEntity.GetWorldPosition();
    }

    // Fallback: GameInstance.FindEntityByID() (slower, used by RemoteBreachLockSystem)
    let entityID: EntityID = PersistentID.ExtractEntityID(device.GetID());
    let deviceObject: ref<Device> = GameInstance.FindEntityByID(gameInstance, entityID) as Device;
    if IsDefined(deviceObject) {
      return deviceObject.GetWorldPosition();
    }

    // Error signal
    return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
  }

  /// Checks if device entity is within radius (combines position extraction + distance check)
  /// Fallback Behavior: Returns true if entity not found (allows unlock/processing)
  /// Use Case: Physical proximity filtering for breach operations
  public static func IsDeviceWithinRadius(
    device: ref<DeviceComponentPS>,
    centerPosition: Vector4,
    radiusMeters: Float,
    gameInstance: GameInstance
  ) -> Bool {
    let devicePosition: Vector4 = DeviceDistanceUtils.GetDevicePosition(device, gameInstance);

    // Check for error signal
    if devicePosition.X <= -999000.0 {
      return true; // Fallback: allow if position unavailable
    }

    return DeviceDistanceUtils.IsPositionWithinRadius(devicePosition, centerPosition, radiusMeters);
  }
}
