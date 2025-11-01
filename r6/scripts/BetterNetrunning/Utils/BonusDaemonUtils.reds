// ============================================================================
// BetterNetrunning - Bonus Daemon Utilities
// ============================================================================
// Auto-execute PING quickhack and auto-apply Datamine based on success count
// ============================================================================

module BetterNetrunning.Utils
import BetterNetrunning.Logging.*

import BetterNetrunning.Core.*
import BetterNetrunning.Utils.DaemonFilterUtils
import BetterNetrunningConfig.*

public abstract class BonusDaemonUtils {

  // ============================================================================
  // Bonus Daemon Application
  // ============================================================================

  /*
   * Apply bonus daemons based on settings and success count
   *
   * @param activePrograms - Array of successfully uploaded daemon programs (modified in-place)
   * @param gi - GameInstance for settings access
   * @param logContext - Optional context string for logging
   */
  public static func ApplyBonusDaemons(
    activePrograms: script_ref<array<TweakDBID>>,
    gi: GameInstance,
    opt logContext: String
  ) -> Void {
      let successCount: Int32 = ArraySize(Deref(activePrograms));

    if successCount == 0 {
      return; // No successful daemons
    }

    let pingEnabled: Bool = BetterNetrunningSettings.AutoExecutePingOnSuccess();

    if pingEnabled {
      let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().HackingMinigame);

      let targetEntity: wref<Entity> = FromVariant<wref<Entity>>(
        minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity)
      );

