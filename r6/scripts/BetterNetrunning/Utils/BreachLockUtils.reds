// ============================================================================
// BetterNetrunning - Breach Lock Utilities
// ============================================================================
//
// PURPOSE:
// High-level wrapper functions for RemoteBreach lock checks, simplifying
// repeated patterns of entity/player/position retrieval across the codebase.
//
// FUNCTIONALITY:
// - Device lock check: Combines GetOwnerEntityWeak() + GetWorldPosition() + player retrieval
// - NPC lock check: Combines GetOwnerEntity() (ScriptedPuppet) + GetWorldPosition() + player retrieval
// - Delegates to RemoteBreachLockUtils.IsRemoteBreachLockedForDevice() for actual lock logic
//
// ARCHITECTURE:
// - Static utility methods (no instantiation required)
// - Single source of truth for entity/position retrieval pattern
// - Eliminates 100+ lines of duplicate code across 9 files
//
// RATIONALE:
// - Centralize guard-heavy entity/player/position retrieval so callers can remain
//   focused on domain logic. This reduces duplication and ensures consistent
//   null-safety when calling into the Breach domain lock check.
//
// DEPENDENCIES:
// - BetterNetrunning.Breach.RemoteBreachLockUtils: Low-level position-based lock check
// - BetterNetrunningConfig: Settings control (BreachFailurePenaltyEnabled)
// ============================================================================

module BetterNetrunning.Utils

import BetterNetrunningConfig.*
import BetterNetrunning.Breach.*

// ============================================================================
// BreachLockUtils - High-level breach lock check utilities
// ============================================================================
public abstract class BreachLockUtils {

  /*
   * High-level wrapper for device RemoteBreach lock check
   *
   * PURPOSE: Simplify repeated pattern of entity/player/position retrieval
   * ARCHITECTURE: Single point of entry for device lock checks
   * USAGE: All ScriptableDeviceComponentPS contexts (devices, computers, vehicles)
   * RATIONALE: Centralize null-safe entity/player/position retrieval so callers
   * avoid duplicating guard clauses and to guarantee consistent invocation of
   * the domain-level lock check implemented in RemoteBreachLockUtils.
   */
  public static func IsDeviceLockedByBreachFailure(
    devicePS: ref<ScriptableDeviceComponentPS>
  ) -> Bool {
    if !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
      return false;
    }

    let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(deviceEntity) {
      return false;
    }

    let player: ref<PlayerPuppet> = GetPlayer(devicePS.GetGameInstance());
    if !IsDefined(player) {
      return false;
    }

    let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
    return RemoteBreachLockUtils.IsRemoteBreachLockedForDevice(player, devicePosition, devicePS.GetGameInstance());
  }

  /*
   * High-level wrapper for NPC RemoteBreach lock check
   *
   * PURPOSE: Simplify repeated pattern for NPC puppet lock checks
   * ARCHITECTURE: Single point of entry for NPC lock checks
   * USAGE: All ScriptedPuppetPS contexts (NPCs)
   * RATIONALE: Centralize null-safe puppet/player/position retrieval so NPC
   * callers don't repeat guard logic and to provide one consistent callsite
   * into the Breach domain lock check.
   */
  public static func IsNPCLockedByBreachFailure(
    npcPS: ref<ScriptedPuppetPS>
  ) -> Bool {
    if !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
      return false;
    }

    let puppet: wref<ScriptedPuppet> = npcPS.GetOwnerEntity() as ScriptedPuppet;
    if !IsDefined(puppet) {
      return false;
    }

    let player: ref<PlayerPuppet> = GetPlayer(npcPS.GetGameInstance());
    if !IsDefined(player) {
      return false;
    }

    let npcPosition: Vector4 = puppet.GetWorldPosition();
    return RemoteBreachLockUtils.IsRemoteBreachLockedForDevice(player, npcPosition, npcPS.GetGameInstance());
  }
}
