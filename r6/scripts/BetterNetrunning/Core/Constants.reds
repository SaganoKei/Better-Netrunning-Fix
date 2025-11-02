// ============================================================================
// BetterNetrunning Constants - Centralized String Literal Management
// ============================================================================
//
// PURPOSE:
// - Single source of truth for class names, action names, and other constants
// - Prevents typos and inconsistencies across modules
// - Enables easy refactoring (rename in one place, changes everywhere)
// - Self-documenting code (METHOD_NAME instead of magic strings)
//
// DESIGN PRINCIPLES:
// - All methods are static (no instantiation needed)
// - Returns CName for REDscript compatibility
// - Organized by category (Class Names, Action Names, Daemon Types, etc.)
//
// USAGE EXAMPLES:
//   if Equals(className, BNConstants.CLASS_REMOTE_BREACH_COMPUTER()) { ... }
//   let actionName: CName = BNConstants.ACTION_REMOTE_BREACH();
//   if BNConstants.IsRemoteBreachAction(className) { ... }
//
// MAINTENANCE:
// - When adding new RemoteBreach types: Add constant + update IsRemoteBreachAction()
// - When renaming classes: Update constant value (all references update automatically)
// ============================================================================

module BetterNetrunning.Core

public abstract class BNConstants {

  // ==================== RemoteBreach Action Class Names ====================
  //
  // Fully qualified class names for RemoteBreach actions.
  // CRITICAL: Must use complete module path (n"Module.Path.ClassName")
  // Short names (n"ClassName") do NOT work for cross-module references.
  //
  // Module: BetterNetrunning.RemoteBreach.Actions
  // See: RemoteBreach/Actions/RemoteBreachAction_*.reds for class definitions
  // ========================================================================

  // Computer RemoteBreach (AccessPoint, Laptop)
  public static func CLASS_REMOTE_BREACH_COMPUTER() -> CName {
    return n"BetterNetrunning.RemoteBreach.Actions.RemoteBreachAction";
  }

  // Device RemoteBreach (Door, Camera, Turret, generic devices)
  public static func CLASS_REMOTE_BREACH_DEVICE() -> CName {
    return n"BetterNetrunning.RemoteBreach.Actions.DeviceRemoteBreachAction";
  }

  // Vehicle RemoteBreach
  public static func CLASS_REMOTE_BREACH_VEHICLE() -> CName {
    return n"BetterNetrunning.RemoteBreach.Actions.VehicleRemoteBreachAction";
  }

  // ==================== ScriptableSystem Class Names ====================
  //
  // Fully qualified class names for BetterNetrunning ScriptableSystems.
  // CRITICAL: Must match exact module path used in system registration
  // Used with GameInstance.GetScriptableSystemsContainer().Get()
  //
  // See: RemoteBreach/Core/RemoteBreachStateSystem.reds for system definitions
  // ========================================================================

  // Computer RemoteBreach state tracking (AccessPoint, Laptop)
  public static func CLASS_REMOTE_BREACH_STATE_SYSTEM() -> CName {
    return n"BetterNetrunning.RemoteBreach.Core.RemoteBreachStateSystem";
  }

  // Device RemoteBreach state tracking (Door, Camera, Turret, generic devices)
  public static func CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM() -> CName {
    return n"BetterNetrunning.RemoteBreach.Core.DeviceRemoteBreachStateSystem";
  }

  // Vehicle RemoteBreach state tracking
  public static func CLASS_VEHICLE_REMOTE_BREACH_STATE_SYSTEM() -> CName {
    return n"BetterNetrunning.RemoteBreach.Core.VehicleRemoteBreachStateSystem";
  }

  // DisplayedDaemons state tracking (stores FilterPlayerPrograms output)
  public static func CLASS_DISPLAYED_DAEMONS_STATE_SYSTEM() -> CName {
    return n"BetterNetrunning.Logging.DisplayedDaemonsStateSystem";
  }

