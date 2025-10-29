// ============================================================================
// BetterNetrunning - RadialBreach MOD Gating Layer
// ============================================================================
//
// PURPOSE:
// Provides conditional gating for RadialBreach MOD integration
// (https://www.nexusmods.com/cyberpunk2077/mods/14816)
// Enables physical proximity-based breach filtering for network devices.
//
// FUNCTIONALITY:
// - Conditionally compiled based on RadialBreach MOD presence
// - Syncs breach range configuration with RadialBreach settings
// - Implements physical distance filtering for network devices
// - Records network centroid position for radial unlock system
// - Supports both AccessPoint breach and RemoteBreach
//
// ARCHITECTURE:
// - @if(ModuleExists("RadialBreach")): Full RadialBreach gating enabled
// - @if(!ModuleExists("RadialBreach")): Fallback stubs (no physical filtering)
//
// MOD COMPATIBILITY:
// - Works with or without RadialBreach MOD installed
// - Automatically syncs breach range with RadialBreach Native Settings
// - Delegates to vanilla behavior when MOD not present
//
// NAMING CONVENTION:
// - Follows [MOD]Gating.reds pattern (e.g., DNRGating.reds, RadialBreachGating.reds)
// - "Gating" = Conditional filtering layer for external MOD integration
// ============================================================================

module BetterNetrunning.Integration

import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Utils.*

// Conditional import: Only load RadialBreach settings when MOD exists
@if(ModuleExists("RadialBreach"))
import RadialBreach.Config.*

// ============================================================================
// RADIALBREACH INTEGRATION LAYER (External Dependency Isolation)
// ============================================================================

/*
 * GetRadialBreachRange - External dependency isolation function
 *
 * PURPOSE:
 * Centralizes RadialBreach MOD integration logic in Integration/ layer
 * Isolates external dependency (RadialBreachSettings) from Core/ layer
 *
 * ARCHITECTURE:
 * - Single Responsibility: RadialBreach MOD configuration access
 * - Design Principle: External dependencies must be isolated in Integration/
 * - Delegation Pattern: Core/DeviceTypeUtils delegates to this function
 *
 * RATIONALE:
 * Core/ modules should NOT depend on external MODs directly
 * Integration/ layer provides conditional gating and fallback logic
 *
 * FUNCTIONALITY:
 * - Reads config.breachRange from RadialBreach Native Settings (10-50m, default 25m)
 * - Falls back to 50m if RadialBreach disabled or invalid
 *
 * USAGE:
 * let range: Float = GetRadialBreachRange(gameInstance);
 */
@if(ModuleExists("RadialBreach"))
public static func GetRadialBreachRange(gameInstance: GameInstance) -> Float {
  let config: ref<RadialBreachSettings> = new RadialBreachSettings();

  // Use RadialBreach user setting if enabled and valid
  if config.enabled && config.breachRange > 0.0 {
    return config.breachRange;
  }

  // Fallback: 50m when RadialBreach disabled or invalid
  return 50.0;
}

// Fallback stub: Returns default 50m when RadialBreach MOD not installed
@if(!ModuleExists("RadialBreach"))
public static func GetRadialBreachRange(gameInstance: GameInstance) -> Float {
  return 50.0;
}

// ============================================================================
// BREACH POSITION TRACKING
// ============================================================================

/// Gets the breach position (AccessPoint position or player position as fallback)
/// Used for network centroid calculation and radial unlock system
@addMethod(AccessPointControllerPS)
public final func GetBreachPosition() -> Vector4 {
  // Try to get AccessPoint entity position
  let apEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  if IsDefined(apEntity) {
    return apEntity.GetWorldPosition();
  }

  // Fallback: player position
  let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
  if IsDefined(player) {
    return player.GetWorldPosition();
  }

  // Error signal (prevents filtering all devices if position unavailable)
  BNError("RadialBreach", "Could not get breach position - returning error signal");
  return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
}

