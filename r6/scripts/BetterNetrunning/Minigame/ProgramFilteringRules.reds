module BetterNetrunning.Minigame

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Integration.*

/*
 * ============================================================================
 * PROGRAM FILTERING MODULE
 * ============================================================================
 *
 * PURPOSE:
 * Determines which breach programs (daemons) should be available in the
 * breach minigame based on context, settings, and device state.
 *
 * FUNCTIONALITY:
 * - Network connectivity filtering (remove unlock programs if not connected)
 * - Device type filtering (access points vs backdoor devices)
 * - Access point program restrictions (based on user settings)
 * - Non-netrunner NPC restrictions (limit programs for regular NPCs)
 * - Already-breached program removal (prevent re-breach of same type)
 * - Device type availability (remove programs for unavailable device types)
 * - Datamine V1/V2 removal (based on user settings)
 *
 * MOD COMPATIBILITY:
 * These functions are called from FilterPlayerPrograms() @wrapMethod,
 * ensuring compatibility with other mods that modify breach programs.
 *
 * ============================================================================
 */

// ==================== Already-Breached Program Filtering ====================

/*
 * Returns true if already breached programs should be removed
 * CRITICAL: This removes daemons that were added by vanilla logic but already completed
 *
 * TEMPORARY UNLOCK FEATURE:
 * - If QuickhackUnlockDurationHours() > 0: Checks if unlock has expired
 * - If expired: Resets breach flags and timestamp, returns false (allow re-breach)
 * - If still valid: Returns true (remove program)
 * - If QuickhackUnlockDurationHours() == 0: Permanent unlock (legacy behavior)
 *
 * @param actionID - The program's TweakDB ID
 * @param entity - The target entity (device/NPC)
 * @return True if the program should be removed
 */
public func ShouldRemoveBreachedPrograms(actionID: TweakDBID, entity: wref<GameObject>) -> Bool {
  // Only applies to devices (not NPCs)
  if !IsDefined(entity as Device) {
    return false;
  }

  let devicePS: ref<DeviceComponentPS> = (entity as Device).GetDevicePS();
  let sharedPS: ref<SharedGameplayPS> = devicePS as SharedGameplayPS;

  if !IsDefined(sharedPS) {
    return false;
  }

  // Check if temporary unlock is enabled
  let unlockDurationHours: Int32 = BetterNetrunningSettings.QuickhackUnlockDurationHours();
  let currentTime: Float = DeviceUnlockUtils.GetCurrentTimestamp(devicePS.GetGameInstance());

  // Convert hours to seconds (0 = permanent unlock)
  let unlockDurationSeconds: Float = Cast<Float>(unlockDurationHours) * 3600.0;

  BNTrace("CheckBreachedStatus", "unlockDurationHours=" + ToString(unlockDurationHours) + ", currentTime=" + ToString(currentTime));

  // Check each daemon type
  if actionID == BNConstants.PROGRAM_UNLOCK_QUICKHACKS() {
    return HandleTemporaryUnlock(
      sharedPS.m_betterNetrunningUnlockTimestampBasic,
      currentTime,
      unlockDurationSeconds,
      unlockDurationHours,
      sharedPS,
      "Basic"
    );
  }

  if actionID == BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS() {
    return HandleTemporaryUnlock(
      sharedPS.m_betterNetrunningUnlockTimestampNPCs,
      currentTime,
      unlockDurationSeconds,
      unlockDurationHours,
      sharedPS,
      "NPCs"
    );
  }

  if actionID == BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS() {
    return HandleTemporaryUnlock(
      sharedPS.m_betterNetrunningUnlockTimestampCameras,
      currentTime,
      unlockDurationSeconds,
      unlockDurationHours,
      sharedPS,
      "Cameras"
    );
  }

  if actionID == BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS() {
    return HandleTemporaryUnlock(
      sharedPS.m_betterNetrunningUnlockTimestampTurrets,
      currentTime,
      unlockDurationSeconds,
      unlockDurationHours,
      sharedPS,
      "Turrets"
    );
  }

  return false;
}

