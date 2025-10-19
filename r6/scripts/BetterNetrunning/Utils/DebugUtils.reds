// ============================================================================
// BetterNetrunning - Debug Utilities
// ============================================================================
// HIGH-LEVEL DEBUG LOGGING FUNCTIONS
//
// PURPOSE:
//   Provides structured debug information logging for breach operations
//   Built on top of Logger.reds (BNLog function)
//
// ARCHITECTURE:
//   DebugUtils (this file) -> Logger.reds -> RED4ext.ModLog
//
// FEATURES:
//   - Device quickhack state logging (locked/unlocked state)
//   - NPC quickhack state logging (breach flags, network state)
//   - Breach target information logging (location, device type, network info)
//   - Network device type scanning (cameras, turrets, NPCs, doors)
//
// USAGE:
//   - Call LogDeviceQuickhackState() after breach completion
//   - Call LogNPCQuickhackState() for NPC targets
//   - Call LogAccessPointBreachTarget() for AccessPoint breaches
//   - Call LogRemoteBreachTarget() for RemoteBreach operations
//   - Call LogUnconsciousNPCBreachTarget() for Unconscious NPC breaches
//   - Enable via EnableDebugLog setting in config
//
// DESIGN NOTES:
//   - All functions check EnableDebugLog setting before output
//   - Uses BNLog() from Logger.reds (never calls ModLog directly)
//   - Provides human-readable structured output with clear section headers
//   - Includes location information (X/Y/Z coordinates) for all targets
// ============================================================================

module BetterNetrunning.Utils

import BetterNetrunning.Core.*
import BetterNetrunningConfig.*

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Removes "Gameplay-Devices-DisplayNames-" prefix from device name
public static func CleanDeviceName(rawName: String) -> String {
  let prefix: String = "Gameplay-Devices-DisplayNames-";
  if StrBeginsWith(rawName, prefix) {
    return StrMid(rawName, StrLen(prefix));
  }
  return rawName;
}

// ============================================================================
// DEVICE QUICKHACK STATE LOGGING
// ============================================================================

// Log all quickhack states for a device (locked/unlocked)
public func LogDeviceQuickhackState(devicePS: ref<ScriptableDeviceComponentPS>, opt logContext: String) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Debug]";
  // ScriptableDeviceComponentPS already extends SharedGameplayPS
  let sharedPS: ref<SharedGameplayPS> = devicePS;

  if !IsDefined(sharedPS) {
    BNLog(context + " Device is not SharedGameplayPS, skipping quickhack state logging");
    return;
  }

  BNLog(context + " ===== DEVICE QUICKHACK STATE =====");
  BNLog(context + " Device: " + CleanDeviceName(devicePS.GetDeviceName()));

  // Location information
  let deviceEntity: ref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
  if IsDefined(deviceEntity) {
    let position: Vector4 = deviceEntity.GetWorldPosition();
    BNLog(context + " --- Location ---");
    BNLog(context + " x = " + ToString(position.X) + ", y = " + ToString(position.Y) + ", z = " + ToString(position.Z));
  }

  // Breach state (timestamp-based)
  BNLog(context + " --- Breach State (Timestamp) ---");
  BNLog(context + " Basic Subnet Breached: " + ToString(BreachStatusUtils.IsBasicBreached(sharedPS)) + " (ts: " + ToString(sharedPS.m_betterNetrunningUnlockTimestampBasic) + ")");
  BNLog(context + " Camera Subnet Breached: " + ToString(BreachStatusUtils.IsCamerasBreached(sharedPS)) + " (ts: " + ToString(sharedPS.m_betterNetrunningUnlockTimestampCameras) + ")");
  BNLog(context + " Turret Subnet Breached: " + ToString(BreachStatusUtils.IsTurretsBreached(sharedPS)) + " (ts: " + ToString(sharedPS.m_betterNetrunningUnlockTimestampTurrets) + ")");
  BNLog(context + " NPC Subnet Breached: " + ToString(BreachStatusUtils.IsNPCsBreached(sharedPS)) + " (ts: " + ToString(sharedPS.m_betterNetrunningUnlockTimestampNPCs) + ")");

  // Network connectivity
  BNLog(context + " --- Network State ---");
  BNLog(context + " Connected to Network: " + ToString(sharedPS.IsConnectedToPhysicalAccessPoint()));
  BNLog(context + " Has Network Backdoor: " + ToString(sharedPS.HasNetworkBackdoor()));

  // Explicit standalone computation for clarity in logs
  let isStandaloneDevice: Bool = !sharedPS.IsConnectedToPhysicalAccessPoint() && !sharedPS.HasNetworkBackdoor();
  BNLog(context + " Is Standalone: " + ToString(isStandaloneDevice));

  // Quickhack availability (basic examples)
  BNLog(context + " --- Quickhack Availability ---");

  // Camera-specific quickhacks
  if DaemonFilterUtils.IsCamera(devicePS) {
    BNLog(context + " [Camera] Remote Disable: Available");
    BNLog(context + " [Camera] Friendly Turret: " + ToString(BreachStatusUtils.IsCamerasBreached(sharedPS)));
  }

  // Turret-specific quickhacks
  if DaemonFilterUtils.IsTurret(devicePS) {
    BNLog(context + " [Turret] Remote Disable: Available");
    BNLog(context + " [Turret] Friendly Turret: " + ToString(BreachStatusUtils.IsTurretsBreached(sharedPS)));
  }

  // Basic device quickhacks
  BNLog(context + " [Basic] Distract: " + ToString(BreachStatusUtils.IsBasicBreached(sharedPS)));

  BNLog(context + " ==================================");
}