// ============================================================================
// DEVICE UNLOCK APPLICATION (CONDITIONAL COMPILATION)
// ============================================================================

/// Applies device-type-specific unlock to all connected devices
/// RadialBreach version: Filters devices by physical proximity
/// Architecture: Shallow nesting (max 2 levels) using helper methods
@if(ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
public final func ApplyBreachUnlockToDevices(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  // RadialBreach Integration - Physical Distance Filtering
  let breachPosition: Vector4 = this.GetBreachPosition();
  let maxDistance: Float = GetRadialBreachRange(this.GetGameInstance());
  let shouldUseRadialFiltering: Bool = breachPosition.X >= -999000.0;

  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];

    // Physical distance check (RadialBreach integration)
    let withinRadius: Bool = !shouldUseRadialFiltering ||
                             DeviceDistanceUtils.IsDeviceWithinRadius(device, breachPosition, maxDistance, this.GetGameInstance());

    if withinRadius {
      // Process device unlock
      this.ProcessSingleDeviceUnlock(device, unlockFlags);
    }
    i += 1;
  }
}

/// Applies device-type-specific unlock to all connected devices
/// Fallback version: No physical filtering (unlocks all devices in network)
/// Architecture: Shallow nesting (max 2 levels)
@if(!ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
public final func ApplyBreachUnlockToDevices(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  // No RadialBreach filtering - unlock all devices in network
  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];
    this.ProcessSingleDeviceUnlock(device, unlockFlags);
    i += 1;
  }
}

/// Helper: Process unlock for a single device (shared by both versions)
@addMethod(AccessPointControllerPS)
private final func ProcessSingleDeviceUnlock(device: ref<DeviceComponentPS>, unlockFlags: BreachUnlockFlags) -> Void {
  // Apply device-type-specific unlock
  this.ApplyDeviceTypeUnlock(device, unlockFlags);

  // REMOVED: ProcessMinigameNetworkActions(device)
  // REASON: Vanilla ProcessMinigameNetworkActions() unlocks ALL devices without checking unlockFlags
  // This caused vehicles to be re-unlocked after RollbackIncorrectVanillaUnlocks()
  // ApplyDeviceTypeUnlock() already handles device unlocking with proper flag checks

  // Queue SetBreachedSubnet event with timestamps
  let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(this.GetGameInstance());

  let evt: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  evt.unlockTimestampBasic = unlockFlags.unlockBasic ? currentTime : 0.0;
  evt.unlockTimestampNPCs = unlockFlags.unlockNPCs ? currentTime : 0.0;
  evt.unlockTimestampCameras = unlockFlags.unlockCameras ? currentTime : 0.0;
  evt.unlockTimestampTurrets = unlockFlags.unlockTurrets ? currentTime : 0.0;
  this.GetPersistencySystem().QueuePSEvent(device.GetID(), device.GetClassName(), evt);
}

// ============================================================================
// REMOTEBREACH INTEGRATION
// ============================================================================

// Direct API calls for clarity and minimal indirection
// Uses: GetRadialBreachRange(gameInstance), DeviceDistanceUtils.IsDeviceWithinRadius(...)

// ============================================================================
// SHARED HELPER METHODS
// ============================================================================

