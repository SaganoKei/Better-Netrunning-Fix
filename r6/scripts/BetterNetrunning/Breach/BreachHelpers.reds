module BetterNetrunning.Breach

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Breach.*

/*
 * Breach helper functions for network hierarchy and minigame completion
 * Provides utility functions for access point navigation and NPC breach handling
 *
 * FEATURES:
 * - GetMainframe(): Recursive access point hierarchy traversal
 * - CheckConnectedClassTypes(): Device type detection (ignores power state)
 * - OnAccessPointMiniGameStatus(): NPC breach completion handler (no alarm trigger)
 */

/*
 * Recursively finds the top-level access point in network hierarchy
 * Used for determining the root access point of a network
 */
@addMethod(AccessPointControllerPS)
public func GetMainframe() -> ref<AccessPointControllerPS> {
  let parents: array<ref<DeviceComponentPS>>;
  this.GetParents(parents);
  let i: Int32 = 0;
  while i < ArraySize(parents) {
    if IsDefined(parents[i] as AccessPointControllerPS) {
      return (parents[i] as AccessPointControllerPS).GetMainframe();
    };
    i += 1;
  };
  return this;
}

/*
 * Allows breach program upload even when all devices of specific type are disabled
 * VANILLA DIFF: Removes IsON() and IsBroken() checks to count all devices regardless of power state
 * Fixes vanilla issue where disabled devices block program availability
 *
 * RATIONALE:
 * Vanilla checks device power state (IsON() && !IsBroken()) before counting cameras/turrets.
 * This prevents camera/turret unlock programs from appearing if all devices are disabled.
 * Better Netrunning removes these checks to allow unlocking disabled devices.
 *
 * ARCHITECTURE: Continue Pattern + Extract Method with shallow nesting (max 2 levels)
 */
@replaceMethod(AccessPointControllerPS)
public final const func CheckConnectedClassTypes() -> ConnectedClassTypes {
  let data: ConnectedClassTypes;
  let slaves: array<ref<DeviceComponentPS>> = this.GetImmediateSlaves();

  let i: Int32 = 0;
  while i < ArraySize(slaves) {
    // Early exit: All device types found
    if data.surveillanceCamera && data.securityTurret && data.puppet {
      break;
    }

    // Update device type flags
    this.UpdateDeviceTypeData(slaves[i], data);
    i += 1;
  }

  return data;
}

// Helper: Update device type detection flags for a single slave device
@addMethod(AccessPointControllerPS)
private final func UpdateDeviceTypeData(slave: ref<DeviceComponentPS>, out data: ConnectedClassTypes) -> Void {
  // Check for Camera/Turret (ScriptableDeviceComponentPS)
  let slavePS: ref<ScriptableDeviceComponentPS> = slave as ScriptableDeviceComponentPS;
  if IsDefined(slavePS) {
    if !data.surveillanceCamera && DaemonFilterUtils.IsCamera(slavePS) {
      data.surveillanceCamera = true;
      return;
    }
    if !data.securityTurret && DaemonFilterUtils.IsTurret(slavePS) {
      data.securityTurret = true;
      return;
    }
  }

  // Check for NPC (PuppetDeviceLinkPS)
  if data.puppet {
    return;  // Already found
  }

  let puppetLink: ref<PuppetDeviceLinkPS> = slave as PuppetDeviceLinkPS;
  if !IsDefined(puppetLink) {
    return;
  }

  let puppet: ref<GameObject> = puppetLink.GetOwnerEntityWeak() as GameObject;
  if IsDefined(puppet) && puppet.IsActive() {
    data.puppet = true;
  }
}

/*
 * Handles breach minigame completion for NPCs (Unconscious NPC Breach)
 * VANILLA DIFF: Removes TriggerSecuritySystemNotification(ALARM) call on breach failure
 * Intentionally suppresses alarm on breach failure to avoid breaking stealth
 *
 * RATIONALE:
 * Vanilla triggers an alarm when breach fails on an NPC, causing all enemies to become hostile.
 * Better Netrunning removes this to allow failed breach attempts without consequences.
 * Players can retry breach without alerting the entire area.
 *
 * BREACH PENALTY INTEGRATION:
 * - Success: Normal processing (no penalty)
 * - Failure: Apply breach failure penalty via unified ApplyFailurePenalty() (VFX + lock + trace)
 */
