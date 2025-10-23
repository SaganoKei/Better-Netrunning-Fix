// ============================================================================
// BetterNetrunning - English Localization
// ============================================================================
//
// PURPOSE:
// English language definitions for Better Netrunning mod.
//
// TOTAL ENTRIES: 142
//
// CATEGORIES:
// - Controls (3 entries)
// - Breaching (7 entries)
// - RemoteBreach (13 entries)
// - BreachPenalty (5 entries)
// - AccessPoints (7 entries)
// - UnlockedQuickhacks (21 entries)
// - Progression (71 entries: Cyberdeck/Intelligence/EnemyRarity)
// - Debug (12 entries)
// - Daemon Names/Descriptions (8 entries)
//
// DEPENDENCIES:
// - Codeware.Localization.ModLocalizationPackage
// ============================================================================

module BetterNetrunning.Localization
import Codeware.Localization.*

public class English extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // ===== CONTROLS =====
    this.Text("Category-Controls", "Controls");
    this.Text("DisplayName-BetterNetrunning-BreachingHotkey", "Unconscious Breaching Hotkey");
    this.Text("Description-BetterNetrunning-BreachingHotkey", "Select which hotkey to assign Breach for unconscious NPCs.");

    // ===== BREACHING =====
    this.Text("Category-Breaching", "Breaching");
    this.Text("DisplayName-BetterNetrunning-EnableClassicMode", "Enable Classic Mode");
    this.Text("Description-BetterNetrunning-EnableClassicMode", "If true, the entire network can be breached by uploading any daemon. This disables the subnet system, along with the corresponding breach daemons.");

    this.Text("DisplayName-BetterNetrunning-AllowBreachingUnconsciousNPCs", "Allow Breaching Unconscious NPCs");
    this.Text("Description-BetterNetrunning-AllowBreachingUnconsciousNPCs", "If true, you can perform a network breach on any unconscious NPC connected to a network.");

    this.Text("DisplayName-BetterNetrunning-QuickhackUnlockDurationHours", "Quickhack Unlock Duration (Hours)");
    this.Text("Description-BetterNetrunning-QuickhackUnlockDurationHours",
              "Sets how long quickhacks remain unlocked after a successful breach (in-game time). \nSet to 0: Once breached, devices remain unlocked indefinitely (no expiration). \nSet to 1+: Devices re-lock after the specified hours and require another breach.");

    // ===== REMOTE BREACH =====
    this.Text("Category-RemoteBreach", "Remote Breach");
    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledDevice", "Remote Breach - Device");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledDevice",
              "Enable/Disable Remote Breach action for Devices (Camera/Turret/Terminal/etc). \nWhen disabled, the Breach Protocol quickhack will not appear on these devices.");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledComputer", "Remote Breach - Computer");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledComputer",
              "Enable/Disable Remote Breach action for Computers. \nWhen disabled, the Breach Protocol quickhack will not appear on Computer devices.");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledCamera", "Remote Breach - Camera");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledCamera",
              "Enable/Disable Remote Breach action for Cameras. \nWhen disabled, the Breach Protocol quickhack will not appear on Camera devices.");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledTurret", "Remote Breach - Turret");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledTurret",
              "Enable/Disable Remote Breach action for Turrets. \nWhen disabled, the Breach Protocol quickhack will not appear on Turret devices.");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledVehicle", "Remote Breach - Vehicle");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledVehicle",
              "Enable/Disable Remote Breach action for Vehicles. \nWhen disabled, the Breach Protocol quickhack will not appear on Vehicle devices.");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachRAMCostPercent", "RAM Cost Percentage");
    this.Text("Description-BetterNetrunning-RemoteBreachRAMCostPercent",
              "Percentage of max RAM consumed by Remote Breach (default: 50% = 1/2. 100% = full RAM). \nAllows you to balance the cost of remote breaching.");

    // ===== BREACH FAILURE PENALTY =====
    this.Text("Category-BreachPenalty", "Breach Failure Penalty");
    this.Text("DisplayName-BetterNetrunning-BreachFailurePenaltyEnabled", "Enable Breach Failure Penalty");
    this.Text("Description-BetterNetrunning-BreachFailurePenaltyEnabled",
              "Apply penalties when breach protocol fails (applies to all breach types). \nOn failure: Disconnection VFX + Type-specific lock + Trace attempt. \nNote: Failure and skip are not differentiated; both are treated as Failed state.");

    this.Text("DisplayName-BetterNetrunning-APBreachFailurePenaltyEnabled", "Access Point Breach Penalty");
    this.Text("Description-BetterNetrunning-APBreachFailurePenaltyEnabled",
              "Apply penalty when Access Point breach fails.\nWhen enabled: Disconnection VFX + Re-Jack In unavailable on target + Trace (if netrunner nearby)\nJack In action becomes unavailable on the failed device for a certain duration (other devices remain accessible)");

    this.Text("DisplayName-BetterNetrunning-NPCBreachFailurePenaltyEnabled", "NPC Breach Penalty");
    this.Text("Description-BetterNetrunning-NPCBreachFailurePenaltyEnabled",
              "Apply penalty when Unconscious NPC breach fails.\nWhen enabled: Disconnection VFX + Re-Breach unavailable on target + Trace (if netrunner nearby)\nBreach action becomes unavailable on the failed NPC for a certain duration (other NPCs remain breachable)");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachFailurePenaltyEnabled", "RemoteBreach Penalty");
    this.Text("Description-BetterNetrunning-RemoteBreachFailurePenaltyEnabled",
              "Apply penalty when RemoteBreach quickhack fails.\nWhen enabled: Disconnection VFX + RemoteBreach unavailable on entire connected network + standalone/vehicle devices within range + Trace (if netrunner nearby)\nBreach Protocol quickhacks become unavailable on: (1) entire connected network if failed device is network-connected, (2) standalone/vehicle devices within range from failure position for a certain duration");

    this.Text("DisplayName-BetterNetrunning-BreachPenaltyDurationMinutes", "Breach Penalty Duration (minutes)");
    this.Text("Description-BetterNetrunning-BreachPenaltyDurationMinutes",
              "Duration that breach failure penalties persist (in-game time).\nAP Breach: Jack In action locked on failed device\nNPC Breach: Breach action locked on failed NPC\nRemoteBreach: Breach Protocol quickhacks locked on entire connected network (if network-connected) or standalone/vehicle devices within range (if standalone)");

    // ===== ACCESS POINTS =====
    this.Text("Category-AccessPoints", "Access Points");
    this.Text("DisplayName-BetterNetrunning-UnlockIfNoAccessPoint", "Unlock Networks With No Access Points");
    this.Text("Description-BetterNetrunning-UnlockIfNoAccessPoint",
              "If TRUE, devices without access points are always unlocked (no breach required). \nIf FALSE, standalone devices require breach via Radial Unlock System \n(auto-unlocks within breach radius from breached network's center. Radius configurable in Radial Breach settings).");

    this.Text("DisplayName-BetterNetrunning-AutoDatamineBySuccessCount", "Auto-Datamine by Success Count");
    this.Text("Description-BetterNetrunning-AutoDatamineBySuccessCount",
              "Automatically apply Datamine V1/V2/V3 based on successful daemon count (1 daemon = V1, 2 daemons = V2, 3+ daemons = V3). \nAll Datamine programs will be hidden from breach screen.");

    this.Text("DisplayName-BetterNetrunning-AutoExecutePingOnSuccess", "Auto-Execute PING on Success");
    this.Text("Description-BetterNetrunning-AutoExecutePingOnSuccess", "Automatically execute PING daemon (hidden) when any other daemon succeeds. This provides network visibility as a bonus reward.");

    // ===== ALWAYS UNLOCKED QUICKHACKS =====
    this.Text("Category-UnlockedQuickhacks", "Always Unlocked Quickhacks");
    this.Text("DisplayName-BetterNetrunning-AlwaysAllowPing", "Ping");
    this.Text("Description-BetterNetrunning-AlwaysAllowPing", "If true, the Ping quickhack is always available on unbreached networks.");

    this.Text("DisplayName-BetterNetrunning-AlwaysAllowWhistle", "Whistle");
    this.Text("Description-BetterNetrunning-AlwaysAllowWhistle", "If true, the Whistle quickhack is always available on unbreached networks.");

    this.Text("DisplayName-BetterNetrunning-AlwaysAllowDistract", "Distract Enemies");
    this.Text("Description-BetterNetrunning-AlwaysAllowDistract", "If true, the Distract Enemies quickhack is always available on unbreached networks.");

    this.Text("DisplayName-BetterNetrunning-AlwaysBasicDevices", "Basic Devices");
    this.Text("Description-BetterNetrunning-AlwaysBasicDevices", "If true, basic device quickhacks are always available on unbreached networks.");

    this.Text("DisplayName-BetterNetrunning-AlwaysCameras", "Cameras");
    this.Text("Description-BetterNetrunning-AlwaysCameras", "If true, camera quickhacks are always available on unbreached networks.");

    this.Text("DisplayName-BetterNetrunning-AlwaysTurrets", "Turrets");
    this.Text("Description-BetterNetrunning-AlwaysTurrets", "If true, turret quickhacks are always available on unbreached networks.");

    this.Text("DisplayName-BetterNetrunning-AlwaysNPCsCovert", "NPCs - Covert");
    this.Text("Description-BetterNetrunning-AlwaysNPCsCovert", "If true, covert NPC quickhacks are always available on unbreached networks.");

    this.Text("DisplayName-BetterNetrunning-AlwaysNPCsCombat", "NPCs - Combat");
    this.Text("Description-BetterNetrunning-AlwaysNPCsCombat", "If true, combat quickhacks to NPCs are always available on unbreached networks.");

    this.Text("DisplayName-BetterNetrunning-AlwaysNPCsControl", "NPCs - Control");
    this.Text("Description-BetterNetrunning-AlwaysNPCsControl", "If true, control NPC quickhacks are always available on unbreached networks.");

    this.Text("DisplayName-BetterNetrunning-AlwaysNPCsUltimate", "NPCs - Ultimate");
    this.Text("Description-BetterNetrunning-AlwaysNPCsUltimate", "If true, ultimate NPC quickhacks are always available on unbreached networks.");

    // ===== PROGRESSION =====
    this.Text("Category-Progression", "Progression");
    this.Text("DisplayName-BetterNetrunning-ProgressionRequireAll", "Require All");
    this.Text("Description-BetterNetrunning-ProgressionRequireAll", "If true, all progression categories (that are not disabled) must be met to unlock a type of hack. If false, at least one must be met.");

    // ===== PROGRESSION - CYBERDECK QUALITY =====
    this.Text("Category-BetterNetrunning-ProgressionCyberdeck", "Progression - Cyberdeck Quality");
    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckEnabled", "Enable Cyberdeck Progression");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckEnabled", "If enabled, cyberdeck quality requirements will be enforced for accessing quickhacks. Disable to ignore cyberdeck quality restrictions.");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckBasicDevices", "Basic Devices");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckBasicDevices", "Minimum cyberdeck quality to access quickhacks on basic devices (no cameras or turrets).");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckCameras", "Cameras");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckCameras", "Minimum cyberdeck quality to access quickhacks on cameras.");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckTurrets", "Turrets");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckTurrets", "Minimum cyberdeck quality to access quickhacks on turrets.");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsCovert", "NPCs - Covert");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckNPCsCovert", "Minimum cyberdeck quality to access covert quickhacks on NPCs.");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsCombat", "NPCs - Combat");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckNPCsCombat", "Minimum cyberdeck quality to access combat quickhacks on NPCs.");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsControl", "NPCs - Control");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckNPCsControl", "Minimum cyberdeck quality to access control quickhacks on NPCs.");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsUltimate", "NPCs - Ultimate");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckNPCsUltimate", "Minimum cyberdeck quality to access ultimate quickhacks on NPCs.");

    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Common", "Tier 1");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-CommonPlus", "Tier 1+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Uncommon", "Tier 2");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-UncommonPlus", "Tier 2+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Rare", "Tier 3");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-RarePlus", "Tier 3+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Epic", "Tier 4");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-EpicPlus", "Tier 4+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Legendary", "Tier 5");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-LegendaryPlus", "Tier 5+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-LegendaryPlusPlus", "Tier 5++");

    // ===== PROGRESSION - INTELLIGENCE =====
    this.Text("Category-BetterNetrunning-ProgressionIntelligence", "Progression - Intelligence");
    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceEnabled", "Enable Intelligence Progression");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceEnabled", "If enabled, Intelligence attribute requirements will be enforced for accessing quickhacks. Disable to ignore Intelligence restrictions.");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceBasicDevices", "Basic Devices");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceBasicDevices", "Minimum intelligence to access quickhacks on basic devices (no cameras or turrets).");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceCameras", "Cameras");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceCameras", "Minimum intelligence to access quickhacks on cameras.");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceTurrets", "Turrets");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceTurrets", "Minimum intelligence to access quickhacks on turrets.");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsCovert", "NPCs - Covert");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceNPCsCovert", "Minimum intelligence to access covert quickhacks on NPCs.");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsCombat", "NPCs - Combat");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceNPCsCombat", "Minimum intelligence to access combat quickhacks on NPCs.");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsControl", "NPCs - Control");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceNPCsControl", "Minimum intelligence to access control quickhacks on NPCs.");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsUltimate", "NPCs - Ultimate");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceNPCsUltimate", "Minimum intelligence to access ultimate quickhacks on NPCs.");

    // ===== PROGRESSION - ENEMY TIER =====
    this.Text("Category-BetterNetrunning-ProgressionEnemyRarity", "Progression - Enemy Tier Difference");
    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityEnabled", "Enable Enemy Tier Progression");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityEnabled", "When enabled, enemy tier requirements are applied to quickhack access. Disable to ignore enemy tier restrictions.");

    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsCovert", "NPCs - Covert");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityNPCsCovert", "Highest NPCs tier eligible for covert quickhack.");

    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsCombat", "NPCs - Combat");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityNPCsCombat", "Highest NPCs tier eligible for combat quickhack.");

    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsControl", "NPCs - Control");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityNPCsControl", "Highest NPCs tier eligible for control quickhack.");

    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsUltimate", "NPCs - Ultimate");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityNPCsUltimate", "Highest NPCs tier eligible for ultimate quickhack.");

    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Trash", "Trash");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Weak", "Weak");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Normal", "Normal");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Rare", "Rare");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Officer", "Officer");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Elite", "Elite");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Boss", "Boss");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-MaxTac", "MaxTac");

    // ===== DEBUG =====
    this.Text("Category-Debug", "Debug");
    this.Text("DisplayName-BetterNetrunning-EnableDebugLog", "Enable Debug Logging");
    this.Text("Description-BetterNetrunning-EnableDebugLog", "Enables debug log output");

    this.Text("DisplayName-BetterNetrunning-DebugLogLevel", "Log Level");
    this.Text("Description-BetterNetrunning-DebugLogLevel",
              "Set the verbosity of debug logs. Only output when Debug Log is enabled.\n0=ERROR (Critical errors only)\n1=WARNING (Errors + warnings)\n2=INFO (Default, normal information)\n3=DEBUG (Detailed debugging information)\n4=TRACE (Very detailed, may impact performance)");

    this.Text("DisplayValues-BetterNetrunning-LogLevel-ERROR", "ERROR (Errors Only)");
    this.Text("DisplayValues-BetterNetrunning-LogLevel-WARNING", "WARNING (Errors + Warnings)");
    this.Text("DisplayValues-BetterNetrunning-LogLevel-INFO", "INFO (Default)");
    this.Text("DisplayValues-BetterNetrunning-LogLevel-DEBUG", "DEBUG (Detailed)");
    this.Text("DisplayValues-BetterNetrunning-LogLevel-TRACE", "TRACE (Very Detailed)");

    // ===== DAEMON NAMES / DESCRIPTIONS =====
    this.Text("Better-Netrunning-Basic-Access-Name", "Breach Root Network");
    this.Text("Better-Netrunning-Basic-Access-Description", "Unlocks quickhacks on connected basic devices.");
    this.Text("Better-Netrunning-NPC-Access-Name", "Breach Personnel System");
    this.Text("Better-Netrunning-NPC-Access-Description", "Unlocks quickhacks on connected personnel.");
    this.Text("Better-Netrunning-Camera-Access-Name", "Breach Surveillance System");
    this.Text("Better-Netrunning-Camera-Access-Description", "Unlocks quickhacks on connected surveillance cameras.");
    this.Text("Better-Netrunning-Turret-Access-Name", "Breach Defense System");
    this.Text("Better-Netrunning-Turret-Access-Description", "Unlocks quickhacks on connected turrets.");
    this.Text("Better-Netrunning-Quickhacks-Locked", "No Network access rights");
  }
}