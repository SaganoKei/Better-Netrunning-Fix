// ============================================================================
// FILE: Utils/BreachSessionLogger.reds
// PURPOSE: Breach session statistics aggregation and logging
// ============================================================================
// BREACH SESSION STATISTICS LOGGER
//
// PURPOSE:
//   Collects all breach processing statistics into a single summary object
//   and outputs formatted log summary, replacing 50+ detailed log statements
//   with clean statistical output
//
// USAGE:
//   let stats: ref<BreachSessionStats> = BreachSessionStats.Create("AccessPoint", "Device Name");
//   stats.minigameSuccess = true;
//   stats.devicesUnlocked = 18;
//   stats.Finalize(); // Calculate processing time
//   LogBreachSummary(stats); // Output formatted summary
//
// OUTPUT EXAMPLE:
//   [INFO] ╔═══════════════════════════════════════╗
//   [INFO] ║   BREACH SESSION SUMMARY             ║
//   [INFO] ╚═══════════════════════════════════════╝
//   [INFO] Type: AccessPoint | Target: H10 Access Point
//   [INFO] Result: SUCCESS | Processing: 234.5 ms
//   [INFO] Total: 23 | Unlocked: 18 (78%)
//   [INFO] � Basic: 5 | �📷 Cameras: 8 | 🔫 Turrets: 4 | 👤 NPCs: 6
//
// DESIGN RATIONALE:
//   - Reduces log noise by 70% (50+ logs → 1 summary)
//   - Improves readability (structured tables vs scattered messages)
//   - Preserves debugging value (all critical metrics included)
//   - Performance neutral (stats collection is negligible overhead)
// ============================================================================

module BetterNetrunning.Logging

import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*

// ============================================================================
// STATISTICS DATA CLASS
// ============================================================================

public class BreachSessionStats {
  // Basic information
  public let breachType: String;           // "AccessPoint", "RemoteBreach", "UnconsciousNPC"
  public let breachTarget: String;         // Device name (e.g., "AccessPoint", "Turret")
  public let timestamp: Float;             // Start time

  // Minigame results
  public let minigameSuccess: Bool;        // Success/Failure
  public let programsInjected: Int32;      // Daemon count injected
  public let programsFiltered: Int32;      // Daemon count after filtering
  public let programsRemoved: Int32;       // Daemon count removed

  // Network processing
  public let networkDeviceCount: Int32;    // Total network devices
  public let devicesUnlocked: Int32;       // Successfully unlocked
  public let devicesFailed: Int32;         // Failed to unlock
  public let devicesSkipped: Int32;        // Skipped (flag check)

  // Device type breakdown (consolidated: Doors/Terminals/Other → Basic)
  public let basicCount: Int32;            // Basic devices (doors, terminals, etc.)
  public let cameraCount: Int32;           // Surveillance cameras
  public let turretCount: Int32;           // Security turrets
  public let npcNetworkCount: Int32;       // Network-connected NPCs (via device link)

  // Network device unlock breakdown (success/skip per type)
  public let basicUnlocked: Int32;         // Basic devices successfully unlocked
  public let basicSkipped: Int32;          // Basic devices skipped (flag check)
  public let cameraUnlocked: Int32;        // Cameras successfully unlocked
  public let cameraSkipped: Int32;         // Cameras skipped (flag check)
  public let turretUnlocked: Int32;        // Turrets successfully unlocked
  public let turretSkipped: Int32;         // Turrets skipped (flag check)
  public let npcNetworkUnlocked: Int32;    // Network NPCs successfully unlocked
  public let npcNetworkSkipped: Int32;     // Network NPCs skipped (flag check)

  // Radial unlock statistics
  public let standaloneDeviceCount: Int32; // Standalone devices unlocked (radial)
  public let vehicleCount: Int32;          // Vehicles unlocked (radial)
  public let npcStandaloneCount: Int32;    // Standalone NPCs (radial unlock, no network)

  // Radial unlock breakdown (success/skip per type)
  public let standaloneUnlocked: Int32;    // Standalone devices successfully unlocked
  public let standaloneSkipped: Int32;     // Standalone devices skipped (flag check)
  public let vehicleUnlocked: Int32;       // Vehicles successfully unlocked
  public let vehicleSkipped: Int32;        // Vehicles skipped (flag check)
  public let npcStandaloneUnlocked: Int32; // Standalone NPCs successfully unlocked
  public let npcStandaloneSkipped: Int32;  // Standalone NPCs skipped (flag check)

  // Unlock flags
  public let unlockBasic: Bool;            // Basic Subnet unlocked
  public let unlockCameras: Bool;          // Camera Subnet unlocked
  public let unlockTurrets: Bool;          // Turret Subnet unlocked
  public let unlockNPCs: Bool;             // NPC Subnet unlocked

