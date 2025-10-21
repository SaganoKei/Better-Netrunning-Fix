// ============================================================================
// BetterNetrunning - Debug Utilities
// ============================================================================
// HIGH-LEVEL DEBUG LOGGING FUNCTIONS
//
// PURPOSE:
//   Provides structured debug information logging for breach operations
//   Built on top of Logger.reds (BNInfo/BNDebug/BNWarn functions)
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
//   - Control detail level via DebugLogLevel setting (2=INFO, 3=DEBUG)
//
// DESIGN NOTES:
//   - All functions check EnableDebugLog setting before output
//   - Uses BNInfo/BNDebug/BNWarn from Logger.reds (never calls ModLog directly)
//   - Provides human-readable structured output with clear section headers
//   - Includes location information (X/Y/Z coordinates) for all targets
//   - Section headers output at INFO level, detailed data at DEBUG level
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
    BNWarn(context, "Device is not SharedGameplayPS, skipping quickhack state logging");
    return;
  }

  BNInfo(context, "===== DEVICE QUICKHACK STATE =====");
  BNInfo(context, "Device: " + CleanDeviceName(devicePS.GetDeviceName()));

  // Location information
  let deviceEntity: ref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
  if IsDefined(deviceEntity) {
    let position: Vector4 = deviceEntity.GetWorldPosition();
    BNDebug(context, "--- Location ---");
    BNDebug(context, "x = " + ToString(position.X) + ", y = " + ToString(position.Y) + ", z = " + ToString(position.Z));
  }

  // Breach state (timestamp-based)
  BNDebug(context, "--- Breach State (Timestamp) ---");
  BNDebug(context, "Basic Subnet Breached: " + ToString(BreachStatusUtils.IsBasicBreached(sharedPS)) + " (ts: " + ToString(sharedPS.m_betterNetrunningUnlockTimestampBasic) + ")");
  BNDebug(context, "Camera Subnet Breached: " + ToString(BreachStatusUtils.IsCamerasBreached(sharedPS)) + " (ts: " + ToString(sharedPS.m_betterNetrunningUnlockTimestampCameras) + ")");
  BNDebug(context, "Turret Subnet Breached: " + ToString(BreachStatusUtils.IsTurretsBreached(sharedPS)) + " (ts: " + ToString(sharedPS.m_betterNetrunningUnlockTimestampTurrets) + ")");
  BNDebug(context, "NPC Subnet Breached: " + ToString(BreachStatusUtils.IsNPCsBreached(sharedPS)) + " (ts: " + ToString(sharedPS.m_betterNetrunningUnlockTimestampNPCs) + ")");

  // Network connectivity
  BNDebug(context, "--- Network State ---");
  BNDebug(context, "Connected to Network: " + ToString(sharedPS.IsConnectedToPhysicalAccessPoint()));
  BNDebug(context, "Has Network Backdoor: " + ToString(sharedPS.HasNetworkBackdoor()));

  // Explicit standalone computation for clarity in logs
  let isStandaloneDevice: Bool = !sharedPS.IsConnectedToPhysicalAccessPoint() && !sharedPS.HasNetworkBackdoor();
  BNDebug(context, "Is Standalone: " + ToString(isStandaloneDevice));

  // Quickhack availability (basic examples)
  BNDebug(context, "--- Quickhack Availability ---");

  // Camera-specific quickhacks
  if DaemonFilterUtils.IsCamera(devicePS) {
    BNDebug(context, "[Camera] Remote Disable: Available");
    BNDebug(context, "[Camera] Friendly Turret: " + ToString(BreachStatusUtils.IsCamerasBreached(sharedPS)));
  }

  // Turret-specific quickhacks
  if DaemonFilterUtils.IsTurret(devicePS) {
    BNDebug(context, "[Turret] Remote Disable: Available");
    BNDebug(context, "[Turret] Friendly Turret: " + ToString(BreachStatusUtils.IsTurretsBreached(sharedPS)));
  }

  // Basic device quickhacks
  BNDebug(context, "[Basic] Distract: " + ToString(BreachStatusUtils.IsBasicBreached(sharedPS)));

  BNInfo(context, "==================================");
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
    BNWarn(context, "NPC has no device link, skipping quickhack state logging");
    return;
  }

  BNInfo(context, "===== NPC QUICKHACK STATE =====");

  // Location information
  let npcEntity: ref<GameObject> = npcPS.GetOwnerEntityWeak() as GameObject;
  if IsDefined(npcEntity) {
    let position: Vector4 = npcEntity.GetWorldPosition();
    BNDebug(context, "--- Location ---");
    BNDebug(context, "x = " + ToString(position.X) + ", y = " + ToString(position.Y) + ", z = " + ToString(position.Z));
  }

  // Breach state (timestamp-based)
  BNDebug(context, "--- Breach State (Timestamp) ---");
  BNDebug(context, "NPC Subnet Breached: " + ToString(BreachStatusUtils.IsNPCsBreached(deviceLinkPS)) + " (ts: " + ToString(deviceLinkPS.m_betterNetrunningUnlockTimestampNPCs) + ")");

  // Network connectivity
  BNDebug(context, "--- Network State ---");
  BNDebug(context, "Connected to Network: " + ToString(npcPS.IsConnectedToAccessPoint()));
  BNDebug(context, "Connected to AP: " + ToString(deviceLinkPS.IsConnectedToPhysicalAccessPoint()));

  // Explicit standalone computation for NPCs (not connected to any AP/backdoor)
  let isStandaloneNPC: Bool = !npcPS.IsConnectedToAccessPoint() && !deviceLinkPS.IsConnectedToPhysicalAccessPoint() && !deviceLinkPS.HasNetworkBackdoor();
  BNDebug(context, "Is Standalone: " + ToString(isStandaloneNPC));

  // Quickhack availability categories
  let npcBreached: Bool = BreachStatusUtils.IsNPCsBreached(deviceLinkPS);
  BNDebug(context, "--- Quickhack Availability ---");
  BNDebug(context, "[Covert] Memory Wipe, Reboot Optics: " + ToString(npcBreached));
  BNDebug(context, "[Combat] Short Circuit, Overheat: " + ToString(npcBreached));
  BNDebug(context, "[Control] Cyberware Malfunction, Weapon Glitch: " + ToString(npcBreached));
  BNDebug(context, "[Ultimate] Cyberpsychosis, Suicide: " + ToString(npcBreached));

  BNInfo(context, "===============================");
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

  BNInfo(context, "===== NETWORK DEVICE TYPES =====");
  BNDebug(context, "Cameras Connected: " + ToString(data.surveillanceCamera));
  BNDebug(context, "Turrets Connected: " + ToString(data.securityTurret));
  BNDebug(context, "NPCs Connected: " + ToString(data.puppet));
  BNInfo(context, "================================");
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

  BNInfo(context, "===== BREACH TARGET INFORMATION =====");
  BNInfo(context, "Breach Method: Access Point Breach");
  BNInfo(context, "Target Device: " + CleanDeviceName(apPS.GetDeviceName()));
  BNInfo(context, "Device Type: Access Point");

  let apEntity: ref<GameObject> = apPS.GetOwnerEntityWeak() as GameObject;
  if IsDefined(apEntity) {
    let apPosition: Vector4 = apEntity.GetWorldPosition();
    BNDebug(context, "x = " + ToString(apPosition.X) + ", y = " + ToString(apPosition.Y) + ", z = " + ToString(apPosition.Z));
  }

  BNInfo(context, "Network Name: " + apPS.GetNetworkName());
  BNInfo(context, "=====================================");
}

