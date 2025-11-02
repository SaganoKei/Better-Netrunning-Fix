// ============================================================================
// BetterNetrunning - Debug Utilities
// ============================================================================
//
// PURPOSE:
//   Provides structured debug information logging for breach operations
//   Built on top of Logger.reds (BNInfo/BNDebug/BNWarn functions)
//
// FUNCTIONALITY:
//   - Device scan logging: Outputs quickhack state when player completes scanning
//   - Device quickhack state logging: Locked/unlocked state per action
//   - NPC quickhack state logging: Breach flags, network state
//   - Breach target information logging: Location, device type, network info
//   - Program filtering logging: Daemon removal tracking with before/after counts
//   - RemoteBreach RAM check logging: Cost validation with current/max RAM
//
// ARCHITECTURE:
//   - Layered logging: DebugUtils → Logger.reds → RED4ext.ModLog
//   - Settings-aware: Checks EnableDebugLog before output
//   - Structured output: Section headers (INFO) + detailed data (DEBUG)
//   - Location tracking: X/Y/Z coordinates for all targets
//   - Event-driven: OnScanningActionFinishedEvent hook for scan-time logging
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
    let prefix: String = BNConstants.DEVICE_NAME_PREFIX();
    let cleaned: String = rawName;

    // Remove prefix if present
    if StrBeginsWith(rawName, prefix) {
      cleaned = StrMid(rawName, StrLen(prefix));
    }

    // Convert LocKey to localized string
    if StrBeginsWith(cleaned, "LocKey#") {
      return GetLocalizedText(cleaned);
    }

    return cleaned;
  }

  // ============================================================================
  // QUICKHACK LIST LOGGING (COMMON HELPER)
  // ============================================================================

  /*
   * Logs quickhack list with localized names and lock status
   *
   * Common helper for both device and NPC quickhack logging
   * Accepts DeviceAction parent type (compatible with PuppetAction via inheritance)
   *
   * @param actions - Array of device actions (DeviceAction or PuppetAction)
   * @param logContext - Context label for log output
   */
  private static func LogQuickhackListFromDeviceActions(
    actions: array<ref<DeviceAction>>,
    logContext: String
  ) -> Void {
    BNDebug(logContext, "--- Available Quickhacks (" + ToString(ArraySize(actions)) + ") ---");

    let i: Int32 = 0;
    while i < ArraySize(actions) {
      let action: ref<DeviceAction> = actions[i];
      if IsDefined(action) {
        let baseAction: ref<BaseScriptableAction> = action as BaseScriptableAction;
        if IsDefined(baseAction) {
          let isInactive: Bool = baseAction.IsInactive();
          let status: String = isInactive ? "[LOCKED]" : "[AVAILABLE]";

          let record: ref<ObjectAction_Record> = baseAction.GetObjectActionRecord();
          if IsDefined(record) {
            let displayName: String = GetLocalizedTextByKey(record.ObjectActionUI().Caption());
            let actionName: CName = record.ActionName();

            BNDebug(logContext, "  " + status + " " + displayName + " (" + NameToString(actionName) + ")");
          }
        }
      }
      i += 1;
    }
  }

  // ============================================================================
  // DEVICE QUICKHACK STATE LOGGING
  // ============================================================================

  /*
   * Logs device quickhack state when player completes scanning
   *
   * Called from Device.OnScanningActionFinishedEvent wrapper
   * Outputs device name, location, and available quickhacks
   *
   * @param devicePS - Device persistent state to log
   * @param actions - Array of quickhack actions (already evaluated)
   */
  public static func LogDeviceQuickhackStateOnScan(devicePS: ref<ScriptableDeviceComponentPS>, actions: array<ref<DeviceAction>>) -> Void {
    if !BetterNetrunningSettings.EnableDebugLog() {
      return;
    }

    let sharedPS: ref<SharedGameplayPS> = devicePS;
    if !IsDefined(sharedPS) {
      BNWarn("[SCAN]", "Device is not SharedGameplayPS, skipping scan log");
      return;
    }

    // Get device type and localized name
    let deviceType: String = DaemonFilterUtils.GetDeviceTypeName(devicePS);
    let rawDeviceName: String = devicePS.GetDeviceName();
    let deviceName: String = DebugUtils.CleanDeviceName(rawDeviceName);

    BNInfo("[SCAN]", "===== DEVICE SCANNED =====");
    BNInfo("[SCAN]", "Device: " + deviceName + " (" + deviceType + ")");

    // Location information
    let deviceEntity: ref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
    if IsDefined(deviceEntity) {
      let position: Vector4 = deviceEntity.GetWorldPosition();
      BNDebug("[SCAN]", "Location: X=" + ToString(position.X) + " Y=" + ToString(position.Y) + " Z=" + ToString(position.Z));
    }

    // Breach state summary
    BNDebug("[SCAN]", "--- Breach State ---");
    BNDebug("[SCAN]", "Basic Breached: " + ToString(BreachStatusUtils.IsBasicBreached(sharedPS)));
    BNDebug("[SCAN]", "Camera Breached: " + ToString(BreachStatusUtils.IsCamerasBreached(sharedPS)));
    BNDebug("[SCAN]", "Turret Breached: " + ToString(BreachStatusUtils.IsTurretsBreached(sharedPS)));
    BNDebug("[SCAN]", "NPC Breached: " + ToString(BreachStatusUtils.IsNPCsBreached(sharedPS)));

    // Network state
    let isConnected: Bool = sharedPS.IsConnectedToPhysicalAccessPoint();
    let hasBackdoor: Bool = sharedPS.HasNetworkBackdoor();
    let isStandalone: Bool = !isConnected && !hasBackdoor;
    BNDebug("[SCAN]", "Network: " + (isConnected ? "Connected" : (hasBackdoor ? "Backdoor" : "Standalone")));

    // Quickhack availability (use common helper)
    DebugUtils.LogQuickhackListFromDeviceActions(actions, "[SCAN]");

    BNInfo("[SCAN]", "==========================");
  }

