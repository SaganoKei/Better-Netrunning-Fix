module BetterNetrunning.NPCs

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*

// ============================================================================
// NPC Lifecycle Module
// ============================================================================
//
// PURPOSE:
//   Manages NPC network connection state throughout their lifecycle (active,
//   incapacitated, dead) to enable/disable unconscious NPC breaching
//
// FUNCTIONALITY:
//   - Keeps NPCs connected to network when incapacitated (allows unconscious breach)
//   - Disconnects NPCs from network upon death (vanilla behavior)
//   - Adds breach action to unconscious NPC interaction menu
//   - Detects unconscious NPC breaches via IsUnconsciousNPCBreach() entity type check
//   - Checks physical access point connection for radial unlock mode
//
// ARCHITECTURE:
//   - OnIncapacitated() override: Removes RemoveLink() call to keep network connection
//   - GetValidChoices() override: Adds breach action to unconscious NPC interaction menu
//   - CompleteAction() override: Delegates to vanilla after entity type detection
//   - OnDeath() not overridden: Identical to vanilla, improves mod compatibility
//

// ==================== Incapacitation Handling ====================

/*
 * Keeps NPCs connected to network when incapacitated.
 *
 * VANILLA DIFF: Removes this.RemoveLink() call to keep network connection active.
 * Allows quickhacking unconscious NPCs per mod design.
 */
@replaceMethod(ScriptedPuppet)
protected func OnIncapacitated() -> Void {
  let incapacitatedEvent: ref<IncapacitatedEvent>;
  if this.IsIncapacitated() {
    return;
  }
  if !StatusEffectSystem.ObjectHasStatusEffectWithTag(this, n"CommsNoiseIgnore") {
    incapacitatedEvent = new IncapacitatedEvent();
    GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, incapacitatedEvent, 0.50);
  }
  this.m_securitySupportListener = null;
  // Keep network link active (do not call this.RemoveLink())
  this.EnableLootInteractionWithDelay(this);
  this.EnableInteraction(n"Grapple", false);
  this.EnableInteraction(n"TakedownLayer", false);
  this.EnableInteraction(n"AerialTakedown", false);
  this.EnableInteraction(n"NewPerkFinisherLayer", false);
  StatusEffectHelper.RemoveAllStatusEffectsByType(this, gamedataStatusEffectType.Cloaked);
  if this.IsBoss() {
    this.EnableInteraction(n"BossTakedownLayer", false);
  } else if this.IsMassive() {
    this.EnableInteraction(n"MassiveTargetTakedownLayer", false);
  }
  this.RevokeAllTickets();
  this.GetSensesComponent().ToggleComponent(false);
  this.GetBumpComponent().Toggle(false);
  this.UpdateQuickHackableState(false);
  if this.IsPerformingCallReinforcements() {
    this.HidePhoneCallDuration(gamedataStatPoolType.CallReinforcementProgress);
  }
  this.GetPuppetPS().SetWasIncapacitated(true);
  this.ProcessQuickHackQueueOnDefeat();
  CachedBoolValue.SetDirty(this.m_isActiveCached);
}

// ==================== Network Connection Checks ====================

/*
 * Checks if device is connected to any access point controller
 * Used to determine if unconscious NPC breach is possible
 *
 * @return True if device is connected to at least one access point
 */
@addMethod(DeviceComponentPS)
public final func IsConnectedToPhysicalAccessPoint() -> Bool {
  let sharedGameplayPS: ref<SharedGameplayPS> = this as SharedGameplayPS;
  if !IsDefined(sharedGameplayPS) {
    return false;
  }
  let apControllers: array<ref<AccessPointControllerPS>> = sharedGameplayPS.GetAccessPoints();
  return ArraySize(apControllers) > 0;
}

// ==================== Unconscious NPC Breach Action ====================

/*
 * Adds breach action to unconscious NPC interaction menu.
 * Allows breaching unconscious NPCs when connected to network.
 *
 * VANILLA DIFF: Injects BreachUnconsciousOfficer action before vanilla processing.
 */