/*
 * Handles temporary unlock logic with expiration check
 *
 * @param unlockTimestamp - Timestamp when unlock was recorded (0.0 = not breached)
 * @param currentTime - Current game time
 * @param durationSeconds - Unlock duration in seconds (0.0 = permanent)
 * @param durationHours - Unlock duration in hours (0 = permanent, for logging)
 * @param sharedPS - Device PS reference (for resetting expired timestamps)
 * @param daemonType - Daemon type name (for logging)
 * @return True if program should be removed (still unlocked), False if expired/not breached
 */
private func HandleTemporaryUnlock(
  unlockTimestamp: Float,
  currentTime: Float,
  durationSeconds: Float,
  durationHours: Int32,
  sharedPS: ref<SharedGameplayPS>,
  daemonType: String
) -> Bool {
  // Check if breached (unified state check via timestamp)
  if !BreachStatusUtils.IsBreached(unlockTimestamp) {
    return false; // Not breached - show program
  }

  // Permanent unlock mode (0 hours = infinite duration)
  if durationHours <= 0 {
    return true; // Remove program permanently
  }

  // Temporary unlock mode - check if expired
  let elapsedTime: Float = currentTime - unlockTimestamp;

  if elapsedTime > durationSeconds {
    // Expired - reset timestamp and restore JackIn interaction
    ResetDeviceTimestamp(sharedPS, daemonType);

    // JackIn restoration: Only for MasterControllerPS devices
    // This allows re-breach attempts after unlock expiration
    let devicePS: ref<ScriptableDeviceComponentPS> = sharedPS as ScriptableDeviceComponentPS;
    let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;

    if IsDefined(masterController) {
      BreachLockUtils.SetJackInInteractionState(devicePS, true);
      BNDebug("ProgramFiltering", "Unlock expired for " + daemonType + " - JackIn restored");
    }

    return false; // Show program (allow re-breach)
  }

  // Still valid - remove program
  return true; // Remove program
}

/*
 * Resets device unlock timestamp to 0.0 (re-locked state)
 */
private func ResetDeviceTimestamp(sharedPS: ref<SharedGameplayPS>, daemonType: String) -> Void {
  if Equals(daemonType, "Basic") {
    sharedPS.m_betterNetrunningUnlockTimestampBasic = 0.0;
  } else if Equals(daemonType, "NPCs") {
    sharedPS.m_betterNetrunningUnlockTimestampNPCs = 0.0;
  } else if Equals(daemonType, "Cameras") {
    sharedPS.m_betterNetrunningUnlockTimestampCameras = 0.0;
  } else if Equals(daemonType, "Turrets") {
    sharedPS.m_betterNetrunningUnlockTimestampTurrets = 0.0;
  }
}

// ==================== Device Type Availability Filtering ====================

/*
 * Returns true if programs should be removed based on device type availability
 *
 * In RadialUnlock mode, delegates filtering to RadialBreach's physical proximity-based system.
 * If RadialBreach is not installed, disables network-based filtering to reduce UI noise.
 *
 * In Classic mode, uses traditional network connectivity-based filtering.
 *
 * @param actionID - The program's TweakDB ID
 * @param miniGameActionRecord - The program's record data
 * @param data - Connected device types data
 * @return True if the program should be removed
 */
public func ShouldRemoveDeviceTypePrograms(actionID: TweakDBID, miniGameActionRecord: wref<MinigameAction_Record>, data: ConnectedClassTypes) -> Bool {
  // In RadialUnlock mode, delegate filtering to RadialBreach's physical proximity-based system if installed
  // If RadialBreach is not installed, disable network-based filtering to reduce UI noise
  if !BetterNetrunningSettings.UnlockIfNoAccessPoint() {
    return false;
  }

  // In Classic mode, use traditional network connectivity-based filtering
  // Remove camera programs if no cameras connected
  if (Equals(miniGameActionRecord.Category().Type(), gamedataMinigameCategory.CameraAccess) || actionID == BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()) && !data.surveillanceCamera {
    return true;
  }
  // Remove turret programs if no turrets connected
  if (Equals(miniGameActionRecord.Category().Type(), gamedataMinigameCategory.TurretAccess) || actionID == BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()) && !data.securityTurret {
    return true;
  }
  // Remove NPC programs if no NPCs connected
  if (Equals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.NPC) || actionID == BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()) && !data.puppet {
    return true;
  }
  return false;
}

