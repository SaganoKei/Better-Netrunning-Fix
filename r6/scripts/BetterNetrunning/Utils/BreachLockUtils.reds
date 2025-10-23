// ============================================================================
// BetterNetrunning - Breach Lock Utilities
// ============================================================================
//
// PURPOSE:
// High-level wrapper functions for breach lock checks, simplifying
// repeated patterns of entity/player/position retrieval across the codebase.
//
// FUNCTIONALITY:
// - Device lock check: Combines GetOwnerEntityWeak() + GetWorldPosition() + player retrieval
// - NPC lock check: Combines GetOwnerEntity() (ScriptedPuppet) + GetWorldPosition() + player retrieval
// - Delegates to BreachLockSystem for position-based lock checks
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
// - BetterNetrunning.Breach.BreachLockSystem: Position-based lock checks
// - BetterNetrunningConfig: Settings control (BreachFailurePenaltyEnabled)
// ============================================================================

module BetterNetrunning.Utils

import BetterNetrunningConfig.*
import BetterNetrunning.Breach.*
import BetterNetrunning.RemoteBreach.Core.*

// ============================================================================
// BreachLockUtils - High-level breach lock check utilities
// ============================================================================
public abstract class BreachLockUtils {

  /*
   * High-level wrapper for device RemoteBreach lock check
   *
   * PURPOSE: Simplify repeated pattern for device RemoteBreach lock checks
   * ARCHITECTURE: Single point of entry for device RemoteBreach lock checks
   * USAGE: All ScriptableDeviceComponentPS contexts (devices, computers, vehicles)
   * RATIONALE: Centralize null-safe devicePS retrieval and guarantee consistent
   * invocation of the domain-level lock check implemented in RemoteBreachLockSystem.
   */
  public static func IsDeviceLockedByRemoteBreachFailure(
    devicePS: ref<ScriptableDeviceComponentPS>
  ) -> Bool {
    if !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
      return false;
    }

    // Timestamp-based check (delegated to RemoteBreachLockSystem)
    return RemoteBreachLockSystem.IsRemoteBreachLockedByTimestamp(devicePS, devicePS.GetGameInstance());
  }

  /*
   * Check if NPC is locked by RemoteBreach failure (position-based, 50m radius)
   *
   * PURPOSE: RemoteBreach-specific lock check for NPCs
   * ARCHITECTURE: Single point of entry for RemoteBreach lock checks on NPCs
   * USAGE: NPCQuickhacks, NPCLifecycle contexts where RemoteBreach affects NPC actions
   *
   * CHECKS:
   * - RemoteBreach failure within 50m radius (affects all NPCs/devices in range)
   *
   * RATIONALE: Centralize null-safe puppet/player/position retrieval for
   * RemoteBreach-specific lock checks. Separated from Unconscious NPC Breach
   * checks per Single Responsibility Principle.
   */
  public static func IsNPCLockedByRemoteBreachFailure(
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

    // NOTE: RemoteBreach penalty does not apply to NPCs (device-only feature)
    // NPCs use separate UnconsciousNPC Breach penalty (timestamp-based)
    return false;
  }

  /*
   * Check if NPC is locked by Unconscious NPC Breach failure (NPC-specific timestamp)
   *
   * PURPOSE: Unconscious NPC Breach-specific lock check
   * ARCHITECTURE: Single point of entry for Unconscious NPC Breach lock checks
   * USAGE: NPCLifecycle contexts (BreachUnconsciousOfficer action)
   *
   * CHECKS:
   * - Unconscious NPC Breach failure timestamp (affects this specific NPC only)
   *
   * RATIONALE: Separated from RemoteBreach checks per Single Responsibility Principle.
   * This check only applies to the specific NPC that was previously breached while unconscious.
   */
  public static func IsNPCLockedByUnconsciousNPCBreachFailure(
    npcPS: ref<ScriptedPuppetPS>
  ) -> Bool {
    if !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
      return false;
    }

    if !BetterNetrunningSettings.NPCBreachFailurePenaltyEnabled() {
      return false;
    }

    return BreachLockSystem.IsNPCBreachLockedByTimestamp(npcPS, npcPS.GetGameInstance());
  }

  /*
   * High-level wrapper for AP breach JackIn lock check
   *
   * FUNCTIONALITY:
   * - Checks if JackIn should be disabled due to AP breach failure
   * - Used by DeviceInteractionUtils.EnableJackInInteractionForAccessPoint()
   * - Only affects MasterControllerPS devices (AccessPoint, Computer, Terminal)
   *
   * ARCHITECTURE:
   * - Guard Clause pattern for early return
   * - Delegates to BreachLockSystem.IsAPBreachLockedByTimestamp()
   *
   * RATIONALE:
   * - Prevents duplicate AP breach (via JackIn) after failure
   * - Uses device-side timestamp for persistence across save/load
   */
  public static func IsJackInLockedByAPBreachFailure(
    devicePS: ref<ScriptableDeviceComponentPS>
  ) -> Bool {
    if !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
      return false;
    }

    if !BetterNetrunningSettings.APBreachFailurePenaltyEnabled() {
      return false;
    }

    let sharedPS: ref<SharedGameplayPS> = devicePS;
    return BreachLockSystem.IsAPBreachLockedByTimestamp(sharedPS, devicePS.GetGameInstance());
  }
}