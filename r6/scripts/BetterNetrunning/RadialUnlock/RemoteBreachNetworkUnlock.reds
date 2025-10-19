// ============================================================================
// BetterNetrunning - RemoteBreach Network Unlock Integration
// ============================================================================
// Extends RemoteBreach (CustomHackingSystem) to apply network effects similar
// to AccessPoint breach. Provides target device unlock + Radial Unlock support.
//
// FUNCTIONALITY:
// - Target device unlock: Immediate unlock of breached device
// - Network-wide unlock: Propagates unlock to all connected devices (same as AccessPoint breach)
// - Radial Unlock: Records breach position for standalone device support (50m radius)
// - NPC duplicate prevention: Tracks directly breached NPCs (m_betterNetrunningWasDirectlyBreached flag on ScriptedPuppetPS)
// - Loot rewards: Datamine programs provide money/crafting materials/shards
// - RadialBreach integration: Physical distance filtering (50m default)
//
// ARCHITECTURE:
// - OnRemoteBreachSucceeded callback (RemoteBreachHelpers.reds) handles breach success with statistics
// - RemoteBreachStateSystem integration for target device retrieval
// - DeviceTypeUtils for unified device unlock logic
// - RadialUnlockSystem for position recording
// - TransactionSystem for loot rewards
// - RadialBreachGating for physical distance filtering
//
// DEPENDENCIES:
// - BetterNetrunning.Common.* (DeviceTypeUtils, BNLog)
// - BetterNetrunning.RemoteBreach.Core.* (RemoteBreachStateSystem variants, RemoteBreachHelpers)
// - BetterNetrunning.RadialUnlock.* (RecordAccessPointBreachByPosition, RadialBreachGating)
// ============================================================================

module BetterNetrunning.RadialUnlock

import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.RemoteBreach.Actions.*
import BetterNetrunning.RemoteBreach.UI.*
import BetterNetrunningConfig.*

// NOTE: RadialBreach integration is handled by RadialBreachGating.reds

// ============================================================================
// DATA STRUCTURES
// ============================================================================

// RemoteBreach loot reward accumulator (reduces parameter passing)
// Using struct instead of class to avoid ref<> requirement
public struct RemoteBreachLootData {
  let baseMoney: Float;
  let craftingMaterial: Bool;
  let baseShardDropChance: Float;
  let shouldLoot: Bool;
}
// No need for conditional import here - RadialBreachGating manages it

// ============================================================================
// UNCONSCIOUS NPC BREACH PROCESSING
// ============================================================================

// Apply network unlock to devices after Unconscious NPC Breach
@addMethod(PlayerPuppet)
private func ApplyUnconsciousNPCNetworkUnlockWithStats(
  networkDevices: array<ref<DeviceComponentPS>>,
  unlockFlags: BreachUnlockFlags,
  stats: ref<BreachSessionStats>
) -> Void {
  let i: Int32 = 0;

  while i < ArraySize(networkDevices) {
    let device: ref<DeviceComponentPS> = networkDevices[i];
    if IsDefined(device) {
      let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

      // Check if this device type should be unlocked
      if DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
        let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
        if IsDefined(sharedPS) {
          // Apply device-type-specific unlock timestamp
          let currentTime: Float = TimeUtils.GetCurrentTimestamp(this.GetGame());
          TimeUtils.SetDeviceUnlockTimestamp(sharedPS, deviceType, currentTime);

          // DEBUG: Log timestamp application
          BNTrace("UnconsciousNPCUnlock", "Applied unlock timestamp: " +
            ToString(currentTime) + " to device type: " +
            EnumValueToString("DeviceType", Cast<Int64>(EnumInt(deviceType))));

          // Update statistics
          stats.devicesUnlocked += 1;
          if Equals(deviceType, DeviceType.Camera) {
            stats.cameraCount += 1;
          } else if Equals(deviceType, DeviceType.Turret) {
            stats.turretCount += 1;
          } else if Equals(deviceType, DeviceType.NPC) {
            stats.npcNetworkCount += 1;
          } else {
            stats.basicCount += 1;
          }
        } else {
          stats.devicesSkipped += 1;
        }
      } else {
        stats.devicesSkipped += 1;
      }
    }
    i += 1;
  }
}