// ==================== Datamine Program Filtering ====================

/*
 * Returns true if Datamine programs should be removed when AutoDatamineBySuccessCount is enabled
 *
 * When AutoDatamineBySuccessCount is enabled, Datamine programs are automatically added
 * AFTER breach success based on the number of successfully uploaded daemons.
 * Therefore, ALL Datamine programs should be hidden from the initial program list.
 *
 * @param actionID - The program's TweakDB ID
 * @return True if the program should be removed
 */
public func ShouldRemoveDataminePrograms(actionID: TweakDBID) -> Bool {
  // Only filter if AutoDatamineBySuccessCount is enabled
  if !BetterNetrunningSettings.AutoDatamineBySuccessCount() {
    return false;
  }

  // Remove ALL Datamine variants when auto-datamine is enabled
  return actionID == BNConstants.PROGRAM_DATAMINE_BASIC()
      || actionID == BNConstants.PROGRAM_DATAMINE_ADVANCED()
      || actionID == BNConstants.PROGRAM_DATAMINE_MASTER();
}

// ==================== Physical Range Device Filtering ====================

/*
 * Returns true if programs should be removed based on physical range device availability
 *
 * P2 FIX (2025-10-12): Now uses Access Point network (GetChildren) instead of TargetingSystem
 * Scans devices in the Access Point's network and removes subnet programs if no corresponding
 * device types are found. This respects the actual network topology instead of spatial proximity.
 *
 * @param actionID - The program's TweakDB ID
 * @param gameInstance - The game instance
 * @param breachPosition - The breach position (source entity position)
 * @param breachEntity - The entity being breached (Access Point, Device, or NPC)
 * @return True if the program should be removed
 */
public func ShouldRemoveOutOfRangeDevicePrograms(actionID: TweakDBID, gameInstance: GameInstance, breachPosition: Vector4, breachEntity: wref<GameObject>) -> Bool {
  // Skip filtering if breach position is invalid
  if breachPosition.X < -999000.0 {
    return false;
  }

  // Scan for devices in network
  let devicesInRange: DeviceTypesInRange = ScanDeviceTypesInNetwork(gameInstance, breachPosition, breachEntity);

  // Remove camera programs if no cameras in network
  if actionID == BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS() && !devicesInRange.hasCameras {
    return true;
  }

  // Remove turret programs if no turrets in network
  if actionID == BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS() && !devicesInRange.hasTurrets {
    return true;
  }

  // Remove NPC programs if no NPCs in network
  if actionID == BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS() && !devicesInRange.hasNPCs {
    return true;
  }

  // Basic subnet (UnlockQuickhacks) is always available if any basic devices exist
  // (Doors, Terminals, Computers, etc.)
  if actionID == BNConstants.PROGRAM_UNLOCK_QUICKHACKS() && !devicesInRange.hasBasicDevices {
    return true;
  }

  return false;
}

/*
 * Data structure to hold device type scan results
 */
public struct DeviceTypesInRange {
  let hasCameras: Bool;
  let hasTurrets: Bool;
  let hasNPCs: Bool;
  let hasBasicDevices: Bool;
}