// ============================================================================
// NPC QUICKHACK STATE LOGGING
// ============================================================================

// Log all quickhack states for an NPC (locked/unlocked)
public func LogNPCQuickhackState(npcPS: ref<ScriptedPuppetPS>, opt logContext: String) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Debug]";
  let deviceLinkPS: ref<SharedGameplayPS> = npcPS.GetDeviceLink();

  if !IsDefined(deviceLinkPS) {
    BNLog(context + " NPC has no device link, skipping quickhack state logging");
    return;
  }

  BNLog(context + " ===== NPC QUICKHACK STATE =====");

  // Location information
  let npcEntity: ref<GameObject> = npcPS.GetOwnerEntityWeak() as GameObject;
  if IsDefined(npcEntity) {
    let position: Vector4 = npcEntity.GetWorldPosition();
    BNLog(context + " --- Location ---");
    BNLog(context + " x = " + ToString(position.X) + ", y = " + ToString(position.Y) + ", z = " + ToString(position.Z));
  }

  // Breach state (timestamp-based)
  BNLog(context + " --- Breach State (Timestamp) ---");
  BNLog(context + " NPC Subnet Breached: " + ToString(BreachStatusUtils.IsNPCsBreached(deviceLinkPS)) + " (ts: " + ToString(deviceLinkPS.m_betterNetrunningUnlockTimestampNPCs) + ")");

  // Network connectivity
  BNLog(context + " --- Network State ---");
  BNLog(context + " Connected to Network: " + ToString(npcPS.IsConnectedToAccessPoint()));
  BNLog(context + " Connected to AP: " + ToString(deviceLinkPS.IsConnectedToPhysicalAccessPoint()));

  // Explicit standalone computation for NPCs (not connected to any AP/backdoor)
  let isStandaloneNPC: Bool = !npcPS.IsConnectedToAccessPoint() && !deviceLinkPS.IsConnectedToPhysicalAccessPoint() && !deviceLinkPS.HasNetworkBackdoor();
  BNLog(context + " Is Standalone: " + ToString(isStandaloneNPC));

  // Quickhack availability categories
  let npcBreached: Bool = BreachStatusUtils.IsNPCsBreached(deviceLinkPS);
  BNLog(context + " --- Quickhack Availability ---");
  BNLog(context + " [Covert] Memory Wipe, Reboot Optics: " + ToString(npcBreached));
  BNLog(context + " [Combat] Short Circuit, Overheat: " + ToString(npcBreached));
  BNLog(context + " [Control] Cyberware Malfunction, Weapon Glitch: " + ToString(npcBreached));
  BNLog(context + " [Ultimate] Cyberpsychosis, Suicide: " + ToString(npcBreached));

  BNLog(context + " ===============================");
}

// ============================================================================
// NETWORK SCAN LOGGING
// ============================================================================

