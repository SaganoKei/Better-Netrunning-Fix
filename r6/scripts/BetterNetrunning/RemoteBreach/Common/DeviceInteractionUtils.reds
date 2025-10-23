// ============================================================================
// BetterNetrunning - Device Interaction Management
// ============================================================================
//
// PURPOSE:
// Manages device interaction states (JackIn, UI elements)
//
// FUNCTIONALITY:
// - Re-enable JackIn interaction after unlock expiration
// - Disable JackIn interaction after successful breach
// - Device-specific interaction control
//
// ARCHITECTURE:
// - Single Responsibility: Interaction state management only
// - Type-safe casting with IsDefined checks
// - Symmetric enable/disable operations
//
// DEPENDENCIES:
// - None (uses vanilla MasterControllerPS)
// ============================================================================

module BetterNetrunning.RemoteBreach.Common
import BetterNetrunning.Utils.*

// ============================================================================
// Device Interaction Utilities
// ============================================================================

public abstract class DeviceInteractionUtils {

  /*
   * Re-enables JackIn interaction for MasterController devices after unlock expiration
   *
   * FUNCTIONALITY:
   * - Restores JackIn interaction when quickhack unlock expires
   * - Applies to MasterControllerPS devices (AccessPoint, Computer, Terminal)
   * - No-op for non-MasterController devices (Vehicle, Camera, Turret)
   * - No-op if device is locked by AP breach failure (breach penalty system)
   * - Symmetric operation with DisableJackInInteractionForAccessPoint
   *
   * ARCHITECTURE:
   * - Type-safe casting with guard clauses
   * - Uses vanilla flag m_hasPersonalLinkSlot = true
   * - Integrates with breach penalty lock system
   * - Matches DisableJackInInteractionForAccessPoint implementation
   *
   * RATIONALE:
   * - AccessPointControllerPS.EnableInteraction(n"JackIn") does not support Computer/Terminal
   * - MasterControllerPS.SetHasPersonalLinkSlot() supports all JackIn-capable devices
   * - Enables proper expiration handling for Computer/Terminal devices
   * - Prevents JackIn re-enable if device is locked by AP breach failure
   */
  public static func EnableJackInInteractionForAccessPoint(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
    // Guard: Only MasterControllerPS devices support JackIn interaction
    let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
    if !IsDefined(masterController) { return; }

    // Guard: Do not re-enable if device is locked by AP breach failure
    if BreachLockUtils.IsJackInLockedByAPBreachFailure(devicePS) { return; }

    // Re-enable JackIn interaction (vanilla flag - symmetric with disable)
    masterController.SetHasPersonalLinkSlot(true);
  }

  /*
   * Disables JackIn interaction for MasterController devices after successful breach
   *
   * FUNCTIONALITY:
   * - Disables JackIn interaction to prevent duplicate breach
   * - Applies to MasterControllerPS devices (AccessPoint, Computer, Terminal)
   * - No-op for non-MasterController devices
   * - Symmetric operation with EnableJackInInteractionForAccessPoint
   *
   * ARCHITECTURE:
   * - Type-safe casting with guard clause
   * - Uses vanilla flag m_hasPersonalLinkSlot = false
   * - Matches vanilla SpiderbotEnableAccessPoint approach
   *
   * RATIONALE:
   * - Prevents duplicate breach (RemoteBreach + JackIn on same device)
   * - Matches vanilla behavior: AP breach disables JackIn
   * - Supports all JackIn-capable devices via MasterControllerPS
   */
  public static func DisableJackInInteractionForAccessPoint(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
    // Guard: Only MasterControllerPS devices support JackIn interaction
    let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
    if !IsDefined(masterController) { return; }

    // Disable JackIn interaction (vanilla flag - symmetric with enable)
    masterController.SetHasPersonalLinkSlot(false);
  }
}
