// ============================================================================
// Breach Lock System - Penalty Management for AP/NPC Breach Types
// ============================================================================
//
// PURPOSE:
// Timestamp-based lock system for AccessPoint and UnconsciousNPC breach types.
// Prevents re-attempts on failed breach targets for configurable duration
// (default 10 minutes) to balance risk-free gameplay.
//
// FUNCTIONALITY:
// - Timestamp Recording: Store breach failure timestamps on device/NPC PS
// - Lock Check: Determine if target is locked based on timestamp
// - Lock Expiration: Auto-expire locks after configurable duration (default 10 minutes)
// - Multi-Type Support: Independent lock management for AP/NPC breach types
// - Shared Helper: IsLockedByTimestamp() used by AP/NPC/RemoteBreach lock checks
//
// LOCK SCOPE:
// - AP Breach: Timestamp-based lock (device-specific, stored on SharedGameplayPS)
// - NPC Breach: Timestamp-based lock (NPC-specific, stored on ScriptedPuppetPS)
// - RemoteBreach: Lock management in RemoteBreach/Core/RemoteBreachLockSystem.reds
//
// ARCHITECTURE:
// - Persistent fields on SharedGameplayPS/ScriptedPuppetPS (survive save/load)
// - Timestamp-based lock checking (IsAPBreachLockedByTimestamp, IsNPCBreachLockedByTimestamp)
// - Guard Clause pattern for validation (max nesting: 1-2 levels)
// - Public helper method (IsLockedByTimestamp) for DRY pattern
//
// DEPENDENCIES:
// - BetterNetrunningConfig: Settings control (BreachPenaltyDurationMinutes)
// - Core/TimeUtils.reds: Timestamp management
// - Core/Logger.reds: Debug logging
// ============================================================================

module BetterNetrunning.Breach
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*

// ============================================================================
// Persistent Failure Storage - SharedGameplayPS/ScriptedPuppetPS
// ============================================================================
//
// FUNCTIONALITY:
// - Store AP/NPC breach failure timestamps on device/NPC PS
// - Persistent fields survive save/load cycles
//
// FIELDS (AccessPoint):
// - m_betterNetrunningAPBreachFailedTimestamp: AP breach failure timestamp (on SharedGameplayPS)
//
// FIELDS (UnconsciousNPC):
// - m_betterNetrunningNPCBreachFailedTimestamp: NPC breach failure timestamp (on ScriptedPuppetPS)
//
// NOTE:
// RemoteBreach persistent fields (m_betterNetrunningRemoteBreachFailedTimestamp)
// defined in Core/Events.reds, accessed via RemoteBreach/Core/RemoteBreachLockSystem.reds
//
// ARCHITECTURE:
// - Persistent Fields Pattern (survive save/load)
// - Timestamp-based locking (overwrite-style, auto-expires)
// ============================================================================

// ============================================================================
// BreachLockSystem - Timestamp-Based Lock Management
// ============================================================================
//
// FUNCTIONALITY:
// Provides timestamp-based lock checking for AP and NPC breach types.
// Provides shared helper (IsLockedByTimestamp) for RemoteBreach lock checks.
//
// ARCHITECTURE:
// - Static class (no instantiation required)
// - Public interface for lock checking (IsAPBreachLockedByTimestamp, IsNPCBreachLockedByTimestamp)
// - Public helper (IsLockedByTimestamp) for DRY pattern across all breach types
// - Guard Clause pattern for validation
// ============================================================================

public class BreachLockSystem {
  // ============================================================================
  // Timestamp Validation Helper (DRY Pattern)
  // ============================================================================
  //
  // FUNCTIONALITY:
  // - Validate timestamp against lock duration
  // - Auto-expiration detection
  //
  // ARCHITECTURE:
  // - Shared helper for AP/NPC/RemoteBreach lock checks (DRY pattern)
  // - Called by IsAPBreachLockedByTimestamp, IsNPCBreachLockedByTimestamp, RemoteBreachLockSystem
  //
  // PARAMETERS:
  // - timestamp: Failure timestamp to check
  // - gameInstance: For current time/settings
  // - shouldClear: (out) true if timestamp should be cleared
  //
  // RETURNS:
  // - true if locked (timestamp valid and not expired)
  // - false if accessible (no timestamp or expired)
  // ============================================================================
  public static func IsLockedByTimestamp(
    timestamp: Float,
    gameInstance: GameInstance,
    out shouldClear: Bool
  ) -> Bool {
    shouldClear = false;
    if timestamp <= 0.0 {
      return false;
    }

    let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
    let lockDurationSeconds: Float = Cast<Float>(BetterNetrunningSettings.BreachPenaltyDurationMinutes() * 60);
    if currentTime - timestamp > lockDurationSeconds {
      shouldClear = true;
      return false;
    }

    return true;
  }

  // ============================================================================
  // AP Breach Lock Check - Timestamp-Based
  // ============================================================================
  public static func IsAPBreachLockedByTimestamp(
    devicePS: ref<SharedGameplayPS>,
    gameInstance: GameInstance
  ) -> Bool {
    if !IsDefined(devicePS) {
      return false;
    }

    let shouldClear: Bool;
    let isLocked: Bool = BreachLockSystem.IsLockedByTimestamp(
      devicePS.m_betterNetrunningAPBreachFailedTimestamp,
      gameInstance,
      shouldClear
    );

    if shouldClear {
      devicePS.m_betterNetrunningAPBreachFailedTimestamp = 0.0;
    }

    return isLocked;
  }

  // ============================================================================
  // NPC Breach Lock Check - ScriptedPuppetPS Timestamp-Based
  // ============================================================================
  public static func IsNPCBreachLockedByTimestamp(
    npcPS: ref<ScriptedPuppetPS>,
    gameInstance: GameInstance
  ) -> Bool {
    if !IsDefined(npcPS) {
      return false;
    }

    let shouldClear: Bool;
    let isLocked: Bool = BreachLockSystem.IsLockedByTimestamp(
      npcPS.m_betterNetrunningNPCBreachFailedTimestamp,
      gameInstance,
      shouldClear
    );

    if shouldClear {
      npcPS.m_betterNetrunningNPCBreachFailedTimestamp = 0.0;
    }

    return isLocked;
  }
}