/*
 * Scans for device types in the Access Point's network and surrounding area
 *
 * FUNCTIONALITY:
 * - Scans Access Point's network devices (via GetChildren)
 * - Scans standalone devices within breach radius (via RadialBreach integration)
 * - Classifies devices by type (Camera, Turret, NPC, Basic)
 *
 * ARCHITECTURE:
 * - Network Scan: Uses AccessPointControllerPS.GetChildren()
 * - Radial Scan: Uses AccessPointControllerPS.GetAllNearbyObjects() when RadialBreach MOD exists
 * - Composed Method: Delegates to helper functions for each scan type
 *
 * BREACH RADIUS:
 * - Configurable via RadialBreach MOD settings (default 25m, range 10-50m)
 * - Falls back to 50m when RadialBreach not installed
 *
 * @param gameInstance - The game instance
 * @param breachPosition - The breach position (for logging)
 * @param breachEntity - The entity being breached (Access Point, Device, or NPC)
 * @return Device type availability data
 */
private func ScanDeviceTypesInNetwork(
  gameInstance: GameInstance,
  breachPosition: Vector4,
  breachEntity: wref<GameObject>
) -> DeviceTypesInRange {
  let result: DeviceTypesInRange;
  result.hasCameras = false;
  result.hasTurrets = false;
  result.hasNPCs = false;
  result.hasBasicDevices = false;

  // Check if this is an Access Point breach
  let accessPoint: ref<AccessPoint> = breachEntity as AccessPoint;

  if !IsDefined(accessPoint) {
    result.hasCameras = true;
    result.hasTurrets = true;
    result.hasNPCs = true;
    result.hasBasicDevices = true;
    return result;
  }

  let accessPointPS: ref<AccessPointControllerPS> = accessPoint.GetDevicePS() as AccessPointControllerPS;

  if !IsDefined(accessPointPS) {
    result.hasCameras = true;
    result.hasTurrets = true;
    result.hasNPCs = true;
    result.hasBasicDevices = true;
    return result;
  }

  // Scan network devices (Access Point's GetChildren)
  ScanNetworkDevices(accessPointPS, result);

  // Scan radial devices (RadialBreach integration for standalone devices)
  ScanRadialDevices(accessPointPS, result);

  return result;
}

/*
 * Helper: Scans network devices using Access Point's GetChildren()
 *
 * @param accessPointPS - The Access Point's persistent state
 * @param result - The result structure to populate (passed by reference)
 */
private func ScanNetworkDevices(
  accessPointPS: ref<AccessPointControllerPS>,
  out result: DeviceTypesInRange
) -> Void {
  let networkDevices: array<ref<DeviceComponentPS>>;
  accessPointPS.GetChildren(networkDevices);

  let i: Int32 = 0;
  while i < ArraySize(networkDevices) {
    let devicePS: ref<DeviceComponentPS> = networkDevices[i];

    if IsDefined(devicePS) {
      ClassifyDeviceByType(devicePS as ScriptableDeviceComponentPS, result);
    }

    i += 1;
  }
}

/*
 * Helper: Scans radial devices using RadialBreach integration
 * Only compiled when RadialBreach MOD is installed
 *
 * @param accessPointPS - The Access Point's persistent state
 * @param result - The result structure to populate (passed by reference)
 */
@if(ModuleExists("RadialBreach"))
private func ScanRadialDevices(
  accessPointPS: ref<AccessPointControllerPS>,
  out result: DeviceTypesInRange
) -> Void {
  let radialObjects: array<wref<GameObject>> = accessPointPS.GetAllNearbyObjects();

  let i: Int32 = 0;
  while i < ArraySize(radialObjects) {
    let obj: wref<GameObject> = radialObjects[i];

    if IsDefined(obj) {
      // Check for NPCs
      let npc: ref<NPCPuppet> = obj as NPCPuppet;
      if IsDefined(npc) {
        result.hasNPCs = true;
      } else {
        // Check for Devices
        let device: ref<Device> = obj as Device;
        if IsDefined(device) {
          let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
          if IsDefined(devicePS) {
            ClassifyDeviceByType(devicePS, result);
          }
        }
      }
    }

    i += 1;
  }
}

