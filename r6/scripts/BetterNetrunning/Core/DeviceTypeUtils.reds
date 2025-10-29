// -----------------------------------------------------------------------------
// Device Type Utilities
// -----------------------------------------------------------------------------
// Provides centralized device type classification and breach flag management.
// Eliminates duplicate device type checking logic across the codebase.
//
// DESIGN RATIONALE:
// - Single Responsibility: Device type determination
// - DRY Principle: Replaces 16+ duplicate type checks
// - Type Safety: Enum-based classification
// - Maintainability: Centralized breach flag access
//
// USAGE:
// let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(devicePS);
// if DeviceTypeUtils.IsBreached(deviceType, sharedPS) { ... }
// -----------------------------------------------------------------------------

module BetterNetrunning.Core

import BetterNetrunning.Integration.*

// Device type classification enum
public enum DeviceType {
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

public struct BreachLootResult {
  public let baseMoney: Float;
  public let craftingMaterial: Bool;
  public let baseShardDropChance: Float;
  public let shouldLoot: Bool;
  public let markForErase: Bool;
  public let eraseIndex: Int32;
  public let unlockFlags: BreachUnlockFlags;
}

// Centralized device type utilities
public abstract class DeviceTypeUtils {

  // ==================== Type Detection ====================

  // Determines device type from DeviceComponentPS
  // Replaces duplicate if-else chains across codebase
  public static func GetDeviceType(device: ref<DeviceComponentPS>) -> DeviceType {
    // NPCs (PuppetDeviceLink or CommunityProxy)
    if IsDefined(device as PuppetDeviceLinkPS) || IsDefined(device as CommunityProxyPS) {
      return DeviceType.NPC;
    }

    // Get owner entity for Camera/Turret detection
    let entity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;

    // Cameras
    if IsDefined(entity as SurveillanceCamera) {
      return DeviceType.Camera;
    }

    // Turrets
    if IsDefined(entity as SecurityTurret) {
      return DeviceType.Turret;
    }

    // Basic devices (everything else)
    return DeviceType.Basic;
  }

  // Alternative: Type detection from GameObject entity
  public static func GetDeviceTypeFromEntity(entity: wref<GameObject>) -> DeviceType {
    if IsDefined(entity as SurveillanceCamera) {
      return DeviceType.Camera;
    }
    if IsDefined(entity as SecurityTurret) {
      return DeviceType.Turret;
    }
    if IsDefined(entity as ScriptedPuppet) {
      return DeviceType.NPC;
    }
    return DeviceType.Basic;
  }

  // Convenience methods for type checking
  public static func IsCameraDevice(device: ref<DeviceComponentPS>) -> Bool {
    return Equals(DeviceTypeUtils.GetDeviceType(device), DeviceType.Camera);
  }

  public static func IsTurretDevice(device: ref<DeviceComponentPS>) -> Bool {
    return Equals(DeviceTypeUtils.GetDeviceType(device), DeviceType.Turret);
  }

  public static func IsNPCDevice(device: ref<DeviceComponentPS>) -> Bool {
    return Equals(DeviceTypeUtils.GetDeviceType(device), DeviceType.NPC);
  }

  public static func IsBasicDevice(device: ref<DeviceComponentPS>) -> Bool {
    return Equals(DeviceTypeUtils.GetDeviceType(device), DeviceType.Basic);
  }

  // ==================== Breach Flag Management ====================

  // Gets breach state for specific device type
  // Centralizes unlock timestamp field access (unified state check)
  public static func IsBreached(deviceType: DeviceType, sharedPS: ref<SharedGameplayPS>) -> Bool {
    if !IsDefined(sharedPS) {
      return false;
    }

    switch deviceType {
      case DeviceType.NPC:
        return BreachStatusUtils.IsNPCsBreached(sharedPS);
      case DeviceType.Camera:
        return BreachStatusUtils.IsCamerasBreached(sharedPS);
      case DeviceType.Turret:
        return BreachStatusUtils.IsTurretsBreached(sharedPS);
      default: // DeviceType.Basic
        return BreachStatusUtils.IsBasicBreached(sharedPS);
    }
  }

  // ==================== Unlock Flag Management ====================

  // Checks if device type should be unlocked based on BreachUnlockFlags
  public static func ShouldUnlockByFlags(deviceType: DeviceType, flags: BreachUnlockFlags) -> Bool {
    switch deviceType {
      case DeviceType.NPC:
        return flags.unlockNPCs;
      case DeviceType.Camera:
        return flags.unlockCameras;
      case DeviceType.Turret:
        return flags.unlockTurrets;
      default: // DeviceType.Basic
        return flags.unlockBasic;
    }
  }

  // ==================== Helper Predicates ====================

  // Type checking predicates for readability
  public static func IsNPC(deviceType: DeviceType) -> Bool {
    return Equals(deviceType, DeviceType.NPC);
  }

  public static func IsCamera(deviceType: DeviceType) -> Bool {
    return Equals(deviceType, DeviceType.Camera);
  }

  public static func IsTurret(deviceType: DeviceType) -> Bool {
    return Equals(deviceType, DeviceType.Turret);
  }

  public static func IsBasicDevice(deviceType: DeviceType) -> Bool {
    return Equals(deviceType, DeviceType.Basic);
  }

  // ==================== Debug Utilities ====================

  // Converts DeviceType enum to string for logging
  public static func DeviceTypeToString(deviceType: DeviceType) -> String {
    switch deviceType {
      case DeviceType.NPC: return "NPC";
      case DeviceType.Camera: return "Camera";
      case DeviceType.Turret: return "Turret";
      default: return "Basic";
    }
  }

  // ==================== RemoteBreach Support ====================

  // Determines device type from GameObject entity (for RemoteBreach cost calculation)
  // Centralizes entity-based type detection for RAM cost multipliers
  public static func GetDeviceTypeForRemoteBreach(entity: wref<GameObject>) -> DeviceType {
    if IsDefined(entity as SurveillanceCamera) {
      return DeviceType.Camera;
    }
    if IsDefined(entity as SecurityTurret) {
      return DeviceType.Turret;
    }
    if IsDefined(entity as ScriptedPuppet) {
      return DeviceType.NPC;
    }
    return DeviceType.Basic;
  }

  // Gets RAM cost multiplier based on device type (for RemoteBreach dynamic cost)
  // Camera/Turret: 1.5x, NPC: 2.0x, Basic: 1.0x
  public static func GetRemoteBreachCostMultiplier(deviceType: DeviceType) -> Float {
    switch deviceType {
      case DeviceType.Camera:
        return 1.5;
      case DeviceType.Turret:
        return 1.5;
      case DeviceType.NPC:
        return 2.0;
      default: // DeviceType.Basic
        return 1.0;
    }
  }
}
