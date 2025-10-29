// ============================================================================
// RemoteBreachCostCalculator - RAM Cost Calculation
// ============================================================================
//
// PURPOSE:
// Calculates RAM cost for RemoteBreach QuickHack as a percentage
// of player's maximum RAM (Memory stat).
//
// FUNCTIONALITY:
// - Percentage-based cost: User configurable via RemoteBreachRAMCostPercent (10-100%)
// - RAM availability check: Validates sufficient RAM before execution
// - Settings integration: Respects RemoteBreachRAMCostPercent()
//
// ARCHITECTURE:
// - Pure static utility class (no instantiation)
// - Single Responsibility: RAM cost calculation only
// - Integration point: Called from ScriptableDeviceAction.GetCost()
//
// DEPENDENCIES:
// - StatsSystem (Memory stat retrieval)
// - BetterNetrunningSettings (percentage setting)
//
// DESIGN RATIONALE:
// RemoteBreach has no RAM cost (GetCost() returns 0). This calculator
// introduces simple percentage-based cost for easy user control.
// Formula: Cost = MaxRAM * (RemoteBreachRAMCostPercent / 100)
// Example: MaxRAM 20, Percent 50% ↁECost 10
// ============================================================================

module BetterNetrunning.RemoteBreach

import BetterNetrunningConfig.*
import BetterNetrunning.Core.*
import BetterNetrunning.Logging.*

// ============================================================================
// RemoteBreachCostCalculator - Static utility for RAM cost calculation
// ============================================================================
public abstract class RemoteBreachCostCalculator {

  // ==================== Public API ====================

  // Calculates RAM cost for RemoteBreach as percentage of max RAM
  // Returns 0 if player reference invalid or percentage is 0
  public static func CalculateCost(
    player: ref<GameObject>,
    gameInstance: GameInstance
  ) -> Int32 {
    // Guard: Invalid player reference
    if !IsDefined(player) {
      return 0;
    }

    let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
    let playerID: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());

    // Get max RAM (Memory stat)
    let maxRAM: Float = statsSystem.GetStatValue(playerID, gamedataStatType.Memory);

    // Get cost percentage from settings
    let percent: Int32 = BetterNetrunningSettings.RemoteBreachRAMCostPercent();

    // Calculate cost as percentage of max RAM
    let cost: Int32 = Cast<Int32>(maxRAM * Cast<Float>(percent) / 100.0);

    BNDebug("RemoteBreachCost", "RAM cost calculated: " + ToString(cost)
      + " (" + ToString(percent) + "% of " + ToString(Cast<Int32>(maxRAM)) + " max RAM)");

    return cost;
  }

  // Checks if player has sufficient RAM to pay cost
  public static func CanPayCost(
    player: ref<GameObject>,
    cost: Int32,
    gameInstance: GameInstance
  ) -> Bool {
    // Guard: Invalid player reference
    if !IsDefined(player) {
      return false;
    }

    // Guard: Zero cost always payable
    if cost <= 0 {
      return true;
    }

    // Get current available RAM
    let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
    let playerID: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());

    let currentRAM: Int32 = Cast<Int32>(statsSystem.GetStatValue(
      playerID,
      gamedataStatType.Memory
    ));

    let canPay: Bool = currentRAM >= cost;

    if !canPay {
      BNDebug("RemoteBreachCost", "Insufficient RAM: " + ToString(currentRAM)
        + "/" + ToString(cost) + " required");
    }

    return canPay;
  }
}
