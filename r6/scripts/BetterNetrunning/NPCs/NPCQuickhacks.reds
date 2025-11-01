// ============================================================================
// BetterNetrunning - NPC Quickhacks
// ============================================================================
//
// PURPOSE:
// Controls NPC quickhack availability based on breach status and player progression
//
// FUNCTIONALITY:
// - Progressive unlock system (Cyberdeck tier, Intelligence stat, Enemy Rarity)
// - Network isolation detection with auto-unlock for isolated NPCs
// - Category-based restrictions (Covert, Combat, Control, Ultimate)
// - Special always-allowed quickhacks (Ping, Whistle)
// - Tutorial NPC whitelist for progression bypass
//
// ARCHITECTURE:
// - Extract Method pattern with shallow nesting (max 2 levels)
// - Event interception for vanilla behavior control
// - Continue Pattern for cleaner control flow
//

module BetterNetrunning.NPCs
import BetterNetrunning.Logging.*

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Systems.*
import BetterNetrunning.Breach.*

// Prevent vanilla from setting m_quickHacksExposed when NPC Subnet not unlocked
/*
 * Controls exposure of NPC quickhacks when NPC subnet is not unlocked.
 *
 * VANILLA DIFF: Blocks vanilla from setting m_quickHacksExposed if NPC subnet
 * timestamp is not set.
 *
 * @param evt - SetExposeQuickHacks event
 * @return EntityNotificationType - vanilla result or DoNotNotifyEntity when blocked
 */
@wrapMethod(ScriptedPuppetPS)
public func OnSetExposeQuickHacks(evt: ref<SetExposeQuickHacks>) -> EntityNotificationType {
  // Check if NPC is connected to network
  if !this.IsConnectedToAccessPoint() {
    // Standalone NPC - allow vanilla processing (auto-unlock)
    return wrappedMethod(evt);
  }

  // Network-connected NPC - check if NPC subnet was unlocked
  let deviceLink: ref<SharedGameplayPS> = this.GetDeviceLink();
  if !IsDefined(deviceLink) {
    // No device link - allow vanilla processing
    return wrappedMethod(evt);
  }

  // Check NPC subnet timestamp
  let npcUnlockTime: Float = deviceLink.m_betterNetrunningUnlockTimestampNPCs;
  if npcUnlockTime > 0.0 {
    // NPC Subnet unlocked - allow vanilla processing
    return wrappedMethod(evt);
  }

  // NPC Subnet NOT unlocked - block vanilla processing
  BNDebug("NPCQuickhacks", "Blocked OnSetExposeQuickHacks (NPC Subnet not unlocked)");
  return EntityNotificationType.DoNotNotifyEntity;
}

/*
 * Controls NPC quickhack availability based on breach status and progression
 *
 * VANILLA DIFF: Base game generates quickhacks, Better Netrunning filters via 3-step workflow
 *
 * Workflow:
 * - Pre-processing: Calculate permissions
 * - Base Game: 76-line black box (wrappedMethod)
 * - Post-processing: Remove AccessBreach + apply Progressive Unlock
 */
@wrapMethod(ScriptedPuppetPS)
public final const func GetAllChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, puppetActions: script_ref<array<ref<PuppetAction>>>) -> Void {
  // Pre-processing: Calculate NPC permissions (breach state + progression)
  let permissions: NPCHackPermissions = this.CalculateNPCHackPermissions();

  // Log NPC quickhack state (debug mode only)
  DebugUtils.LogNPCQuickhackState(this, "NPCQuickhacks");

  // Base Game Processing: Generate quickhacks with wrappedMethod()
  wrappedMethod(actions, context, puppetActions);

  // Post-processing: Apply Better Netrunning filter
  let attiudeTowardsPlayer: EAIAttitude = this.GetOwnerEntity().GetAttitudeTowards(GetPlayer(this.GetGameInstance()));
  this.ApplyBetterNetrunningQuickhackFilter(puppetActions, permissions, attiudeTowardsPlayer);
}

/*
 * Applies Better Netrunning's Progressive Unlock filter to vanilla-generated quickhacks
 *
 * Operations:
 * - Removes AccessBreach (Better Netrunning uses Access Point breach instead)
 * - Activates quickhacks that meet Progressive Unlock requirements
 * - Deactivates quickhacks that don't meet requirements
 * - Uses reverse iteration for safe array removal
 *
 * @param puppetActions Array of NPC quickhacks (modified in-place)
 * @param permissions Permission flags for NPC hack categories
 * @param attiudeTowardsPlayer NPC's attitude (affects inactive reason message)
 */
@addMethod(ScriptedPuppetPS)
private final func ApplyBetterNetrunningQuickhackFilter(
  puppetActions: script_ref<array<ref<PuppetAction>>>,
  permissions: NPCHackPermissions,
  attiudeTowardsPlayer: EAIAttitude
) -> Void {
  let i: Int32 = ArraySize(Deref(puppetActions)) - 1;

  while i >= 0 {
    let action: ref<PuppetAction> = Deref(puppetActions)[i];

    // Step 1: Remove AccessBreach (Better Netrunning design)
    if IsDefined(action as AccessBreach) {
      ArrayErase(Deref(puppetActions), i);
    } else {
      // Step 2: Apply Progressive Unlock logic
      if this.ShouldQuickhackBeInactive(action, permissions) {
        // Deactivate with Better Netrunning reason
        this.SetQuickhackInactiveReason(action, attiudeTowardsPlayer);
      } else {
        // Activate - override vanilla inactive state
        action.SetActive();
      }
    }

    i -= 1;
  }
}

// ==================== Permission Calculation ====================

