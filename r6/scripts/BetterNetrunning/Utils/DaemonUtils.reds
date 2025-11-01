// ============================================================================
// BetterNetrunning - Daemon Utilities
// ============================================================================
// Device type detection, daemon classification, and network connectivity checks
// ============================================================================

module BetterNetrunning.Utils

import BetterNetrunning.Core.*

public abstract class DaemonFilterUtils {

    // ===================================
    // Device Type Detection
    // ===================================

    /*
     * @param devicePS - Device power state
     * @return true if device is a surveillance camera
     */
    public static func IsCamera(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return IsDefined(devicePS as SurveillanceCameraControllerPS);
    }

    /*
     * @param devicePS - Device power state
     * @return true if device is a security turret
     */
    public static func IsTurret(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return IsDefined(devicePS as SecurityTurretControllerPS);
    }

    /*
     * @param devicePS - Device power state
     * @return true if device is a computer/terminal
     */
    public static func IsComputer(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return IsDefined(devicePS as ComputerControllerPS);
    }

    /*
     * @param entity - Game object to check
     * @return true if regular device (not AccessPoint, not Computer)
     */
    public static func IsRegularDevice(entity: wref<GameObject>) -> Bool {
        return IsDefined(entity as Device)
            && !IsDefined(entity as AccessPoint)
            && !IsDefined((entity as Device).GetDevicePS() as ComputerControllerPS);
    }

    // ===================================
    // Network Connection Check
    // ===================================

    /*
     * @param entity - Game object to check
     * @return true if connected to network
     */
    public static func IsConnectedToNetwork(entity: wref<GameObject>) -> Bool {
        // Regular devices (not AccessPoint, not Computer) are considered connected
        if DaemonFilterUtils.IsRegularDevice(entity) {
            return true;
        }
        return false;
    }

    /*
     * @param devicePS - Device power state to check
     * @return true if connected to physical access point
     */
    public static func IsConnectedToPhysicalAccessPoint(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return devicePS.IsConnectedToPhysicalAccessPoint();
    }

    // ===================================
    // Daemon Type Detection
    // ===================================