// Log connected device types in network
public func LogNetworkDeviceTypes(devicePS: ref<ScriptableDeviceComponentPS>, opt logContext: String) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Debug]";
  // ScriptableDeviceComponentPS already extends SharedGameplayPS
  let sharedPS: ref<SharedGameplayPS> = devicePS;

  if !IsDefined(sharedPS) {
    return;
  }

  let data: ConnectedClassTypes = sharedPS.CheckMasterConnectedClassTypes();

  BNLog(context + " ===== NETWORK DEVICE TYPES =====");
  BNLog(context + " Cameras Connected: " + ToString(data.surveillanceCamera));
  BNLog(context + " Turrets Connected: " + ToString(data.securityTurret));
  BNLog(context + " NPCs Connected: " + ToString(data.puppet));
  BNLog(context + " ================================");
}

// ============================================================================
// BREACH TARGET LOGGING
// ============================================================================

// Log Access Point breach target information
public func LogAccessPointBreachTarget(apPS: ref<AccessPointControllerPS>, opt logContext: String) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[AccessPoint]";

  BNLog(context + " ===== BREACH TARGET INFORMATION =====");
  BNLog(context + " Breach Method: Access Point Breach");
  BNLog(context + " Target Device: " + CleanDeviceName(apPS.GetDeviceName()));
  BNLog(context + " Device Type: Access Point");

  let apEntity: ref<GameObject> = apPS.GetOwnerEntityWeak() as GameObject;
  if IsDefined(apEntity) {
    let apPosition: Vector4 = apEntity.GetWorldPosition();
    BNLog(context + " x = " + ToString(apPosition.X) + ", y = " + ToString(apPosition.Y) + ", z = " + ToString(apPosition.Z));
  }

  BNLog(context + " Network Name: " + apPS.GetNetworkName());
  BNLog(context + " =====================================");
}

// Log Remote Breach target information
public func LogRemoteBreachTarget(devicePS: ref<ScriptableDeviceComponentPS>, opt logContext: String) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[RemoteBreach]";

  BNLog(context + " ===== BREACH TARGET INFORMATION =====");
  BNLog(context + " Breach Method: Remote Breach (CustomHackingSystem)");
  BNLog(context + " Target Device: " + CleanDeviceName(devicePS.GetDeviceName()));
  BNLog(context + " Device Type: " + DaemonFilterUtils.GetDeviceTypeName(devicePS));

  let deviceEntity: ref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
  if IsDefined(deviceEntity) {
    let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
    BNLog(context + " x = " + ToString(devicePosition.X) + ", y = " + ToString(devicePosition.Y) + ", z = " + ToString(devicePosition.Z));
  }

  // ScriptableDeviceComponentPS already extends SharedGameplayPS
  let sharedPS: ref<SharedGameplayPS> = devicePS;
  if IsDefined(sharedPS) {
    BNLog(context + " Network Name: " + sharedPS.GetNetworkName());
    BNLog(context + " Connected to AP: " + ToString(sharedPS.IsConnectedToPhysicalAccessPoint()));
  }
  BNLog(context + " =====================================");
}

// Log Unconscious NPC Breach target information
public func LogUnconsciousNPCBreachTarget(npc: ref<ScriptedPuppet>, npcPS: ref<ScriptedPuppetPS>, opt logContext: String) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[UnconsciousNPC]";

  BNLog(context + " ===== BREACH TARGET INFORMATION =====");
  BNLog(context + " Breach Method: Unconscious NPC Breach");

  let npcDisplayName: String = npc.GetDisplayName();
  if NotEquals(npcDisplayName, "") {
    BNLog(context + " Target NPC: " + npcDisplayName);
  } else {
    BNLog(context + " Target NPC: [Unknown]");
  }

  let npcPosition: Vector4 = npc.GetWorldPosition();
  BNLog(context + " x = " + ToString(npcPosition.X) + ", y = " + ToString(npcPosition.Y) + ", z = " + ToString(npcPosition.Z));

  let deviceLinkPS: ref<SharedGameplayPS> = npcPS.GetDeviceLink();
  if IsDefined(deviceLinkPS) {
    BNLog(context + " Connected to Network: " + ToString(npcPS.IsConnectedToAccessPoint()));
    if npcPS.IsConnectedToAccessPoint() {
      BNLog(context + " Network Name: " + deviceLinkPS.GetNetworkName());
    }
  }
  BNLog(context + " =====================================");
}

// ============================================================================
// PROGRAM FILTERING LOGGING
// ============================================================================

