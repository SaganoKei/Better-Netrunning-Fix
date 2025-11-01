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

module BetterNetrunning.RemoteBreach.Common
import BetterNetrunning.Utils.*

public abstract class DeviceInteractionUtils {

  /*
   * Re-enables JackIn interaction for MasterController devices after unlock expiration
   * @param devicePS - Device persistent state to modify
   */
  public static func EnableJackInInteractionForAccessPoint(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
    let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
    if !IsDefined(masterController) { return; }

    if BreachLockUtils.IsJackInLockedByAPBreachFailure(devicePS) { return; }

    masterController.SetHasPersonalLinkSlot(true);
  }

  /*
   * Disables JackIn interaction for MasterController devices after successful breach
   * @param devicePS - Device persistent state to modify
   */
  public static func DisableJackInInteractionForAccessPoint(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
    // Guard: Only MasterControllerPS devices support JackIn interaction
    let masterController: ref<MasterControllerPS> = devicePS as MasterControllerPS;
    if !IsDefined(masterController) { return; }

    // Disable JackIn interaction (vanilla flag - symmetric with enable)
    masterController.SetHasPersonalLinkSlot(false);
  }
}
