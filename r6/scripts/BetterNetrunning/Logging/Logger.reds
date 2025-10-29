// ============================================================================
// BetterNetrunning - Unified Logging System
// ============================================================================
// 5-LEVEL LOG SYSTEM WITH DUPLICATE SUPPRESSION
//
// PURPOSE:
//   Provides structured logging with log levels, duplicate suppression,
//   and settings integration for debug output control
//
// LOG LEVELS:
//   ERROR (0)   - Critical errors (output when EnableDebugLog=false)
//   WARNING (1) - Warnings + errors
//   INFO (2)    - Normal information (default)
//   DEBUG (3)   - Detailed debugging
//   TRACE (4)   - Very detailed (loop internals, performance impact)
//
// EnableDebugLog CONTROL:
//   When EnableDebugLog=false: Only ERROR logs are output
//   When EnableDebugLog=true:  Log level controlled by DebugLogLevel setting
//
// USAGE:
//   BNError("Context", "Critical error message");   // Always output if EnableDebugLog=true or for critical errors
//   BNWarn("Context", "Warning message");            // Requires DebugLogLevel >= 1 (WARNING)
//   BNInfo("Context", "Information message");        // Requires DebugLogLevel >= 2 (INFO, default)
//   BNDebug("Context", "Debug message");             // Requires DebugLogLevel >= 3 (DEBUG)
//   BNTrace("Context", "Trace message");             // Requires DebugLogLevel >= 4 (TRACE)
//
// DUPLICATE SUPPRESSION:
//   Identical messages within 5 seconds are automatically collapsed:
//   "[DEBUG] Processing device 1"
//   "[DEBUG] → Previous message repeated 19 times"
//
// ARCHITECTURE:
//   Application Layer (BreachProcessing, etc.)
//        ↓
//   Logging Layer (Logger.reds - level filtering + deduplication)
//        ↓
//   State Management (LoggerStateSystem - ScriptableSystem for duplicate tracking)
//        ↓
//   Framework Layer (RED4ext.ModLog)
// ============================================================================

module BetterNetrunning.Logging

import BetterNetrunningConfig.*

// ============================================================================
// LOG LEVEL ENUM
// ============================================================================

public enum LogLevel {
  ERROR = 0,    // Critical errors only
  WARNING = 1,  // Warnings + errors
  INFO = 2,     // Normal information (default)
  DEBUG = 3,    // Detailed debugging
  TRACE = 4     // Very detailed (performance impact)
}

// ============================================================================
// DUPLICATE SUPPRESSION STATE (via ScriptableSystem)
// ============================================================================

public class LoggerStateSystem extends ScriptableSystem {
  private let m_lastLogMessage: String;
  private let m_lastLogContext: String;
  private let m_lastLogTimestamp: Float;
  private let m_duplicateCount: Int32;

  private func OnAttach() {
    this.m_lastLogMessage = "";
    this.m_lastLogContext = "";
    this.m_lastLogTimestamp = 0.0;
    this.m_duplicateCount = 0;
  }

  public func GetLastMessage() -> String { return this.m_lastLogMessage; }
  public func GetLastContext() -> String { return this.m_lastLogContext; }
  public func GetLastTimestamp() -> Float { return this.m_lastLogTimestamp; }
  public func GetDuplicateCount() -> Int32 { return this.m_duplicateCount; }

  public func SetLastMessage(msg: String) { this.m_lastLogMessage = msg; }
  public func SetLastContext(ctx: String) { this.m_lastLogContext = ctx; }
  public func SetLastTimestamp(time: Float) { this.m_lastLogTimestamp = time; }
  public func SetDuplicateCount(count: Int32) { this.m_duplicateCount = count; }
  public func IncrementDuplicateCount() { this.m_duplicateCount += 1; }
}

// ============================================================================
// SETTINGS INTEGRATION
// ============================================================================

