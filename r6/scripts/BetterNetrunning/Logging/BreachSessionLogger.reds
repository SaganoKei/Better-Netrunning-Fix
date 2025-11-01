// ============================================================================
// FILE: Utils/BreachSessionLogger.reds
// PURPOSE: Breach session statistics aggregation and logging
// ============================================================================
// BREACH SESSION STATISTICS LOGGER
//
// PURPOSE:
//   Collects all breach processing statistics into a single summary object
//   and outputs formatted log summary with clean statistical output
//
// FUNCTIONALITY:
//   - Factory method creates stats object with timestamp
//   - Finalize() calculates processing time
//   - LogBreachSummary() outputs formatted tabular display
//   - Supports network devices, radial unlock, and daemon execution tracking
//
// ARCHITECTURE:
//   - Structured log output with formatted tables
//   - Single summary replaces scattered messages
//   - Preserves debugging value with all critical metrics
//   - Performance neutral (stats collection is negligible overhead)
// ============================================================================

module BetterNetrunning.Logging

import BetterNetrunning.Core.*
import BetterNetrunning.Minigame.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Logging.*

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

  // Radial unlock statistics - separated by network connectivity
  public let standaloneDeviceCount: Int32; // Pure standalone devices (no network connection)
  public let crossNetworkDeviceCount: Int32; // Cross-network devices (other network connections)
  public let vehicleCount: Int32;          // Vehicles (always standalone)
  public let npcPureStandaloneCount: Int32; // Pure standalone NPCs (no DeviceLink)
  public let npcCrossNetworkCount: Int32;  // Cross-network NPCs (has DeviceLink, other network)

  // Radial unlock breakdown - Pure standalone
  public let standaloneUnlocked: Int32;    // Pure standalone devices successfully unlocked
  public let standaloneSkipped: Int32;     // Pure standalone devices skipped (flag check)

  // Radial unlock breakdown - Cross-network
  public let crossNetworkUnlocked: Int32;  // Cross-network devices successfully unlocked
  public let crossNetworkSkipped: Int32;   // Cross-network devices skipped (flag check)

  // Radial unlock breakdown - Vehicles and NPCs
  public let vehicleUnlocked: Int32;       // Vehicles successfully unlocked
  public let vehicleSkipped: Int32;        // Vehicles skipped (flag check)
  public let npcPureStandaloneUnlocked: Int32; // Pure standalone NPCs successfully unlocked
  public let npcPureStandaloneSkipped: Int32;  // Pure standalone NPCs skipped (flag check)
  public let npcCrossNetworkUnlocked: Int32;   // Cross-network NPCs successfully unlocked
  public let npcCrossNetworkSkipped: Int32;    // Cross-network NPCs skipped (flag check)

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
  public let executedBonusDaemons: array<TweakDBID>;   // Bonus daemons (auto Datamine) executed

  // Radial Breach specific
  public let breachRadius: Float;          // Radius in meters
  public let breachPosition: Vector4;      // Breach coordinates
  public let devicesInRadius: Int32;       // Devices within radius

  // Origin tracking
  public let originPosition: Vector4;      // Origin coordinates for radial unlock
  public let originType: String;           // "NPC" or "Device"
  public let radialUnlockRange: Float;     // Actual radial unlock range in meters

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

/*
 * Format Vector4 coordinates to string with 2 decimal precision
 *
 * @param pos Vector4 position
 * @return Formatted string "(X, Y, Z)"
 */
private static func FormatCoordinates(pos: Vector4) -> String {
  let x: String = FloatToStringPrec(pos.X, 2);
  let y: String = FloatToStringPrec(pos.Y, 2);
  let z: String = FloatToStringPrec(pos.Z, 2);
  return "(" + x + ", " + y + ", " + z + ")";
}

/*
 * Output breach statistics as formatted summary (INFO level)
 *
 * Replaces 30-50 individual log statements with clean tabular output
 *
 * @param stats - Breach session statistics object
 */
