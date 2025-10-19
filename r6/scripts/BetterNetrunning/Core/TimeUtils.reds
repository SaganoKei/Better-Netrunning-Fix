// ============================================================================
// Time Utilities
// ============================================================================
//
// PURPOSE:
// Centralized timestamp management for Better Netrunning mod
//
// FUNCTIONALITY:
// - GetCurrentTimestamp(): Unified timestamp retrieval
// - SetDeviceUnlockTimestamp(): Type-safe device unlock timestamp setting
//
// ARCHITECTURE:
// - Static utility class (no instantiation required)
// - Used by: DaemonImplementation, BreachProcessing, RemoteBreachSystem, etc.
//
// RATIONALE:
// - DRY Principle: Eliminates 13+ duplicate timestamp retrieval patterns
// - Maintainability: Single point of change for timestamp logic
// - Testability: Static methods enable easy unit testing
// ============================================================================

module BetterNetrunning.Core

// ==================== Time Utilities ====================

public abstract class TimeUtils {

    // Get current game timestamp
    // Replaces scattered "let timeSystem: ref<TimeSystem> = GameInstance.GetTimeSystem(gi); timeSystem.GetGameTimeStamp()"
    public static func GetCurrentTimestamp(gameInstance: GameInstance) -> Float {
        let timeSystem: ref<TimeSystem> = GameInstance.GetTimeSystem(gameInstance);
        return timeSystem.GetGameTimeStamp();
    }

    // Set unlock timestamp for device based on device type
    // Centralized logic to avoid switch statement duplication
    public static func SetDeviceUnlockTimestamp(
        sharedPS: ref<SharedGameplayPS>,
        deviceType: DeviceType,
        timestamp: Float
    ) -> Void {
        switch deviceType {
            case DeviceType.NPC:
                sharedPS.m_betterNetrunningUnlockTimestampNPCs = timestamp;
                break;
            case DeviceType.Camera:
                sharedPS.m_betterNetrunningUnlockTimestampCameras = timestamp;
                break;
            case DeviceType.Turret:
                sharedPS.m_betterNetrunningUnlockTimestampTurrets = timestamp;
                break;
            default: // DeviceType.Basic
                sharedPS.m_betterNetrunningUnlockTimestampBasic = timestamp;
                break;
        }
    }
}