/*
 * Helper: Fallback for radial scan when RadialBreach MOD is not installed
 * Defaults to allowing NPC programs (since we can't scan NPCs without TargetingSystem)
 *
 * @param accessPointPS - The Access Point's persistent state (unused in fallback)
 * @param result - The result structure to populate (passed by reference)
 */
@if(!ModuleExists("RadialBreach"))
private func ScanRadialDevices(
  accessPointPS: ref<AccessPointControllerPS>,
  out result: DeviceTypesInRange
) -> Void {
  // Fallback: Allow NPC programs (better to show than hide incorrectly)
  result.hasNPCs = true;
}

/*
 * Helper: Classifies a device by type and updates result flags
 *
 * @param devicePS - The device's persistent state
 * @param result - The result structure to populate (passed by reference)
 */
private func ClassifyDeviceByType(
  devicePS: ref<ScriptableDeviceComponentPS>,
  out result: DeviceTypesInRange
) -> Void {
  if !IsDefined(devicePS) {
    return;
  }

  // Camera
  if IsDefined(devicePS as SurveillanceCameraControllerPS) {
    result.hasCameras = true;
  }
  // Turret
  else if IsDefined(devicePS as SecurityTurretControllerPS) {
    result.hasTurrets = true;
  }
  // Basic devices
  else {
    result.hasBasicDevices = true;
  }
}

// ==================== NETWORK CONNECTIVITY FILTERING (VANILLA RULE 5) ====================

/*
 * Check if program is Better Netrunning subnet daemon
 *
 * PURPOSE:
 * Identifies BetterNetrunning's custom subnet unlock daemons to apply
 * proper network connectivity filtering (vanilla Rule 5 logic).
 *
 * FUNCTIONALITY:
 * Checks if actionID matches any of the 4 BN subnet daemon TweakDBIDs:
 * - UnlockQuickhacks (Basic devices)
 * - UnlockCameraQuickhacks (Cameras)
 * - UnlockTurretQuickhacks (Turrets)
 * - UnlockNPCQuickhacks (NPCs)
 *
 * @param actionID - TweakDBID of the program to check
 * @return True if program is a BN subnet daemon
 */
public static func IsBetterNetrunningSubnetDaemon(actionID: TweakDBID) -> Bool {
  if Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS()) { return true; }
  if Equals(actionID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()) { return true; }
  if Equals(actionID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()) { return true; }
  if Equals(actionID, BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()) { return true; }
  return false;
}

// ==================== REMOTEBREACH DAEMON FILTERING ====================

/*
 * Determines if a daemon should be removed from RemoteBreach minigame
 *
 * PURPOSE:
 * Filters daemons for RemoteBreach based on target device type,
 * enabling dynamic daemon availability instead of static daemon lists.
 *
 * ARCHITECTURE:
 * Mirrors AccessPoint's ShouldRemoveBreachedPrograms() pattern:
 * - Device type detection (Computer/Camera/Turret/Device/Vehicle)
 * - TweakDBID-based filtering (keeps only relevant daemons)
 * - Integration with FilterPlayerPrograms() pipeline
 *
 * DEVICE TYPE DAEMON MAPPING:
 * - Computer: Basic + Camera (network access devices)
 * - Device: Basic only (generic hackable devices)
 * - Camera: Basic + Camera (surveillance devices)
 * - Turret: Basic + Turret (combat devices)
 * - Vehicle: Basic only (no network unlock for vehicles)
 *
 * @param actionID - The daemon's TweakDB ID
 * @param breachEntity - The entity being breached (Computer/Device/Camera/Turret/Vehicle)
 * @return True if daemon should be removed (not applicable to this target type)
 */