    /*
     * @param actionID - TweakDB ID of the daemon action
     * @return true if this is the camera unlock daemon
     */
    public static func IsCameraDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS());
    }

    /*
     * @param actionID - TweakDB ID of the daemon action
     * @return true if this is the turret unlock daemon
     */
    public static func IsTurretDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS());
    }

    /*
     * @param actionID - TweakDB ID of the daemon action
     * @return true if this is the NPC unlock daemon
     */
    public static func IsNPCDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS());
    }

    /*
     * @param actionID - TweakDB ID of the daemon action
     * @return true if this is the basic unlock daemon
     */
    public static func IsBasicDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, BNConstants.PROGRAM_NETWORK_DEVICE_BASIC_ACTIONS());
    }

    /*
     * @param actionID - TweakDB ID of the daemon action
     * @return true if this is any unlock daemon (Camera/Turret/NPC/Basic)
     */
    public static func IsUnlockDaemon(actionID: TweakDBID) -> Bool {
        return DaemonFilterUtils.IsCameraDaemon(actionID)
            || DaemonFilterUtils.IsTurretDaemon(actionID)
            || DaemonFilterUtils.IsNPCDaemon(actionID)
            || DaemonFilterUtils.IsBasicDaemon(actionID);
    }

    // ===================================
    // Unlock Flags Extraction
    // ===================================

    /*
     * Extract unlock flags from minigame programs array
     *
     * @param minigamePrograms - Array of TweakDB IDs for injected programs
     * @return BreachUnlockFlags struct with flags for Basic/NPC/Camera/Turret
     */
    public static func ExtractUnlockFlags(minigamePrograms: array<TweakDBID>) -> BreachUnlockFlags {
        let flags: BreachUnlockFlags;

        let i: Int32 = 0;
        while i < ArraySize(minigamePrograms) {
            let programID: TweakDBID = minigamePrograms[i];

            // AccessPoint/UnconsciousNPC Breach programs
            if Equals(programID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS()) {
                flags.unlockBasic = true;
            } else if Equals(programID, BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()) {
                flags.unlockNPCs = true;
            } else if Equals(programID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()) {
                flags.unlockCameras = true;
            } else if Equals(programID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()) {
                flags.unlockTurrets = true;
            }
            // RemoteBreach programs (BN_RemoteBreach_* series)
            else if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_BASIC()) {
                flags.unlockBasic = true;
            } else if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_NPC()) {
                flags.unlockNPCs = true;
            } else if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_CAMERA()) {
                flags.unlockCameras = true;
            } else if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_TURRET()) {
                flags.unlockTurrets = true;
            }

            i += 1;
        }

        return flags;
    }

    // ===================================
    // Device Capability Check
    // ===================================

    /*
     * @param devicePS - Device power state
     * @param data - Connected device class types
     * @return true if Camera daemon should be visible
     */
    public static func ShouldShowCameraDaemon(
        devicePS: ref<ScriptableDeviceComponentPS>,
        data: ConnectedClassTypes
    ) -> Bool {
        return DaemonFilterUtils.IsCamera(devicePS) || data.surveillanceCamera;
    }

    /*
     * @param devicePS - Device power state
     * @param data - Connected device class types
     * @return true if Turret daemon should be visible
     */
    public static func ShouldShowTurretDaemon(
        devicePS: ref<ScriptableDeviceComponentPS>,
        data: ConnectedClassTypes
    ) -> Bool {
        return DaemonFilterUtils.IsTurret(devicePS) || data.securityTurret;
    }

    /*
     * @param data - Connected device class types
     * @return true if NPC daemon should be visible
     */
    public static func ShouldShowNPCDaemon(data: ConnectedClassTypes) -> Bool {
        return data.puppet;
    }

    // ===================================
    // Utility Helpers
    // ===================================

    /*
     * @param devicePS - Device power state
     * @return Device type name (Camera/Turret/Computer/Device)
     */
    public static func GetDeviceTypeName(devicePS: ref<ScriptableDeviceComponentPS>) -> String {
        if DaemonFilterUtils.IsCamera(devicePS) {
            return "Camera";
        } else if DaemonFilterUtils.IsTurret(devicePS) {
            return "Turret";
        } else if DaemonFilterUtils.IsComputer(devicePS) {
            return "Computer";
        } else {
            return "Device";
        }
    }

    /*
     * @param actionID - TweakDB ID of the daemon action
     * @return Daemon type name (Camera/Turret/NPC/Basic/Unknown)
     */
    public static func GetDaemonTypeName(actionID: TweakDBID) -> String {
        if DaemonFilterUtils.IsCameraDaemon(actionID) {
            return "Camera";
        } else if DaemonFilterUtils.IsTurretDaemon(actionID) {
            return "Turret";
        } else if DaemonFilterUtils.IsNPCDaemon(actionID) {
            return "NPC";
        } else if DaemonFilterUtils.IsBasicDaemon(actionID) {
            return "Basic";
        } else {
            return "Unknown";
        }
    }

    // ===================================
    // Daemon Classification Helpers
    // ===================================

    /*
     * @param programID - TweakDB ID of the program
     * @return true if program is a Subnet Daemon (Basic/Camera/Turret/NPC)
     */
    public static func IsSubnetDaemon(programID: TweakDBID) -> Bool {
        if Equals(programID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()) { return true; }

        if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_BASIC()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_CAMERA()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_TURRET()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_NPC()) { return true; }

        return false;
    }

    /*
     * Get human-readable daemon name (localized via TweakDB)
     *
     * @param programID - TweakDB ID of the program
     * @return Localized display name from TweakDB
     */
    public static func GetDaemonDisplayName(programID: TweakDBID) -> String {
        let record: ref<ObjectAction_Record> = TweakDBInterface.GetObjectActionRecord(programID);
        if !IsDefined(record) {
            return TDBID.ToStringDEBUG(programID);
        }

        return GetLocalizedTextByKey(record.ObjectActionUI().Caption());
    }
}