// Record unconscious NPC breach position for radial unlock
@addMethod(PlayerPuppet)
private func RecordUnconsciousNPCBreachPosition(targetNPC: ref<ScriptedPuppet>) -> Void {
  if !IsDefined(targetNPC) {
    return;
  }

  let position: Vector4 = targetNPC.GetWorldPosition();
  RecordAccessPointBreachByPosition(position, this.GetGame());

  BNInfo("UnconsciousNPC", "Recorded breach position for radial unlock");
}

// ============================================================================
// REMOTEBREACH DETECTION
// ============================================================================

// Check if current minigame is a RemoteBreach (not AccessPoint or Quickhack)
@addMethod(PlayerPuppet)
private func IsRemoteBreachMinigame() -> Bool {
  let gameInstance: GameInstance = this.GetGame();
  let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);

  // Check Computer RemoteBreach
  let computerSystem: ref<RemoteBreachStateSystem> = container.Get(BNConstants.CLASS_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
  if IsDefined(computerSystem) {
    let currentComputer: wref<ComputerControllerPS> = computerSystem.GetCurrentComputer();
    if IsDefined(currentComputer) {
      return true;
    }
  }

  // Check Device RemoteBreach
  let deviceSystem: ref<DeviceRemoteBreachStateSystem> = container.Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as DeviceRemoteBreachStateSystem;
  if IsDefined(deviceSystem) {
    let currentDevice: wref<ScriptableDeviceComponentPS> = deviceSystem.GetCurrentDevice();
    if IsDefined(currentDevice) {
      return true;
    }
  }

  // Check Vehicle RemoteBreach
  let vehicleSystem: ref<VehicleRemoteBreachStateSystem> = container.Get(BNConstants.CLASS_VEHICLE_REMOTE_BREACH_STATE_SYSTEM()) as VehicleRemoteBreachStateSystem;
  if IsDefined(vehicleSystem) {
    let currentVehicle: wref<VehicleComponentPS> = vehicleSystem.GetCurrentVehicle();
    if IsDefined(currentVehicle) {
      return true;
    }
  }

  return false;
}

// Check if current minigame is an Unconscious NPC Breach
@addMethod(PlayerPuppet)
private func IsUnconsciousNPCBreachMinigame() -> Bool {
  let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGame()).Get(GetAllBlackboardDefs().HackingMinigame);

  if !IsDefined(minigameBB) {
    return false;
  }

  // Check if the target entity is an unconscious NPC
  let entity: wref<Entity> = FromVariant<wref<Entity>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity));

  if !IsDefined(entity) {
    return false;
  }

  // Check if entity is a ScriptedPuppet (NPC)
  let puppet: ref<ScriptedPuppet> = entity as ScriptedPuppet;
  if !IsDefined(puppet) {
    return false;
  }

  // Check if NPC is incapacitated (unconscious)
  return puppet.IsIncapacitated();
}

// ============================================================================
// DEBUG LOGGING (REMOVED - now handled by statistics)
// ============================================================================

// ============================================================================
// NETWORK UNLOCK PROCESSING
// ============================================================================

// Apply network unlock to devices after RemoteBreach (with statistics)
@addMethod(PlayerPuppet)
private func ApplyRemoteBreachNetworkUnlockWithStats(
  targetDevice: ref<ScriptableDeviceComponentPS>,
  networkDevices: array<ref<DeviceComponentPS>>,
  unlockFlags: BreachUnlockFlags,
  stats: ref<BreachSessionStats>
) -> Void {
  let i: Int32 = 0;

  while i < ArraySize(networkDevices) {
    let device: ref<DeviceComponentPS> = networkDevices[i];
    if IsDefined(device) {
      let scriptableDevice: ref<ScriptableDeviceComponentPS> = device as ScriptableDeviceComponentPS;
      if IsDefined(scriptableDevice) {
        let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(scriptableDevice);

        // Check if this device type should be unlocked
        if DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
          let sharedPS: ref<SharedGameplayPS> = scriptableDevice;
          if IsDefined(sharedPS) {
            // Apply device-type-specific unlock timestamp
            let currentTime: Float = TimeUtils.GetCurrentTimestamp(this.GetGame());
            TimeUtils.SetDeviceUnlockTimestamp(sharedPS, deviceType, currentTime);

            // Update statistics
            stats.devicesUnlocked += 1;
            if Equals(deviceType, DeviceType.Camera) {
              stats.cameraCount += 1;
            } else if Equals(deviceType, DeviceType.Turret) {
              stats.turretCount += 1;
            } else if Equals(deviceType, DeviceType.NPC) {
              stats.npcNetworkCount += 1;
            } else {
              stats.basicCount += 1;
            }
          } else {
            stats.devicesSkipped += 1;
          }
        } else {
          stats.devicesSkipped += 1;
        }
      }
    }
    i += 1;
  }
}