public func ShouldRemoveRemoteBreachPrograms(
  actionID: TweakDBID,
  breachEntity: wref<GameObject>
) -> Bool {
  // Only applies to RemoteBreach (not AccessPoint or NPC breach)
  // Caller must verify breach type before calling this function

  if !IsDefined(breachEntity) {
    return false;
  }

  // Get device PS for type detection
  let device: ref<Device> = breachEntity as Device;
  if !IsDefined(device) {
    // Not a device (might be puppet) - allow all daemons
    return false;
  }

  let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
  if !IsDefined(devicePS) {
    return false;
  }

  // Determine device type and filter accordingly
  let isComputer: Bool = DaemonFilterUtils.IsComputer(devicePS);
  let isCamera: Bool = DaemonFilterUtils.IsCamera(devicePS);
  let isTurret: Bool = DaemonFilterUtils.IsTurret(devicePS);
  let isVehicle: Bool = IsDefined(devicePS as VehicleComponentPS);

  // Computer: Allow Basic + Camera daemons only
  if isComputer {
    return !(Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS())
          || Equals(actionID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()));
  }

  // Camera: Allow Basic + Camera daemons only
  if isCamera {
    return !(Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS())
          || Equals(actionID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()));
  }

  // Turret: Allow Basic + Turret daemons only
  if isTurret {
    return !(Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS())
          || Equals(actionID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()));
  }

  // Vehicle: Allow Basic daemon only (no network unlock)
  if isVehicle {
    return !Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS());
  }

  // Generic Device: Allow Basic daemon only
  return !Equals(actionID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS());
}

/*
 * Apply vanilla Rule 5 (network connectivity) to BN subnet daemons
 *
 * PURPOSE:
 * Replicates vanilla FilterPlayerPrograms() Rule 5 logic to ensure BN subnet
 * daemons only appear when corresponding device types exist in the network.
 *
 * RATIONALE:
 * BN subnet daemons have type="MinigameAction.Both" (not AccessPoint), which
 * bypasses vanilla Rule 3/4 but also skips Rule 5 (network connectivity check).
 * This function manually applies Rule 5 to extracted BN daemons before restoration.
 *
 * VANILLA RULE 5 LOGIC (hackingMinigameUtils.script Line 910-923):
 * - CameraAccess: Keep if surveillanceCamera exists in network
 * - TurretAccess: Keep if securityTurret exists in network
 * - NPC: Keep if puppet exists AND is Active (not unconscious)
 * - Other categories: Always keep
 *
 * ARCHITECTURE:
 * - Uses CheckConnectedClassTypes() to get network topology
 * - Applies category-specific filtering rules
 * - Removes programs from array if conditions not met
 *
 * @param entity - Target entity (Access Point, Device, or NPC)
 * @param programs - Array of BN subnet daemons to filter (modified in-place)
 */
public static func ApplyNetworkConnectivityFilter(
  entity: wref<Entity>,
  programs: script_ref<array<MinigameProgramData>>
) -> Void {
  // Step 1: Get network topology
  let networkInfo: ConnectedClassTypes = GetNetworkTopology(entity);

  BNDebug("ApplyNetworkConnectivityFilter",
    "Network topology - Camera: " + ToString(networkInfo.surveillanceCamera) +
    ", Turret: " + ToString(networkInfo.securityTurret) +
    ", NPC: " + ToString(networkInfo.puppet));

  // Step 2: Apply Rule 5 filtering (reverse iteration for safe removal)
  let i: Int32 = ArraySize(Deref(programs)) - 1;
  while i >= 0 {
    let program: MinigameProgramData = Deref(programs)[i];
    let shouldRemove: Bool = ShouldRemoveByNetworkConnectivity(program, networkInfo);

    if shouldRemove {
      BNDebug("ApplyNetworkConnectivityFilter",
        "Removing daemon (no network connectivity): " + TDBID.ToStringDEBUG(program.actionID));
      ArrayErase(Deref(programs), i);
    }

    i -= 1;
  }
}

/*
 * Get network topology for connectivity filtering
 *
 * PURPOSE:
 * Retrieves ConnectedClassTypes struct containing network device composition.
 *
 * FUNCTIONALITY:
 * - Uses vanilla pattern from hackingMinigameUtils.script:875-887
 * - Puppets: Cast to ScriptedPuppet ↁEGetMasterConnectedClassTypes()
 * - Devices: Cast to Device ↁEGetDevicePS().CheckMasterConnectedClassTypes()
 * - Returns struct with camera/turret/puppet flags
 *
 * @param entity - Target entity (Device or ScriptedPuppet)
 * @return ConnectedClassTypes struct (all false if invalid entity)
 */
