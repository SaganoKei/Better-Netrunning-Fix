// ============================================================================
// BetterNetrunning - Common Event Definitions
// ============================================================================
//
// PURPOSE:
// Defines custom events and persistent fields used across Better Netrunning modules
//
// EVENTS:
// - SetBreachedSubnet: Propagates breach state across network devices
//
// PERSISTENT FIELDS:
// - m_betterNetrunningWasDirectlyBreached (ScriptedPuppetPS): Tracks if NPC was directly breached
// - m_betterNetrunningUnlockTimestamp*: Timestamp-based breach state (0.0 = never unlocked or expired)
//
// USAGE:
// - Import this module in any script that needs to use these events/fields
// - Events are used by RadialBreachGating, betterNetrunning, etc.
// ============================================================================

module BetterNetrunning.Core
import BetterNetrunning.Core.TimeUtils
import BetterNetrunningConfig.*

// ==================== Persistent Field Definitions ====================

// Persistent field for tracking direct breach on NPCs
@addField(ScriptedPuppetPS)
public persistent let m_betterNetrunningWasDirectlyBreached: Bool;

// ==================== Unlock Timestamp Fields ====================
// Tracks when each device type was last unlocked (for temporary unlock feature)
// Value: Float timestamp from TimeSystem.GetGameTimeStamp()
// 0.0 = never unlocked or expired

@addField(SharedGameplayPS)
public persistent let m_betterNetrunningUnlockTimestampBasic: Float;

@addField(SharedGameplayPS)
public persistent let m_betterNetrunningUnlockTimestampCameras: Float;

@addField(SharedGameplayPS)
public persistent let m_betterNetrunningUnlockTimestampTurrets: Float;

@addField(SharedGameplayPS)
public persistent let m_betterNetrunningUnlockTimestampNPCs: Float;

// ==================== Breach Failure Penalty Timestamps ====================
// Records breach failure timestamps for penalty system (10 minutes lock duration)
// Value: Float timestamp from TimeSystem.GetGameTimeStamp()
// 0.0 = never failed or penalty expired

// AP Breach failure penalty timestamp (device-side persistent for save/load compatibility)
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningAPBreachFailedTimestamp: Float;

// NPC Breach failure penalty timestamp (NPC-side persistent for save/load compatibility)
@addField(ScriptedPuppetPS)
public persistent let m_betterNetrunningNPCBreachFailedTimestamp: Float;

// RemoteBreach failure penalty timestamp (device-side persistent for save/load compatibility)
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningRemoteBreachFailedTimestamp: Float;

// ==================== Breach State Event System ====================

/*
 * Custom event for propagating breach state across network devices
 * Sent to all devices when subnet is successfully breached
 * Uses timestamp-based state management (0.0 = unlocked expired or never breached)
 */
public class SetBreachedSubnet extends ActionBool {

  public let unlockTimestampBasic: Float;
  public let unlockTimestampNPCs: Float;
  public let unlockTimestampCameras: Float;
  public let unlockTimestampTurrets: Float;

  public final func SetProperties() -> Void {
    this.actionName = BNConstants.ACTION_SET_BREACHED_SUBNET();
    this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(this.actionName, true, BNConstants.ACTION_SET_BREACHED_SUBNET(), BNConstants.ACTION_SET_BREACHED_SUBNET());
  }

  public func GetTweakDBChoiceRecord() -> String {
    return NameToString(BNConstants.ACTION_SET_BREACHED_SUBNET());
  }

  public final static func IsAvailable(device: ref<ScriptableDeviceComponentPS>) -> Bool {
    return true;
  }

  public final static func IsClearanceValid(clearance: ref<Clearance>) -> Bool {
    if Clearance.IsInRange(clearance, 2) {
      return true;
    };
    return false;
  }

  public final static func IsContextValid(const context: script_ref<GetActionsContext>) -> Bool {
    if Equals(Deref(context).requestType, gamedeviceRequestType.Direct) {
      return true;
    };
    return false;
  }

}

// Event handler: Updates device breach state when subnet is breached
@addMethod(SharedGameplayPS)
public func OnSetBreachedSubnet(evt: ref<SetBreachedSubnet>) -> EntityNotificationType {
  // Timestamp-based state management
  // 0.0 = unlocked expired or never breached
  // > 0.0 = breached at specific game time

  this.m_betterNetrunningUnlockTimestampBasic = evt.unlockTimestampBasic;
  this.m_betterNetrunningUnlockTimestampNPCs = evt.unlockTimestampNPCs;
  this.m_betterNetrunningUnlockTimestampCameras = evt.unlockTimestampCameras;
  this.m_betterNetrunningUnlockTimestampTurrets = evt.unlockTimestampTurrets;

  return EntityNotificationType.DoNotNotifyEntity;
}

// ==================== Utility Functions ====================

// ==================== Breach Status Utilities ====================

/*
 * Checks if a device type is breached based on unlock timestamp
 * Unified breach status check - replaces redundant m_betterNetrunningBreached* flags
 *
 * @param unlockTimestamp - The unlock timestamp (0.0 = not breached)
 * @return True if breached (timestamp > 0.0), False otherwise
 */
