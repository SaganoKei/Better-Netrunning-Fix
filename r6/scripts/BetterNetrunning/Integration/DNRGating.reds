module BetterNetrunning.Integration

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*

// DNR (Daemon Netrunning Revamp) Compatibility Layer
// This module provides integration with DNR mod's daemon system
// DNR daemons require Basic + NPC subnet breach (PR#3 implementation)
//
// Implementation based on: https://github.com/SaganoKei/Better-Netrunning-Fix/pull/3
// Credits: BiasNil (schizoabe)

// ==================== DNR Module Conditional Imports ====================

@if(ModuleExists("DNR.Replace"))
import DNR.Core.*

@if(ModuleExists("DNR.Replace"))
import DNR.Settings.*

// ==================== DNR Daemon Gating System ====================

// Apply DNR daemon filtering with subnet-based gating (PR#3 implementation)
// DNR daemons require: Basic subnet + NPC subnet breach
// Additional checks: Queue Mastery, Network Breach (from DNR settings)
@if(ModuleExists("DNR.Replace"))
public func ApplyDNRDaemonGating(
  programs: script_ref<array<MinigameProgramData>>,
  devPS: ref<SharedGameplayPS>,
  isRemoteBreach: Bool,
  player: wref<PlayerPuppet>,
  entity: wref<Entity>
) -> Void {
  // Don't show DNR daemons until Basic + NPC subnets are breached
  let dnrSubnetsBreached: Bool = IsDefined(devPS)
    && BreachStatusUtils.IsBasicBreached(devPS)
    && BreachStatusUtils.IsNPCsBreached(devPS);

  if !dnrSubnetsBreached {
    DNR_BP_RemoveAllDNRPrograms(programs);
    return;
  }

  // Apply DNR filtering logic
  let s: ref<DNR_Settings> = DNR_Svc();

  // Remove all DNR programs if queue mastery is required but not met
  if IsDefined(s) && s.bpdeviceRequiresQueueMastery && !DNR_PlayerHasQueueMastery(player) {
    DNR_BP_RemoveAllDNRPrograms(programs);
    return;
  }

  // Remove all DNR programs if network breach is required but not met
  if IsDefined(s) && s.bpdeviceRequiresNetworkBreached {
    if !DNR_BP_CheckNetworkBreached(entity, isRemoteBreach) {
      DNR_BP_RemoveAllDNRPrograms(programs);
      return;
    }
  }

  // Add DNR programs based on player's owned quickhacks
  DNR_BP_AddQualifiedPrograms(player, programs, isRemoteBreach);

  // Remove wrong variant (Remote vs AP versions)
  DNR_BP_RemoveWrongVariant(programs, isRemoteBreach);
}

// Stub implementation when DNR mod is not installed
@if(!ModuleExists("DNR.Replace"))
public func ApplyDNRDaemonGating(
  programs: script_ref<array<MinigameProgramData>>,
  devPS: ref<SharedGameplayPS>,
  isRemoteBreach: Bool,
  player: wref<PlayerPuppet>,
  entity: wref<Entity>
) -> Void {
  // No-op: DNR not installed, no gating needed
}

// ==================== DNR Non-Netrunner Filter ====================

// Returns true if ultimate hack programs should be removed when DNR mod is installed
// This filters DNR's powerful ultimate hacks from non-netrunner NPCs during remote breach
// Prevents overpowered quickhacks on regular enemies who aren't netrunner-class
@if(ModuleExists("DNR.Replace"))
public func ShouldRemoveDNRNonNetrunnerPrograms(actionID: TweakDBID) -> Bool {
  return actionID == BNConstants.PROGRAM_DNR_REMOTE_CYBERPSYCHOSIS()
      || actionID == BNConstants.PROGRAM_DNR_CYBERPSYCHOSIS_AP()
      || actionID == BNConstants.PROGRAM_DNR_REMOTE_SUICIDE()
      || actionID == BNConstants.PROGRAM_DNR_SUICIDE_AP()
      || actionID == BNConstants.PROGRAM_DNR_REMOTE_SYSTEM_RESET()
      || actionID == BNConstants.PROGRAM_DNR_SYSTEM_RESET_AP()
      || actionID == BNConstants.PROGRAM_DNR_REMOTE_DETONATE_GRENADE()
      || actionID == BNConstants.PROGRAM_DNR_DETONATE_GRENADE_AP()
      || actionID == BNConstants.PROGRAM_DNR_REMOTE_NETWORK_OVERLOAD()
      || actionID == BNConstants.PROGRAM_DNR_NETWORK_OVERLOAD_AP()
      || actionID == BNConstants.PROGRAM_DNR_REMOTE_NETWORK_CONTAGION()
      || actionID == BNConstants.PROGRAM_DNR_NETWORK_CONTAGION_AP();
}

// Stub implementation when DNR mod is not installed (always returns false)
@if(!ModuleExists("DNR.Replace"))
public func ShouldRemoveDNRNonNetrunnerPrograms(actionID: TweakDBID) -> Bool {
  return false;
}