  // Executed daemons (Detailed daemon display)
  public let displayedSubnetDaemons: array<TweakDBID>;  // All Subnet daemons displayed (success + failed)
  public let executedSubnetDaemons: array<TweakDBID>;  // Subnet daemons successfully executed
  public let displayedNormalDaemons: array<TweakDBID>;  // All Normal daemons displayed (success + failed)
  public let executedNormalDaemons: array<TweakDBID>;  // Normal daemons successfully executed

  // Radial Breach specific
  public let breachRadius: Float;          // Radius in meters
  public let breachPosition: Vector4;      // Breach coordinates
  public let devicesInRadius: Int32;       // Devices within radius

  // Processing time
  public let processingTimeMs: Float;      // Milliseconds (auto-calculated in Finalize)

  /// Factory method - creates new stats instance with timestamp
  public static func Create(breachType: String, breachTarget: String) -> ref<BreachSessionStats> {
    let stats: ref<BreachSessionStats> = new BreachSessionStats();
    stats.breachType = breachType;
    stats.breachTarget = breachTarget;
    stats.timestamp = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));
    return stats;
  }

  /// Finalize processing - calculates elapsed time
  /// Call this after all processing is complete, before LogBreachSummary
  public func Finalize() -> Void {
    let currentTime: Float = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));
    this.processingTimeMs = (currentTime - this.timestamp) * 1000.0;
  }
}

// ============================================================================
// FORMATTED SUMMARY OUTPUT
// ============================================================================