// ============================================================================
// DEBUG LOGGING (REMOVED - now handled by statistics)
// ============================================================================

// ============================================================================
// PROGRAM PARSING
// ============================================================================

// Parse unlock flags from active minigame programs
@addMethod(PlayerPuppet)
private func ParseRemoteBreachUnlockFlags(activePrograms: array<TweakDBID>) -> BreachUnlockFlags {
  let flags: BreachUnlockFlags;

  let i: Int32 = 0;
  while i < ArraySize(activePrograms) {
    let programID: TweakDBID = activePrograms[i];

    if Equals(programID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS()) {
      flags.unlockBasic = true;
    } else if Equals(programID, BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()) {
      flags.unlockNPCs = true;
    } else if Equals(programID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()) {
      flags.unlockCameras = true;
    } else if Equals(programID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()) {
      flags.unlockTurrets = true;
    }

    i += 1;
  }

  return flags;
}

// ============================================================================
// TARGET DEVICE RETRIEVAL
// ============================================================================

// Get RemoteBreach target device from state systems
@addMethod(PlayerPuppet)
private func GetRemoteBreachTargetDevice() -> ref<ScriptableDeviceComponentPS> {
  let gameInstance: GameInstance = this.GetGame();
  let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);

  // Try Computer RemoteBreach
  let computerSystem: ref<RemoteBreachStateSystem> = container.Get(BNConstants.CLASS_REMOTE_BREACH_STATE_SYSTEM()) as RemoteBreachStateSystem;
  if IsDefined(computerSystem) {
    let currentComputer: wref<ComputerControllerPS> = computerSystem.GetCurrentComputer();
    if IsDefined(currentComputer) {
      return currentComputer;
    }
  }

  // Try Device RemoteBreach
  let deviceSystem: ref<DeviceRemoteBreachStateSystem> = container.Get(BNConstants.CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM()) as DeviceRemoteBreachStateSystem;
  if IsDefined(deviceSystem) {
    let currentDevice: wref<ScriptableDeviceComponentPS> = deviceSystem.GetCurrentDevice();
    if IsDefined(currentDevice) {
      return currentDevice;
    }
  }

  // Try Vehicle RemoteBreach
  let vehicleSystem: ref<VehicleRemoteBreachStateSystem> = container.Get(BNConstants.CLASS_VEHICLE_REMOTE_BREACH_STATE_SYSTEM()) as VehicleRemoteBreachStateSystem;
  if IsDefined(vehicleSystem) {
    let currentVehicle: wref<VehicleComponentPS> = vehicleSystem.GetCurrentVehicle();
    if IsDefined(currentVehicle) {
      return currentVehicle;
    }
  }

  return null;
}

// ============================================================================
// NETWORK DEVICE RETRIEVAL
// ============================================================================

// Get all network devices connected to RemoteBreach target device
// Uses GetAccessPoints() + GetChildren() API (same as AccessPoint breach)
// Architecture: Shallow nesting (max 2 levels) using helper methods
@addMethod(PlayerPuppet)
private func GetRemoteBreachNetworkDevices(
  targetDevice: ref<ScriptableDeviceComponentPS>
) -> array<ref<DeviceComponentPS>> {
  let networkDevices: array<ref<DeviceComponentPS>>;

  // ScriptableDeviceComponentPS extends SharedGameplayPS
  let sharedPS: ref<SharedGameplayPS> = targetDevice;
  if !IsDefined(sharedPS) {
    return networkDevices;
  }

  // Get all AccessPoints in network
  let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
  if ArraySize(apControllers) == 0 {
    return networkDevices;
  }

  // Collect devices from all AccessPoints
  let i: Int32 = 0;
  while i < ArraySize(apControllers) {
    this.CollectAccessPointDevices(apControllers[i], i, networkDevices);
    i += 1;
  }

  return networkDevices;
}

