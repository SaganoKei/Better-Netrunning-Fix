// ============================================================================
// BetterNetrunning - Debug Utilities
// ============================================================================
//
// PURPOSE:
//   Provides structured debug information logging for breach operations
//   Built on top of Logger.reds (BNInfo/BNDebug/BNWarn functions)
//
// FUNCTIONALITY:
//   - Device quickhack state logging (locked/unlocked state)
//   - NPC quickhack state logging (breach flags, network state)
//   - Breach target information logging (location, device type, network info)
//   - Network device type scanning (cameras, turrets, NPCs, doors)
//
// ARCHITECTURE:
//   - Layered logging: DebugUtils → Logger.reds → RED4ext.ModLog
//   - Settings-aware: Checks EnableDebugLog before output
//   - Structured output: Section headers (INFO) + detailed data (DEBUG)
//   - Location tracking: X/Y/Z coordinates for all targets
//

module BetterNetrunning.Logging

import BetterNetrunning.Core.*
import BetterNetrunning.Minigame.*
import BetterNetrunning.Utils.*
import BetterNetrunningConfig.*
import BetterNetrunning.Logging.*

// ============================================================================
// Debug Utilities - Static Helper Class
// ============================================================================

public abstract class DebugUtils {

  // ============================================================================
  // HELPER FUNCTIONS
  // ============================================================================

  // Removes "Gameplay-Devices-DisplayNames-" prefix from device name
  // and converts LocKey to localized string
  public static func CleanDeviceName(rawName: String) -> String {
    let prefix: String = "Gameplay-Devices-DisplayNames-";
    let cleaned: String = rawName;

    // Remove prefix if present
    if StrBeginsWith(rawName, prefix) {
      cleaned = StrMid(rawName, StrLen(prefix));
    }

    // Convert LocKey to localized string
    if StrBeginsWith(cleaned, "LocKey#") {
      return GetLocalizedTextByKey(StringToName(cleaned));
    }

    return cleaned;
  }

  // ============================================================================
  // DEVICE QUICKHACK STATE LOGGING
  // ============================================================================

  // Log all quickhack states for a device (locked/unlocked)
  public static func LogDeviceQuickhackState(devicePS: ref<ScriptableDeviceComponentPS>, opt logContext: String) -> Void {
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
    BNInfo(context, "Device: " + DebugUtils.CleanDeviceName(devicePS.GetDeviceName()));

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
  public static func LogNPCQuickhackState(npcPS: ref<ScriptedPuppetPS>, opt logContext: String) -> Void {
    if !BetterNetrunningSettings.EnableDebugLog() {
      return;
    }

    let context: String = NotEquals(logContext, "") ? logContext : "[Debug]";

    // Early return: Skip NPCs not connected to any Access Point
    // This prevents false warnings during DeviceLink initialization phase
    if !npcPS.IsConnectedToAccessPoint() {
      return;  // Normal state - no warning needed
    }

    let deviceLinkPS: ref<SharedGameplayPS> = npcPS.GetDeviceLink();

    if !IsDefined(deviceLinkPS) {
      // If NPC is connected to AP but has no device link, this is unexpected
      BNWarn(context, "NPC is connected to AP but DeviceLink is null (unexpected timing issue)");
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
// BREACH TARGET LOGGING
// ============================================================================

  // Log Access Point breach target information with network device types
  public static func LogAccessPointBreachTarget(apPS: ref<AccessPointControllerPS>, opt logContext: String) -> Void {
    if !BetterNetrunningSettings.EnableDebugLog() {
      return;
    }

    let context: String = NotEquals(logContext, "") ? logContext : "[AccessPoint]";

    BNInfo(context, "===== BREACH TARGET INFORMATION =====");
    BNInfo(context, "Breach Method: Access Point Breach");
    BNInfo(context, "Target Device: " + DebugUtils.CleanDeviceName(apPS.GetDeviceName()));
    BNInfo(context, "Device Type: Access Point");

    let apEntity: ref<GameObject> = apPS.GetOwnerEntityWeak() as GameObject;
    if IsDefined(apEntity) {
      let apPosition: Vector4 = apEntity.GetWorldPosition();
      BNDebug(context, "x = " + ToString(apPosition.X) + ", y = " + ToString(apPosition.Y) + ", z = " + ToString(apPosition.Z));
    }

    BNInfo(context, "Network Name: " + apPS.GetNetworkName());

    let data: ConnectedClassTypes = apPS.CheckMasterConnectedClassTypes();
    BNDebug(context, "--- Network Device Types ---");
    BNDebug(context, "Cameras Connected: " + ToString(data.surveillanceCamera));
    BNDebug(context, "Turrets Connected: " + ToString(data.securityTurret));
    BNDebug(context, "NPCs Connected: " + ToString(data.puppet));

    BNInfo(context, "=====================================");
  }

  // Log Remote Breach target information
  public static func LogRemoteBreachTarget(devicePS: ref<ScriptableDeviceComponentPS>, opt logContext: String) -> Void {
    if !BetterNetrunningSettings.EnableDebugLog() {
      return;
    }

    let context: String = NotEquals(logContext, "") ? logContext : "[RemoteBreach]";

    BNInfo(context, "===== BREACH TARGET INFORMATION =====");
    BNInfo(context, "Breach Method: Remote Breach (CustomHackingSystem)");
    BNInfo(context, "Target Device: " + DebugUtils.CleanDeviceName(devicePS.GetDeviceName()));
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
  public static func LogUnconsciousNPCBreachTarget(npc: ref<ScriptedPuppet>, npcPS: ref<ScriptedPuppetPS>, opt logContext: String) -> Void {
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
  public static func LogProgramFilteringStep(
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
  public static func LogFilteringSummary(
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

}