@replaceMethod(ScriptedPuppet)
protected cb func OnAccessPointMiniGameStatus(evt: ref<AccessPointMiniGameStatus>) -> Bool {
  let deviceLink: ref<PuppetDeviceLinkPS> = this.GetDeviceLink();

  // Update NPC breach state
  if IsDefined(deviceLink) {
    deviceLink.PerformNPCBreach(evt.minigameState);
    // Vanilla alarm trigger disabled - prevents hostility on failed breach attempt
  }

  // BREACH PENALTY: Apply failure penalty if breach failed
  // NOTE: Uses ApplyFailurePenalty(player, npcPuppet, gameInstance) overload
  // because PuppetDeviceLinkPS and ScriptableDeviceComponentPS are sibling classes
  // and cannot be cast to each other.
  if Equals(evt.minigameState, HackingMinigameState.Failed) && BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGame());

    if IsDefined(player) && IsDefined(this) {
      // Use NPC-specific overload: ApplyFailurePenalty(player, npcPuppet, gameInstance)
      ApplyFailurePenalty(player, this, this.GetGame());
      BNInfo("OnAccessPointMiniGameStatus", "Unconscious NPC breach failed - penalty applied via overload");
    } else {
      if !IsDefined(player) {
        BNError("OnAccessPointMiniGameStatus", "Player not found - cannot apply penalty");
      }
      if !IsDefined(this) {
        BNError("OnAccessPointMiniGameStatus", "ScriptedPuppet not found - cannot apply penalty");
      }
    }
  }

  // Clean up breach state
  this.ClearNetworkBlackboardState();
  this.RestoreTimeDilation();
  QuickhackModule.RequestRefreshQuickhackMenu(this.GetGame(), this.GetEntityID());
}

// Helper: Clears network state from blackboard
@addMethod(ScriptedPuppet)
private final func ClearNetworkBlackboardState() -> Void {
  let emptyID: EntityID;
  this.GetNetworkBlackboard().SetString(this.GetNetworkBlackboardDef().NetworkName, "");
  this.GetNetworkBlackboard().SetEntityID(this.GetNetworkBlackboardDef().DeviceID, emptyID);
}

// Helper: Restores normal time flow after breach minigame
@addMethod(ScriptedPuppet)
private final func RestoreTimeDilation() -> Void {
  let easeOutCurve: CName = TweakDBInterface.GetCName(t"timeSystem.nanoWireBreach.easeOutCurve", n"DiveEaseOut");
  GameInstance.GetTimeSystem(this.GetGame()).UnsetTimeDilation(n"NetworkBreach", easeOutCurve);
}

// ============================================================================
// Section 3: Breach Extension Processing
// ============================================================================

public abstract class BreachHelpers {

  /*
  * Execute radius-based device/NPC unlocks after successful breach
  *
  * PURPOSE:
  * Centralized breach extension logic for AccessPoint/RemoteBreach/UnconsciousNPC breach types
  *
  * FUNCTIONALITY:
  * - Radius unlock: Unlocks devices/vehicles within 50m radius
  * - NPC unlock: Unlocks unconscious NPCs in network
  * - Position tracking: Records breach position for RadialUnlockSystem integration
  *
  * ARCHITECTURE:
  * - Template Method Pattern: Common flow with caller-specific network unlock
  * - Shallow nesting (max 2 levels) using guard clauses
  * - Single Responsibility: Shared extensions only, network unlock delegated to callers
  *
  * DEPENDENCIES:
  * - DeviceUnlockUtils: Radius/NPC unlock + position tracking
  * - BreachStatisticsCollector: Optional statistics collection (null-safe)
  *
  * RATIONALE:
  * DRY compliance - eliminates 60 lines of duplicate code (30 lines × 2 implementations)
  * Single point of change for common breach extension logic
  *
  * @param devicePS - Target device (breached AccessPoint/Computer/Device/Vehicle/NPC)
  * @param unlockFlags - Unlock configuration (unlockBasic/unlockNPCs/recordPosition)
  * @param stats - Optional statistics collector (null = no collection)
  * @param gameInstance - Game instance for system access
  */
  public static func ExecuteRadiusUnlocks(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockFlags: BreachUnlockFlags,
    stats: ref<BreachSessionStats>,
    gameInstance: GameInstance
  ) -> Void {
    // Guard clause: Validate required parameters
    if !IsDefined(devicePS) {
      BNError("BreachHelpers", "Invalid parameters - devicePS is null");
      return;
    }

    BNDebug("BreachHelpers",
      "Applying breach extensions - unlockBasic: " + ToString(unlockFlags.unlockBasic) +
      ", unlockNPCs: " + ToString(unlockFlags.unlockNPCs));

    // Step 1: Radius unlock (devices + vehicles)
    if unlockFlags.unlockBasic {
      DeviceUnlockUtils.UnlockDevicesInRadius(devicePS, gameInstance);
      DeviceUnlockUtils.UnlockVehiclesInRadius(devicePS, gameInstance);

      // Optional statistics collection
      if IsDefined(stats) {
        BreachStatisticsCollector.CollectRadialUnlockStats(devicePS, unlockFlags, stats, gameInstance);
      }

      BNDebug("BreachHelpers", "Radius unlock (devices + vehicles) completed");
    }

    // Step 2: NPC unlock
    if unlockFlags.unlockNPCs {
      DeviceUnlockUtils.UnlockNPCsInRadius(devicePS, gameInstance);
    }

    // Step 3: Position tracking (RadialUnlockSystem integration)
    DeviceUnlockUtils.RecordBreachPosition(devicePS, gameInstance);

    BNDebug("BreachHelpers", "Breach extensions completed");
  }

}