  // HackingExtensions CustomHackingSystem (external dependency)
  public static func CLASS_CUSTOM_HACKING_SYSTEM() -> CName {
    return n"HackingExtensions.CustomHackingSystem";
  }

  // ==================== Action Names ====================
  //
  // CName identifiers for QuickHack actions and events
  // ========================================================================

  public static func ACTION_REMOTE_BREACH() -> CName {
    return n"RemoteBreach";
  }

  public static func ACTION_SET_BREACHED_SUBNET() -> CName {
    return n"SetBreachedSubnet";
  }

  public static func ACTION_PING_DEVICE() -> CName {
    return n"PingDevice";
  }

  public static func ACTION_DISTRACTION() -> CName {
    return n"QuickHackDistraction";
  }

  // ==================== Vanilla Breach Action Names ====================
  //
  // These are vanilla game actions, not BetterNetrunning-specific
  // Used in NPCLifecycle.reds for breach action detection
  // ========================================================================

  public static func ACTION_PHYSICAL_BREACH() -> CName {
    return n"PhysicalBreach";
  }

  public static func ACTION_SUICIDE_BREACH() -> CName {
    return n"SuicideBreach";
  }

  public static func ACTION_UNCONSCIOUS_BREACH() -> CName {
    return n"BreachUnconsciousOfficer";
  }

  // ==================== Localization Keys ====================
  //
  // LocKey identifiers for UI text
  // ========================================================================

  public static func LOCKEY_QUICKHACKS_LOCKED() -> CName {
    return n"Better-Netrunning-Quickhacks-Locked";
  }

  public static func LOCKEY_NO_NETWORK_ACCESS() -> String {
    return "LocKey#7021";
  }

  public static func LOCKEY_ACTIVATE_NETWORK_DEVICE() -> String {
    return "LocKey#49279";
  }

  public static func LOCKEY_NOT_POWERED() -> String {
    return "LocKey#7013";
  }

  public static func LOCKEY_ACCESS() -> CName {
    return n"LocKey#34844";
  }

  public static func LOCKEY_RAM_INSUFFICIENT() -> String {
    return "LocKey#27398";
  }

  // ==================== Device Localization ====================
  //
  // Localization prefixes for device name cleanup
  // ========================================================================

  public static func DEVICE_NAME_PREFIX() -> String {
    return "Gameplay-Devices-DisplayNames-";
  }

  // ==================== TweakDB IDs ====================
  //
  // TweakDB record identifiers for game data (Daemon Programs, Minigame Difficulty, etc.)
  // Organized by category: MinigameAction, MinigameProgramAction, Minigame, DeviceAction
  // ========================================================================

  // ----- Daemon Program Actions (MinigameAction.*) -----
  // These define which daemon programs appear in the breach minigame
  // and what they unlock when successfully executed.

  // Core unlock programs (high frequency - 10+ usage locations each)
  public static func PROGRAM_UNLOCK_QUICKHACKS() -> TweakDBID {
    return t"MinigameAction.UnlockQuickhacks";
  }

  public static func PROGRAM_UNLOCK_NPC_QUICKHACKS() -> TweakDBID {
    return t"MinigameAction.UnlockNPCQuickhacks";
  }

  public static func PROGRAM_UNLOCK_CAMERA_QUICKHACKS() -> TweakDBID {
    return t"MinigameAction.UnlockCameraQuickhacks";
  }

  public static func PROGRAM_UNLOCK_TURRET_QUICKHACKS() -> TweakDBID {
    return t"MinigameAction.UnlockTurretQuickhacks";
  }

  // Auto-execution programs (medium frequency - 5+ usage locations)
  public static func PROGRAM_DATAMINE_BASIC() -> TweakDBID {
    return t"MinigameAction.NetworkDataMineLootAll";
  }

  public static func PROGRAM_DATAMINE_ADVANCED() -> TweakDBID {
    return t"MinigameAction.NetworkDataMineLootAllAdvanced";
  }

