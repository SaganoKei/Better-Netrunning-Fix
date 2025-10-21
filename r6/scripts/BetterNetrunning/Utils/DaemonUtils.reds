// ============================================================================
// BetterNetrunning - Common Daemon Filter Utilities
// ============================================================================
// Shared logic for device type detection, daemon identification, and
// network connectivity checks used by both AccessPointBreach and RemoteBreach
// ============================================================================

module BetterNetrunning.Utils

import BetterNetrunning.Core.*

// ============================================================================
// DaemonFilterUtils - Common filtering utilities for daemon display logic
// ============================================================================
public abstract class DaemonFilterUtils {

    // ========================================================================
    // DEVICE TYPE DETECTION
    // ========================================================================

    /// Check if device is a surveillance camera
    /// @param devicePS Device power state to check
    /// @return true if device is a camera, false otherwise
    public static func IsCamera(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return IsDefined(devicePS as SurveillanceCameraControllerPS);
    }

    /// Check if device is a security turret
    /// @param devicePS Device power state to check
    /// @return true if device is a turret, false otherwise
    public static func IsTurret(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return IsDefined(devicePS as SecurityTurretControllerPS);
    }

    /// Check if device is a computer/terminal
    /// @param devicePS Device power state to check
    /// @return true if device is a computer, false otherwise
    public static func IsComputer(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return IsDefined(devicePS as ComputerControllerPS);
    }

    /// Check if entity is a regular device (not AccessPoint, not Computer)
    /// @param entity Game object to check
    /// @return true if entity is a regular hackable device
    public static func IsRegularDevice(entity: wref<GameObject>) -> Bool {
        return IsDefined(entity as Device)
            && !IsDefined(entity as AccessPoint)
            && !IsDefined((entity as Device).GetDevicePS() as ComputerControllerPS);
    }

    // ========================================================================
    // NETWORK CONNECTION CHECK
    // ========================================================================

    /// Check if entity is connected to an access point network
    /// @param entity Game object to check
    /// @return true if connected to network, false otherwise
    public static func IsConnectedToNetwork(entity: wref<GameObject>) -> Bool {
        // Regular devices (not AccessPoint, not Computer) are considered connected
        if DaemonFilterUtils.IsRegularDevice(entity) {
            return true;
        }
        return false;
    }

    /// Check if device is connected to physical access point
    /// (Delegates to device's native method)
    /// @param devicePS Device power state to check
    /// @return true if connected to physical access point
    public static func IsConnectedToPhysicalAccessPoint(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return devicePS.IsConnectedToPhysicalAccessPoint();
    }

    // ========================================================================
    // DAEMON TYPE DETECTION
    // ========================================================================

