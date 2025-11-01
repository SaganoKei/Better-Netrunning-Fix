// ============================================================================
// BetterNetrunning - Device Type Utilities
// ============================================================================
//
// PURPOSE:
// Centralized device type classification and breach flag management
//
// FUNCTIONALITY:
// - Device type determination (NPC, Camera, Turret, Basic devices)
// - Breach status validation across device types
// - Permission calculation for progressive unlock
// - Unified device type checking for consistency
//
// ARCHITECTURE:
// - Enum-based device classification for type safety
// - Struct-based permission containers
// - Static utility methods for device identification
// - Single Responsibility Principle implementation
//

module BetterNetrunning.Core

import BetterNetrunning.Integration.*

// Target classification enum (devices and breach unlock types)
public enum TargetType {
  NPC = 0,
  Camera = 1,
  Turret = 2,
  Basic = 3
}

// Helper struct for SetActionsInactiveUnbreached() - Device classification
public struct DeviceBreachInfo {
  public let isCamera: Bool;
  public let isTurret: Bool;
  public let isStandaloneDevice: Bool;
}

// Helper struct for SetActionsInactiveUnbreached() - Permission calculation
public struct DevicePermissions {
  public let allowCameras: Bool;
  public let allowTurrets: Bool;
  public let allowBasicDevices: Bool;
  public let allowPing: Bool;
  public let allowDistraction: Bool;
}

// Helper struct for GetAllChoices() - NPC hack permissions
public struct NPCHackPermissions {
  public let isBreached: Bool;
  public let allowCovert: Bool;
  public let allowCombat: Bool;
  public let allowControl: Bool;
  public let allowUltimate: Bool;
  public let allowPing: Bool;
  public let allowWhistle: Bool;
}

// Data structures for breach processing results
public struct BreachUnlockFlags {
  public let unlockBasic: Bool;
  public let unlockNPCs: Bool;
  public let unlockCameras: Bool;
  public let unlockTurrets: Bool;
}

public abstract class DeviceTypeUtils {

  // ===================================
  // Type Detection
  // ===================================

  /*
   * Determines device type from DeviceComponentPS
   * @param device - Device persistent state
   * @return TargetType enum value (NPC, Camera, Turret, Basic)
   */
  public static func GetDeviceType(device: ref<DeviceComponentPS>) -> TargetType {
    // NPCs (PuppetDeviceLink or CommunityProxy)
    if IsDefined(device as PuppetDeviceLinkPS) || IsDefined(device as CommunityProxyPS) {
      return TargetType.NPC;
    }

    // Get owner entity for Camera/Turret detection
    let entity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;

    // Cameras
    if IsDefined(entity as SurveillanceCamera) {
      return TargetType.Camera;
    }

    // Turrets
    if IsDefined(entity as SecurityTurret) {
      return TargetType.Turret;
    }

    return TargetType.Basic;
  }

  /*
   * Type detection from GameObject entity
   * @param entity - Game object entity
   * @return TargetType enum value
   */
  public static func GetDeviceTypeFromEntity(entity: wref<GameObject>) -> TargetType {
    if IsDefined(entity as SurveillanceCamera) {
      return TargetType.Camera;
    }
    if IsDefined(entity as SecurityTurret) {
      return TargetType.Turret;
    }
    if IsDefined(entity as ScriptedPuppet) {
      return TargetType.NPC;
    }
    return TargetType.Basic;
  }

  /* IsCameraDevice() - Checks if device is a camera */
  public static func IsCameraDevice(device: ref<DeviceComponentPS>) -> Bool {
    return Equals(DeviceTypeUtils.GetDeviceType(device), TargetType.Camera);
  }

  /* IsTurretDevice() - Checks if device is a turret */
  public static func IsTurretDevice(device: ref<DeviceComponentPS>) -> Bool {
    return Equals(DeviceTypeUtils.GetDeviceType(device), TargetType.Turret);
  }

  /* IsNPCDevice() - Checks if device is an NPC */
  public static func IsNPCDevice(device: ref<DeviceComponentPS>) -> Bool {
    return Equals(DeviceTypeUtils.GetDeviceType(device), TargetType.NPC);
  }

  /* IsBasicDevice() - Checks if device is a basic device */
  public static func IsBasicDevice(device: ref<DeviceComponentPS>) -> Bool {
    return Equals(DeviceTypeUtils.GetDeviceType(device), TargetType.Basic);
  }

  // ===================================
  // Breach Flag Management
  // ===================================

  /*
   * Gets breach state for specific device type
   * @param TargetType - Type of device to check
   * @param sharedPS - Shared gameplay persistent state
   * @return True if device type is breached
   */
  public static func IsBreached(TargetType: TargetType, sharedPS: ref<SharedGameplayPS>) -> Bool {
    if !IsDefined(sharedPS) {
      return false;
    }

    switch TargetType {
      case TargetType.NPC:
        return BreachStatusUtils.IsNPCsBreached(sharedPS);
      case TargetType.Camera:
        return BreachStatusUtils.IsCamerasBreached(sharedPS);
      case TargetType.Turret:
        return BreachStatusUtils.IsTurretsBreached(sharedPS);
      default: // TargetType.Basic
        return BreachStatusUtils.IsBasicBreached(sharedPS);
    }
  }

  // ==================== Unlock Flag Management ====================

  /*
   * ShouldUnlockByFlags() - Device Unlock Flag Check
   *
   * Checks if device type should be unlocked based on BreachUnlockFlags.
   *
   * @param TargetType Type of device to check
   * @param flags Breach unlock flags
   * @return True if device type should be unlocked
   */
  public static func ShouldUnlockByFlags(TargetType: TargetType, flags: BreachUnlockFlags) -> Bool {
    switch TargetType {
      case TargetType.NPC:
        return flags.unlockNPCs;
      case TargetType.Camera:
        return flags.unlockCameras;
      case TargetType.Turret:
        return flags.unlockTurrets;
      default: // TargetType.Basic
        return flags.unlockBasic;
    }
  }

  // ==================== Helper Predicates ====================

  // Type checking predicates for readability
  public static func IsNPC(TargetType: TargetType) -> Bool {
    return Equals(TargetType, TargetType.NPC);
  }

  public static func IsCamera(TargetType: TargetType) -> Bool {
    return Equals(TargetType, TargetType.Camera);
  }

  public static func IsTurret(TargetType: TargetType) -> Bool {
    return Equals(TargetType, TargetType.Turret);
  }

  public static func IsBasicDevice(TargetType: TargetType) -> Bool {
    return Equals(TargetType, TargetType.Basic);
  }

  // ==================== Debug Utilities ====================

  // Converts TargetType enum to string for logging
  public static func DeviceTypeToString(TargetType: TargetType) -> String {
    switch TargetType {
      case TargetType.NPC: return "NPC";
      case TargetType.Camera: return "Camera";
      case TargetType.Turret: return "Turret";
      default: return "Basic";
    }
  }
}
