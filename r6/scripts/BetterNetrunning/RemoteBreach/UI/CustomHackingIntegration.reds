// -----------------------------------------------------------------------------
// CustomHackingSystem Integration Layer
// -----------------------------------------------------------------------------
// Provides integration logic between Better Netrunning and HackingExtensions MOD.
// Handles CustomAccessBreach action filtering, injection, and UI integration.
//
// RESPONSIBILITIES:
// - Replace vanilla RemoteBreach with CustomAccessBreach in device actions
// - Remove CustomAccessBreach when device already breached
// - Mark CustomAccessBreach as QuickHack (UI integration)
// - Detect CustomRemoteBreach actions (Computer/Device/Vehicle)
//
// ARCHITECTURE:
// - Static utility classes (no state)
// - Conditional compilation (@if(ModuleExists("HackingExtensions")))
// - Called from Devices/DeviceQuickhacks.reds
//
// DEPENDENCIES:
// - HackingExtensions.CustomAccessBreach (external MOD)
// - BetterNetrunning.Breach.RemoteBreachLock (breach penalty system)
// - BetterNetrunning.Common.* (logging, events)
//
// MIGRATION:
// This file consolidates CustomHackingSystem-specific logic previously scattered in:
// - Devices/DeviceQuickhacks.reds (5 functions, ~180 lines)
// - Common/Events.reds (1 function, ~10 lines)
// -----------------------------------------------------------------------------

module BetterNetrunning.RemoteBreach.UI

import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.RemoteBreach.Core.*
import BetterNetrunning.RemoteBreach.Actions.*
import BetterNetrunning.Breach.*
import BetterNetrunning.Utils.*
import BetterNetrunning.Breach.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

// =============================================================================
// CustomRemoteBreach Action Filtering
// =============================================================================

// Replaces vanilla RemoteBreach with CustomAccessBreach in device action list
// CRITICAL: Must be called AFTER vanilla FinalizeGetQuickHackActions()
@if(ModuleExists("HackingExtensions"))
public abstract class CustomRemoteBreachActionFilter {

    // Main entry point: Replaces vanilla RemoteBreach with CustomAccessBreach
    // Returns true if replacement occurred, false otherwise
    public static func ReplaceVanillaRemoteBreachWithCustom(
        devicePS: ref<ScriptableDeviceComponentPS>,
        outActions: script_ref<array<ref<DeviceAction>>>
    ) -> Bool {
        // Early return: Device already breached
        if devicePS.IsBreached() {
            CustomRemoteBreachActionFilter.RemoveVanillaRemoteBreachFromActions(outActions);
            return false;
        }

        // Early return: Device locked by breach failure
        if CustomRemoteBreachActionFilter.IsDeviceLockedByBreachFailure(devicePS) {
            CustomRemoteBreachActionFilter.RemoveAllRemoteBreachActions(outActions);
            return false;
        }

        // Replace vanilla RemoteBreach with custom implementation
        if CustomRemoteBreachActionFilter.RemoveVanillaRemoteBreachFromActions(outActions) {
            // TryAddCustomRemoteBreach() is device-specific logic in DeviceQuickhacks.reds
            // (Computer/Device/Vehicle detection + action creation)
            return true;
        }

        return false;
    }