// Log Remote Breach target information
public func LogRemoteBreachTarget(devicePS: ref<ScriptableDeviceComponentPS>, opt logContext: String) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[RemoteBreach]";

  BNInfo(context, "===== BREACH TARGET INFORMATION =====");
  BNInfo(context, "Breach Method: Remote Breach (CustomHackingSystem)");
  BNInfo(context, "Target Device: " + CleanDeviceName(devicePS.GetDeviceName()));
  BNInfo(context, "Device Type: " + DaemonFilterUtils.GetDeviceTypeName(devicePS));

  let deviceEntity: ref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
  if IsDefined(deviceEntity) {
    let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
    BNDebug(context, "x = " + ToString(devicePosition.X) + ", y = " + ToString(devicePosition.Y) + ", z = " + ToString(devicePosition.Z));
  }

  // ScriptableDeviceComponentPS already extends SharedGameplayPS
  let sharedPS: ref<SharedGameplayPS> = devicePS;
  if IsDefined(sharedPS) {
    BNDebug(context, "Network Name: " + sharedPS.GetNetworkName());
    BNDebug(context, "Connected to AP: " + ToString(sharedPS.IsConnectedToPhysicalAccessPoint()));
  }
  BNInfo(context, "=====================================");
}

// Log Unconscious NPC Breach target information
public func LogUnconsciousNPCBreachTarget(npc: ref<ScriptedPuppet>, npcPS: ref<ScriptedPuppetPS>, opt logContext: String) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[UnconsciousNPC]";

  BNInfo(context, "===== BREACH TARGET INFORMATION =====");
  BNInfo(context, "Breach Method: Unconscious NPC Breach");

  let npcDisplayName: String = npc.GetDisplayName();
  if NotEquals(npcDisplayName, "") {
    BNInfo(context, "Target NPC: " + npcDisplayName);
  } else {
    BNWarn(context, "Target NPC: [Unknown]");
  }

  let npcPosition: Vector4 = npc.GetWorldPosition();
  BNDebug(context, "x = " + ToString(npcPosition.X) + ", y = " + ToString(npcPosition.Y) + ", z = " + ToString(npcPosition.Z));

  let deviceLinkPS: ref<SharedGameplayPS> = npcPS.GetDeviceLink();
  if IsDefined(deviceLinkPS) {
    BNDebug(context, "Connected to Network: " + ToString(npcPS.IsConnectedToAccessPoint()));
    if npcPS.IsConnectedToAccessPoint() {
      BNDebug(context, "Network Name: " + deviceLinkPS.GetNetworkName());
    }
  }
  BNInfo(context, "=====================================");
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
    let programName: String = DaemonFilterUtils.GetDaemonDisplayName(removedProgram);
    BNDebug(context, filterName + ": Removed " + programName +
          " (" + ToString(programsBefore) + " → " + ToString(programsAfter) + " programs)");
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

  BNInfo(context, "===== FILTERING SUMMARY =====");
  BNInfo(context, "Initial programs: " + ToString(initialCount));
  BNInfo(context, "Final programs: " + ToString(finalCount));
  BNInfo(context, "Removed programs: " + ToString(removedCount));

  if removedCount > 0 {
    BNDebug(context, "--- Removed Program List ---");
    let i: Int32 = 0;
    while i < ArraySize(removedPrograms) {
      let programName: String = DaemonFilterUtils.GetDaemonDisplayName(removedPrograms[i]);
      BNDebug(context, ToString(i + 1) + ". " + programName +
            " (" + TDBID.ToStringDEBUG(removedPrograms[i]) + ")");
      i += 1;
    }
  }

  BNInfo(context, "=============================");
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

  BNInfo(context, "===== LOOT REWARDS =====");
  BNInfo(context, "Money Multiplier: " + ToString(baseMoney) + "x");
  BNInfo(context, "Crafting Material: " + ToString(hasCraftingMaterial));
  BNInfo(context, "Shard Drop Chance: +" + ToString(baseShardDropChance * 100.0) + "%");
  BNInfo(context, "========================");
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

  BNInfo(context, "===== BETTER NETRUNNING SETTINGS =====");
  BNDebug(context, "EnableDebugLog: " + ToString(BetterNetrunningSettings.EnableDebugLog()));
  BNDebug(context, "AutoExecutePingOnSuccess: " + ToString(BetterNetrunningSettings.AutoExecutePingOnSuccess()));
  BNDebug(context, "AutoDatamineBySuccessCount: " + ToString(BetterNetrunningSettings.AutoDatamineBySuccessCount()));
  BNDebug(context, "UnlockIfNoAccessPoint: " + ToString(BetterNetrunningSettings.UnlockIfNoAccessPoint()));
  BNDebug(context, "AllowBreachingUnconsciousNPCs: " + ToString(BetterNetrunningSettings.AllowBreachingUnconsciousNPCs()));
  BNInfo(context, "======================================");
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

  BNInfo(context, "===== MINIGAME COMPLETION =====");
  BNInfo(context, "State: " + stateName);
  BNInfo(context, "Successful Programs: " + ToString(successfulPrograms) + " / " + ToString(totalPrograms));
  BNInfo(context, "Success Rate: " + ToString((Cast<Float>(successfulPrograms) / Cast<Float>(totalPrograms)) * 100.0) + "%");
  BNInfo(context, "===============================");
}