public abstract class BreachStatusUtils {

  public static func IsBreached(unlockTimestamp: Float) -> Bool {
    return unlockTimestamp > 0.0;
  }

  /**
   * Check if device is breached AND unlock duration has not expired
   *
   * @param unlockTimestamp - The unlock timestamp (0.0 = not breached)
   * @param gameInstance - Game instance for time retrieval
   * @return True if breached and not expired, False otherwise
   */
  public static func IsBreachedWithExpiration(unlockTimestamp: Float, gameInstance: GameInstance) -> Bool {
    // Not breached
    if unlockTimestamp <= 0.0 {
      return false;
    }

    // Check expiration
    let unlockDurationHours: Int32 = BetterNetrunningSettings.QuickhackUnlockDurationHours();

    // Permanent unlock (duration = 0)
    if unlockDurationHours <= 0 {
      return true;
    }

    // Temporary unlock - check expiration
    let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
    let elapsedTime: Float = currentTime - unlockTimestamp;
    let durationSeconds: Float = Cast<Float>(unlockDurationHours) * 3600.0;

    let isStillValid: Bool = elapsedTime <= durationSeconds;

    return isStillValid;
  }

  // Convenience methods for SharedGameplayPS
  public static func IsBasicBreached(sharedPS: ref<SharedGameplayPS>) -> Bool {
    return BreachStatusUtils.IsBreached(sharedPS.m_betterNetrunningUnlockTimestampBasic);
  }

  public static func IsNPCsBreached(sharedPS: ref<SharedGameplayPS>) -> Bool {
    return BreachStatusUtils.IsBreached(sharedPS.m_betterNetrunningUnlockTimestampNPCs);
  }

  public static func IsCamerasBreached(sharedPS: ref<SharedGameplayPS>) -> Bool {
    return BreachStatusUtils.IsBreached(sharedPS.m_betterNetrunningUnlockTimestampCameras);
  }

  public static func IsTurretsBreached(sharedPS: ref<SharedGameplayPS>) -> Bool {
    return BreachStatusUtils.IsBreached(sharedPS.m_betterNetrunningUnlockTimestampTurrets);
  }
}

// =============================================================================
// CustomRemoteBreach Action Detection (Single Source of Truth)
// =============================================================================

/*
 * Returns true if className is a CustomRemoteBreach action class
 *
 * PURPOSE:
 * Centralized detection for all BetterNetrunning CustomRemoteBreach actions.
 * Used by DeviceQuickhacks, RemoteBreachVisibility, and CustomHackingIntegration.
 *
 * SUPPORTED ACTION TYPES (only when HackingExtensions MOD installed):
 * - RemoteBreachAction: Computer breach (AccessPoint, Laptop)
 * - DeviceRemoteBreachAction: Generic device breach (Door, Camera, Turret)
 * - VehicleRemoteBreachAction: Vehicle breach
 *
 * ARCHITECTURE:
 * - Self-contained implementation (no imports of feature modules)
 * - Circular imports are harmless in REDscript (tested and verified)
 * - Single source of truth (DRY principle)
 * - Conditional compilation (@if(ModuleExists("HackingExtensions")))
 *
 * RATIONALE:
 * Delegates to BNConstants.IsRemoteBreachAction() for centralized constant management.
 * All class names defined in Common/Constants.reds (Single Source of Truth).
 * Class definitions are in CustomHacking/RemoteBreachAction_*.reds files.
 *
 * CRITICAL:
 * No @if(ModuleExists("HackingExtensions")) guard needed here.
 * RemoteBreachAction classes have @if guards in their definitions,
 * so this function will return false when HackingExtensions is not installed.
 *
 * CLASS NAME PATTERN:
 * MUST use fully qualified names (n"Module.Path.ClassName") - defined in Constants.reds.
 * Short names (n"ClassName") do NOT work for cross-module references.
 *
 * TECHNICAL REQUIREMENTS:
 * - Circular imports are safe (tested and verified)
 * - Fully qualified names are required (n"Module.Path.ClassName")
 * - Centralized constants prevent typos and enable easy refactoring
 */
public func IsCustomRemoteBreachAction(className: CName) -> Bool {
  // ✓ Use centralized constants (Single Source of Truth)
  // Defined in: Common/Constants.reds
  // Class definitions: CustomHacking/RemoteBreachAction_*.reds
  return BNConstants.IsRemoteBreachAction(className);
}/*
 * Overload for ref<DeviceAction> parameter (convenience method)
 *
 * PURPOSE:
 * Allows direct checking of DeviceAction instances without manual GetClassName() calls.
 *
 * USAGE:
 * - if (IsCustomRemoteBreachAction(action)) { ... }
 * Instead of:
 * - if (IsCustomRemoteBreachAction(action.GetClassName())) { ... }
 */

public func IsCustomRemoteBreachAction(action: ref<DeviceAction>) -> Bool {
  if !IsDefined(action) {
    return false;
  }
  return IsCustomRemoteBreachAction(action.GetClassName());
}