private static func GetNetworkTopology(entity: wref<Entity>) -> ConnectedClassTypes {
  let result: ConnectedClassTypes;

  let gameObject: ref<GameObject> = entity as GameObject;
  if !IsDefined(gameObject) {
    BNWarn("GetNetworkTopology", "Entity is not GameObject");
    return result;
  }

  // Puppets use GetMasterConnectedClassTypes()
  if gameObject.IsPuppet() {
    let puppet: ref<ScriptedPuppet> = entity as ScriptedPuppet;
    if IsDefined(puppet) {
      result = puppet.GetMasterConnectedClassTypes();
    }
  } else {
    // Devices use GetDevicePS().CheckMasterConnectedClassTypes()
    let device: ref<Device> = entity as Device;
    if IsDefined(device) {
      result = device.GetDevicePS().CheckMasterConnectedClassTypes();
    }
  }

  return result;
}

/*
 * Check if program should be removed based on network connectivity (Rule 5)
 *
 * PURPOSE:
 * Applies vanilla Rule 5 category checks to a single program.
 *
 * VANILLA CATEGORIES (minigame_actions.tweak):
 * - MinigameAction.CameraAccess: NetworkCameraShutdown (Line 89)
 * - MinigameAction.TurretAccess: NetworkTurretShutdown (Line 122)
 * - MinigameAction.DataAccess: NetworkDataMineLootAll/Advanced/Master (Line 220-253)
 * - MinigameAction.NPC: (No vanilla examples, BN uses for UnlockNPCQuickhacks)
 *
 * BN SUBNET DAEMON MAPPING:
 * - UnlockCameraQuickhacks ↁEcategory="MinigameAction.CameraAccess"
 * - UnlockTurretQuickhacks ↁEcategory="MinigameAction.TurretAccess"
 * - UnlockNPCQuickhacks ↁEcategory="MinigameAction.NPC"
 * - UnlockQuickhacks ↁEcategory="MinigameAction.DataAccess" (Basic devices)
 *
 * @param program - Program to check
 * @param networkInfo - Network topology from CheckConnectedClassTypes()
 * @return True if program should be removed
 */
private static func ShouldRemoveByNetworkConnectivity(
  program: MinigameProgramData,
  networkInfo: ConnectedClassTypes
) -> Bool {
  let category: CName = TweakDBInterface.GetCName(program.actionID + t".category", n"");

  // CameraAccess: Remove if no cameras in network
  if Equals(category, n"MinigameAction.CameraAccess") {
    if !networkInfo.surveillanceCamera {
      BNTrace("ShouldRemoveByNetworkConnectivity",
        "Removing CameraAccess daemon (no cameras): " + TDBID.ToStringDEBUG(program.actionID));
      return true;
    }
  }

  // TurretAccess: Remove if no turrets in network
  if Equals(category, n"MinigameAction.TurretAccess") {
    if !networkInfo.securityTurret {
      BNTrace("ShouldRemoveByNetworkConnectivity",
        "Removing TurretAccess daemon (no turrets): " + TDBID.ToStringDEBUG(program.actionID));
      return true;
    }
  }

  // NPC: Remove if no NPCs in network (puppet flag)
  // NOTE: Vanilla checks Active state, but CheckConnectedClassTypes() already excludes unconscious NPCs
  if Equals(category, n"MinigameAction.NPC") {
    if !networkInfo.puppet {
      BNTrace("ShouldRemoveByNetworkConnectivity",
        "Removing NPC daemon (no active NPCs): " + TDBID.ToStringDEBUG(program.actionID));
      return true;
    }
  }

  // DataAccess and other categories: Always keep
  return false;
}