// ============================================================================
// NPC QUICKHACK STATE LOGGING
// ============================================================================

  /*
   * Logs NPC quickhack state with actual quickhack list
   *
   * @param npcPS - NPC persistent state
   * @param puppetActions - Array of NPC quickhack actions (script_ref)
   * @param logContext - Optional context label
   */
  public static func LogNPCQuickhackState(
    npcPS: ref<ScriptedPuppetPS>,
    puppetActions: script_ref<array<ref<PuppetAction>>>,
    opt logContext: String
  ) -> Void {
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

    // Quickhack availability (use common helper with PuppetAction → DeviceAction upcast)
    let deviceActions: array<ref<DeviceAction>>;
    let i: Int32 = 0;
    while i < ArraySize(Deref(puppetActions)) {
      let puppetAction: ref<PuppetAction> = Deref(puppetActions)[i];
      if IsDefined(puppetAction) {
        ArrayPush(deviceActions, puppetAction);
      }
      i += 1;
    }

    DebugUtils.LogQuickhackListFromDeviceActions(deviceActions, context);

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

  // ============================================================================
  // REMOTEBREACH RAM CHECK LOGGING
  // ============================================================================

  /*
   * Log RemoteBreach RAM check details (cost vs current/max RAM)
   *
   * @param actionClassName - RemoteBreach action class name
   * @param ramCost - Required RAM cost
   * @param currentRAM - Player's current RAM
   * @param maxRAM - Player's max RAM
   * @param canPay - Whether player can pay the cost
   * @param logContext - Optional context label
   */
  public static func LogRemoteBreachRAMCheck(
    actionClassName: CName,
    ramCost: Int32,
    currentRAM: Float,
    maxRAM: Float,
    canPay: Bool,
    opt logContext: String
  ) -> Void {
    if !BetterNetrunningSettings.EnableDebugLog() {
      return;
    }

    let context: String = NotEquals(logContext, "") ? logContext : "[RemoteBreach]";

    BNInfo(context, "===== REMOTEBREACH RAM CHECK =====");
    BNInfo(context, "Action: " + NameToString(actionClassName));
    BNDebug(context, "--- RAM Status ---");
    BNDebug(context, "Cost: " + ToString(ramCost));
    BNDebug(context, "Current: " + ToString(currentRAM));
    BNDebug(context, "Max: " + ToString(maxRAM));
    BNDebug(context, "Can Pay: " + ToString(canPay));
    BNInfo(context, "==================================");
  }

}

// ============================================================================
// DEVICE SCAN EVENT HOOK
// ============================================================================

/*
 * Logs device quickhack state when player completes scanning
 *
 * VANILLA DIFF: Adds debug logging after scan completion
 * Called by native engine when scan finishes (ScanningActionFinishedEvent)
 */
@wrapMethod(Device)
protected cb func OnScanningActionFinishedEvent(evt: ref<ScanningActionFinishedEvent>) -> Void {
  wrappedMethod(evt);

  // Log quickhack state if debug logging enabled
  if BetterNetrunningSettings.EnableDebugLog() {
    let devicePS: ref<ScriptableDeviceComponentPS> = this.GetDevicePS();
    if !IsDefined(devicePS) {
      return;
    }

    // Generate context for quickhack evaluation
    let player: ref<GameObject> = GetPlayer(this.GetGame());
    if !IsDefined(player) {
      return;
    }

    let context: GetActionsContext = devicePS.GenerateContext(
      gamedeviceRequestType.Remote,
      Device.GetInteractionClearance(),
      player,
      player.GetEntityID()
    );

    // Get current quickhack actions
    let actions: array<ref<DeviceAction>>;
    devicePS.GetQuickHackActions(actions, context);

    // Delegate to logging function
    DebugUtils.LogDeviceQuickhackStateOnScan(devicePS, actions);
  }
}
