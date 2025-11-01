// ============================================================================
// BetterNetrunning - DNR Integration
// ============================================================================
//
// PURPOSE:
// Compatibility layer for Daemon Netrunning Revamp (DNR) MOD integration
//
// FUNCTIONALITY:
// - DNR daemon filtering with subnet-based gating
// - Queue Mastery requirement enforcement
// - Network Breach requirement validation
// - Conditional compilation for DNR MOD presence
//
// ARCHITECTURE:
// - Conditional imports using @if(ModuleExists("DNR.Replace"))
// - DNR daemon removal when prerequisites not met
// - Integration with Better Netrunning breach status
//

module BetterNetrunning.Integration

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*

@if(ModuleExists("DNR.Replace"))
import DNR.Core.*

@if(ModuleExists("DNR.Replace"))
import DNR.Settings.*

// Apply DNR daemon filtering with subnet-based gating
// DNR daemons require: Basic subnet + NPC subnet breach
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