// Log program filtering step with initial/final program count state
public func LogProgramFilteringStep(
  filterName: String,
  programsBefore: Int32,
  programsAfter: Int32,
  removedProgram: TweakDBID,
  opt logContext: String
) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Filter]";

  if programsBefore != programsAfter {
    let programName: String = GetDaemonDisplayName(removedProgram);
    BNLog(context + " " + filterName + ": Removed " + programName +
          " (" + ToString(programsBefore) + " ↁE" + ToString(programsAfter) + " programs)");
  }
}

// Log filtering summary with removed program details
public func LogFilteringSummary(
  initialCount: Int32,
  finalCount: Int32,
  removedPrograms: array<TweakDBID>,
  opt logContext: String
) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Filter]";
  let removedCount: Int32 = initialCount - finalCount;

  BNLog(context + " ===== FILTERING SUMMARY =====");
  BNLog(context + " Initial programs: " + ToString(initialCount));
  BNLog(context + " Final programs: " + ToString(finalCount));
  BNLog(context + " Removed programs: " + ToString(removedCount));

  if removedCount > 0 {
    BNLog(context + " --- Removed Program List ---");
    let i: Int32 = 0;
    while i < ArraySize(removedPrograms) {
      let programName: String = GetDaemonDisplayName(removedPrograms[i]);
      BNLog(context + " " + ToString(i + 1) + ". " + programName +
            " (" + TDBID.ToStringDEBUG(removedPrograms[i]) + ")");
      i += 1;
    }
  }

  BNLog(context + " =============================");
}

// ============================================================================
// LOOT REWARD LOGGING
// ============================================================================

// Log loot rewards after breach completion
public func LogLootRewards(
  baseMoney: Float,
  hasCraftingMaterial: Bool,
  baseShardDropChance: Float,
  opt logContext: String
) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Loot]";

  BNLog(context + " ===== LOOT REWARDS =====");
  BNLog(context + " Money Multiplier: " + ToString(baseMoney) + "x");
  BNLog(context + " Crafting Material: " + ToString(hasCraftingMaterial));
  BNLog(context + " Shard Drop Chance: +" + ToString(baseShardDropChance * 100.0) + "%");
  BNLog(context + " ========================");
}

// ============================================================================
// SETTINGS STATE LOGGING
// ============================================================================

// Log current Better Netrunning settings state
public func LogBetterNetrunningSettings(opt logContext: String) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Settings]";

  BNLog(context + " ===== BETTER NETRUNNING SETTINGS =====");
  BNLog(context + " EnableDebugLog: " + ToString(BetterNetrunningSettings.EnableDebugLog()));
  BNLog(context + " AutoExecutePingOnSuccess: " + ToString(BetterNetrunningSettings.AutoExecutePingOnSuccess()));
  BNLog(context + " AutoDatamineBySuccessCount: " + ToString(BetterNetrunningSettings.AutoDatamineBySuccessCount()));
  BNLog(context + " UnlockIfNoAccessPoint: " + ToString(BetterNetrunningSettings.UnlockIfNoAccessPoint()));
  BNLog(context + " AllowBreachingUnconsciousNPCs: " + ToString(BetterNetrunningSettings.AllowBreachingUnconsciousNPCs()));
  BNLog(context + " ======================================");
}

// ============================================================================
// MINIGAME STATE LOGGING
// ============================================================================

// Log minigame completion state
public func LogMinigameCompletionState(
  state: HackingMinigameState,
  successfulPrograms: Int32,
  totalPrograms: Int32,
  opt logContext: String
) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Minigame]";
  let stateName: String = "Unknown";

  if Equals(state, HackingMinigameState.Succeeded) {
    stateName = "Succeeded";
  } else if Equals(state, HackingMinigameState.Failed) {
    stateName = "Failed";
  } else if Equals(state, HackingMinigameState.InProgress) {
    stateName = "InProgress";
  }

  BNLog(context + " ===== MINIGAME COMPLETION =====");
  BNLog(context + " State: " + stateName);
  BNLog(context + " Successful Programs: " + ToString(successfulPrograms) + " / " + ToString(totalPrograms));
  BNLog(context + " Success Rate: " + ToString((Cast<Float>(successfulPrograms) / Cast<Float>(totalPrograms)) * 100.0) + "%");
  BNLog(context + " ===============================");
}
