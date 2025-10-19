// ============================================================================
// TracePositionOverhaul Integration - Position Reveal Trace Support
// ============================================================================
//
// PURPOSE:
// Provide conditional integration with TracePositionOverhaul MOD for enhanced
// netrunner trace mechanics. Isolates all TracePositionOverhaul dependencies
// in a single file for maintainability.
//
// FUNCTIONALITY:
// - Netrunner validation (enhanced vs basic)
// - NPC radius search (real vs stub)
// - Trace execution support
//
// MOD DEPENDENCY:
// - TracePositionOverhaul (optional)
// - https://www.nexusmods.com/cyberpunk2077/mods/XXXX
//
// FALLBACK BEHAVIOR (MOD disabled):
// - IsValidTraceSource(): Basic vanilla validation (IsAlive, IsDefeated, IsNetrunnerPuppet)
// - GetNPCsInRadius(): Returns empty array (skip search)
// - Trace system gracefully degrades to virtual trace (no penalties)
//
// INTEGRATION POINTS:
// - Breach/BreachPenaltySystem.reds: Breach failure trace trigger
//
// ARCHITECTURE:
// - Dual implementation pattern (real + stub)
// - Conditional compilation via @if(ModuleExists("TracePositionOverhaul"))
// - Same function signatures for both variants (no caller-side conditionals)
// ============================================================================

module BetterNetrunning.Integration

@if(ModuleExists("TracePositionOverhaul"))
import TracePositionOverhaul.*

// ============================================================================
// TracePositionOverhaulGating - Static Utility Class
// ============================================================================

public abstract class TracePositionOverhaulGating {

  // ============================================================================
  // IsValidTraceSource() - Validate Netrunner NPC for Trace
  // ============================================================================
  //
  // Determine if NPC can initiate position reveal trace.
  //
  // VALIDATION CHECKS:
  // 1. WITH TracePositionOverhaul:
  //    - Basic: IsAlive, not defeated, IsNetrunnerPuppet
  //    - Enhanced: CanTrace() (checks HackInterrupt StatusEffect, unconscious, etc.)
  // 2. WITHOUT TracePositionOverhaul:
  //    - Basic only: IsAlive, not defeated, IsNetrunnerPuppet
  //
  // RETURNS:
  // - true: NPC is valid trace source
  // - false: NPC cannot trace (defeated, hacked, not netrunner, etc.)
  // ============================================================================

  // Version 1: TracePositionOverhaul available - use enhanced validation
  @if(ModuleExists("TracePositionOverhaul"))
  public static func IsValidTraceSource(npc: wref<NPCPuppet>) -> Bool {
    // Basic checks
    if !IsDefined(npc) { return false; }
    if !ScriptedPuppet.IsAlive(npc) { return false; }
    if ScriptedPuppet.IsDefeated(npc) { return false; }

    // TracePositionOverhaul enhanced validation
    // - Checks HackInterrupt StatusEffect (prevents trace if netrunner is being hacked)
    // - Checks unconscious state, stunned state, etc.
    if !ScriptedPuppet.CanTrace(npc) { return false; }

    // Netrunner check
    if !npc.IsNetrunnerPuppet() { return false; }

    return true;
  }

  // Version 2: TracePositionOverhaul NOT available - use basic validation
  @if(!ModuleExists("TracePositionOverhaul"))
  public static func IsValidTraceSource(npc: wref<NPCPuppet>) -> Bool {
    // Basic checks (vanilla API only)
    if !IsDefined(npc) { return false; }
    if !ScriptedPuppet.IsAlive(npc) { return false; }
    if ScriptedPuppet.IsDefeated(npc) { return false; }

    // Netrunner check
    if !npc.IsNetrunnerPuppet() { return false; }

    return true;
  }

  // ============================================================================
  // GetNPCsInRadius() - Get NPCs Within Radius
  // ============================================================================
  //
  // Retrieve all NPCs within specified radius of player using TargetingSystem.
  //
  // IMPLEMENTATION VARIANTS:
  // 1. WITH TracePositionOverhaul: Performs actual search (real netrunner support)
  // 2. WITHOUT TracePositionOverhaul: Returns empty array (skip search, use fallback)
  //
  // PARAMETERS:
  // - player: PlayerPuppet reference
  // - gameInstance: GameInstance reference
  // - radius: Search radius in meters
  //
  // RETURNS:
  // - Array of GameObject references (NPCs within radius)
  // ============================================================================

