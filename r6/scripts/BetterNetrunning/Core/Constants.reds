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
    return n"BetterNetrunning.RemoteBreach.RemoteBreachStateSystem";
  }

  // Device RemoteBreach state tracking (Door, Camera, Turret, generic devices)
  public static func CLASS_DEVICE_REMOTE_BREACH_STATE_SYSTEM() -> CName {
    return n"BetterNetrunning.RemoteBreach.RemoteBreachStateSystem";
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

  // ==================== Breach Type Identifiers ====================
  //
  // String identifiers for breach session types
  // Used in statistics logging, breach state tracking, and debug output
  // Also serves as log channel name for BNDebug/BNInfo/BNError functions
  // ========================================================================

  public static func BREACH_TYPE_ACCESS_POINT() -> String {
    return "AccessPoint";
  }

  public static func BREACH_TYPE_REMOTE_BREACH() -> String {
    return "RemoteBreach";
  }

  public static func BREACH_TYPE_UNCONSCIOUS_NPC() -> String {
    return "UnconsciousNPC";
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
  // Used as first parameter in BNDebug/BNInfo/BNError logging functions
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

  // ----- Device Actions (DeviceAction.*) -----
  public static func DEVICE_ACTION_REMOTE_BREACH() -> TweakDBID {
    return t"DeviceAction.RemoteBreach";
  }
}
