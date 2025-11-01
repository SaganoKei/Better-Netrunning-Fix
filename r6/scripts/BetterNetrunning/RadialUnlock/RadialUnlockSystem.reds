// ============================================================================
// BetterNetrunning - Radial Unlock System
// ============================================================================
//
// PURPOSE:
// Radial-based network breach tracking for standalone devices
//
// FUNCTIONALITY:
// - Records breached AccessPoint positions in persistent storage
// - Validates standalone devices within configurable breach radius
// - Integrates with RadialBreach MOD for settings
// - Spatial proximity-based device discovery
//
// ARCHITECTURE:
// - Uses GameInstance.GetTargetingSystem() for native device discovery
// - Persistent storage in PlayerPuppet for breach positions
// - Position-based tracking instead of EntityID hashing
// - Configurable breach radius (default 50m)
// ============================================================================

module BetterNetrunning.RadialUnlock

import BetterNetrunning.Core.*
import BetterNetrunning.Integration.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Logging.*
import BetterNetrunningConfig.*

// ============================================================================
// PLAYER PERSISTENT STORAGE
// ============================================================================

// Store breach positions instead of EntityIDs (more reliable)
@addField(PlayerPuppet)
public persistent let m_betterNetrunning_breachedAccessPointPositions: array<Vector4>;

@addField(PlayerPuppet)
public persistent let m_betterNetrunning_breachTimestamps: array<Uint64>;

// ============================================================================
// CONFIGURATION
// ============================================================================

/*
 * Maximum stored breach records (prevents save bloat)
 *
 * @return Maximum number of breach records to store
 */
public func GetMaxBreachRecords() -> Int32 {
  return 50; // Stores AccessPoint IDs only (not device hashes) to minimize save size
}

/*
 * Records to remove when pruning (20% of max)
 *
 * @return Number of oldest records to remove when pruning
 */
public func GetPruneCount() -> Int32 {
  return 10;
}

// ============================================================================
// CORE API
// ============================================================================

/*
 * Records a successful AccessPoint breach by position
 *
 * Called from RefreshSlaves() after breach minigame completion
 * Uses position-based tracking since EntityID retrieval is unreliable
 *
 * @param apPosition - World position of the breached AccessPoint
 * @param gameInstance - Current game instance
 */
public func RecordAccessPointBreachByPosition(apPosition: Vector4, gameInstance: GameInstance) -> Void {
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    return;
  }

  // Check if already recorded (within 1m tolerance)
  let idx: Int32 = 0;
  let tolerance: Float = 1.0; // 1 meter tolerance for duplicate detection
  while idx < ArraySize(player.m_betterNetrunning_breachedAccessPointPositions) {
    let existingPos: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[idx];
    let distance: Float = Vector4.Distance(existingPos, apPosition);

    if distance < tolerance {
      // Update timestamp and return
      player.m_betterNetrunning_breachTimestamps[idx] = GetCurrentTimestamp(gameInstance);
      return;
    }
    idx += 1;
  }

  // Add new record
  ArrayPush(player.m_betterNetrunning_breachedAccessPointPositions, apPosition);
  ArrayPush(player.m_betterNetrunning_breachTimestamps, GetCurrentTimestamp(gameInstance));

  let newSize: Int32 = ArraySize(player.m_betterNetrunning_breachedAccessPointPositions);

  // Prune old records if limit exceeded
  if newSize > GetMaxBreachRecords() {
    PruneOldestBreachRecords(player);
  }
}

/*
 * Legacy function for compatibility - now records by position
 *
 * @param apEntityID - Entity ID of the breached AccessPoint
 * @param gameInstance - Current game instance
 */
public func RecordAccessPointBreach(apEntityID: EntityID, gameInstance: GameInstance) -> Void {
  // Try to get entity position
  let apEntity: wref<GameObject> = GameInstance.FindEntityByID(gameInstance, apEntityID) as GameObject;
  if IsDefined(apEntity) {
    RecordAccessPointBreachByPosition(apEntity.GetWorldPosition(), gameInstance);
  }
}

/*
 * Checks if a standalone device should be unlocked
 *
 * Returns true if device is within breach radius of any recorded AccessPoint
 *
 * @param device - Device power state to check
 * @param gameInstance - Current game instance
 * @return true if device should be unlocked (within breach radius or setting allows)
 */
public func ShouldUnlockStandaloneDevice(device: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Bool {
  // CRITICAL FIX: UnlockIfNoAccessPoint setting logic
  // - UnlockIfNoAccessPoint = true -> Standalone devices ALWAYS unlock (don't require AP)
  // - UnlockIfNoAccessPoint = false -> Standalone devices require nearby breached AP

  if BetterNetrunningSettings.UnlockIfNoAccessPoint() {
    // Setting is TRUE -> Always unlock standalone devices without requiring AP
    return true;
  }

  // Setting is FALSE -> Require nearby breached AccessPoint

  // Get device position
  let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(deviceEntity) {
    return false;
  }

  let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);

  if !IsDefined(player) {
    return false;
  }

  // Check if within radius of any breached AccessPoint
  return IsWithinBreachedAccessPointRadius(devicePosition, player, gameInstance);
}

/*
 * Checks if a position is within breach radius of any recorded AccessPoint
 *
 * Now uses stored positions instead of EntityIDs
 * Uses RadialBreach settings for breach radius (or default 50m)
 *
 * @param position - World position to check
 * @param player - Player puppet instance
 * @param gameInstance - Current game instance
 * @return true if position is within breach radius of any recorded AccessPoint
 */
