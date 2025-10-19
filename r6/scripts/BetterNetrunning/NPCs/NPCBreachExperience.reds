// ============================================================================
// NPC Breach - Unconscious NPC Breach Action
// ============================================================================
//
// PURPOSE:
// Custom AccessBreach implementation for unconscious NPCs that enables breach
// protocol minigame when performing takedowns on unconscious enemies.
//
// FUNCTIONALITY:
// - Extends vanilla AccessBreach with custom breach behavior
// - Integrates with Better Netrunning's daemon injection system
// - Provides TweakDB action for unconscious NPC breach
//
// ARCHITECTURE:
// - UnconsciousNPCBreach: Custom AccessBreach class
// - Simple extension of vanilla behavior
//
// DEPENDENCIES:
// - Vanilla AccessBreach class (base functionality)
// ============================================================================

module BetterNetrunning.NPCs
import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*

// ============================================================================
// UnconsciousNPCBreach - Custom AccessBreach for Unconscious NPCs
// ============================================================================
//
// Simple extension of AccessBreach that provides breach protocol for
// unconscious NPCs. Uses vanilla experience awarding and behavior.
// ============================================================================

public class UnconsciousNPCBreach extends AccessBreach {
    // Override CompleteAction to execute custom Unconscious NPC Breach processing
    //
    // CRITICAL: This method is called when breach minigame succeeds
    // We override it to call ProcessUnconsciousNPCBreachCompletion() instead of vanilla RefreshSlaves()
    //
    // ARCHITECTURE:
    // - Sets OfficerBreach flag BEFORE super.CompleteAction() to skip AccessPoint's InjectBonusDaemons()
    // - Calls super.CompleteAction() to execute vanilla breach logic (which calls RefreshSlaves())
    // - Calls PlayerPuppet.ProcessUnconsciousNPCBreachCompletion() for custom processing
    protected func CompleteAction(gameInstance: GameInstance) -> Void {
        // CRITICAL: Set OfficerBreach flag BEFORE super.CompleteAction()
        // Reason: super.CompleteAction() calls FinalizeNetrunnerDive() which calls RefreshSlaves()
        // RefreshSlaves() checks this flag to skip InjectBonusDaemons()
        this.GetNetworkBlackboard(gameInstance).SetBool(
            this.GetNetworkBlackboardDef().OfficerBreach,
            true
        );

        // Execute vanilla CompleteAction logic (calls RefreshSlaves() internally)
        // RefreshSlaves() handles statistics collection for UnconsciousNPC breach
        super.CompleteAction(gameInstance);
    }
}

// ============================================================================
// AccessBreach.CompleteAction() Wrapper - Detect Unconscious NPC Breach
// ============================================================================
//
// PURPOSE:
// Detect when vanilla AccessBreach completes on an unconscious NPC and
// execute custom NPC breach processing.
//
// ARCHITECTURE:
// - Wrap vanilla AccessBreach.CompleteAction() method
// - Check if OfficerBreach flag is set (vanilla sets this for NPC breaches)
// - If NPC breach, call ProcessUnconsciousNPCBreachCompletion()
// ============================================================================

@wrapMethod(AccessBreach)
protected func CompleteAction(gameInstance: GameInstance) -> Void {
    // Execute vanilla CompleteAction logic
    // RefreshSlaves() handles statistics collection for all breach types
    wrappedMethod(gameInstance);
}