/// Get current log level from CET settings (via config.reds)
private static func GetCurrentLogLevel() -> LogLevel {
  if !BetterNetrunningSettings.EnableDebugLog() {
    return LogLevel.ERROR; // Only errors when debug disabled
  }

  let level: Int32 = BetterNetrunningSettings.DebugLogLevel();

  if level <= 0 {
    return LogLevel.ERROR;
  } else if level == 1 {
    return LogLevel.WARNING;
  } else if level == 2 {
    return LogLevel.INFO;
  } else if level == 3 {
    return LogLevel.DEBUG;
  } else {
    return LogLevel.TRACE;
  }
}

// ============================================================================
// PUBLIC API: LOG LEVEL FUNCTIONS
// ============================================================================

/// Log error (always output, ignores log level)
public static func BNError(context: String, message: String) -> Void {
  LogWithLevel(LogLevel.ERROR, context, message);
}

/// Log warning (WARNING level or higher)
public static func BNWarn(context: String, message: String) -> Void {
  if EnumInt(GetCurrentLogLevel()) >= EnumInt(LogLevel.WARNING) {
    LogWithLevel(LogLevel.WARNING, context, message);
  }
}

/// Log info (INFO level or higher)
public static func BNInfo(context: String, message: String) -> Void {
  if EnumInt(GetCurrentLogLevel()) >= EnumInt(LogLevel.INFO) {
    LogWithLevel(LogLevel.INFO, context, message);
  }
}

/// Log debug (DEBUG level or higher)
public static func BNDebug(context: String, message: String) -> Void {
  if EnumInt(GetCurrentLogLevel()) >= EnumInt(LogLevel.DEBUG) {
    LogWithLevel(LogLevel.DEBUG, context, message);
  }
}

/// Log trace (TRACE level only, for loop internals)
public static func BNTrace(context: String, message: String) -> Void {
  if EnumInt(GetCurrentLogLevel()) >= EnumInt(LogLevel.TRACE) {
    LogWithLevel(LogLevel.TRACE, context, message);
  }
}

// ============================================================================
// INTERNAL: LOG OUTPUT WITH DEDUPLICATION
// ============================================================================

private static func LogWithLevel(level: LogLevel, context: String, message: String) -> Void {
  let gameInstance: GameInstance = GetGameInstance();
  let loggerState: ref<LoggerStateSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"BetterNetrunning.Common.LoggerStateSystem") as LoggerStateSystem;

  if !IsDefined(loggerState) {
    // Fallback: Output without deduplication if system not available
    let levelPrefix: String = GetLevelPrefix(level);
    let fullMessage: String = levelPrefix + " [" + context + "] " + message;
    ModLog(n"BetterNetrunning", fullMessage);
    return;
  }

  let currentTime: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gameInstance));
  let timeSinceLastLog: Float = currentTime - loggerState.GetLastTimestamp();

  // Duplicate detection (within 5 seconds, same context + message)
  if timeSinceLastLog < 5.0 && Equals(loggerState.GetLastContext(), context) && Equals(loggerState.GetLastMessage(), message) {
    loggerState.IncrementDuplicateCount();
    return; // Suppress duplicate
  }

  // Output duplicate summary if any
  if loggerState.GetDuplicateCount() > 0 {
    let levelPrefix: String = GetLevelPrefix(level);
    let summaryMsg: String = levelPrefix + " [" + loggerState.GetLastContext() + "] → Previous message repeated " + ToString(loggerState.GetDuplicateCount()) + " times";
    ModLog(n"BetterNetrunning", summaryMsg);
    loggerState.SetDuplicateCount(0);
  }

  // Output new log message
  let levelPrefix: String = GetLevelPrefix(level);
  let fullMessage: String = levelPrefix + " [" + context + "] " + message;
  ModLog(n"BetterNetrunning", fullMessage);

  // Update cache
  loggerState.SetLastMessage(message);
  loggerState.SetLastContext(context);
  loggerState.SetLastTimestamp(currentTime);
}

/// Get log level prefix for output formatting
private static func GetLevelPrefix(level: LogLevel) -> String {
  switch level {
    case LogLevel.ERROR:   return "[ERROR]  ";
    case LogLevel.WARNING: return "[WARN]   ";
    case LogLevel.INFO:    return "[INFO]   ";
    case LogLevel.DEBUG:   return "[DEBUG]  ";
    case LogLevel.TRACE:   return "[TRACE]  ";
  }
  return "[UNKNOWN]";
}
