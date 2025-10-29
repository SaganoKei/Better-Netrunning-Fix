// ============================================================================
// RemoteBreachStateSystem - RemoteBreach State Management
// ============================================================================
//
// PURPOSE:
// Tracks RemoteBreach targets for deferred network unlock processing
// in FinalizeNetrunnerDive (consistent with AccessPoint breach pattern).
//
// FUNCTIONALITY:
// - RegisterRemoteBreachTarget(): Stores device PS reference from CompleteAction
// - GetRemoteBreachTarget(): Retrieves target for FinalizeNetrunnerDive processing
// - HasPendingRemoteBreach(): Checks if RemoteBreach target registered
// - ClearRemoteBreachTarget(): Cleans up after processing
//
// ARCHITECTURE:
// - ScriptableSystem singleton pattern (one instance per game session)
// - Transient state (no persistence needed - cleared after dive)
// - Thread-safe (accessed only from main thread during breach events)
//
// DEPENDENCIES:
// - None (core infrastructure only)
//
// USAGE PATTERN:
// 1. CompleteAction ↁERegisterRemoteBreachTarget(devicePS)
// 2. FinalizeNetrunnerDive ↁEGetRemoteBreachTarget() ↁEprocess unlock
// 3. FinalizeNetrunnerDive ↁEClearRemoteBreachTarget()
//
// DESIGN RATIONALE:
// Deferred processing enables consistent unlock behavior with AccessPoint:
// - Daemon success detection via ActivePrograms Blackboard
// - Network unlock with proper device hierarchy traversal
// - Radial unlock with position-based tracking
// ============================================================================

module BetterNetrunning.RemoteBreach

import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*

// ============================================================================
// RemoteBreachStateSystem - Singleton state tracker
// ============================================================================
public class RemoteBreachStateSystem extends ScriptableSystem {

  // ==================== State Storage ====================

  // Current RemoteBreach target device (cleared after processing)
  private let m_remoteBreachTarget: wref<ScriptableDeviceComponentPS>;

  // ==================== Lifecycle ====================

  /*
   * System initialization
   * Called once per game session start
   */
  private func OnAttach() -> Void {
    BNInfo("RemoteBreachState", "System attached");
  }

  /*
   * System cleanup
   * Called on game session end
   */
  private func OnDetach() -> Void {
    this.ClearRemoteBreachTarget();
    BNInfo("RemoteBreachState", "System detached");
  }

  // ==================== Public API ====================

  /*
   * Registers RemoteBreach target device for deferred processing
   * Called from ScriptableDeviceAction.CompleteAction()
   */
  public func RegisterRemoteBreachTarget(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
    // Guard: Invalid device PS
    if !IsDefined(devicePS) {
      return;
    }

    // Store weak reference (automatically cleared if device destroyed)
    this.m_remoteBreachTarget = devicePS;

    BNDebug("RemoteBreachState",
      "RemoteBreach target registered: " + devicePS.GetDeviceName());
  }

  /*
   * Retrieves pending RemoteBreach target
   * Returns null if no target registered or target destroyed
   */
  public func GetRemoteBreachTarget() -> wref<ScriptableDeviceComponentPS> {
    return this.m_remoteBreachTarget;
  }

  /*
   * Checks if RemoteBreach target is pending
   * Used by FinalizeNetrunnerDive to detect RemoteBreach events
   */
  public func HasPendingRemoteBreach() -> Bool {
    return IsDefined(this.m_remoteBreachTarget);
  }

  /*
   * Clears RemoteBreach target after processing
   * Called by FinalizeNetrunnerDive after unlock completion
   */
  public func ClearRemoteBreachTarget() -> Void {
    this.m_remoteBreachTarget = null;

    BNDebug("RemoteBreachState", "RemoteBreach target cleared");
  }
}