public static func LogBreachSummary(stats: ref<BreachSessionStats>) -> Void {
  BNInfo("BreachStats", "");
  BNInfo("BreachStats", "╔═══════════════════════════════════════════════════════════╗");
  BNInfo("BreachStats", "║         BREACH SESSION SUMMARY                           ║");
  BNInfo("BreachStats", "╚═══════════════════════════════════════════════════════════╝");
  BNInfo("BreachStats", "");

  // Basic information
  BNInfo("BreachStats", "┌─ BASIC INFO ──────────────────────────────────────────────┐");
  BNInfo("BreachStats", "│ Type         : " + stats.breachType);
  BNInfo("BreachStats", "│ Target       : " + GetLocalizedTextByKey(StringToName(stats.breachTarget)) + " (" + DebugUtils.CleanDeviceName(stats.breachTarget) + ")");
  BNInfo("BreachStats", "│ Result       : " + (stats.minigameSuccess ? "SUCCESS" : "FAILED"));

  // Origin information (if available)
  if stats.radialUnlockRange > 0.0 {
    let originLabel: String = stats.originType + " Position";
    let coordStr: String = FormatCoordinates(stats.originPosition);
    BNInfo("BreachStats", "│ Origin       : " + originLabel + " " + coordStr);
  }

  // Processing time (formatted to 1 decimal) - moved to bottom
  let timeStr: String = FloatToStringPrec(stats.processingTimeMs, 1);
  BNInfo("BreachStats", "│ Processing   : " + timeStr + " ms");
  BNInfo("BreachStats", "└───────────────────────────────────────────────────────────┘");
  BNInfo("BreachStats", "");

  // Executed daemons display
  // FUNCTIONALITY: Shows actual daemons executed in breach minigame
  // ARCHITECTURE: Uses LogDaemonList() for consistent daemon formatting
  BNInfo("BreachStats", "┌─ EXECUTED DAEMONS ─────────────────────────────────────────┐");

  // Calculate counts for Subnet System
  let subnetExecuted: Int32 = ArraySize(stats.executedSubnetDaemons);
  let subnetTotal: Int32 = ArraySize(stats.displayedSubnetDaemons);

  // Subnet System section
  BNInfo("BreachStats", "│ Subnet System (" + ToString(subnetExecuted) + "/" + ToString(subnetTotal) + "):");
  LogDaemonList(
    stats.displayedSubnetDaemons,
    stats.executedSubnetDaemons,
    "(None executed)",
    true,  // showStatusIcon - ✓ executed / ⊘ displayed only
    true,  // showIcon - Subnet type icons (🔌📷🔫👤)
    ""     // no additional suffix
  );

  // Normal Daemons section (conditional display - only if any normal daemons exist)
  if ArraySize(stats.displayedNormalDaemons) > 0 {
    BNInfo("BreachStats", "│");
    let normalTotal: Int32 = ArraySize(stats.displayedNormalDaemons);
    let normalActuallyExecuted: Int32 = ArraySize(stats.executedNormalDaemons);
    BNInfo("BreachStats", "│ Normal Daemons (" + ToString(normalActuallyExecuted) + "/" + ToString(normalTotal) + "):");
    LogDaemonList(
      stats.displayedNormalDaemons,
      stats.executedNormalDaemons,
      "(None executed)",
      true,   // showStatusIcon - ✓ executed / ⊘ displayed only
      false,  // no icon for Normal daemons
      ""      // no additional suffix
    );
  }

  // Bonus Daemons section (conditional display - only if any bonus daemons executed)
  if ArraySize(stats.executedBonusDaemons) > 0 {
    BNInfo("BreachStats", "│");
    let bonusCount: Int32 = ArraySize(stats.executedBonusDaemons);
    BNInfo("BreachStats", "│ Bonus Daemons (" + ToString(bonusCount) + "):");
    LogDaemonList(
      stats.executedBonusDaemons,
      stats.executedBonusDaemons,  // All bonus daemons executed by definition
      "(None)",
      false,  // no status icon - all are ✓
      false,  // no type icon
      "(auto-added)"  // suffix to indicate auto-execution
    );
  }

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

  // Radial unlock breakdown - separated by network connectivity
  // All breach types execute Radial Unlock
  // Displays pure standalone and cross-network devices separately for clarity
  BNInfo("BreachStats", "┌─ STANDALONE DEVICES (Radial Unlock) ──────────────────────┐");

  // Display range information (dynamic based on actual radial unlock range)
  if stats.radialUnlockRange > 0.0 {
    let rangeStr: String = FloatToStringPrec(stats.radialUnlockRange, 1);
    let originLabel: String = Equals(stats.originType, "NPC") ? "npc position" : "device position";
    BNInfo("BreachStats", "│ Range        : " + rangeStr + "m (from " + originLabel + ")");
  }

  let hasPureStandalone: Bool = stats.standaloneDeviceCount > 0 || stats.vehicleCount > 0 || stats.npcPureStandaloneCount > 0;
  let hasCrossNetwork: Bool = stats.crossNetworkDeviceCount > 0 || stats.npcCrossNetworkCount > 0;
  let hasAnyRadialData: Bool = hasPureStandalone || hasCrossNetwork;

  if hasAnyRadialData {
    // Pure Standalone section
    if hasPureStandalone {
      BNInfo("BreachStats", "│");
      BNInfo("BreachStats", "│ Pure Standalone:");
      LogDeviceTypeBreakdown(
        stats.standaloneDeviceCount, stats.standaloneUnlocked, stats.standaloneSkipped,
        "Devices", BNConstants.PROGRAM_UNLOCK_QUICKHACKS()
      );
      LogDeviceTypeBreakdown(
        stats.vehicleCount, stats.vehicleUnlocked, stats.vehicleSkipped,
        "Vehicles", BNConstants.PROGRAM_ACTION_BN_UNLOCK_VEHICLE()
      );
      LogDeviceTypeBreakdown(
        stats.npcPureStandaloneCount, stats.npcPureStandaloneUnlocked, stats.npcPureStandaloneSkipped,
        "NPCs", BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()
      );
    }

    // Cross-Network section
    if hasCrossNetwork {
      BNInfo("BreachStats", "│");
      BNInfo("BreachStats", "│ Cross-Network (Other Networks):");
      LogDeviceTypeBreakdown(
        stats.crossNetworkDeviceCount, stats.crossNetworkUnlocked, stats.crossNetworkSkipped,
        "Devices", BNConstants.PROGRAM_UNLOCK_QUICKHACKS()
      );
      LogDeviceTypeBreakdown(
        stats.npcCrossNetworkCount, stats.npcCrossNetworkUnlocked, stats.npcCrossNetworkSkipped,
        "NPCs", BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()
      );
    }
  } else {
    let rangeStr: String = FloatToStringPrec(stats.radialUnlockRange, 1);
    BNInfo("BreachStats", "│ (No standalone devices detected within " + rangeStr + "m radius)");
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

/*
 * Displays device unlock statistics with consistent formatting
 * - Shows ✓ icon with unlocked count if any devices were unlocked
 * - Shows ⊘ icon with skipped count if all devices were skipped
 * - Skips display if device count is 0
 *
 * ARCHITECTURE: Guard Clauses + Early Return (0-level nesting)
 *
 * @param deviceCount - Total devices of this type detected
 * @param unlockedCount - Devices successfully unlocked
 * @param skippedCount - Devices skipped (daemon not executed or conditions not met)
 * @param label - Device type label (e.g., "Basic", "Cameras", "Vehicles")
 * @param iconProgram - TweakDBID for icon lookup
 */
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
// HELPER: Generic Daemon List Logging
// ============================================================================

/*
 * Generic daemon list logging function (DRY principle)
 *
 * ARCHITECTURE: Parameterized display logic for all daemon types
 * @param daemons - Array of daemon TweakDBIDs to display
 * @param executedDaemons - Array of executed daemon TweakDBIDs (for status icons)
 * @param emptyMessage - Message to display when no daemons exist
 * @param showStatusIcon - Whether to show ✓/⊘ status icons
 * @param showIcon - Whether to show daemon type icon (🔌📷🔫👤)
 * @param additionalSuffix - Optional suffix text (e.g., "(auto-added)")
 */
private static func LogDaemonList(
  daemons: array<TweakDBID>,
  executedDaemons: array<TweakDBID>,
  emptyMessage: String,
  showStatusIcon: Bool,
  showIcon: Bool,
  additionalSuffix: String
) -> Void {
  // Guard: No daemons to display
  if ArraySize(daemons) == 0 {
    BNInfo("BreachStats", "│   " + emptyMessage);
    return;
  }

  // Display all daemons
  let i: Int32 = 0;
  while i < ArraySize(daemons) {
    let programID: TweakDBID = daemons[i];
    let daemonName: String = DaemonFilterUtils.GetDaemonDisplayName(programID);

    // Build status icon prefix
    let statusPrefix: String = "";
    if showStatusIcon {
      let wasExecuted: Bool = ArrayContains(executedDaemons, programID);
      statusPrefix = wasExecuted ? "✓ " : "⊘ ";
    } else {
      statusPrefix = "✓ ";
    }

    // Build type icon (Subnet only)
    let iconStr: String = "";
    if showIcon {
      iconStr = GetSubnetDaemonIcon(programID) + " ";
    }

    // Build suffix
    let suffix: String = NotEquals(additionalSuffix, "") ? " " + additionalSuffix : "";

    BNInfo("BreachStats", "│   " + statusPrefix + iconStr + daemonName + " (" + TDBID.ToStringDEBUG(programID) + ")" + suffix);
    i += 1;
  }
}

// ============================================================================
// HELPER: Get Subnet Daemon Icon
// ============================================================================

/*
 * Returns appropriate icon for subnet daemon type
 * Maps TweakDBID to icon (🔌 Basic, 📷 Camera, 🔫 Turret, 👤 NPC)
 *
 * ARCHITECTURE: Simple lookup table
 *
 * @param programID - Daemon TweakDBID
 * @return Icon string
 */
private static func GetSubnetDaemonIcon(programID: TweakDBID) -> String {
  // Basic Subnet (AccessPoint/UnconsciousNPC Breach + RemoteBreach variants)
  if Equals(programID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS())
      || Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_BASIC()) {
    return "🔌";
  }
  // Camera Subnet
  else if Equals(programID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS())
      || Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_CAMERA()) {
    return "📷";
  }
  // Turret Subnet
  else if Equals(programID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS())
      || Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_TURRET()) {
    return "🔫";
  }
  // NPC Subnet
  else if Equals(programID, BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS())
      || Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_NPC()) {
    return "👤";
  }
  // Vehicle (treated same as Basic devices - difficulty-independent)
  else if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_VEHICLE()) {
    return "🚗";
  }
  // Fallback: no icon
  else {
    return "";
  }
}