// Helper: Collect all devices from a single AccessPoint
@addMethod(PlayerPuppet)
private func CollectAccessPointDevices(
  apPS: ref<AccessPointControllerPS>,
  apIndex: Int32,
  out networkDevices: array<ref<DeviceComponentPS>>
) -> Void {
  if !IsDefined(apPS) {
    return;
  }

  let apDevices: array<ref<DeviceComponentPS>>;
  apPS.GetChildren(apDevices);

  // Merge devices into main array
  let j: Int32 = 0;
  while j < ArraySize(apDevices) {
    ArrayPush(networkDevices, apDevices[j]);
    j += 1;
  }
}

// ============================================================================
// DEVICE UNLOCK LOGIC
// ============================================================================

// Apply unlock to RemoteBreach target device (with statistics)
@addMethod(PlayerPuppet)
private func ApplyRemoteBreachDeviceUnlockWithStats(
  targetDevice: ref<ScriptableDeviceComponentPS>,
  unlockFlags: BreachUnlockFlags,
  stats: ref<BreachSessionStats>
) -> Void {
  // ScriptableDeviceComponentPS already extends SharedGameplayPS, no cast needed
  if !IsDefined(targetDevice) {
    BNError("[RemoteBreach]", "Target device is not defined, cannot unlock");
    return;
  }

  // Use DeviceTypeUtils for centralized device type detection
  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(targetDevice);

  // Check if this device type should be unlocked based on flags
  if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
    stats.devicesSkipped += 1;
    return;
  }

  // Unlock quickhacks (reuse AccessPointControllerPS method via helper)
  let dummyAPPS: ref<AccessPointControllerPS> = new AccessPointControllerPS();
  dummyAPPS.QueuePSEvent(targetDevice, dummyAPPS.ActionSetExposeQuickHacks());

  // Set breach timestamp
  let currentTime: Float = TimeUtils.GetCurrentTimestamp(this.GetGame());
  TimeUtils.SetDeviceUnlockTimestamp(targetDevice, deviceType, currentTime);

  // Set breached subnet event (propagate unlock timestamps to device)
  let setBreachedSubnetEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  setBreachedSubnetEvent.unlockTimestampBasic = unlockFlags.unlockBasic ? currentTime : 0.0;
  setBreachedSubnetEvent.unlockTimestampNPCs = unlockFlags.unlockNPCs ? currentTime : 0.0;
  setBreachedSubnetEvent.unlockTimestampCameras = unlockFlags.unlockCameras ? currentTime : 0.0;
  setBreachedSubnetEvent.unlockTimestampTurrets = unlockFlags.unlockTurrets ? currentTime : 0.0;
  GameInstance.GetPersistencySystem(this.GetGame()).QueuePSEvent(targetDevice.GetID(), targetDevice.GetClassName(), setBreachedSubnetEvent);

  // Update statistics
  stats.devicesUnlocked += 1;
  if Equals(deviceType, DeviceType.Camera) {
    stats.cameraCount += 1;
  } else if Equals(deviceType, DeviceType.Turret) {
    stats.turretCount += 1;
  } else if Equals(deviceType, DeviceType.NPC) {
    stats.npcNetworkCount += 1;
  } else {
    stats.basicCount += 1;
  }
}

// ============================================================================
// ============================================================================
// LOOT REWARD SYSTEM
// ============================================================================

// NOTE: ProcessRemoteBreachLoot() and related helpers consolidated (2025-10-12)
// RATIONALE: Datamine reward processing moved to MinigameProgramUtils.reds (shared utility)
// CURRENT IMPLEMENTATION: ProcessMinigamePrograms() in MinigameProgramUtils.reds

// ============================================================================
// RADIAL UNLOCK INTEGRATION
// ============================================================================

// Record RemoteBreach position for Radial Unlock system (50m radius)
@addMethod(PlayerPuppet)
private func RecordRemoteBreachPosition(targetDevice: ref<ScriptableDeviceComponentPS>) -> Void {
  let deviceEntity: wref<GameObject> = targetDevice.GetOwnerEntityWeak() as GameObject;

  if !IsDefined(deviceEntity) {
    BNWarn("[RemoteBreach]", "Target device entity not found, cannot record position");
    return;
  }

  let devicePosition: Vector4 = deviceEntity.GetWorldPosition();

  // Record position for Radial Unlock system (enables 50m radius unlock)
  RecordAccessPointBreachByPosition(devicePosition, this.GetGame());
}