@wrapMethod(ScriptedPuppetPS)
public final const func GetValidChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, objectActionsCallbackController: wref<gameObjectActionsCallbackController>, checkPlayerQuickHackList: Bool, choices: script_ref<array<InteractionChoice>>) -> Void {
	// Add BreachUnconsciousOfficer action if all conditions met
	if BetterNetrunningSettings.AllowBreachingUnconsciousNPCs()
		&& this.IsConnectedToAccessPoint()
		&& (!BetterNetrunningSettings.UnlockIfNoAccessPoint() || this.GetDeviceLink().IsConnectedToPhysicalAccessPoint())
		&& !this.m_betterNetrunningWasDirectlyBreached
		&& !BreachLockUtils.IsNPCLockedByUnconsciousNPCBreachFailure(this) {
    ArrayPush(Deref(actions), TweakDBInterface.GetObjectActionRecord(t"Takedown.BreachUnconsciousOfficer"));
  }
	wrappedMethod(actions, context, objectActionsCallbackController, checkPlayerQuickHackList, choices);
}

/*
 * Returns AccessBreach action for breach operations.
 *
 * Detects BreachUnconsciousOfficer action by name and returns AccessBreach for all
 * breach types. Delegates other actions to vanilla GetAction().
 *
 * @param actionRecord Object action record from TweakDB
 * @return AccessBreach for breach actions, vanilla PuppetAction for others
 */
@replaceMethod(ScriptedPuppetPS)
protected const func GetAction(actionRecord: wref<ObjectAction_Record>) -> ref<PuppetAction> {
  let puppetAction: ref<PuppetAction>;
  let breachAction: ref<AccessBreach>;
  let isRemoteBreach: Bool;
  let isPhysicalBreach: Bool;
  let isSuicideBreach: Bool;
  let isUnconsciousBreach: Bool;

  if !IsDefined(actionRecord) {
    return null;
  }

  // Detect BreachUnconsciousOfficer action
  isUnconsciousBreach = Equals(actionRecord.ActionName(), BNConstants.ACTION_UNCONSCIOUS_BREACH());

  // VANILLA LOGIC: Handle all breach types (including unconscious)
  isRemoteBreach = Equals(actionRecord.ActionName(), BNConstants.ACTION_REMOTE_BREACH());
  isSuicideBreach = Equals(actionRecord.ActionName(), BNConstants.ACTION_SUICIDE_BREACH());
  isPhysicalBreach = Equals(actionRecord.ActionName(), BNConstants.ACTION_PHYSICAL_BREACH());

  if isPhysicalBreach || isRemoteBreach || isSuicideBreach || isUnconsciousBreach {
    breachAction = new AccessBreach();

    if this.IsConnectedToAccessPoint() {
      let networkName: String = ToString(this.GetNetworkName());
      breachAction.SetProperties(
        networkName,
        ScriptedPuppetPS.GetNPCsConnectedToThisAPCount(),
        this.GetAccessPoint().GetMinigameAttempt(),
        isRemoteBreach,
        isSuicideBreach
      );
    } else {
      let squadNetwork: String = "SQUAD_NETWORK";
      breachAction.SetProperties(
        squadNetwork,
        1,
        1,
        isRemoteBreach,
        isSuicideBreach
      );
    }

    puppetAction = breachAction;
  } else if Equals(actionRecord.ActionName(), n"Ping") {
    puppetAction = new PingSquad();
  } else {
    puppetAction = new PuppetAction();
  }

  return puppetAction;
}

// ==================== Breach Completion Handling ====================

/*
 * Handles unconscious NPC breach completion.
 *
 * Ensures IsUnconsciousNPCBreach() can detect NPC breaches via Entity type check.
 * Entity is set by vanilla AccessBreach in Blackboard.
 */
@wrapMethod(AccessBreach)
protected func CompleteAction(gameInstance: GameInstance) -> Void {
  // Check if this is an unconscious NPC breach
  let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gameInstance)
    .Get(GetAllBlackboardDefs().HackingMinigame);


  let entity: wref<Entity> = FromVariant<wref<Entity>>(
    minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity)
  );

  let npcPuppet: wref<ScriptedPuppet> = entity as ScriptedPuppet;

  // Note: IsUnconsciousNPCBreach() already detects NPC breaches via Entity type check
  // No additional flag needed

  // Execute vanilla logic
  wrappedMethod(gameInstance);
}

