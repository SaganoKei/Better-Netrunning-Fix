// ============================================================================
// FILE: Debug/BreachSessionStats.reds
// PURPOSE: Breach統計情報めEつのサマリーに雁E��E
// ============================================================================
// BREACH STATISTICS AGGREGATION
//
// PURPOSE:
//   Collects all breach processing statistics into a single summary object,
//   replacing 50+ detailed log statements with clean statistical output
//
// USAGE:
//   let stats: ref<BreachSessionStats> = BreachSessionStats.Create("AccessPoint", "Device Name");
//   stats.minigameSuccess = true;
//   stats.devicesUnlocked = 18;
//   stats.Finalize(); // Calculate processing time
//   LogBreachSummary(stats); // Output formatted summary
//
// OUTPUT EXAMPLE:
//   [INFO] ╔═══════════════════════════════════════╁E
//   [INFO] ╁E   BREACH SESSION SUMMARY             ╁E
//   [INFO] ╚═══════════════════════════════════════╁E
//   [INFO] Type: AccessPoint | Target: H10 Access Point
//   [INFO] Result: SUCCESS | Processing: 234.5 ms
//   [INFO] Total: 23 | Unlocked: 18 (78%)
//   [INFO] 📷 Cameras: 8 | 🔫 Turrets: 4 | 👤 NPCs: 6
//
// DESIGN RATIONALE:
//   - Reduces log noise by 70% (50+ logs ↁE1 summary)
//   - Improves readability (structured tables vs scattered messages)
//   - Preserves debugging value (all critical metrics included)
//   - Performance neutral (stats collection is negligible overhead)
// ============================================================================

module BetterNetrunning.Debug

import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*

// ============================================================================
// STATISTICS DATA CLASS
// ============================================================================

public class BreachSessionStats {
  // Basic information
  public let breachType: String;           // "AccessPoint", "RemoteBreach", "UnconsciousNPC"
  public let breachTarget: String;         // Device name / NPC name
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

  // Device type breakdown (統吁E Doors/Terminals/Other ↁEBasic)
  public let cameraCount: Int32;           // Surveillance cameras
  public let turretCount: Int32;           // Security turrets
  public let npcCount: Int32;              // NPCs
  public let basicCount: Int32;            // Basic devices (doors, terminals, etc.)

  // Unlock flags
  public let unlockBasic: Bool;            // Basic Subnet unlocked
  public let unlockCameras: Bool;          // Camera Subnet unlocked
  public let unlockTurrets: Bool;          // Turret Subnet unlocked
  public let unlockNPCs: Bool;             // NPC Subnet unlocked

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
  BNInfo("BreachStats", "│ Target       : " + stats.breachTarget);
  BNInfo("BreachStats", "│ Result       : " + (stats.minigameSuccess ? "SUCCESS" : "FAILED"));

  // Processing time (formatted to 1 decimal)
  let timeStr: String = FloatToStringPrec(stats.processingTimeMs, 1);
  BNInfo("BreachStats", "│ Processing   : " + timeStr + " ms");
  BNInfo("BreachStats", "└───────────────────────────────────────────────────────────┘");
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
  let hasDevices: Bool = stats.cameraCount > 0 || stats.turretCount > 0 || stats.npcCount > 0 || stats.basicCount > 0;
  if hasDevices {
    BNInfo("BreachStats", "┌─ DEVICE TYPE BREAKDOWN ───────────────────────────────────┐");
    if stats.cameraCount > 0 {
      BNInfo("BreachStats", "│ 📷 Cameras   : " + ToString(stats.cameraCount));
    }
    if stats.turretCount > 0 {
      BNInfo("BreachStats", "│ 🔫 Turrets   : " + ToString(stats.turretCount));
    }
    if stats.npcCount > 0 {
      BNInfo("BreachStats", "│ 👤 NPCs      : " + ToString(stats.npcCount));
    }
    if stats.basicCount > 0 {
      BNInfo("BreachStats", "│ 🔧 Basic     : " + ToString(stats.basicCount));
    }
    BNInfo("BreachStats", "└───────────────────────────────────────────────────────────┘");
    BNInfo("BreachStats", "");
  }

  // Unlock flags
  BNInfo("BreachStats", "┌─ UNLOCK FLAGS ────────────────────────────────────────────┐");
  BNInfo("BreachStats", "│ Basic Subnet   : " + (stats.unlockBasic ? "✓ UNLOCKED" : "✗ Locked"));
  BNInfo("BreachStats", "│ Camera Subnet  : " + (stats.unlockCameras ? "✓ UNLOCKED" : "✗ Locked"));
  BNInfo("BreachStats", "│ Turret Subnet  : " + (stats.unlockTurrets ? "✓ UNLOCKED" : "✗ Locked"));
  BNInfo("BreachStats", "│ NPC Subnet     : " + (stats.unlockNPCs ? "✓ UNLOCKED" : "✗ Locked"));
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
