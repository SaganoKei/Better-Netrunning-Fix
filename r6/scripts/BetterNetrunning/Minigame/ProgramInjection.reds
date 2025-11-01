module BetterNetrunning.Minigame

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Logging.*

// ============================================================================
// Program Injection Module
// ============================================================================
//
// PURPOSE:
//   Injects progressive unlock programs into the breach minigame based on
//   device state and breach point type
//
// FUNCTIONALITY:
//   - Adds unlock programs for un-breached device types
//   - Determines appropriate programs based on breach point (Access Point,
//     Computer, Backdoor, NPC)
//   - Supports remote breach integration (CustomHackingSystem)
//   - Respects progressive unlock state (m_betterNetrunningBreached* flags)
//   - Breach point classification: Access Points (full), Computers (full),
//     Backdoor Devices (limited), Netrunner NPCs (full), Regular NPCs (limited)
//
// ARCHITECTURE:
//   - Called from FilterPlayerPrograms() @wrapMethod for mod compatibility
//   - Computer classification priority: Checked BEFORE backdoor to avoid misclassification
//   - Computers EXCLUDED from backdoor check (full network access)
//   - Remote breach integration ensures proper daemon availability
//

/*
 * Injects progressive unlock programs into breach minigame
 * Programs appear only if their device type has not been breached yet
 *
 * @param programs - Reference to the array of programs to inject into
 */
@addMethod(MinigameGenerationRuleScalingPrograms)
public final func InjectBetterNetrunningPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {

  // Skip injection in Classic Mode (vanilla behavior)
  if BetterNetrunningSettings.EnableClassicMode() {
      return;
  }

  // ==================== Get Target Device State ====================

  let device: ref<SharedGameplayPS>;
  if IsDefined(this.m_entity as ScriptedPuppet) {
    // NPC breach: Get device link from puppet persistent state
    device = (this.m_entity as ScriptedPuppet).GetPS().GetDeviceLink();
    } else {
    // Device breach: Get device persistent state directly
    device = (this.m_entity as Device).GetDevicePS();
    }

  if !IsDefined(device) {
    BNError("InjectBetterNetrunningPrograms", "device (SharedGameplayPS) is null!");
    return;
  }

  // ==================== Determine Breach Point Type ====================

  // Check if breaching from an access point
  let isAccessPoint: Bool = IsDefined(this.m_entity as AccessPoint);

  // Check if breaching from an unconscious NPC
  let isUnconsciousNPC: Bool = IsDefined(this.m_entity as ScriptedPuppet);

  // Check if the NPC is a netrunner (full network access)
  let isNetrunner: Bool = isUnconsciousNPC && (this.m_entity as ScriptedPuppet).IsNetrunnerPuppet();

  // CRITICAL FIX: Remote breach support (CustomHackingSystem integration)
  // Remote breach should behave like Access Point breach (full network access)
  // PRIORITY: Check isComputer BEFORE isBackdoor to avoid misclassification
  let devicePS: ref<ScriptableDeviceComponentPS> = (this.m_entity as Device).GetDevicePS();
  let isComputer: Bool = IsDefined(devicePS) && DaemonFilterUtils.IsComputer(devicePS);

  // CRITICAL FIX: Backdoor check must EXCLUDE Computers
  // Computers can be connected to backdoor network, but should NOT be treated as backdoor breach points
  let isBackdoor: Bool = !isAccessPoint && !isComputer && IsDefined(this.m_entity as Device) && (this.m_entity as Device).GetDevicePS().IsConnectedToBackdoorDevice();

  // ==================== Inject Unlock Programs ====================

  // Add unlock programs for un-breached device types
  // Programs are inserted at the beginning of the array (highest priority)

  // Track which programs were added
  let turretAdded: Bool = false;
  let cameraAdded: Bool = false;
  let npcAdded: Bool = false;
  let basicAdded: Bool = false;

  // TURRETS: Access Points, Computers, or Netrunners
  // Backdoor devices do NOT have turret access (security restriction)
  if !BreachStatusUtils.IsTurretsBreached(device) && (isAccessPoint || isComputer || isNetrunner) {
    let turretAccessProgram: MinigameProgramData;
    turretAccessProgram.actionID = BNConstants.PROGRAM_UNLOCK_TURRET_QUICKHACKS();
    turretAccessProgram.programName = BNConstants.LOCKEY_ACCESS();
    ArrayInsert(Deref(programs), 0, turretAccessProgram);
    turretAdded = true;
  }

  // CAMERAS: Access Points, Computers, Backdoors, or Netrunners
  // Backdoor devices HAVE camera access (surveillance network connection)
  if !BreachStatusUtils.IsCamerasBreached(device) && (isAccessPoint || isComputer || isBackdoor || isNetrunner) {
    let cameraAccessProgram: MinigameProgramData;
    cameraAccessProgram.actionID = BNConstants.PROGRAM_UNLOCK_CAMERA_QUICKHACKS();
    cameraAccessProgram.programName = BNConstants.LOCKEY_ACCESS();
    ArrayInsert(Deref(programs), 0, cameraAccessProgram);
    cameraAdded = true;
  }

  // NPCs: Access Points, Computers, Unconscious NPCs, or Netrunners
  // Backdoor devices do NOT have NPC access (requires full network or direct neural link)
  if !BreachStatusUtils.IsNPCsBreached(device) && (isAccessPoint || isComputer || isUnconsciousNPC || isNetrunner) {
    let npcAccessProgram: MinigameProgramData;
    npcAccessProgram.actionID = BNConstants.PROGRAM_UNLOCK_NPC_QUICKHACKS();
    npcAccessProgram.programName = BNConstants.LOCKEY_ACCESS();
    ArrayInsert(Deref(programs), 0, npcAccessProgram);
    npcAdded = true;
  }

  // BASIC: All breach points (always available)
  // This is the root access program - available from any breach point
  if !BreachStatusUtils.IsBasicBreached(device) {
    let basicAccessProgram: MinigameProgramData;
    basicAccessProgram.actionID = BNConstants.PROGRAM_UNLOCK_QUICKHACKS();
    basicAccessProgram.programName = BNConstants.LOCKEY_ACCESS();
    ArrayInsert(Deref(programs), 0, basicAccessProgram);
    basicAdded = true;
  }

  // Log summary of injected programs (debug mode only)
  BNDebug("ProgramInjection", s"Program injection complete: Turret=\(turretAdded), Camera=\(cameraAdded), NPC=\(npcAdded), Basic=\(basicAdded)");

}
