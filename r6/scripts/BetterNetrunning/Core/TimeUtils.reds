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
// - Single point of change for timestamp logic
// - Used by: DaemonImplementation, BreachProcessing, RemoteBreachSystem, etc.
//

module BetterNetrunning.Core

import BetterNetrunning.Core.*

public abstract class TimeUtils {

    /*
     * Get current game timestamp
     * @param gameInstance - Current game instance
     * @return Current game timestamp as Float
     */
    public static func GetCurrentTimestamp(gameInstance: GameInstance) -> Float {
        let timeSystem: ref<TimeSystem> = GameInstance.GetTimeSystem(gameInstance);
        return timeSystem.GetGameTimeStamp();
    }

    /*
     * Set unlock timestamp for device based on device type
     * @param sharedPS - Shared gameplay persistent state
     * @param TargetType - Type of device being unlocked
     * @param timestamp - Timestamp to set
     */
    public static func SetDeviceUnlockTimestamp(
        sharedPS: ref<SharedGameplayPS>,
        TargetType: TargetType,
        timestamp: Float
    ) -> Void {
        switch TargetType {
            case TargetType.NPC:
                sharedPS.m_betterNetrunningUnlockTimestampNPCs = timestamp;
                break;
            case TargetType.Camera:
                sharedPS.m_betterNetrunningUnlockTimestampCameras = timestamp;
                break;
            case TargetType.Turret:
                sharedPS.m_betterNetrunningUnlockTimestampTurrets = timestamp;
                break;
            default: // TargetType.Basic
                sharedPS.m_betterNetrunningUnlockTimestampBasic = timestamp;
                break;
        }
    }
}
