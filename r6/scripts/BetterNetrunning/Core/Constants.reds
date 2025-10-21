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
// - When adding new RemoteBreach types: Add constant + update GetAllRemoteBreachClassNames()
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

  // ==================== Daemon Types ====================
  //
  // Minigame daemon type identifiers
  // Used for breach state tracking and unlock logic
  // ========================================================================

  public static func DAEMON_BASIC() -> CName {
    return n"UnlockQuickhacks";
  }

  public static func DAEMON_CAMERA() -> CName {
    return n"UnlockCamera";
  }

  public static func DAEMON_TURRET() -> CName {
    return n"UnlockTurret";
  }

  public static func DAEMON_NPC() -> CName {
    return n"UnlockNPC";
  }

  // ==================== Log Channel Names ====================
  //
  // Standardized log channel names for debug output
  // ========================================================================

  public static func LOG_CHANNEL_DEBUG() -> CName {
    return n"DEBUG";
  }

  public static func LOG_CHANNEL_ERROR() -> CName {
    return n"ERROR";
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
  public static func PROGRAM_NETWORK_PING_HACK() -> TweakDBID {
    return t"MinigameAction.NetworkPingHack";
  }

  public static func PROGRAM_DATAMINE_BASIC() -> TweakDBID {
    return t"MinigameAction.NetworkDataMineLootAll";
  }

  public static func PROGRAM_DATAMINE_ADVANCED() -> TweakDBID {
    return t"MinigameAction.NetworkDataMineLootAllAdvanced";
  }

  public static func PROGRAM_DATAMINE_MASTER() -> TweakDBID {
    return t"MinigameAction.NetworkDataMineLootAllMaster";
  }

  // Daemon Netrunning Revamp (DNR) gated programs (low frequency - 1 usage each)
  public static func PROGRAM_DNR_UNLOCK_DOORS() -> TweakDBID {
    return t"MinigameAction.DNR_UnlockDoors";
  }

  public static func PROGRAM_DNR_DISABLE_CAMERAS() -> TweakDBID {
    return t"MinigameAction.DNR_DisableCameras";
  }

  public static func PROGRAM_DNR_EXPLODE_GENERATORS() -> TweakDBID {
    return t"MinigameAction.DNR_ExplodeGenerators";
  }

  public static func PROGRAM_DNR_FRIENDLY_TURRETS() -> TweakDBID {
    return t"MinigameAction.DNR_FriendlyTurrets";
  }

  public static func PROGRAM_DNR_MASS_DISTRACT() -> TweakDBID {
    return t"MinigameAction.DNR_MassDistract";
  }

  public static func PROGRAM_DNR_MASS_VULNERABILITY() -> TweakDBID {
    return t"MinigameAction.DNR_MassVulnerability";
  }

  public static func PROGRAM_DNR_SUICIDE() -> TweakDBID {
    return t"MinigameAction.DNR_Suicide";
  }

  public static func PROGRAM_DNR_WEAPON_MALFUNCTION() -> TweakDBID {
    return t"MinigameAction.DNR_WeaponMalfunction";
  }

  // Basic device actions
  public static func PROGRAM_NETWORK_DEVICE_BASIC_ACTIONS() -> TweakDBID {
    return t"MinigameAction.NetworkDeviceBasicActions";
  }

  // ----- DNR (Daemon Netrunning Revamp) Ultimate Hacks -----
  // DNR MOD compatibility - Ultimate quickhacks for filtering

  public static func PROGRAM_DNR_REMOTE_CYBERPSYCHOSIS() -> TweakDBID {
    return t"MinigameAction.RemoteCyberpsychosis";
  }

  public static func PROGRAM_DNR_CYBERPSYCHOSIS_AP() -> TweakDBID {
    return t"MinigameAction.Cyberpsychosis_AP";
  }

  public static func PROGRAM_DNR_REMOTE_SUICIDE() -> TweakDBID {
    return t"MinigameAction.RemoteSuicide";
  }

  public static func PROGRAM_DNR_SUICIDE_AP() -> TweakDBID {
    return t"MinigameAction.Suicide_AP";
  }

  public static func PROGRAM_DNR_REMOTE_SYSTEM_RESET() -> TweakDBID {
    return t"MinigameAction.RemoteSystemReset";
  }

  public static func PROGRAM_DNR_SYSTEM_RESET_AP() -> TweakDBID {
    return t"MinigameAction.SystemReset_AP";
  }

  public static func PROGRAM_DNR_REMOTE_DETONATE_GRENADE() -> TweakDBID {
    return t"MinigameAction.RemoteDetonateGrenade";
  }

  public static func PROGRAM_DNR_DETONATE_GRENADE_AP() -> TweakDBID {
    return t"MinigameAction.DetonateGrenade_AP";
  }

  public static func PROGRAM_DNR_REMOTE_NETWORK_OVERLOAD() -> TweakDBID {
    return t"MinigameAction.RemoteNetworkOverload";
  }

  public static func PROGRAM_DNR_NETWORK_OVERLOAD_AP() -> TweakDBID {
    return t"MinigameAction.NetworkOverload_AP";
  }

  public static func PROGRAM_DNR_REMOTE_NETWORK_CONTAGION() -> TweakDBID {
    return t"MinigameAction.RemoteNetworkContagion";
  }

  public static func PROGRAM_DNR_NETWORK_CONTAGION_AP() -> TweakDBID {
    return t"MinigameAction.NetworkContagion_AP";
  }

  // Quest-specific programs
  public static func PROGRAM_NETWORK_LOOT_Q003() -> TweakDBID {
    return t"MinigameAction.NetworkLootQ003";
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
   * Returns all RemoteBreach action class names as array
   *
   * @return Array containing all RemoteBreach class name constants
   */
  public static func GetAllRemoteBreachClassNames() -> array<CName> {
    let result: array<CName>;
    ArrayPush(result, BNConstants.CLASS_REMOTE_BREACH_COMPUTER());
    ArrayPush(result, BNConstants.CLASS_REMOTE_BREACH_DEVICE());
    ArrayPush(result, BNConstants.CLASS_REMOTE_BREACH_VEHICLE());
    return result;
  }

  /**
   * Check if className is any RemoteBreach action class
   *
   * PURPOSE:
   * Centralized RemoteBreach action detection.
   * Automatically includes all current and future RemoteBreach types.
   *
   * @param className - The class name to check
   * @return True if className matches any RemoteBreach action class
   */
  public static func IsRemoteBreachAction(className: CName) -> Bool {
    return Equals(className, BNConstants.CLASS_REMOTE_BREACH_COMPUTER())
        || Equals(className, BNConstants.CLASS_REMOTE_BREACH_DEVICE())
        || Equals(className, BNConstants.CLASS_REMOTE_BREACH_VEHICLE());
  }

  /**
   * Check if actionName is RemoteBreach
   *
   * @param actionName - The action name to check
   * @return True if actionName is RemoteBreach
   */
  public static func IsRemoteBreachActionName(actionName: CName) -> Bool {
    return Equals(actionName, BNConstants.ACTION_REMOTE_BREACH());
  }
}
