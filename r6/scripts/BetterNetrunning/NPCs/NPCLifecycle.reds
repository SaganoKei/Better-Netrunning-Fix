module BetterNetrunning.NPCs

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*
import BetterNetrunning.Utils.*

/*
 * ============================================================================
 * NPC LIFECYCLE MODULE
 * ============================================================================
 *
 * PURPOSE:
 * Manages NPC network connection state throughout their lifecycle (active,
 * incapacitated, dead) to enable/disable unconscious NPC breaching.
 *
 * FUNCTIONALITY:
 * - Keeps NPCs connected to network when incapacitated (allows unconscious breach)
 * - Disconnects NPCs from network upon death (vanilla behavior)
 * - Adds breach action to unconscious NPC interaction menu
 * - Checks physical access point connection for radial unlock mode
 * - Provides UnconsciousNPCBreach action class with OfficerBreach flag
 *
 * VANILLA DIFF:
 * - OnIncapacitated(): Removes this.RemoveLink() call to keep network connection active
 * - GetValidChoices(): Adds breach action to unconscious NPC interaction menu
 *
 * MOD COMPATIBILITY:
 * OnDeath() override was removed as it's 100% identical to vanilla behavior,
 * improving compatibility with other mods that may hook death events.
 *
 * ============================================================================
 */

// ============================================================================
// UnconsciousNPCBreach - Custom AccessBreach for Unconscious NPCs
// ============================================================================
//
// FUNCTIONALITY:
// Custom AccessBreach implementation for unconscious NPCs that sets
// OfficerBreach flag before breach processing to enable type-specific logic.
//
// ARCHITECTURE:
// - Sets OfficerBreach flag BEFORE super.CompleteAction()
// - super.CompleteAction() calls FinalizeNetrunnerDive() ↁERefreshSlaves()
// - RefreshSlaves() detects OfficerBreach flag and applies NPC-specific processing
// ============================================================================

public class UnconsciousNPCBreach extends AccessBreach {
    protected func CompleteAction(gameInstance: GameInstance) -> Void {
        // Set OfficerBreach flag before vanilla processing
        // RefreshSlaves() checks this flag to apply NPC-specific breach processing
        this.GetNetworkBlackboard(gameInstance).SetBool(
            this.GetNetworkBlackboardDef().OfficerBreach,
            true
        );

        // Execute vanilla CompleteAction logic (calls RefreshSlaves() internally)
        super.CompleteAction(gameInstance);
    }
}

// ==================== Incapacitation Handling ====================

/*
 * Keeps NPCs connected to network when incapacitated
 * VANILLA DIFF: Removes this.RemoveLink() call to keep network connection active
 * Allows quickhacking unconscious NPCs per mod design
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

// ==================== Death Handling ====================

/*
 * Disconnects NPCs from network upon death
 *
 * MOD COMPATIBILITY: Delegates death handling to vanilla logic
 */

// ==================== Network Connection Checks ====================

/*
 * Checks if device is connected to any access point controller
 * Used to determine if unconscious NPC breach is possible
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
 * Adds breach action to unconscious NPC interaction menu
 * Allows breaching unconscious NPCs when connected to network
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

// ==================== Custom Action Creation ====================

/*
 * Returns custom UnconsciousNPCBreach for BreachUnconsciousOfficer action
 *
 * FUNCTIONALITY:
 * - Detects BreachUnconsciousOfficer action by name
 * - Returns UnconsciousNPCBreach (custom AccessBreach with manual experience control)
 * - Delegates all other actions to vanilla GetAction()
 *
 * ARCHITECTURE:
 * - @replaceMethod for full control over action creation
 * - UnconsciousNPCBreach: Custom class with StartUpload()/CompleteAction() overrides
 *
 * MOD COMPATIBILITY:
 * - Uses @replaceMethod (necessary to intercept action creation)
 * - Preserves vanilla logic for all non-BreachUnconsciousOfficer actions
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

  // CRITICAL: Detect BreachUnconsciousOfficer and return UnconsciousNPCBreach
  // This ensures manual experience control (experience only on minigame success)
  isUnconsciousBreach = Equals(actionRecord.ActionName(), BNConstants.ACTION_UNCONSCIOUS_BREACH());

  if isUnconsciousBreach {
    let unconsciousBreachAction: ref<UnconsciousNPCBreach> = new UnconsciousNPCBreach();

    if this.IsConnectedToAccessPoint() {
      let networkName: String = ToString(this.GetNetworkName());
      unconsciousBreachAction.SetProperties(
        networkName,
        ScriptedPuppetPS.GetNPCsConnectedToThisAPCount(),
        this.GetAccessPoint().GetMinigameAttempt(),
        false,  // isRemoteBreach = false
        false   // isSuicideBreach = false
      );
    } else {
      let squadNetwork: String = "SQUAD_NETWORK";
      unconsciousBreachAction.SetProperties(
        squadNetwork,
        1,
        1,
        false,  // isRemoteBreach = false
        false   // isSuicideBreach = false
      );
    }

    return unconsciousBreachAction;
  }

  // VANILLA LOGIC: Handle all other breach types
  isRemoteBreach = Equals(actionRecord.ActionName(), BNConstants.ACTION_REMOTE_BREACH());
  isSuicideBreach = Equals(actionRecord.ActionName(), BNConstants.ACTION_SUICIDE_BREACH());
  isPhysicalBreach = Equals(actionRecord.ActionName(), BNConstants.ACTION_PHYSICAL_BREACH());

  if isPhysicalBreach || isRemoteBreach || isSuicideBreach {
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