      if IsDefined(targetEntity) {
        BonusDaemonUtils.ExecutePingQuickHackOnTarget(targetEntity, gi, logContext);
      }
    }

    let datamineEnabled: Bool = BetterNetrunningSettings.AutoDatamineBySuccessCount();

    if datamineEnabled {
      let nonDatamineCount: Int32 = BonusDaemonUtils.CountNonDataminePrograms(Deref(activePrograms));
      let hasDatamine: Bool = BonusDaemonUtils.HasAnyDatamineProgram(Deref(activePrograms));

      if NotEquals(logContext, "") {
        BNTrace(logContext, "Non-Datamine daemon count: " + ToString(nonDatamineCount) + ", Has Datamine: " + ToString(hasDatamine));
      }

      if nonDatamineCount > 0 && !hasDatamine {
        let datamineToAdd: TweakDBID;
        let logMessage: String;

        if nonDatamineCount >= 3 {
          datamineToAdd = BNConstants.PROGRAM_DATAMINE_MASTER();
          logMessage = "DatamineV3 (3+ daemons succeeded)";
        } else if nonDatamineCount == 2 {
          datamineToAdd = BNConstants.PROGRAM_DATAMINE_ADVANCED();
          logMessage = "DatamineV2 (2 daemons succeeded)";
        } else if nonDatamineCount == 1 {
          datamineToAdd = BNConstants.PROGRAM_DATAMINE_BASIC();
          logMessage = "DatamineV1 (1 daemon succeeded)";
        }

        ArrayPush(Deref(activePrograms), datamineToAdd);

        if NotEquals(logContext, "") {
          BNDebug(logContext, "Bonus Daemon: Auto-added " + logMessage);
        }
      }
    }

    // Log final program count (debug mode only)
    if NotEquals(logContext, "") {
      let finalCount: Int32 = ArraySize(Deref(activePrograms));
      BNTrace(logContext, "Final program count: " + ToString(finalCount));
    }
  }

  // ============================================================================
  // Program Detection Utilities
  // ============================================================================

  // Check if programs array contains a specific program
  public static func HasProgram(programs: array<TweakDBID>, programID: TweakDBID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(programs) {
      if Equals(programs[i], programID) {
        return true;
      }
      i += 1;
    }
    return false;
  }

  /*
   * CountNonDataminePrograms() - Non-Datamine Program Counter
   *
   * Returns the number of daemons that are NOT Datamine programs (for auto-datamine feature).
   *
   * @param programs Array of program TweakDBIDs
   * @return Count of non-Datamine programs
   */
  public static func CountNonDataminePrograms(programs: array<TweakDBID>) -> Int32 {
    let count: Int32 = 0;
    let i: Int32 = 0;

    while i < ArraySize(programs) {
      if !BonusDaemonUtils.IsDatamineDaemon(programs[i]) {
        count += 1;
      }

      i += 1;
    }

    return count;
  }

  // Check if any Datamine program exists in array
  public static func HasAnyDatamineProgram(programs: array<TweakDBID>) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(programs) {
      if BonusDaemonUtils.IsDatamineDaemon(programs[i]) {
        return true;
      }

      i += 1;
    }
    return false;
  }

  // Check if program is a Datamine daemon (bonus daemon)
  public static func IsDatamineDaemon(programID: TweakDBID) -> Bool {
    return Equals(programID, BNConstants.PROGRAM_DATAMINE_BASIC())
        || Equals(programID, BNConstants.PROGRAM_DATAMINE_ADVANCED())
        || Equals(programID, BNConstants.PROGRAM_DATAMINE_MASTER());
  }

  // ============================================================================
  // PING QuickHack Execution
  // ============================================================================

  /*
   * Execute PING quickhack on breach target entity
   *
   * @param targetEntity - Target entity (Device or NPC)
   * @param gi - GameInstance
   * @param logContext - Optional context string for logging
   */
  public static func ExecutePingQuickHackOnTarget(targetEntity: wref<Entity>, gi: GameInstance, opt logContext: String) -> Void {
    if !IsDefined(targetEntity) {
      if NotEquals(logContext, "") {
        BNError(logContext, "[PING] Target entity not defined");
      }
      return;
    }

    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if !IsDefined(player) {
      if NotEquals(logContext, "") {
        BNError(logContext, "[PING] Player not found");
      }
      return;
    }

    let targetDevice: ref<Device> = targetEntity as Device;
    let targetNPC: ref<ScriptedPuppet> = targetEntity as ScriptedPuppet;

    if IsDefined(targetDevice) {
      if NotEquals(logContext, "") {
        BNDebug(logContext, "[PING] Executing PING on Device: " + NameToString(targetDevice.GetClassName()));
      }
      BonusDaemonUtils.ExecutePingQuickHackOnDevice(targetDevice, player, logContext);
    } else if IsDefined(targetNPC) {
      if NotEquals(logContext, "") {
        BNDebug(logContext, "[PING] Executing PING on NPC: " + NameToString(targetNPC.GetClassName()));
      }
      BonusDaemonUtils.ExecutePingQuickHackOnNPC(targetNPC, player, logContext);
    } else {
      if NotEquals(logContext, "") {
        BNError(logContext, "[PING] Unknown target type (not Device or NPC)");
      }
    }
  }

  /*
   * Execute PING quickhack on Device
   *
   * @param targetDevice - Target device entity
   * @param player - Player puppet
   * @param logContext - Optional context string for logging
   */
  private static func ExecutePingQuickHackOnDevice(targetDevice: ref<Device>, player: ref<PlayerPuppet>, opt logContext: String) -> Void {
    let devicePS: ref<ScriptableDeviceComponentPS> = targetDevice.GetDevicePS();
    if !IsDefined(devicePS) {
      if NotEquals(logContext, "") {
        BNError(logContext, "[PING] Device PS not found");
      }
      return;
    }

    let pingAction: ref<ScriptableDeviceAction> = devicePS.ActionPing();
    if !IsDefined(pingAction) {
      return;
    }

    pingAction.SetExecutor(player);
    pingAction.RegisterAsRequester(targetDevice.GetEntityID());

    let gi: GameInstance = targetDevice.GetGame();

    if NotEquals(logContext, "") {
      BNTrace(logContext, "[PING] Executing auto-PING on device via ProcessRPGAction: " + NameToString(targetDevice.GetClassName()));
    }

    pingAction.SetCanSkipPayCost(true);
    pingAction.ProcessRPGAction(gi);

    if NotEquals(logContext, "") {
      BNDebug(logContext, "[PING] Auto-PING completed on device");
    }
  }

  /*
   * Execute PING quickhack on NPC
   *
   * @param targetNPC - Target NPC entity
   * @param player - Player puppet
   * @param logContext - Optional context string for logging
   */
  private static func ExecutePingQuickHackOnNPC(targetNPC: ref<ScriptedPuppet>, player: ref<PlayerPuppet>, opt logContext: String) -> Void {
    let npcPS: ref<ScriptedPuppetPS> = targetNPC.GetPuppetPS();
    if !IsDefined(npcPS) {
      if NotEquals(logContext, "") {
        BNError(logContext, "[PING] NPC PS not found");
      }
      return;
    }

    let context: GetActionsContext = npcPS.GenerateContext(
      gamedeviceRequestType.Remote,
      Device.GetInteractionClearance(),
      player,
      targetNPC.GetEntityID()
    );

    let actionRecords: array<wref<ObjectAction_Record>>;
    let puppetActions: array<ref<PuppetAction>>;

    targetNPC.GetRecord().ObjectActions(actionRecords);
    npcPS.GetAllChoices(actionRecords, context, puppetActions);

    let pingAction: ref<PuppetAction>;
    let i: Int32 = 0;
    while i < ArraySize(puppetActions) {
      if Equals(puppetActions[i].GetObjectActionID(), t"QuickHack.BasePingHack") {
        pingAction = puppetActions[i];
        break;
      }
      i += 1;
    }

    if !IsDefined(pingAction) {
      return;
    }

    pingAction.SetExecutor(player);
    pingAction.RegisterAsRequester(targetNPC.GetEntityID());

    let gi: GameInstance = targetNPC.GetGame();

    if NotEquals(logContext, "") {
      BNTrace(logContext, "[PING] Executing auto-PING via ProcessRPGAction - Target: " + ToString(targetNPC.GetEntityID()) + ", Action: " + TDBID.ToStringDEBUG(pingAction.GetObjectActionID()));
    }

    pingAction.SetCanSkipPayCost(true);
    pingAction.ProcessRPGAction(gi, targetNPC.GetGameplayRoleComponent());

    if NotEquals(logContext, "") {
      BNDebug(logContext, "[PING] Auto-PING completed via ProcessRPGAction");
    }
  }

} // class BonusDaemonUtils