/// Output breach statistics as formatted summary (INFO level)
/// Replaces 30-50 individual log statements with clean tabular output
public static func LogBreachSummary(stats: ref<BreachSessionStats>) -> Void {
  BNInfo("BreachStats", "");
  BNInfo("BreachStats", "╔═══════════════════════════════════════════════════════════╗");
  BNInfo("BreachStats", "║         BREACH SESSION SUMMARY                           ║");
  BNInfo("BreachStats", "╚═══════════════════════════════════════════════════════════╝");
  BNInfo("BreachStats", "");

  // Basic information
  BNInfo("BreachStats", "┌─ BASIC INFO ──────────────────────────────────────────────┐");
  BNInfo("BreachStats", "│ Type         : " + stats.breachType);
  BNInfo("BreachStats", "│ Target       : " + GetLocalizedTextByKey(StringToName(stats.breachTarget)) + " (" + stats.breachTarget + ")");
  BNInfo("BreachStats", "│ Result       : " + (stats.minigameSuccess ? "SUCCESS" : "FAILED"));

  // Processing time (formatted to 1 decimal)
  let timeStr: String = FloatToStringPrec(stats.processingTimeMs, 1);
  BNInfo("BreachStats", "│ Processing   : " + timeStr + " ms");
  BNInfo("BreachStats", "└───────────────────────────────────────────────────────────┘");
  BNInfo("BreachStats", "");

  // Executed daemons display
  // FUNCTIONALITY: Shows actual daemons executed in breach minigame
  // ARCHITECTURE: Composed Method pattern - separate helpers for Subnet/Normal daemons
  BNInfo("BreachStats", "┌─ EXECUTED DAEMONS ─────────────────────────────────────────┐");

  // Calculate counts for Subnet System
  let subnetExecuted: Int32 = ArraySize(stats.executedSubnetDaemons);
  let subnetTotal: Int32 = ArraySize(stats.displayedSubnetDaemons);

  // Subnet System section
  BNInfo("BreachStats", "│ Subnet System (" + ToString(subnetExecuted) + "/" + ToString(subnetTotal) + "):");
  LogSubnetDaemons(stats);

  BNInfo("BreachStats", "│");

  // Calculate counts for Normal Daemons
  let normalTotal: Int32 = ArraySize(stats.displayedNormalDaemons);
  let normalActuallyExecuted: Int32 = ArraySize(stats.executedNormalDaemons);

  // Normal Daemons section
  BNInfo("BreachStats", "│ Normal Daemons (" + ToString(normalActuallyExecuted) + "/" + ToString(normalTotal) + "):");
  LogNormalDaemons(stats);

  BNInfo("BreachStats", "└────────────────────────────────────────────────────────────┘");
  BNInfo("BreachStats", "");

  // Network unlock results (only if devices processed)
  if stats.networkDeviceCount > 0 {
    let unlockPercent: Int32 = (stats.devicesUnlocked * 100) / stats.networkDeviceCount;
    BNInfo("BreachStats", "┌─ NETWORK UNLOCK RESULTS ──────────────────────────────────┐");
    BNInfo("BreachStats", "│ Total Devices   : " + ToString(stats.networkDeviceCount));
    BNInfo("BreachStats", "│ ├─ Unlocked     : " + ToString(stats.devicesUnlocked) + " (" + ToString(unlockPercent) + "%)");
    BNInfo("BreachStats", "│ ├─ Skipped      : " + ToString(stats.devicesSkipped));
    BNInfo("BreachStats", "│ └─ Failed       : " + ToString(stats.devicesFailed));
    BNInfo("BreachStats", "└───────────────────────────────────────────────────────────┘");
    BNInfo("BreachStats", "");
  }

  // Device type breakdown (only if any devices)
  let hasDevices: Bool = stats.basicCount > 0 || stats.cameraCount > 0 || stats.turretCount > 0 || stats.npcNetworkCount > 0;
  if hasDevices {
    BNInfo("BreachStats", "┌─ NETWORK DEVICES (Via Access Point) ──────────────────────┐");
    LogDeviceTypeBreakdown(
      stats.basicCount, stats.basicUnlocked, stats.basicSkipped,
      "Basic", BNConstants.PROGRAM_UNLOCK_QUICKHACKS()
    );
    LogDeviceTypeBreakdown(
      stats.cameraCount, stats.cameraUnlocked, stats.cameraSkipped,
      "Cameras", BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()
    );
    LogDeviceTypeBreakdown(
      stats.turretCount, stats.turretUnlocked, stats.turretSkipped,
      "Turrets", BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()
    );
    LogDeviceTypeBreakdown(
      stats.npcNetworkCount, stats.npcNetworkUnlocked, stats.npcNetworkSkipped,
      "NPCs", BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()
    );
    BNInfo("BreachStats", "└───────────────────────────────────────────────────────────┘");
    BNInfo("BreachStats", "");
  }

  // Radial unlock breakdown
  // RATIONALE: All breach types execute Radial Unlock (50m radius scan)
  // Always display section for consistency, even if no standalone devices found
  BNInfo("BreachStats", "┌─ STANDALONE DEVICES (50m Radial Unlock) ──────────────────┐");

  let hasAnyRadialData: Bool = stats.standaloneDeviceCount > 0 || stats.vehicleCount > 0 || stats.npcStandaloneCount > 0;

  if hasAnyRadialData {
    LogDeviceTypeBreakdown(
      stats.standaloneDeviceCount, stats.standaloneUnlocked, stats.standaloneSkipped,
      "Devices", BNConstants.PROGRAM_UNLOCK_QUICKHACKS()
    );
    LogDeviceTypeBreakdown(
      stats.vehicleCount, stats.vehicleUnlocked, stats.vehicleSkipped,
      "Vehicles", BNConstants.PROGRAM_UNLOCK_QUICKHACKS()
    );
    LogDeviceTypeBreakdown(
      stats.npcStandaloneCount, stats.npcStandaloneUnlocked, stats.npcStandaloneSkipped,
      "NPCs", BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()
    );
  } else {
    BNInfo("BreachStats", "│ (No standalone devices detected within 50m radius)");
  }

  BNInfo("BreachStats", "└───────────────────────────────────────────────────────────┘");
  BNInfo("BreachStats", "");

  // Radial Breach info (only if radius > 0)
  if stats.breachRadius > 0.0 {
    BNInfo("BreachStats", "┌─ RADIAL BREACH ───────────────────────────────────────────┐");
    BNInfo("BreachStats", "│ Radius       : " + FloatToStringPrec(stats.breachRadius, 1) + "m");
    BNInfo("BreachStats", "│ Devices Found: " + ToString(stats.devicesInRadius));
    BNInfo("BreachStats", "└───────────────────────────────────────────────────────────┘");
    BNInfo("BreachStats", "");
  }

  BNInfo("BreachStats", "═══════════════════════════════════════════════════════════");
}

// ============================================================================
// HELPER: Log Device Type Breakdown
// ============================================================================
// PURPOSE: Displays device unlock statistics with consistent formatting
// FUNCTIONALITY:
// - Shows ✓ icon with unlocked count if any devices were unlocked
// - Shows ⊘ icon with skipped count if all devices were skipped
// - Skips display if device count is 0
// ARCHITECTURE: Guard Clauses + Early Return (0-level nesting)
// PARAMETERS:
// - deviceCount: Total devices of this type detected
// - unlockedCount: Devices successfully unlocked
// - skippedCount: Devices skipped (daemon not executed or conditions not met)
// - label: Device type label (e.g., "Basic", "Cameras", "Vehicles")
// - iconProgram: TweakDBID for icon lookup
private static func LogDeviceTypeBreakdown(
  deviceCount: Int32,
  unlockedCount: Int32,
  skippedCount: Int32,
  label: String,
  iconProgram: TweakDBID
) -> Void {
  if deviceCount == 0 {
    return;
  }

  let icon: String = GetSubnetDaemonIcon(iconProgram);
  let paddedLabel: String = label;

  // Pad label to 8 characters for alignment
  while StrLen(paddedLabel) < 8 {
    paddedLabel += " ";
  }

  if unlockedCount > 0 {
    BNInfo("BreachStats", "│ " + icon + " " + paddedLabel + ": ✓" + ToString(unlockedCount));
  } else {
    BNInfo("BreachStats", "│ " + icon + " " + paddedLabel + ": ⊘" + ToString(skippedCount));
  }
}