  // Version 1: TracePositionOverhaul available - perform actual NPC search
  @if(ModuleExists("TracePositionOverhaul"))
  public static func GetNPCsInRadius(
    player: wref<PlayerPuppet>,
    gameInstance: GameInstance,
    radius: Float
  ) -> array<ref<GameObject>> {
    let npcs: array<ref<GameObject>>;

    // Use TargetingSystem for efficient radius search
    let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);

    // Setup search query
    let searchQuery: TargetSearchQuery;
    searchQuery.testedSet = TargetingSet.Complete;
    searchQuery.searchFilter = TSF_All(TSFMV.Obj_Puppet);  // All puppets (NPCs)
    searchQuery.maxDistance = radius;
    searchQuery.filterObjectByDistance = true;
    searchQuery.includeSecondaryTargets = false;
    searchQuery.ignoreInstigator = true;

    let targetParts: array<TS_TargetPartInfo>;
    targetingSystem.GetTargetParts(player, searchQuery, targetParts);

    // Extract NPCs from targeting components
    let i: Int32 = 0;
    while i < ArraySize(targetParts) {
      let targetComponent: ref<TargetingComponent> = TS_TargetPartInfo.GetComponent(targetParts[i]);
      if IsDefined(targetComponent) {
        let obj: ref<GameObject> = targetComponent.GetEntity() as GameObject;
        if IsDefined(obj) && obj.IsNPC() {
          ArrayPush(npcs, obj);
        }
      }
      i += 1;
    }

    return npcs;
  }

  // Version 2: TracePositionOverhaul NOT available - return empty array
  @if(!ModuleExists("TracePositionOverhaul"))
  public static func GetNPCsInRadius(
    player: wref<PlayerPuppet>,
    gameInstance: GameInstance,
    radius: Float
  ) -> array<ref<GameObject>> {
    // Return empty array (skip search)
    // Caller will use fallback behavior (no real netrunner trace)
    let npcs: array<ref<GameObject>>;
    return npcs;
  }

  // ============================================================================
  // FindNearestValidTraceSource() - Find Nearest Valid Netrunner
  // ============================================================================
  //
  // Search for nearest valid netrunner NPC within radius that can initiate trace.
  //
  // ALGORITHM:
  // 1. GetNPCsInRadius() to get all NPCs within range
  // 2. Filter by IsValidTraceSource() (netrunner validation)
  // 3. Calculate squared distances (avoid sqrt overhead)
  // 4. Return nearest valid netrunner
  //
  // RETURNS:
  // - wref<NPCPuppet>: Nearest valid netrunner (if found)
  // - null: No valid netrunner within radius (or TracePositionOverhaul not installed)
  //
  // PERFORMANCE:
  // - Distance calculation: Vector4.DistanceSquared2D() (no sqrt)
  // - Early exit: Returns immediately if no NPCs found
  // ============================================================================

  public static func FindNearestValidTraceSource(
    player: wref<PlayerPuppet>,
    gameInstance: GameInstance,
    radius: Float
  ) -> wref<NPCPuppet> {
    // Get all NPCs within radius (empty array if TracePositionOverhaul not installed)
    let npcs: array<ref<GameObject>> = TracePositionOverhaulGating.GetNPCsInRadius(player, gameInstance, radius);

    // Early exit if no NPCs found
    if ArraySize(npcs) == 0 {
      return null;
    }

    // Filter and find nearest valid netrunner
    let playerPos: Vector4 = player.GetWorldPosition();
    let nearestNPC: wref<NPCPuppet>;
    let nearestDistSq: Float = radius * radius; // Squared distance threshold

    let i: Int32 = 0;
    let count: Int32 = ArraySize(npcs);
    while i < count {
      let npcPuppet: wref<NPCPuppet> = npcs[i] as NPCPuppet;

      // Validate netrunner NPC
      if TracePositionOverhaulGating.IsValidTraceSource(npcPuppet) {
        let npcPos: Vector4 = npcPuppet.GetWorldPosition();
        let distSq: Float = Vector4.DistanceSquared2D(playerPos, npcPos);

        // Update nearest if closer
        if distSq < nearestDistSq {
          nearestDistSq = distSq;
          nearestNPC = npcPuppet;
        }
      }

      i += 1;
    }

    return nearestNPC;
  }

} // class TracePositionOverhaulGating