/// Applies unlock to a single RemoteBreach network device
/// Shared by both RadialBreach and Fallback versions
@addMethod(PlayerPuppet)
private final func ApplyRemoteBreachDeviceUnlockInternal(
  device: ref<DeviceComponentPS>,
  unlockFlags: BreachUnlockFlags
) -> Bool {
  let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
  if !IsDefined(sharedPS) {
    return false;
  }

  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

  // Validate device type against unlock flags (daemon-based filtering)
  if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
    return false;
  }

  // Apply unlock
  let dummyAPPS: ref<AccessPointControllerPS> = new AccessPointControllerPS();
  dummyAPPS.QueuePSEvent(device, dummyAPPS.ActionSetExposeQuickHacks());

  // Set breach timestamp (device type-specific)
  let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(this.GetGame());
  DeviceUnlockUtils.SetDeviceUnlockTimestamp(sharedPS, deviceType, currentTime);

  // Set breached subnet event with timestamps
  let setBreachedSubnetEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  setBreachedSubnetEvent.unlockTimestampBasic = unlockFlags.unlockBasic ? currentTime : 0.0;
  setBreachedSubnetEvent.unlockTimestampNPCs = unlockFlags.unlockNPCs ? currentTime : 0.0;
  setBreachedSubnetEvent.unlockTimestampCameras = unlockFlags.unlockCameras ? currentTime : 0.0;
  setBreachedSubnetEvent.unlockTimestampTurrets = unlockFlags.unlockTurrets ? currentTime : 0.0;
  GameInstance.GetPersistencySystem(this.GetGame()).QueuePSEvent(device.GetID(), device.GetClassName(), setBreachedSubnetEvent);

  return true;
}

/// Applies RemoteBreach network unlock (RadialBreach MOD version)
/// Uses daemon-based filtering + physical distance filtering
@if(ModuleExists("RadialBreach"))
@addMethod(PlayerPuppet)
public final func ApplyRemoteBreachNetworkUnlock(
  targetDevice: ref<ScriptableDeviceComponentPS>,
  networkDevices: array<ref<DeviceComponentPS>>,
  unlockFlags: BreachUnlockFlags
) -> Void {
  let unlockedCount: Int32 = 0;
  let skippedCount: Int32 = 0;
  let filteredCount: Int32 = 0;

  // Get breach position (target device position)
  let targetEntity: wref<GameObject> = targetDevice.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(targetEntity) {
    BNError("RadialBreach", "Target entity not found for RadialBreach filtering");
    return;
  }

  let breachPosition: Vector4 = targetEntity.GetWorldPosition();
  let maxDistance: Float = GetRadialBreachRange(this.GetGame());
  let shouldUseRadialFiltering: Bool = breachPosition.X >= -999000.0;

  let i: Int32 = 0;
  while i < ArraySize(networkDevices) {
    let device: ref<DeviceComponentPS> = networkDevices[i];

    if IsDefined(device) {
      // Physical distance check (RadialBreach integration)
      let withinRadius: Bool = !shouldUseRadialFiltering ||
                               DeviceDistanceUtils.IsDeviceWithinRadius(device, breachPosition, maxDistance, this.GetGame());

      if withinRadius {
        // Apply unlock using shared helper
        if this.ApplyRemoteBreachDeviceUnlockInternal(device, unlockFlags) {
          unlockedCount += 1;
        } else {
          skippedCount += 1;
        }
      } else {
        filteredCount += 1;
      }
    }

    i += 1;
  }
}

/// Applies RemoteBreach network unlock (Fallback version - no RadialBreach)
/// Uses daemon-based filtering only (no physical distance filtering)
@if(!ModuleExists("RadialBreach"))
@addMethod(PlayerPuppet)
public final func ApplyRemoteBreachNetworkUnlock(
  targetDevice: ref<ScriptableDeviceComponentPS>,
  networkDevices: array<ref<DeviceComponentPS>>,
  unlockFlags: BreachUnlockFlags
) -> Void {
  let unlockedCount: Int32 = 0;
  let skippedCount: Int32 = 0;

  let i: Int32 = 0;
  while i < ArraySize(networkDevices) {
    let device: ref<DeviceComponentPS> = networkDevices[i];

    if IsDefined(device) {
      // Apply unlock using shared helper (no distance check)
      if this.ApplyRemoteBreachDeviceUnlockInternal(device, unlockFlags) {
        unlockedCount += 1;
      } else {
        skippedCount += 1;
      }
    }

    i += 1;
  }
}