/*
 * Calculates NPC hack permissions based on breach state and progression.
 *
 * @return NPCHackPermissions struct with breach status and unlock permissions
 */
@addMethod(ScriptedPuppetPS)
private final func CalculateNPCHackPermissions() -> NPCHackPermissions {
  let permissions: NPCHackPermissions;
  let gameInstance: GameInstance = this.GetGameInstance();
  let npc: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;

  // Check breach status (m_quickHacksExposed is breach state, not menu visibility)
  permissions.isBreached = this.m_quickHacksExposed;

  // Check if NPC is connected to any network
  let isConnectedToNetwork: Bool = this.IsConnectedToAccessPoint();

  // Auto-unlock if not connected to any network (isolated enemies)
  if !isConnectedToNetwork {
    permissions.isBreached = true;
  }

  // Evaluate progression-based unlock conditions for hack categories
  permissions.allowCovert = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsCovert(), BetterNetrunningSettings.ProgressionCyberdeckNPCsCovert(), BetterNetrunningSettings.ProgressionIntelligenceNPCsCovert(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsCovert());
  permissions.allowCombat = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsCombat(), BetterNetrunningSettings.ProgressionCyberdeckNPCsCombat(), BetterNetrunningSettings.ProgressionIntelligenceNPCsCombat(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsCombat());
  permissions.allowControl = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsControl(), BetterNetrunningSettings.ProgressionCyberdeckNPCsControl(), BetterNetrunningSettings.ProgressionIntelligenceNPCsControl(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsControl());
  permissions.allowUltimate = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsUltimate(), BetterNetrunningSettings.ProgressionCyberdeckNPCsUltimate(), BetterNetrunningSettings.ProgressionIntelligenceNPCsUltimate(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsUltimate());
  permissions.allowPing = BetterNetrunningSettings.AlwaysAllowPing() || permissions.allowCovert;
  permissions.allowWhistle = BetterNetrunningSettings.AlwaysAllowWhistle() || permissions.allowCovert;

  return permissions;
}

// ==================== Permission Enforcement ====================

/*
 * Determines if quickhack should be inactive based on progression requirements
 *
 * @param puppetAction - Quickhack action to check
 * @param permissions - Permission flags for NPC hack categories
 * @return True if quickhack should be inactive, false if active
 */
@addMethod(ScriptedPuppetPS)
private final func ShouldQuickhackBeInactive(puppetAction: ref<PuppetAction>, permissions: NPCHackPermissions) -> Bool {
  // All hacks available if breached or whitelisted
  if permissions.isBreached || this.IsWhiteListedForHacks() {
    return false;
  }

  // Check hack category against progression requirements
  let hackCategory: CName = puppetAction.GetObjectActionRecord().HackCategory().EnumName();
  if Equals(hackCategory, n"CovertHack") && permissions.allowCovert {
    return false;
  }
  if Equals(hackCategory, n"DamageHack") && permissions.allowCombat {
    return false;
  }
  if Equals(hackCategory, n"ControlHack") && permissions.allowControl {
    return false;
  }
  if Equals(hackCategory, n"UltimateHack") && permissions.allowUltimate {
    return false;
  }

  // Check special always-allowed quickhacks
  if IsDefined(puppetAction as PingSquad) && permissions.allowPing {
    return false;
  }
  if Equals(puppetAction.GetObjectActionRecord().ActionName(), n"Whistle") && permissions.allowWhistle {
    return false;
  }

  return true;
}

/*
 * Sets inactive reason for unbreached network (unified message for all NPCs)
 *
 * @param puppetAction - Quickhack action to mark inactive
 * @param attiudeTowardsPlayer - NPC's attitude (currently unused)
 */
@addMethod(ScriptedPuppetPS)
private final func SetQuickhackInactiveReason(puppetAction: ref<PuppetAction>, attiudeTowardsPlayer: EAIAttitude) -> Void {
  // Check if RemoteBreach is locked due to breach failure (position-based, 50m radius)
  let isRemoteBreachLocked: Bool = BreachLockUtils.IsNPCLockedByRemoteBreachFailure(this);

  // Use vanilla lock message when RemoteBreach is locked (breach failure penalty)
  // Otherwise use Better Netrunning's custom message
  if isRemoteBreachLocked {
    puppetAction.SetInactiveWithReason(false, BNConstants.LOCKEY_NO_NETWORK_ACCESS());  // "No network access rights"
  } else {
    puppetAction.SetInactiveWithReason(false, LocKeyToString(BNConstants.LOCKEY_QUICKHACKS_LOCKED()));
  }
}

// ==================== Tutorial NPC Whitelist ====================

/*
 * Whitelist of tutorial NPCs that should have all quickhacks available
 * These NPCs bypass progression requirements for proper tutorial flow
 * Credit: KiroKobra (AKA 'Phantum Jak' on Discord)
 *
 * @return True if NPC is whitelisted tutorial character
 */
@addMethod(ScriptedPuppetPS)
protected final func IsWhiteListedForHacks() -> Bool {
  let puppet: wref<ScriptedPuppet> = this.GetOwnerEntity() as ScriptedPuppet;
  let recordID: TweakDBID = puppet.GetRecordID();
  return recordID == t"Character.q000_tutorial_course_01_patroller"
      || recordID == t"Character.q000_tutorial_course_02_enemy_02"
      || recordID == t"Character.q000_tutorial_course_02_enemy_03"
      || recordID == t"Character.q000_tutorial_course_02_enemy_04"
      || recordID == t"Character.q000_tutorial_course_03_guard_01"
      || recordID == t"Character.q000_tutorial_course_03_guard_02"
      || recordID == t"Character.q000_tutorial_course_03_guard_03";
}