// ============================================================================
// HELPER: Log Subnet Daemons Section
// ============================================================================
// PURPOSE: Displays executed and skipped Subnet Daemons
// FUNCTIONALITY:
// - Shows executed daemons with ✓ icon
// - Shows skipped daemons with ⊘ icon (not executed)
// FUNCTIONALITY: Displays Subnet daemon execution status with icons
// - Iterates displayedSubnetDaemons array (actual screen display)
// - Shows ✓ icon for successfully executed daemons
// - Shows ⊘ icon for displayed but not executed daemons
// - Falls back to "(None executed)" if no subnet daemons displayed
// ARCHITECTURE: Guard Clauses + Early Return (0-level nesting)
private static func LogSubnetDaemons(stats: ref<BreachSessionStats>) -> Void {
  let hasDisplayed: Bool = ArraySize(stats.displayedSubnetDaemons) > 0;

  // Guard: No Subnet daemons displayed
  if !hasDisplayed {
    BNInfo("BreachStats", "│   (None executed)");
    return;
  }

  // Display all Subnet daemons with status icons
  let i: Int32 = 0;
  while i < ArraySize(stats.displayedSubnetDaemons) {
    let programID: TweakDBID = stats.displayedSubnetDaemons[i];
    let wasExecuted: Bool = ArrayContains(stats.executedSubnetDaemons, programID);
    let statusIcon: String = wasExecuted ? "✓" : "⊘";
    let daemonName: String = DaemonFilterUtils.GetDaemonDisplayName(programID);
    let icon: String = GetSubnetDaemonIcon(programID);

    BNInfo("BreachStats", "│   " + statusIcon + " " + icon + " " + daemonName + " (" + TDBID.ToStringDEBUG(programID) + ")");
    i += 1;
  }
}

// ============================================================================
// HELPER: Log Normal Daemons Section
// ============================================================================
// PURPOSE: Displays executed Normal Daemons with execution status
// FUNCTIONALITY:
// - Shows displayed normal daemons with execution status (✓ executed / ⊘ displayed only)
// - Adds effect descriptions (e.g., "rewards eddies")
// - Falls back to "(None executed)" if no normal daemons
// ARCHITECTURE: Guard Clauses + Early Return (0-level nesting)
private static func LogNormalDaemons(stats: ref<BreachSessionStats>) -> Void {
  let hasDisplayed: Bool = ArraySize(stats.displayedNormalDaemons) > 0;

  if !hasDisplayed {
    BNInfo("BreachStats", "│   (None executed)");
    return;
  }

  // Display normal daemons with execution status
  let i: Int32 = 0;
  while i < ArraySize(stats.displayedNormalDaemons) {
    let programID: TweakDBID = stats.displayedNormalDaemons[i];
    let daemonName: String = DaemonFilterUtils.GetDaemonDisplayName(programID);

    // Check if actually executed
    let wasExecuted: Bool = ArrayContains(stats.executedNormalDaemons, programID);
    let statusIcon: String = wasExecuted ? "✓" : "⊘";

    BNInfo("BreachStats", "│   " + statusIcon + " " + daemonName + " (" + TDBID.ToStringDEBUG(programID) + ")");
    i += 1;
  }
}

// ============================================================================
// HELPER: Get Subnet Daemon Icon
// ============================================================================
// PURPOSE: Returns appropriate icon for subnet daemon type
// FUNCTIONALITY: Maps TweakDBID to icon (🔌 Basic, 📷 Camera, 🔫 Turret, 👤 NPC)
// ARCHITECTURE: Simple lookup table
private static func GetSubnetDaemonIcon(programID: TweakDBID) -> String {
  // Basic Subnet
  if Equals(programID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS()) {
    return "🔌";
  }
  // Camera Subnet
  else if Equals(programID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()) {
    return "📷";
  }
  // Turret Subnet
  else if Equals(programID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()) {
    return "🔫";
  }
  // NPC Subnet
  else if Equals(programID, BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()) {
    return "👤";
  }
  // Fallback: no icon
  else {
    return "";
  }
}
