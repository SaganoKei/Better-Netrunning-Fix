// ============================================================================
// DEVICE NETWORK ACCESS RELAXATION
// ============================================================================
//
// PURPOSE:
// Relaxes vanilla network connection requirements to give players more
// freedom in choosing their approach to hacking and infiltration.
//
// FEATURES:
// - All doors can show QuickHack menu (not just AP-connected ones)
// - Standalone devices can use RemoteBreach (not just networked ones)
// - All devices can use Ping for reconnaissance
//
// PHILOSOPHY:
// This aligns with the "Better Netrunning" design goal of making netrunning
// more flexible and player-driven, rather than being constrained by arbitrary
// network topology limitations.
// ============================================================================

module BetterNetrunning.Devices

// ==================== Network Access Relaxation ====================

/*
 * Allow doors to expose QuickHacks even when not connected to Access Point
 *
 * VANILLA: Only doors connected to APs show QuickHack menu
 * BETTER NETRUNNING: All doors show QuickHack menu for player choice
 *
 * RATIONALE: Players should be able to attempt hacking any door, not just
 * those that happen to be part of a specific network topology.
 */
@wrapMethod(DoorControllerPS)
protected func ExposeQuickHakcsIfNotConnnectedToAP() -> Bool {
  let vanilla: Bool = wrappedMethod();
  if !vanilla {
    // Allow QuickHack menu on doors not connected to AP
    return true;
  }
  return vanilla;
}

/*
 * Treat standalone devices as if they're connected to a backdoor
 *
 * VANILLA: Only devices connected to breached Access Points can use RemoteBreach
 * BETTER NETRUNNING: All devices can use RemoteBreach (via Radial Unlock system)
 *
 * RATIONALE: The Radial Unlock system already provides standalone device hacking.
 * This change makes RemoteBreach action consistently available as an entry point.
 *
 * SIDE EFFECTS (20 call sites in vanilla code):
 * 1. QuickHack icon display: DetermineInitialPlaystyle() (desired ✅)
 * 2. Door QuickHack menu: Door.IsNetrunner() (desired ✅)
 * 3. Network prerequisites: ConnectedToBackdoorPrereq (desired ✅)
 * 4. Vanilla RemoteBreach addition: FinalizeGetQuickHackActions() (undesired ❌)
 *
 * NOTE: Side effect #4 is intentionally reversed by ReplaceVanillaRemoteBreachWithCustom()
 * which removes vanilla RemoteBreach and adds BetterNetrunning's CustomRemoteBreach.
 * This two-stage approach (enable → replace) is necessary because:
 * - We need side effects #1-3 for QuickHack system to work on standalone devices
 * - We cannot selectively disable side effect #4 without @replaceMethod on 290-line function
 * - Current approach maintains modularity and MOD compatibility via @wrapMethod
 */
// CRITICAL FIX (v0.6.0 Softlock Bug):
// @wrapMethod(SharedGameplayPS)
// public func IsConnectedToBackdoorDevice() -> Bool {
//   let vanilla: Bool = wrappedMethod();
//   if !vanilla {
//     // Treat standalone devices as if connected to backdoor
//     // This enables RemoteBreach action for all devices
//     return true;
//   }
//   return true;
// }

/*
 * Allow Ping on all devices regardless of network backdoor status
 *
 * VANILLA: Ping only works on devices with network backdoor
 * BETTER NETRUNNING: Ping works on all devices for reconnaissance
 *
 * RATIONALE: Ping is a reconnaissance tool. Players should be able to
 * gather information about any device they can scan, not just networked ones.
 */
 // CRITICAL FIX (v0.6.0 Softlock Bug):
// @replaceMethod(SharedGameplayPS)
// public const func HasNetworkBackdoor() -> Bool {
//   return true;
// }