    /// Check if action is a Camera unlock daemon
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is the camera unlock daemon
    public static func IsCameraDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS());
    }

    /// Check if action is a Turret unlock daemon
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is the turret unlock daemon
    public static func IsTurretDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS());
    }

    /// Check if action is an NPC unlock daemon
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is the NPC unlock daemon
    public static func IsNPCDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS());
    }

    /// Check if action is a Basic device unlock daemon
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is the basic unlock daemon
    public static func IsBasicDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, BNConstants.PROGRAM_NETWORK_DEVICE_BASIC_ACTIONS());
    }

    /// Check if action is any unlock daemon type
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is any unlock daemon (Camera/Turret/NPC/Basic)
    public static func IsUnlockDaemon(actionID: TweakDBID) -> Bool {
        return DaemonFilterUtils.IsCameraDaemon(actionID)
            || DaemonFilterUtils.IsTurretDaemon(actionID)
            || DaemonFilterUtils.IsNPCDaemon(actionID)
            || DaemonFilterUtils.IsBasicDaemon(actionID);
    }

    // ========================================================================
    // UNLOCK FLAGS EXTRACTION
    // ========================================================================

    /// Extract unlock flags from minigame programs array
    /// Parses daemon program IDs to determine which device types should be unlocked
    /// Used by both AccessPoint breach and RemoteBreach for consistent flag parsing
    /// @param minigamePrograms Array of TweakDB IDs for injected programs
    /// @return BreachUnlockFlags struct with flags for Basic/NPC/Camera/Turret
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

    // ========================================================================
    // DEVICE CAPABILITY CHECK (for daemon display logic)
    // ========================================================================

    /// Determine if Camera daemon should be shown for this device
    /// @param devicePS Device power state
    /// @param data Connected device class types
    /// @return true if Camera daemon should be visible
    public static func ShouldShowCameraDaemon(
        devicePS: ref<ScriptableDeviceComponentPS>,
        data: ConnectedClassTypes
    ) -> Bool {
        // Show Camera daemon if:
        // 1. Device IS a camera, OR
        // 2. Device has cameras in network
        return DaemonFilterUtils.IsCamera(devicePS) || data.surveillanceCamera;
    }

    /// Determine if Turret daemon should be shown for this device
    /// @param devicePS Device power state
    /// @param data Connected device class types
    /// @return true if Turret daemon should be visible
    public static func ShouldShowTurretDaemon(
        devicePS: ref<ScriptableDeviceComponentPS>,
        data: ConnectedClassTypes
    ) -> Bool {
        // Show Turret daemon if:
        // 1. Device IS a turret, OR
        // 2. Device has turrets in network
        return DaemonFilterUtils.IsTurret(devicePS) || data.securityTurret;
    }

    /// Determine if NPC daemon should be shown for this device
    /// @param data Connected device class types
    /// @return true if NPC daemon should be visible
    public static func ShouldShowNPCDaemon(data: ConnectedClassTypes) -> Bool {
        // Show NPC daemon if device has NPCs in network
        return data.puppet;
    }

    // ========================================================================
    // UTILITY HELPERS
    // ========================================================================

    /// Get device type as string for logging/debugging
    /// @param devicePS Device power state
    /// @return Device type name (Camera/Turret/Computer/Device)
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

    /// Get daemon type as string for logging/debugging
    /// @param actionID TweakDB ID of the daemon action
    /// @return Daemon type name (Camera/Turret/NPC/Basic/Unknown)
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

    // ========================================================================
    // DAEMON CLASSIFICATION HELPERS (for executed daemon display)
    // ========================================================================

    /// Check if program is a Subnet Daemon (Basic/Camera/Turret/NPC)
    /// Used for EXECUTED DAEMONS display section
    public static func IsSubnetDaemon(programID: TweakDBID) -> Bool {
        // AccessPoint/UnconsciousNPC Breach subnet daemons
        if Equals(programID, BNConstants.PROGRAM_UNLOCK_QUICKHACKS()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS()) { return true; }

        // RemoteBreach subnet daemons (BN_RemoteBreach_* series)
        if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_BASIC()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_CAMERA()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_TURRET()) { return true; }
        if Equals(programID, BNConstants.PROGRAM_ACTION_BN_UNLOCK_NPC()) { return true; }

        return false;
    }

    /// Get human-readable daemon name (localized via TweakDB)
    ///
    /// FUNCTIONALITY:
    /// - Retrieves localized display name from TweakDB ObjectAction records
    /// - Supports all daemon types: vanilla, BN-specific, mod-added
    /// - Automatic language support (uses user's game language)
    ///
    /// ARCHITECTURE:
    /// - TweakDBInterface API for dynamic name resolution
    /// - Fallback to TweakDBID string if record not found
    /// - Zero maintenance (new daemons work automatically)
    public static func GetDaemonDisplayName(programID: TweakDBID) -> String {
        // Retrieve TweakDB record for this program
        let record: ref<ObjectAction_Record> = TweakDBInterface.GetObjectActionRecord(programID);
        if !IsDefined(record) {
            return TDBID.ToStringDEBUG(programID);
        }

        // Get localized display name directly from record (CName → String via GetLocalizedTextByKey)
        return GetLocalizedTextByKey(record.ObjectActionUI().Caption());
    }
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================
/*
// Example 1: Device type detection (replaces IsDefined checks)
let devicePS: ref<ScriptableDeviceComponentPS> = ...;
if DaemonFilterUtils.IsCamera(devicePS) {
    // Camera-specific logic
}

// Example 2: Daemon type identification
let actionID: TweakDBID = BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS();
if DaemonFilterUtils.IsCameraDaemon(actionID) {
    // Camera daemon-specific logic
}

// Example 3: Network connectivity check
let entity: wref<GameObject> = ...;
if DaemonFilterUtils.IsConnectedToNetwork(entity) {
    // Network-dependent logic
}

// Example 4: Should show daemon logic
let data: ConnectedClassTypes = ...;
if DaemonFilterUtils.ShouldShowCameraDaemon(devicePS, data) {
    // Show Camera daemon in UI
}

// Example 5: Logging with device type name
let deviceType: String = DaemonFilterUtils.GetDeviceTypeName(devicePS);
BNDebug("DaemonUtils", "Device type: " + deviceType);
*/