// ============================================================================
// NEARBY STANDALONE DEVICE UNLOCK (PR #5 Feature)
// ============================================================================

/*
 * Unlock nearby standalone devices after breaching any device
 *
 * FEATURE: Auto-unlock standalone devices within 50m radius
 * RATIONALE: Extends RemoteBreach effectiveness to nearby isolated devices
 *
 * TODO: Maybe add NPC subnets here too to make hacking regular civilian NPCs lorefriendly. - Pierre
 */
@addMethod(PlayerPuppet)
private func UnlockNearbyStandaloneDevices(breachPosition: Vector4, unlockFlags: BreachUnlockFlags) -> Void {
  let gameInstance: GameInstance = this.GetGame();
  let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);

  if !IsDefined(targetingSystem) {
    BNWarn("[RadialUnlock]", "TargetingSystem not available, cannot unlock nearby devices");
    return;
  }

  // Search for nearby devices
  let nearbyDevices: array<ref<ScriptableDeviceComponentPS>> = this.FindNearbyDevices(targetingSystem);

  // Filter and unlock standalone devices (with unlockFlags check)
  this.UnlockStandaloneDevices(nearbyDevices, unlockFlags);
}

// Helper: Find all devices within RadialBreach radius
@addMethod(PlayerPuppet)
private func FindNearbyDevices(
  targetingSystem: ref<TargetingSystem>
) -> array<ref<ScriptableDeviceComponentPS>> {
  let devices: array<ref<ScriptableDeviceComponentPS>>;

  // Setup device search query
  let query: TargetSearchQuery;
  query.searchFilter = TSF_All(TSFMV.Obj_Device);
  query.testedSet = TargetingSet.Complete;
  query.maxDistance = DeviceTypeUtils.GetRadialBreachRange(this.GetGame()); // Syncs with RadialBreach range
  query.filterObjectByDistance = true;
  query.includeSecondaryTargets = false;
  query.ignoreInstigator = true;

  let parts: array<TS_TargetPartInfo>;
  targetingSystem.GetTargetParts(this, query, parts);

  // Extract ScriptableDeviceComponentPS from target parts
  let i: Int32 = 0;
  while i < ArraySize(parts) {
    let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(parts[i]).GetEntity() as GameObject;

    if IsDefined(entity) {
      let device: ref<Device> = entity as Device;
      if IsDefined(device) {
        let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
        if IsDefined(devicePS) {
          ArrayPush(devices, devicePS);
        }
      }
    }

    i += 1;
  }

  return devices;
}

// Helper: Filter for standalone devices and unlock them
// Only unlocks devices whose type matches the successful daemons (unlockFlags)
@addMethod(PlayerPuppet)
private func UnlockStandaloneDevices(
  devices: array<ref<ScriptableDeviceComponentPS>>,
  unlockFlags: BreachUnlockFlags
) -> Int32 {
  let unlockedCount: Int32 = 0;
  let gameInstance: GameInstance = this.GetGame();

  let i: Int32 = 0;
  while i < ArraySize(devices) {
    let devicePS: ref<ScriptableDeviceComponentPS> = devices[i];
    let sharedPS: ref<SharedGameplayPS> = devicePS;

    if IsDefined(sharedPS) {
      let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();

      // Standalone = no AccessPoints
      if ArraySize(apControllers) == 0 {
        if this.UnlockSingleDevice(sharedPS, devicePS, gameInstance, unlockFlags) {
          unlockedCount += 1;
        }
      }
    }

    i += 1;
  }

  return unlockedCount;
}

// Helper: Unlock a single device based on type and unlockFlags
@addMethod(PlayerPuppet)
private func UnlockSingleDevice(
  sharedPS: ref<SharedGameplayPS>,
  devicePS: ref<ScriptableDeviceComponentPS>,
  gameInstance: GameInstance,
  unlockFlags: BreachUnlockFlags
) -> Bool {
  // Use DeviceTypeUtils for centralized device type detection
  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(devicePS);

  // Check if this device type should be unlocked based on unlockFlags
  if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
    return false; // Device type not unlocked by current breach
  }

  // Prepare timestamp and set device unlock
  let currentTime: Float = TimeUtils.GetCurrentTimestamp(gameInstance);
  TimeUtils.SetDeviceUnlockTimestamp(sharedPS, deviceType, currentTime);

  return true;
}