    // Checks if device is locked due to breach failure penalty
    public static func IsDeviceLockedByBreachFailure(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        if !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
            return false;
        }

        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return false;
        }

        let player: ref<PlayerPuppet> = GetPlayer(devicePS.GetGameInstance());
        if !IsDefined(player) {
            return false;
        }

        let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
        return RemoteBreachLockUtils.IsRemoteBreachLockedForDevice(
            player, devicePosition, devicePS.GetGameInstance()
        );
    }

    // Removes vanilla RemoteBreach from action list
    // Returns true if at least one RemoteBreach was found and removed
    public static func RemoveVanillaRemoteBreachFromActions(
        outActions: script_ref<array<ref<DeviceAction>>>
    ) -> Bool {
        let i: Int32 = ArraySize(Deref(outActions)) - 1;
        let vanillaRemoteBreachFound: Bool = false;

        while i >= 0 {
            let action: ref<DeviceAction> = Deref(outActions)[i];
            if IsDefined(action as RemoteBreach) {
                ArrayErase(Deref(outActions), i);
                vanillaRemoteBreachFound = true;
            }
            i -= 1;
        }

        return vanillaRemoteBreachFound;
    }

    // Removes ALL RemoteBreach-related actions (vanilla + custom)
    // Used when device is locked by breach failure penalty
    // ARCHITECTURE: Delegate to RemoteBreachLockUtils.RemoveAllRemoteBreachActions (single source of truth)
    public static func RemoveAllRemoteBreachActions(
        outActions: script_ref<array<ref<DeviceAction>>>
    ) -> Void {
        RemoteBreachLockUtils.RemoveAllRemoteBreachActions(outActions);
    }

    // Removes CustomAccessBreach if device already breached
    // Prevents redundant breach action when device quickhacks already available
    public static func RemoveCustomAccessBreachIfUnlocked(
        devicePS: ref<ScriptableDeviceComponentPS>,
        outActions: script_ref<array<ref<DeviceAction>>>
    ) -> Void {
        if !devicePS.IsBreached() {
            return;
        }

        let i: Int32 = ArraySize(Deref(outActions)) - 1;

        while i >= 0 {
            let action: ref<DeviceAction> = Deref(outActions)[i];

            // Check vanilla RemoteBreach
            if IsDefined(action as RemoteBreach) {
                ArrayErase(Deref(outActions), i);
            }

            // Check CustomAccessBreach
            let customBreachAction: ref<CustomAccessBreach> = action as CustomAccessBreach;
            if IsDefined(customBreachAction) {
                ArrayErase(Deref(outActions), i);
            }

            i -= 1;
        }
    }
}

// Fallback version when HackingExtensions not installed
@if(!ModuleExists("HackingExtensions"))
public abstract class CustomRemoteBreachActionFilter {
    // All methods become no-ops when HackingExtensions not available
    public static func ReplaceVanillaRemoteBreachWithCustom(
        devicePS: ref<ScriptableDeviceComponentPS>,
        outActions: script_ref<array<ref<DeviceAction>>>
    ) -> Bool {
        return false;
    }

    public static func IsDeviceLockedByBreachFailure(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return false;
    }

    public static func RemoveVanillaRemoteBreachFromActions(
        outActions: script_ref<array<ref<DeviceAction>>>
    ) -> Bool {
        return false;
    }

    public static func RemoveAllRemoteBreachActions(
        outActions: script_ref<array<ref<DeviceAction>>>
    ) -> Void {
        // No-op (HackingExtensions not installed)
    }

    public static func RemoveCustomAccessBreachIfUnlocked(
        devicePS: ref<ScriptableDeviceComponentPS>,
        outActions: script_ref<array<ref<DeviceAction>>>
    ) -> Void {
        // No-op
    }
}

// =============================================================================
// CustomAccessBreach UI Integration
// =============================================================================

// Marks CustomAccessBreach actions as QuickHacks for UI display
// CRITICAL FIX: CustomAccessBreach extends PuppetAction, not ScriptableDeviceAction,
// so base game MarkActionsAsQuickHacks() skips it
@if(ModuleExists("HackingExtensions"))
public abstract class CustomAccessBreachMarker {

    // Marks all CustomAccessBreach actions in list as QuickHacks
    // Called from DeviceQuickhacks.reds MarkActionsAsQuickHacks() wrapper
    public static func MarkCustomAccessBreachAsQuickHacks(
        actionsToMark: script_ref<array<ref<DeviceAction>>>
    ) -> Void {
        let i: Int32 = 0;

        while i < ArraySize(Deref(actionsToMark)) {
            // Check for CustomAccessBreach (CustomHackingSystem actions)
            let customBreachAction: ref<CustomAccessBreach> = Deref(actionsToMark)[i] as CustomAccessBreach;
            if IsDefined(customBreachAction) {
                customBreachAction.SetAsQuickHack();
            }

            i += 1;
        }
    }
}

// Fallback version when HackingExtensions not installed
@if(!ModuleExists("HackingExtensions"))
public abstract class CustomAccessBreachMarker {
    public static func MarkCustomAccessBreachAsQuickHacks(
        actionsToMark: script_ref<array<ref<DeviceAction>>>
    ) -> Void {
        // No-op
    }
}

// NOTE: CustomRemoteBreachActionDetector class removed (2025-10-16)
// RATIONALE: Duplicate implementation consolidated to Common/Events.reds
// All calls now use: IsCustomRemoteBreachAction(className) from BetterNetrunning.Common
// See DEVELOPMENT_GUIDELINES.md - "Avoiding Circular Dependencies While Maintaining DRY"