  public static func PROGRAM_DATAMINE_MASTER() -> TweakDBID {
    return t"MinigameAction.NetworkDataMineLootAllMaster";
  }

  // Basic device actions
  public static func PROGRAM_NETWORK_DEVICE_BASIC_ACTIONS() -> TweakDBID {
    return t"MinigameAction.NetworkDeviceBasicActions";
  }

  // ----- Custom BN RemoteBreach Programs (MinigameProgramAction.*) -----
  // BetterNetrunning-specific daemon programs registered via CET

  public static func PROGRAM_ACTION_BN_UNLOCK_BASIC() -> TweakDBID {
    return t"MinigameProgramAction.BN_RemoteBreach_UnlockBasic";
  }

  public static func PROGRAM_ACTION_BN_UNLOCK_NPC() -> TweakDBID {
    return t"MinigameProgramAction.BN_RemoteBreach_UnlockNPC";
  }

  public static func PROGRAM_ACTION_BN_UNLOCK_CAMERA() -> TweakDBID {
    return t"MinigameProgramAction.BN_RemoteBreach_UnlockCamera";
  }

  public static func PROGRAM_ACTION_BN_UNLOCK_TURRET() -> TweakDBID {
    return t"MinigameProgramAction.BN_RemoteBreach_UnlockTurret";
  }

  public static func PROGRAM_ACTION_BN_UNLOCK_VEHICLE() -> TweakDBID {
    return t"MinigameProgramAction.BN_RemoteBreach_UnlockVehicle";
  }

  public static func PROGRAM_ACTION_REMOTE_BREACH_EASY() -> TweakDBID {
    return t"MinigameProgramAction.RemoteBreachEasy";
  }

  public static func PROGRAM_ACTION_REMOTE_BREACH_MEDIUM() -> TweakDBID {
    return t"MinigameProgramAction.RemoteBreachMedium";
  }

  public static func PROGRAM_ACTION_REMOTE_BREACH_HARD() -> TweakDBID {
    return t"MinigameProgramAction.RemoteBreachHard";
  }

  // ----- Minigame Difficulty Presets (Minigame.*) -----
  // Define breach minigame parameters (duration, buffer size, program count)

  public static func MINIGAME_COMPUTER_BREACH_EASY() -> TweakDBID {
    return t"Minigame.ComputerRemoteBreachEasy";
  }

  public static func MINIGAME_COMPUTER_BREACH_MEDIUM() -> TweakDBID {
    return t"Minigame.ComputerRemoteBreachMedium";
  }

  public static func MINIGAME_COMPUTER_BREACH_HARD() -> TweakDBID {
    return t"Minigame.ComputerRemoteBreachHard";
  }

  public static func MINIGAME_DEVICE_BREACH_MEDIUM() -> TweakDBID {
    return t"Minigame.DeviceRemoteBreachMedium";
  }

  public static func MINIGAME_VEHICLE_BREACH() -> TweakDBID {
    return t"Minigame.VehicleRemoteBreach";
  }

  // ----- Device Actions (DeviceAction.*) -----
  public static func DEVICE_ACTION_REMOTE_BREACH() -> TweakDBID {
    return t"DeviceAction.RemoteBreach";
  }

  // ==================== Helper Methods ====================
  //
  // Convenience methods for common constant operations
  // ========================================================================

  /**
   * Checks if className is any RemoteBreach action class.
   * Centralized RemoteBreach action detection - automatically includes all
   * current and future RemoteBreach types.
   *
   * @param className - The class name to check
   * @return True if className matches any RemoteBreach action class
   */
  public static func IsRemoteBreachAction(className: CName) -> Bool {
    return Equals(className, BNConstants.CLASS_REMOTE_BREACH_COMPUTER())
        || Equals(className, BNConstants.CLASS_REMOTE_BREACH_DEVICE())
        || Equals(className, BNConstants.CLASS_REMOTE_BREACH_VEHICLE());
  }
}
