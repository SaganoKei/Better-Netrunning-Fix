// ============================================================================
// BetterNetrunning - Debug Utilities
// ============================================================================
// HIGH-LEVEL DEBUG LOGGING FUNCTIONS
//
// PURPOSE:
//   Provides structured debug information logging for program filtering operations
//   Built on top of Logger.reds (BNInfo/BNDebug functions)
//
// ARCHITECTURE:
//   DebugUtils (this file) -> Logger.reds -> RED4ext.ModLog
//
// FEATURES:
//   - Program filtering step-by-step logging (daemon removal tracking)
//   - Filtering summary output (removed program list)
//
// USAGE:
//   - Call LogProgramFilteringStep() during daemon filtering (betterNetrunning.reds)
//   - Call LogFilteringSummary() after filtering completion (betterNetrunning.reds)
//   - Enable via EnableDebugLog setting in config
//   - Control detail level via DebugLogLevel setting (2=INFO, 3=DEBUG)
//
// DESIGN NOTES:
//   - All functions check EnableDebugLog setting before output
//   - Uses BNInfo/BNDebug from Logger.reds (never calls ModLog directly)
//   - Breach statistics are handled by BreachSessionLogger.reds (no duplication)
// ============================================================================

module BetterNetrunning.Logging

import BetterNetrunning.Core.*
import BetterNetrunning.Utils.*
import BetterNetrunningConfig.*

// ============================================================================
// PROGRAM FILTERING LOGGING
// ============================================================================

// Log program filtering step with initial/final program count state
public func LogProgramFilteringStep(
  filterName: String,
  programsBefore: Int32,
  programsAfter: Int32,
  removedProgram: TweakDBID,
  opt logContext: String
) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Filter]";

  if programsBefore != programsAfter {
    let programName: String = DaemonFilterUtils.GetDaemonDisplayName(removedProgram);
    BNDebug(context, filterName + ": Removed " + programName +
          " (" + ToString(programsBefore) + " → " + ToString(programsAfter) + " programs)");
  }
}

// Log filtering summary with removed program details
public func LogFilteringSummary(
  initialCount: Int32,
  finalCount: Int32,
  removedPrograms: array<TweakDBID>,
  opt logContext: String
) -> Void {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return;
  }

  let context: String = NotEquals(logContext, "") ? logContext : "[Filter]";
  let removedCount: Int32 = initialCount - finalCount;

  BNInfo(context, "===== FILTERING SUMMARY =====");
  BNInfo(context, "Initial programs: " + ToString(initialCount));
  BNInfo(context, "Final programs: " + ToString(finalCount));
  BNInfo(context, "Removed programs: " + ToString(removedCount));

  if removedCount > 0 {
    BNDebug(context, "--- Removed Program List ---");
    let i: Int32 = 0;
    while i < ArraySize(removedPrograms) {
      let programName: String = DaemonFilterUtils.GetDaemonDisplayName(removedPrograms[i]);
      BNDebug(context, ToString(i + 1) + ". " + programName +
            " (" + TDBID.ToStringDEBUG(removedPrograms[i]) + ")");
      i += 1;
    }
  }

  BNInfo(context, "=============================");
}
