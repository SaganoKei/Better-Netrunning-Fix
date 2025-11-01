// ============================================================================
// BetterNetrunning - Breach Lock Utilities
// ============================================================================
//
// PURPOSE:
// High-level wrapper functions for breach lock checks with entity/player/position retrieval
//
// FUNCTIONALITY:
// - Device lock check: Combines GetOwnerEntityWeak() + GetWorldPosition() + player retrieval
// - NPC lock check: Combines GetOwnerEntity() (ScriptedPuppet) + GetWorldPosition() + player retrieval
// - Delegates to BreachLockSystem for position-based lock checks
//
// ARCHITECTURE:
// - Static utility methods (no instantiation required)
// - Single source of truth for entity/position retrieval pattern
// - Centralized guard-heavy retrieval keeps callers focused on domain logic
//

module BetterNetrunning.Utils

import BetterNetrunningConfig.*
import BetterNetrunning.Breach.*
import BetterNetrunning.RemoteBreach.Core.*

// ============================================================================
// BreachLockUtils - High-level breach lock check utilities
// ============================================================================
public abstract class BreachLockUtils {

  /*
   * Checks if device is locked by RemoteBreach failure.
   *
   * Centralized wrapper for device RemoteBreach lock checks across all ScriptableDeviceComponentPS
   * contexts (devices, computers, vehicles). Delegates to RemoteBreachLockSystem.IsRemoteBreachLockedByTimestamp().
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
   * Checks if NPC is locked by RemoteBreach failure (position-based, 50m radius).
   *
   * Centralized wrapper for RemoteBreach lock checks on NPCs in NPCQuickhacks/NPCLifecycle
   * contexts. Separated from Unconscious NPC Breach checks per Single Responsibility Principle.
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
   * Checks if NPC is locked by Unconscious NPC Breach failure. Applies to specific NPC previously
   * breached while unconscious (per-NPC timestamp). Separated from RemoteBreach checks per Single
   * Responsibility Principle. Used in NPCLifecycle contexts (BreachUnconsciousOfficer action).
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
   * Checks if JackIn is locked by AP breach failure.
   *
   * Used by DeviceInteractionUtils.EnableJackInInteractionForAccessPoint() to prevent
   * duplicate AP breach (via JackIn) after failure.
   *
   * Scope: Only affects MasterControllerPS devices (AccessPoint, Computer, Terminal)
   *
   * Implementation:
   * - Uses device-side timestamp for persistence across save/load
   * - Delegates to BreachLockSystem.IsAPBreachLockedByTimestamp()
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