private func IsWithinBreachedAccessPointRadius(position: Vector4, player: ref<PlayerPuppet>, gameInstance: GameInstance) -> Bool {
  let breachRadius: Float = GetRadialBreachRange(gameInstance);
  let breachRadiusSq: Float = breachRadius * breachRadius; // Use squared distance for performance

  let idx: Int32 = 0;
  while idx < ArraySize(player.m_betterNetrunning_breachedAccessPointPositions) {
    let apPosition: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[idx];
    let distanceSq: Float = Vector4.DistanceSquared(position, apPosition);

    if distanceSq <= breachRadiusSq {
      return true; // Within breach radius
    }

    idx += 1;
  }

  return false; // Not within any breach radius
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/*
 * Removes oldest breach records when storage limit exceeded
 *
 * @param player - Player puppet instance
 */
private func PruneOldestBreachRecords(player: ref<PlayerPuppet>) -> Void {
  let pruneCount: Int32 = GetPruneCount();
  let currentSize: Int32 = ArraySize(player.m_betterNetrunning_breachedAccessPointPositions);

  if currentSize <= pruneCount {
    // Edge case: just clear all
    ArrayClear(player.m_betterNetrunning_breachedAccessPointPositions);
    ArrayClear(player.m_betterNetrunning_breachTimestamps);
    return;
  }

  // Bubble sort to find oldest records (timestamps are already sorted by insertion order,
  // but may be updated, so we need to sort)
  let idx: Int32 = 0;
  while idx < currentSize - 1 {
    let jdx: Int32 = 0;
    while jdx < currentSize - idx - 1 {
      if player.m_betterNetrunning_breachTimestamps[jdx] > player.m_betterNetrunning_breachTimestamps[jdx + 1] {
        // Swap timestamps
        let tempTimestamp: Uint64 = player.m_betterNetrunning_breachTimestamps[jdx];
        player.m_betterNetrunning_breachTimestamps[jdx] = player.m_betterNetrunning_breachTimestamps[jdx + 1];
        player.m_betterNetrunning_breachTimestamps[jdx + 1] = tempTimestamp;

        // Swap positions
        let tempPos: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[jdx];
        player.m_betterNetrunning_breachedAccessPointPositions[jdx] = player.m_betterNetrunning_breachedAccessPointPositions[jdx + 1];
        player.m_betterNetrunning_breachedAccessPointPositions[jdx + 1] = tempPos;
      }
      jdx += 1;
    }
    idx += 1;
  }

  // Remove oldest records
  let removeIdx: Int32 = 0;
  while removeIdx < pruneCount {
    ArrayErase(player.m_betterNetrunning_breachedAccessPointPositions, 0);
    ArrayErase(player.m_betterNetrunning_breachTimestamps, 0);
    removeIdx += 1;
  }
}

/*
 * Returns current game time as Uint64 timestamp
 *
 * @param gameInstance - Current game instance
 * @return Current game time as Uint64
 */
private func GetCurrentTimestamp(gameInstance: GameInstance) -> Uint64 {
  return Cast<Uint64>(TimeUtils.GetCurrentTimestamp(gameInstance));
}

// ============================================================================
// RADIALBREACH INTEGRATION API
// ============================================================================

/*
 * Gets the last breach position for a given AccessPoint
 *
 * Used by RadialBreach integration to filter devices by physical distance
 *
 * @param apPosition - Position of the AccessPoint being checked
 * @param gameInstance - Current game instance
 * @return Position of the last breach (or zero vector if not found)
 */
public func GetLastBreachPosition(apPosition: Vector4, gameInstance: GameInstance) -> Vector4 {
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    BNWarn("RadialUnlock", "GetLastBreachPosition: Player not found");
    return Vector4(0.0, 0.0, 0.0, 1.0);
  }

  // Find the breach position closest to the given AccessPoint position
  let tolerance: Float = 5.0; // 5 meter tolerance for AccessPoint matching
  let idx: Int32 = ArraySize(player.m_betterNetrunning_breachedAccessPointPositions) - 1;

  while idx >= 0 {
    let breachPos: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[idx];
    let distance: Float = Vector4.Distance(breachPos, apPosition);

    if distance < tolerance {
      return breachPos;
    }
    idx -= 1;
  }

  // Not found - return the AccessPoint position itself as fallback
  return apPosition;
}

/*
 * Checks if a device is within breach radius from any recorded breach position
 *
 * Used by RadialBreach integration for physical distance filtering
 * Uses RadialBreach settings for breach radius (or default 50m)
 *
 * @param devicePosition - World position of the device to check
 * @param gameInstance - Current game instance
 * @param maxDistance - Maximum allowed distance (optional, uses RadialBreach settings if 0)
 * @return true if device is within breach radius of any recorded breach
 */
public func IsDeviceWithinBreachRadius(devicePosition: Vector4, gameInstance: GameInstance, opt maxDistance: Float) -> Bool {
  if maxDistance == 0.0 {
    maxDistance = GetRadialBreachRange(gameInstance);
  }

  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    return false;
  }

  // Check distance from all recorded breach positions
  let idx: Int32 = 0;
  while idx < ArraySize(player.m_betterNetrunning_breachedAccessPointPositions) {
    let breachPos: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[idx];
    let distance: Float = Vector4.Distance(breachPos, devicePosition);

    if distance <= maxDistance {
      return true;
    }
    idx += 1;
  }

  return false;
}
