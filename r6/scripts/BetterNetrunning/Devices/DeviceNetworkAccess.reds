// ============================================================================
// Device Network Access Relaxation
// ============================================================================
//
// PURPOSE:
//   Relaxes vanilla network connection requirements to give players more
//   freedom in choosing their approach to hacking and infiltration
//
// FUNCTIONALITY:
//   - All doors can show QuickHack menu (not just AP-connected ones)
//   - Standalone devices can use RemoteBreach (not just networked ones)
//   - All devices can use Ping for reconnaissance
//
// ARCHITECTURE:
//   - @wrapMethod pattern for mod compatibility
//   - Returns true when vanilla returns false (permissive override)
//   - Aligns with Better Netrunning design goal: flexible, player-driven netrunning
//

module BetterNetrunning.Devices

/*
 * Allows doors to expose QuickHacks even when not connected to Access Point
 *
 * VANILLA DIFF: Vanilla only shows QuickHack menu on AP-connected doors
 *
 * @return True to allow QuickHack menu on all doors
 */
@wrapMethod(DoorControllerPS)
protected func ExposeQuickHakcsIfNotConnnectedToAP() -> Bool {
  let vanilla: Bool = wrappedMethod();
  if !vanilla {
    return true;
  }
  return vanilla;
}

/*
 * Allows Ping on all devices regardless of network backdoor status.
 *
 * Vanilla diff: Vanilla only allows Ping on devices with network backdoor.
 *
 * @return True to allow Ping on all devices
 */
 // CRITICAL FIX (v0.6.0 Softlock Bug):
// @replaceMethod(SharedGameplayPS)
// public const func HasNetworkBackdoor() -> Bool {
//   return true;
// }
