module BetterNetrunningConfig

public class BetterNetrunningSettings {

    // !!! WARNING !!!
    // If using Native Settings UI, the values in this file will have no effect.

    // Controls
    public static func BreachingHotkey() -> String { return "Choice3"; }

    // Breaching
    public static func EnableClassicMode() -> Bool { return false; }
    public static func AllowBreachingUnconsciousNPCs() -> Bool { return true; }
    public static func QuickhackUnlockDurationHours() -> Int32 { return 6; }

    // RemoteBreach
    public static func RemoteBreachEnabledDevice() -> Bool { return true; }
    public static func RemoteBreachEnabledComputer() -> Bool { return true; }
    public static func RemoteBreachEnabledCamera() -> Bool { return true; }
    public static func RemoteBreachEnabledTurret() -> Bool { return true; }
    public static func RemoteBreachEnabledVehicle() -> Bool { return true; }
    public static func RemoteBreachRAMCostPercent() -> Int32 { return 50; }

    // Breach Failure Penalty
    public static func BreachFailurePenaltyEnabled() -> Bool { return true; }
    public static func RemoteBreachLockDurationMinutes() -> Int32 { return 10; }

    // Access Points
    public static func UnlockIfNoAccessPoint() -> Bool { return false; }
    public static func AutoDatamineBySuccessCount() -> Bool { return true; }
    public static func AutoExecutePingOnSuccess() -> Bool { return true; }

    // Always Unlocked Quickhacks
    public static func AlwaysAllowPing() -> Bool { return true; }
    public static func AlwaysAllowWhistle() -> Bool { return false; }
    public static func AlwaysAllowDistract() -> Bool { return false; }
    public static func AlwaysBasicDevices() -> Bool { return false; }
    public static func AlwaysCameras() -> Bool { return false; }
    public static func AlwaysTurrets() -> Bool { return false; }
    public static func AlwaysNPCsCovert() -> Bool { return false; }
    public static func AlwaysNPCsCombat() -> Bool { return false; }
    public static func AlwaysNPCsControl() -> Bool { return false; }
    public static func AlwaysNPCsUltimate() -> Bool { return false; }

    // Progression
    public static func ProgressionRequireAll() -> Bool { return true; }
    public static func ProgressionCyberdeckEnabled() -> Bool { return false; }
    public static func ProgressionIntelligenceEnabled() -> Bool { return false; }
    public static func ProgressionEnemyRarityEnabled() -> Bool { return false; }

    // Progression - Cyberdeck
    public static func ProgressionCyberdeckBasicDevices() -> Int32 { return 1; }
    public static func ProgressionCyberdeckCameras() -> Int32 { return 1; }
    public static func ProgressionCyberdeckTurrets() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsCovert() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsCombat() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsControl() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsUltimate() -> Int32 { return 1; }

    // Progression - Intelligence
    public static func ProgressionIntelligenceBasicDevices() -> Int32 { return 3; }
    public static func ProgressionIntelligenceCameras() -> Int32 { return 3; }
    public static func ProgressionIntelligenceTurrets() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsCovert() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsCombat() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsControl() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsUltimate() -> Int32 { return 3; }

    // Progression - Enemy Rarity
    public static func ProgressionEnemyRarityNPCsCovert() -> Int32 { return 8; }
    public static func ProgressionEnemyRarityNPCsCombat() -> Int32 { return 8; }
    public static func ProgressionEnemyRarityNPCsControl() -> Int32 { return 8; }
    public static func ProgressionEnemyRarityNPCsUltimate() -> Int32 { return 8; }

    // Debug
    public static func EnableDebugLog() -> Bool { return false; }
    public static func DebugLogLevel() -> Int32 { return 2; } // 0=ERROR, 1=WARNING, 2=INFO (default), 3=DEBUG, 4=TRACE
}