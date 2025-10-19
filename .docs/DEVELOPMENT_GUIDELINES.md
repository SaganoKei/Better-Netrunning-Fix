# Better Netrunning - Development Guidelines

**Last Updated:** 2025-10-12
**Version:** 1.0

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Design Principles](#design-principles)
3. [Code Organization](#code-organization)
4. [REDscript Language Standards](#redscript-language-standards)
5. [Naming Conventions](#naming-conventions)
6. [Module Design Patterns](#module-design-patterns)
7. [Mod Compatibility](#mod-compatibility)
8. [Error Handling & Validation](#error-handling--validation)
9. [Performance Considerations](#performance-considerations)
10. [Testing Guidelines](#testing-guidelines)
11. [Documentation Requirements](#documentation-requirements)

---

## Overview

This document establishes **development guidelines** for Better Netrunning, covering both **mandatory language constraints** (REDscript limitations) and **recommended practices** (design patterns, best practices).

**Nature:**
- **Mandatory Rules**: Language constraints, syntax rules, API limitations (MUST follow)
  - Examples: `continue` keyword unavailable, `ArraySize()` instead of `.Size()`, API compatibility workarounds
- **Recommended Practices**: Design patterns, code organization, mod compatibility strategies (SHOULD follow)
  - Examples: @wrapMethod preference, SRP principle, Early Return pattern

**Scope:** All REDscript files in `r6/scripts/BetterNetrunning/`

**Related Documents:**
- `DOCUMENTATION_STANDARDS.md` - Documentation style guide (formerly CODING_STANDARDS.md)
- `ARCHITECTURE_DESIGN.md` - System architecture
- `BREACH_SYSTEM_REFERENCE.md` - Breach system technical reference

---

## Design Principles

### 1. Single Responsibility Principle (SRP)

**Rule:** Each module should have one clear purpose

**✅ Good Example:**
```redscript
// DeviceTypeUtils.reds - Device type classification only
public static func GetDeviceType(devicePS: ref<ScriptableDeviceComponentPS>) -> DeviceType {
    if IsDefined(devicePS as SurveillanceCameraControllerPS) { return DeviceType.Camera; }
    if IsDefined(devicePS as SecurityTurretControllerPS) { return DeviceType.Turret; }
    if IsDefined(devicePS as ScriptedPuppetPS) { return DeviceType.NPC; }
    return DeviceType.Basic;
}
```

**❌ Bad Example:**
```redscript
// Mixing device detection with breach logic (violates SRP)
public static func DetectDeviceAndApplyBreach(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
    let deviceType = this.GetDeviceType(devicePS);
    this.ApplyBreachUnlock(devicePS, deviceType);
    this.RecordBreachPosition(devicePS);
    this.LogBreachResult(devicePS);
}
```

### 2. DRY (Don't Repeat Yourself)

**Rule:** Consolidate shared logic into utility modules

**✅ Good Example:**
```redscript
// Centralized range management
public static func GetRadialBreachRange(gameInstance: GameInstance) -> Float {
    return DeviceTypeUtils.GetRadialBreachRange(gameInstance);
}
```

**❌ Bad Example:**
```redscript
// Duplicated range fetching in multiple files
let range1: Float = 50.0; // In ProgramFiltering.reds
let range2: Float = 50.0; // In RadialUnlockSystem.reds
let range3: Float = 50.0; // In DaemonUnlockStrategy.reds
```

### 3. Composed Method Pattern

**Rule:** Break large functions into small, focused helpers (max 30 lines per function)

**✅ Good Example:**
```redscript
public func ProcessBreachCompletion() -> Void {
    let programs = this.GetActivePrograms();
    let unlockFlags = this.ParseUnlockFlags(programs);
    this.ApplyDeviceUnlock(unlockFlags);
    this.ApplyNetworkUnlock(unlockFlags);
    this.RecordBreachPosition();
}

private func GetActivePrograms() -> array<TweakDBID> { /* ... */ }
private func ParseUnlockFlags(programs: array<TweakDBID>) -> BreachUnlockFlags { /* ... */ }
private func ApplyDeviceUnlock(flags: BreachUnlockFlags) -> Void { /* ... */ }
```

**❌ Bad Example:**
```redscript
public func ProcessBreachCompletion() -> Void {
    // 150 lines of nested logic without helper methods
    let programs = ...;
    for program in programs {
        if condition1 {
            if condition2 {
                if condition3 {
                    // Deep nesting (hard to read)
                }
            }
        }
    }
}
```

### 3.5. Constants Management (Avoiding Magic Strings)

**Rule:** Centralize string literals in a constants class (eliminates typos, enables refactoring)

**✅ Best Practice: Centralized Constants Class**

```redscript
// Common/Constants.reds - Single Source of Truth
module BetterNetrunning.Common

public abstract class BNConstants {
  // Class names (fully qualified)
  public static func CLASS_REMOTE_BREACH_COMPUTER() -> CName {
    return n"BetterNetrunning.CustomHacking.RemoteBreachAction";
  }

  public static func CLASS_REMOTE_BREACH_DEVICE() -> CName {
    return n"BetterNetrunning.CustomHacking.DeviceRemoteBreachAction";
  }

  // Action names
  public static func ACTION_REMOTE_BREACH() -> CName {
    return n"RemoteBreach";
  }

  // Helper methods
  public static func IsRemoteBreachAction(className: CName) -> Bool {
    return Equals(className, BNConstants.CLASS_REMOTE_BREACH_COMPUTER())
        || Equals(className, BNConstants.CLASS_REMOTE_BREACH_DEVICE());
  }
}

// Usage in other files
import BetterNetrunning.Common.Constants

public func IsCustomRemoteBreachAction(className: CName) -> Bool {
  return BNConstants.IsRemoteBreachAction(className);  // ✅ Self-documenting, typo-proof
}
```

**❌ Anti-pattern: Scattered Magic Strings**

```redscript
// Events.reds
if Equals(className, n"BetterNetrunning.CustomHacking.RemoteBreachAction") { ... }

// CustomHackingIntegration.reds
if Equals(className, n"BetterNetrunning.CustomHacking.RemoteBreachAction") { ... }  // Duplicated

// RemoteBreachVisibility.reds
if Equals(className, n"BetterNetrunning.CustomHacking.RemotBreachAction") { ... }  // ❌ TYPO!
```

**Benefits of Constants Class:**
1. **Single Source of Truth**: Change class name once, updates everywhere
2. **Typo Prevention**: IDE autocomplete for method names
3. **Self-Documenting**: `BNConstants.CLASS_REMOTE_BREACH_COMPUTER()` is clearer than `n"BetterNetrunning.CustomHacking.RemoteBreachAction"`
4. **Easy Refactoring**: Rename class → update one constant definition
5. **Testability**: Can verify constant values in isolation

**Implementation History:**
- **2025-10-16**: Initial Constants class (Phase 0 - RemoteBreach bug fix)
  - Added 3 RemoteBreach class name constants + helper methods
  - Resolved short class name bug (`n"RemoteBreachAction"` → fully qualified names)
- **2025-10-17 Phase 1**: Vanilla action names + LocKey constants
  - Added 3 vanilla action constants (PhysicalBreach, SuicideBreach, BreachUnconsciousOfficer)
  - Added 4 LocKey constants (ActivateNetworkDevice, NotPowered, Access, RAMInsufficient)
  - Total: 11 constants covering ~85% of magic strings
- **2025-10-17 Phase 2**: TweakDBID constants integration
  - Added 33 TweakDBID constants (MinigameAction: 17, MinigameProgramAction: 10, Minigame: 7, DeviceAction: 1)
  - Replaced 100 usage locations across 10 files
  - Total: 44 constants covering ~95% of all string literals

**Current Constants Coverage** (as of Phase 2 completion):

| Category | Constants | Usage Locations | Files |
|----------|-----------|-----------------|-------|
| **Class Names** | 3 | 15 | 7 |
| **Action Names** | 4 | 10 | 3 |
| **LocKey Strings** | 4 | 7 | 4 |
| **TweakDBID - MinigameAction** | 17 | 54 | 6 |
| **TweakDBID - MinigameProgramAction** | 10 | 11 | 2 |
| **TweakDBID - Minigame** | 7 | 7 | 1 |
| **TweakDBID - DeviceAction** | 1 | 1 | 1 |
| **Helper Methods** | 3 | - | - |
| **TOTAL** | **44** | **100+** | **10+** |

**TweakDBID Constants Design** (Phase 2):

TweakDBID constants follow a hierarchical naming convention based on their purpose:

```redscript
// Daemon Programs (MinigameAction.*) - What daemons do when executed
public static func PROGRAM_UNLOCK_QUICKHACKS() -> TweakDBID {
  return t"MinigameAction.UnlockQuickhacks";
}
public static func PROGRAM_NETWORK_PING_HACK() -> TweakDBID {
  return t"MinigameAction.NetworkPingHack";
}
public static func PROGRAM_DATAMINE_MASTER() -> TweakDBID {
  return t"MinigameAction.NetworkDataMineLootAllMaster";
}

// Custom BN Programs (MinigameProgramAction.*) - CET-registered programs
public static func PROGRAM_ACTION_BN_UNLOCK_BASIC() -> TweakDBID {
  return t"MinigameProgramAction.BN_RemoteBreach_UnlockBasic";
}
public static func PROGRAM_ACTION_REMOTE_BREACH_MEDIUM() -> TweakDBID {
  return t"MinigameProgramAction.RemoteBreachMedium";
}

// Minigame Difficulty Presets (Minigame.*) - Breach parameters
public static func MINIGAME_COMPUTER_BREACH_HARD() -> TweakDBID {
  return t"Minigame.ComputerRemoteBreachHard";
}
public static func MINIGAME_VEHICLE_BREACH_EASY() -> TweakDBID {
  return t"Minigame.VehicleRemoteBreachEasy";
}

// Device Actions (DeviceAction.*) - Vanilla device actions
public static func DEVICE_ACTION_REMOTE_BREACH() -> TweakDBID {
  return t"DeviceAction.RemoteBreach";
}
```

**Naming Convention Rationale:**
- **PROGRAM_\***: Daemon programs (MinigameAction) - high-level gameplay effect
- **PROGRAM_ACTION_\***: Program actions (MinigameProgramAction) - low-level implementation
- **MINIGAME_\***: Minigame presets (Minigame) - configuration data
- **DEVICE_ACTION_\***: Device actions (DeviceAction) - vanilla game actions

This convention enables:
- **Quick Identification**: Prefix indicates TweakDB category
- **Logical Grouping**: Related constants are adjacent in code
- **Future Expansion**: New categories can be added without conflicts

### 4. Nesting Reduction Strategies

**Rule:** Minimize nesting depth for readability and maintainability (target 0-2 levels)

**Nesting Guidelines:**
- **0-1 levels**: Preferred (use flattening techniques)
- **2-3 levels**: Acceptable (standard practice)
- **4+ levels**: Allowed only if:
  - Each nested block is small (< 5 lines)
  - Each nesting level has explanatory comment
  - All flattening alternatives have been exhausted
- **Refactor when**: Any nested block exceeds 5 lines

---

#### Flattening Techniques (Apply in Order)

**1. Guard Clauses / Early Return** (Most Effective)

Eliminate nesting by validating conditions early and returning immediately on failure.

```redscript
// ✅ Excellent: 0-level nesting with guard clauses
public func ValidateDevice(device: ref<DevicePS>) -> Bool {
    if !IsDefined(device) { return false; }          // Guard 1
    if !this.IsBreached() { return false; }          // Guard 2
    if !this.IsNetworkConnected() { return false; }  // Guard 3
    if !this.HasRequiredFlags() { return false; }    // Guard 4

    // Main logic here (completely flat)
    return true;
}

// ❌ Bad: 4-level nesting
public func ValidateDevice(device: ref<DevicePS>) -> Bool {
    if IsDefined(device) {
        if this.IsBreached() {
            if this.IsNetworkConnected() {
                if this.HasRequiredFlags() {
                    return true;
                }
            }
        }
    }
    return false;
}
```

**Use Cases:**
- Input validation
- Prerequisite checks
- Error handling
- Resource availability checks

---

**2. Combining Conditions (OR/AND Operators)**

Merge related conditional checks into single expressions.

```redscript
// ✅ Good: OR conditions for failure paths (1 level)
public func CanProcessDevice(device: ref<DevicePS>) -> Bool {
    if !IsDefined(device) || !this.IsBreached() || !this.IsNetworkConnected() {
        return false;  // Any failure exits immediately
    }

    // Main logic (flat)
    this.ProcessDevice(device);
    return true;
}

// ✅ Good: AND conditions for success paths (1 level)
public func ProcessIfReady(device: ref<DevicePS>) -> Void {
    if IsDefined(device) && this.IsBreached() && this.IsNetworkConnected() {
        this.ProcessDevice(device);  // All conditions met
    }
}

// ❌ Avoid: Nested conditions (3 levels)
public func CanProcessDevice(device: ref<DevicePS>) -> Bool {
    if IsDefined(device) {
        if this.IsBreached() {
            if this.IsNetworkConnected() {
                this.ProcessDevice(device);
                return true;
            }
        }
    }
    return false;
}
```

**Use Cases:**
- Multiple validation checks
- Permission/capability checks
- State combinations

---

**3. If-Else Chains (Mutually Exclusive Cases)**

Flatten branching logic for mutually exclusive conditions.

```redscript
// ✅ Good: Flat if-else chain (1 level)
public func ProcessDeviceByType(deviceType: DeviceType, device: ref<DevicePS>) -> Void {
    if deviceType == DeviceType.Camera {
        this.ProcessCamera(device);
    } else if deviceType == DeviceType.Turret {
        this.ProcessTurret(device);
    } else if deviceType == DeviceType.Terminal {
        this.ProcessTerminal(device);
    } else {
        this.ProcessGenericDevice(device);
    }
}

// ❌ Avoid: Nested if statements (3+ levels)
public func ProcessDeviceByType(deviceType: DeviceType, device: ref<DevicePS>) -> Void {
    if deviceType == DeviceType.Camera {
        this.ProcessCamera(device);
    } else {
        if deviceType == DeviceType.Turret {
            this.ProcessTurret(device);
        } else {
            if deviceType == DeviceType.Terminal {
                this.ProcessTerminal(device);
            } else {
                this.ProcessGenericDevice(device);
            }
        }
    }
}
```

**Use Cases:**
- Type-based dispatch
- State machine transitions
- Priority-based processing

---

**4. Inverted Logic (De Morgan's Law)**

Invert conditions to reduce nesting depth.

```redscript
// ✅ Good: Inverted condition (1 level)
public func ProcessWithFlags(flags: BreachUnlockFlags) -> Void {
    // Invert: !(A && B && C) = !A || !B || !C
    if !flags.unlockBasic || !flags.unlockCameras || !flags.unlockTurrets {
        return;  // Exit early if any flag is missing
    }

    // Main logic (flat)
    this.ApplyFullUnlock();
}

// ❌ Avoid: Positive nested checks (3 levels)
public func ProcessWithFlags(flags: BreachUnlockFlags) -> Void {
    if flags.unlockBasic {
        if flags.unlockCameras {
            if flags.unlockTurrets {
                this.ApplyFullUnlock();
            }
        }
    }
}
```

**Use Cases:**
- Complex boolean expressions
- Flag validation
- Multi-condition checks

---

**5. Extraction to Helper Methods**

Break complex nested logic into focused helper functions.

```redscript
// ✅ Good: Extracted helper methods (1-2 levels each)
public func ProcessBreach(device: ref<DevicePS>) -> Bool {
    if !this.ValidateDevice(device) { return false; }
    if !this.ValidateBreachState() { return false; }

    this.ApplyBreachEffects(device);
    return true;
}

private func ValidateDevice(device: ref<DevicePS>) -> Bool {
    if !IsDefined(device) { return false; }
    if !this.IsCorrectDeviceType(device) { return false; }
    return true;
}

private func ValidateBreachState() -> Bool {
    if !this.IsBreached() { return false; }
    if !this.IsNetworkConnected() { return false; }
    return true;
}

// ❌ Avoid: Monolithic nested function (4+ levels)
public func ProcessBreach(device: ref<DevicePS>) -> Bool {
    if IsDefined(device) {
        if this.IsCorrectDeviceType(device) {
            if this.IsBreached() {
                if this.IsNetworkConnected() {
                    // Complex logic here (deep nesting)
                    return true;
                }
            }
        }
    }
    return false;
}
```

**Use Cases:**
- Complex validation sequences
- Multi-step processing workflows
- When other flattening techniques are insufficient

---

**6. While-Loop Refactoring Pattern (REDscript Specific)**

REDscript does NOT support `for` keyword or `continue` statement. All iteration must use `while` loops with manual index management. This pattern combines Guard Clause + Extract Method to flatten nested while loops.

```redscript
// ❌ BEFORE: 4-level nesting with complex while loop (28 lines)
@addMethod(ScriptableDeviceComponentPS)
private final func ReplaceVanillaRemoteBreachWithCustom(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let i: Int32 = ArraySize(Deref(outActions)) - 1;

  // Complex nested conditions
  if this.IsBreached() {
    while i >= 0 {
      let action: ref<DeviceAction> = Deref(outActions)[i];
      if IsDefined(action as RemoteBreach) {
        ArrayErase(Deref(outActions), i);          // 4-level nesting
        BNLog("[ReplaceVanilla] Removed vanilla RemoteBreach");
      }
      i -= 1;
    }
  }

  // Another complex nested condition
  if BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
    if IsDefined(deviceEntity) {
      if IsDefined(player) {
        if RemoteBreachLockUtils.IsRemoteBreachLockedForDevice(...) {
          let j: Int32 = ArraySize(Deref(outActions)) - 1;
          while j >= 0 {
            let action: ref<DeviceAction> = Deref(outActions)[j];
            let className: CName = action.GetClassName();
            if IsCustomRemoteBreachAction(className) || IsDefined(action as RemoteBreach) {
              ArrayErase(Deref(outActions), j);    // 5-level nesting!
              BNLog("[ReplaceVanilla] Removed " + ToString(className));
            }
            j -= 1;
          }
        }
      }
    }
  }
}

// ✅ AFTER: 1-2 level nesting with Guard Clause + Extract Method (14 lines main + 3 helpers)
@addMethod(ScriptableDeviceComponentPS)
private final func ReplaceVanillaRemoteBreachWithCustom(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Guard 1: Device already breached - remove vanilla RemoteBreach only
  if this.IsBreached() {
    this.RemoveVanillaRemoteBreachActions(outActions);
    return;
  }

  // Guard 2: Device locked by breach failure - remove ALL RemoteBreach actions
  if this.IsDeviceLockedByBreachFailure() {
    this.RemoveAllRemoteBreachActions(outActions);
    return;
  }

  // Main logic continues here (only if guards pass)
}

// Helper 1: Extract nested condition into boolean method
@addMethod(ScriptableDeviceComponentPS)
private final func IsDeviceLockedByBreachFailure() -> Bool {
  if !BetterNetrunningSettings.BreachFailurePenaltyEnabled() { return false; }

  let deviceEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(deviceEntity) { return false; }

  let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
  if !IsDefined(player) { return false; }

  let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
  return RemoteBreachLockUtils.IsRemoteBreachLockedForDevice(player, devicePosition, this.GetGameInstance());
}

// Helper 2: Extract while loop with simple removal logic
@addMethod(ScriptableDeviceComponentPS)
private final func RemoveVanillaRemoteBreachActions(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let i: Int32 = ArraySize(Deref(outActions)) - 1;

  while i >= 0 {
    let action: ref<DeviceAction> = Deref(outActions)[i];

    if IsDefined(action as RemoteBreach) {
      ArrayErase(Deref(outActions), i);
      BNLog("[RemoveVanillaRemoteBreachActions] Removed vanilla RemoteBreach");
    }

    i -= 1;
  }
}

// Helper 3: Extract while loop with complex removal logic
@addMethod(ScriptableDeviceComponentPS)
private final func RemoveAllRemoteBreachActions(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let i: Int32 = ArraySize(Deref(outActions)) - 1;

  while i >= 0 {
    let action: ref<DeviceAction> = Deref(outActions)[i];
    let className: CName = action.GetClassName();

    if IsCustomRemoteBreachAction(className) || IsDefined(action as RemoteBreach) {
      ArrayErase(Deref(outActions), i);
      BNLog("[RemoveAllRemoteBreachActions] Removed " + ToString(className));
    }

    i -= 1;
  }
}
```

**Pattern Structure:**

1. **Identify Nested While Loops** - Look for `while` inside `if` blocks (2+ levels)
2. **Apply Guard Clauses** - Convert outer `if` conditions to early returns
3. **Extract While Loop Bodies** - Move entire while loop to dedicated helper method
4. **Extract Complex Conditions** - Move nested `if` chains to boolean helper methods
5. **Preserve Single Responsibility** - Each helper method has ONE clear purpose

**Benefits:**
- ✅ Nesting reduced from 4-5 levels to 1-2 levels (60-75% reduction)
- ✅ Each method < 30 lines (maintainable)
- ✅ Self-documenting method names (no comments needed for structure)
- ✅ Testable in isolation (helpers can be unit tested)
- ✅ Follows Composed Method pattern (orchestration + focused helpers)

**REDscript Constraints:**
- ⚠️ No `for` keyword - must use `while` with manual index management
- ⚠️ No `continue` statement - use `if-else` or inverted conditions
- ⚠️ Reverse iteration required for array removal: `let i = ArraySize(arr) - 1; while i >= 0`
- ⚠️ Must decrement index manually: `i -= 1` at end of loop body

**Implementation Date:** 2025-10-17 (Phase 85 refactoring, DeviceQuickhacks.reds Task 1.2)

---

#### Decision Tree for Nesting Reduction

```
Identify nesting depth > 2 levels
  ↓
1. Can use guard clauses? → YES → Apply early return ✅
  ↓ NO
2. Can combine conditions (OR/AND)? → YES → Merge into single expression ✅
  ↓ NO
3. Are cases mutually exclusive? → YES → Use if-else chain ✅
  ↓ NO
4. Can invert logic (De Morgan)? → YES → Invert & return early ✅
  ↓ NO
5. Can extract helper method? → YES → Break into focused functions ✅
  ↓ NO
6. Accept nesting → Ensure:
   - Each block < 5 lines
   - Each level has comment
   - Document why alternatives failed
```

---

#### When 4+ Nesting is Acceptable

After exhausting all flattening techniques, accept deep nesting only if:

1. **Complex State Machines**: Flattening reduces readability (document reasoning)
2. **Resource Cleanup**: Tightly coupled validation with cleanup requirements
3. **Performance-Critical Paths**: Method call overhead is measurable bottleneck (profile first)
4. **Each Block is Minimal**: Every nested block is < 3 lines AND well-commented

**Example: Acceptable 4-level nesting (small blocks with comments):**
```redscript
public func ValidateComplexCondition() -> Bool {
    if this.CheckCondition1() {
        // Level 1: Primary validation
        if this.CheckCondition2() {
            // Level 2: Secondary validation
            if this.CheckCondition3() {
                // Level 3: Tertiary validation
                if this.CheckCondition4() {
                    // Level 4: Final check (2 lines - acceptable)
                    return true;
                }
            }
        }
    }
    return false;
}
```

**Example: Unacceptable 3-level nesting (large blocks without comments):**
```redscript
public func ShouldRemoveProgram(actionID: TweakDBID) -> Bool {
    if this.IsBreached() {
        if this.IsNetworkConnected() {
            if this.IsCameraDaemon(actionID) {
                // 20+ lines of complex logic here
                // No comments explaining each level
                // Should use guard clauses instead
                return true;
            }
        }
    }
    return false;
}
```

### 5. Strategy Pattern

**Rule:** Encapsulate device-specific logic in separate strategy classes

**✅ Good Example:**
```redscript
// DaemonUnlockStrategy.reds - Base interface
public abstract class IDaemonUnlockStrategy {
    public abstract func Execute(devicePS: ref<SharedGameplayPS>, flags: BreachUnlockFlags) -> Void;
}

// CameraUnlockStrategy.reds
public class CameraUnlockStrategy extends IDaemonUnlockStrategy {
    public func Execute(devicePS: ref<SharedGameplayPS>, flags: BreachUnlockFlags) -> Void {
        // Camera-specific unlock logic
    }
}
```

**❌ Bad Example:**
```redscript
// Massive switch statement (violates Open/Closed Principle)
public func ApplyUnlock(deviceType: DeviceType) -> Void {
    switch deviceType {
        case DeviceType.Camera: /* 50 lines */ break;
        case DeviceType.Turret: /* 50 lines */ break;
        case DeviceType.NPC: /* 50 lines */ break;
        // Hard to extend, hard to test
    }
}
```

### 6. Template Method Pattern

**Rule:** Define consistent workflows with customizable steps

**✅ Good Example:**
```redscript
// Base breach processing template
public func ProcessBreach() -> Void {
    this.ValidatePrerequisites(); // Step 1
    this.InjectDaemons();         // Step 2 (customizable)
    this.FilterPrograms();        // Step 3 (customizable)
    this.StartMinigame();         // Step 4
}
```

---

## Code Organization

### Module Structure

**File Naming:**
- PascalCase: `DeviceTypeUtils.reds`, `ProgramFiltering.reds`
- Descriptive names: `RemoteBreachAction_Computer.reds` (not `RBA_C.reds`)

**Module Declaration:**
```redscript
module BetterNetrunning.Common
import BetterNetrunningConfig.*
```

**Import Order:**
1. Standard libraries (if any)
2. BetterNetrunning modules
3. External mod modules (with @if guards)

**⚠️ UPDATED: Circular Dependencies Are Harmless (Proven 2025-10-16)**

REDscript's module system **DOES handle circular dependencies correctly**. After experimental verification, circular imports do NOT cause runtime failures or undefined behavior.

**❌ Anti-pattern: Incorrect Class Name Usage (Bug Case Study - 2025-10-16)**

```redscript
// Common/Events.reds
module BetterNetrunning.Common
import BetterNetrunning.CustomHacking.*  // ❌ CIRCULAR DEPENDENCY

public func IsCustomRemoteBreachAction(className: CName) -> Bool {
  return CustomRemoteBreachActionDetector.IsCustomRemoteBreachAction(className);
  // ❌ Delegates to CustomHacking module
}

// CustomHacking/CustomHackingIntegration.reds
module BetterNetrunning.CustomHacking
import BetterNetrunning.Common.*  // ❌ CIRCULAR DEPENDENCY

public class CustomRemoteBreachActionDetector {
  public static func IsCustomRemoteBreachAction(className: CName) -> Bool {
    // Implementation uses Common.Events definitions
  }
}
```

**Symptom**: RemoteBreach actions appear **always locked** (grayed out) in QuickHack menu
**Root Cause**: Used short class names (n"RemoteBreachAction") instead of fully qualified names
**Impact**: Critical functionality completely broken (100% failure rate)
**Misdiagnosis**: Initially blamed circular imports, but experiments proved imports were harmless

**✅ Solution: Use Fully Qualified Class Names**

```redscript
// Common/Events.reds - Circular imports are safe
module BetterNetrunning.Common
import BetterNetrunning.Common.TimeUtils
import BetterNetrunningConfig.*
// import BetterNetrunning.CustomHacking.*  // ✅ Safe to add if needed (tested and verified)

// ✅ CRITICAL: Use fully qualified class names
public func IsCustomRemoteBreachAction(className: CName) -> Bool {
  // ✅ Fully qualified names (MODULE PATH REQUIRED)
  return Equals(className, n"BetterNetrunning.CustomHacking.RemoteBreachAction")
      || Equals(className, n"BetterNetrunning.CustomHacking.VehicleRemoteBreachAction")
      || Equals(className, n"BetterNetrunning.CustomHacking.DeviceRemoteBreachAction");

  // ❌ Short names DO NOT WORK (tested and confirmed broken)
  // return Equals(className, n"RemoteBreachAction")  // ← WRONG
}

// CustomHacking/CustomHackingIntegration.reds - Can safely import Common
module BetterNetrunning.CustomHacking
import BetterNetrunning.Common.*  // ✅ One-way dependency (Common does not import CustomHacking)

public class CustomRemoteBreachActionDetector {
  public static func IsCustomRemoteBreachAction(className: CName) -> Bool {
    // ✅ Can call Common.IsCustomRemoteBreachAction() safely
    return IsCustomRemoteBreachAction(className);
  }
}
```

**Design Principles for Class Name References:**

1. **Fully Qualified Names Required**: Always use complete module paths in CName literals
   - ✅ `n"BetterNetrunning.CustomHacking.RemoteBreachAction"` (CORRECT)
   - ❌ `n"RemoteBreachAction"` (WRONG - will not match at runtime)

2. **Circular Imports Are Safe**: REDscript handles circular imports correctly
   - ✅ Common can import CustomHacking if needed
   - ✅ CustomHacking can import Common simultaneously
   - ⚠️ But prefer minimal imports for code clarity

3. **Dependency Flexibility** (circular imports proven safe):
   ```
   Common ⇄ Feature (bidirectional imports allowed)
   ```

4. **Testing Strategy**:
   - Test with fully qualified names first
   - If functionality breaks, check class name format (not import structure)
   - Circular imports are NOT the problem (experimentally verified)

5. **Refactoring Guideline**:
   - When checking class names: always use `n"Module.Path.ClassName"` format
   - Short names only work for classes in the same module
   - Cross-module references require full paths

**Historical Note**: Phase 1-75 bug (2025-10-16) caused 100% RemoteBreach failure. Initially blamed circular imports, but experimental testing (2025-10-16 23:15) proved circular imports are harmless. Real cause: using short class names (n"RemoteBreachAction") instead of fully qualified names (n"BetterNetrunning.CustomHacking.RemoteBreachAction"). Fix: restored fully qualified names.

---

#### Experimental Verification: Circular Imports Are Safe

**Test Conducted**: 2025-10-16 23:15

**Hypothesis**: Circular imports cause RemoteBreach failures

**Test Method**:
1. Started with working code (fully qualified class names)
2. Added `import BetterNetrunning.CustomHacking.*` to Events.reds (creating circular import)
3. Tested in-game functionality

**Result**: ✅ RemoteBreach worked perfectly with circular import present

**Conclusion**: **Circular imports are NOT the problem**. The real issue was using short class names instead of fully qualified names.

**Revised Understanding**:
- REDscript's module system handles circular imports correctly
- No compilation errors, warnings, or runtime failures from circular imports
- The Phase 75 bug was a **misdiagnosis** - class name format was the real culprit

**✅ Recommended Pattern: Use Fully Qualified Names**

Invert the dependency: Feature modules **register** their class names with Common utilities.

```redscript
// Common/Events.reds - No imports of feature modules
module BetterNetrunning.Common

// Registry for custom action class names
private let g_customRemoteBreachActions: array<CName>;

// Registration interface (called by feature modules during initialization)
public func RegisterCustomRemoteBreachAction(className: CName) -> Void {
  if !ArrayContains(g_customRemoteBreachActions, className) {
    ArrayPush(g_customRemoteBreachActions, className);
    BNLog("[Events] Registered custom breach action: " + NameToString(className));
  }
}

// Generic check (no knowledge of specific feature classes)
public func IsCustomRemoteBreachAction(className: CName) -> Bool {
  return ArrayContains(g_customRemoteBreachActions, className);
}

// CustomHacking/CustomHackingIntegration.reds
module BetterNetrunning.CustomHacking
import BetterNetrunning.Common.*  // ✅ One-way dependency (Feature → Common)

// Register action classes during module initialization
@if(ModuleExists("HackingExtensions"))
public class CustomHackingInitializer {
  public static func RegisterActions() -> Void {
    // Register all CustomHacking action class names with Common registry
    RegisterCustomRemoteBreachAction(n"BetterNetrunning.CustomHacking.RemoteBreachAction");
    RegisterCustomRemoteBreachAction(n"BetterNetrunning.CustomHacking.VehicleRemoteBreachAction");
    RegisterCustomRemoteBreachAction(n"BetterNetrunning.CustomHacking.DeviceRemoteBreachAction");
  }
}

// Call registration during initialization (e.g., in OnAttach)
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  wrappedMethod();
  CustomHackingInitializer.RegisterActions();
}
```

**Benefits**:
- ✅ No circular dependencies (Common has no knowledge of CustomHacking)
- ✅ DRY preserved (single source of truth in registry)
- ✅ Extensible (new action types register themselves)
- ✅ Separation of Concerns (Common provides infrastructure, Features provide data)

**Trade-offs**:
- ⚠️ Requires initialization timing (must call `RegisterActions()` before checks)
- ⚠️ Global state (registry must persist across game session)

---

**✅ Solution 2: Self-Contained Implementation (Current Fix - Simplicity)**

Embed feature-specific knowledge directly in Common module (acceptable for stable, small datasets).

```redscript
// Common/Events.reds - Self-contained (no imports)
module BetterNetrunning.Common
import BetterNetrunningConfig.*

// Direct implementation (hardcoded class names)
public func IsCustomRemoteBreachAction(className: CName) -> Bool {
  return Equals(className, n"BetterNetrunning.CustomHacking.RemoteBreachAction")
      || Equals(className, n"BetterNetrunning.CustomHacking.VehicleRemoteBreachAction")
      || Equals(className, n"BetterNetrunning.CustomHacking.DeviceRemoteBreachAction");
}
```

**Benefits**:
- ✅ No circular dependencies
- ✅ No initialization complexity
- ✅ Simple and maintainable

**Trade-offs**:
- ⚠️ Violates DRY if CustomHacking also needs this list (acceptable: duplication is localized)
- ⚠️ Not extensible (new action types require editing Common module)
- ⚠️ Common module has knowledge of CustomHacking implementation details

**When to Use Each Pattern**:
- **Registry Pattern**: Use when extensibility is critical (plugins, modular features, frequent additions)
- **Self-Contained**: Use when data is stable, small, and changes infrequently (current use case)

---

**✅ Solution 3: Interface + Delegation (Complex - For Large Systems)**

Define abstract interface in Common, implement in Features, inject via constructor/factory.

```redscript
// Common/Events.reds - Interface only
module BetterNetrunning.Common

public abstract class IRemoteBreachActionDetector {
  public abstract func IsCustomAction(className: CName) -> Bool;
}

// Common utilities accept detector as parameter
public func FilterActions(actions: array<ref<DeviceAction>>, detector: ref<IRemoteBreachActionDetector>) -> array<ref<DeviceAction>> {
  let filtered: array<ref<DeviceAction>>;
  for action in actions {
    if !detector.IsCustomAction(action.GetClassName()) {
      ArrayPush(filtered, action);
    }
  }
  return filtered;
}

// CustomHacking/CustomHackingIntegration.reds
module BetterNetrunning.CustomHacking
import BetterNetrunning.Common.*

public class CustomRemoteBreachActionDetector extends IRemoteBreachActionDetector {
  public func IsCustomAction(className: CName) -> Bool {
    return Equals(className, n"BetterNetrunning.CustomHacking.RemoteBreachAction")
        || Equals(className, n"BetterNetrunning.CustomHacking.VehicleRemoteBreachAction")
        || Equals(className, n"BetterNetrunning.CustomHacking.DeviceRemoteBreachAction");
  }
}

// Usage: Inject detector instance
let detector: ref<IRemoteBreachActionDetector> = new CustomRemoteBreachActionDetector();
let filtered = FilterActions(actions, detector);
```

**Benefits**:
- ✅ Perfect separation of concerns (Common knows interface, CustomHacking knows implementation)
- ✅ Testable (can inject mock detectors)
- ✅ Follows Dependency Inversion Principle

**Trade-offs**:
- ⚠️ High complexity (interface + factory + injection)
- ⚠️ Requires passing detector instance through call chains
- ⚠️ Overkill for simple classification logic

---

**Decision Matrix**:

| Criterion | Self-Contained | Registry | Interface + Delegation |
|-----------|----------------|----------|------------------------|
| Simplicity | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| DRY Compliance | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Extensibility | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| No Circular Deps | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Initialization Cost | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| Testability | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Recommendation for Better Netrunning**:
- **Current state**: Use **Self-Contained** (already implemented, adequate for 3 stable action types)
- **Future refactoring**: Consider **Registry Pattern** if action types become dynamic or exceed 5-10 types
- **Avoid**: Interface + Delegation (complexity not justified for current use case)

---

**General Rule for Avoiding Circular Dependencies**:

1. **Identify Module Hierarchy** (establish layers early):
   ```
   Entry Point (betterNetrunning.reds)
        ↓
   Coordination Layer (no business logic)
        ↓
   Feature Modules (CustomHacking, Breach, Devices)
        ↓
   Common Utilities (DeviceTypeUtils, Events, Logger)
        ↓
   Config (settings only, no logic)
   ```

2. **Apply One-Way Dependency Rule** (higher layers can import lower, never reverse):
   - ✅ Feature → Common (allowed)
   - ❌ Common → Feature (forbidden)
   - ✅ Entry Point → Feature (allowed)
   - ❌ Feature → Entry Point (forbidden)

3. **When Cross-Layer Communication Needed**:
   - **Upward data flow**: Use Registry Pattern (lower layer provides registration, higher layer registers)
   - **Downward behavior flow**: Use Interface + Injection (lower layer defines interface, higher layer implements)
   - **Sibling communication**: Go through parent layer or use Event-Driven pattern

4. **Detect Early with Grep**:
   ```powershell
   # Check if Common imports any Feature modules (should return empty)
   grep -r "import.*CustomHacking\|import.*Breach\|import.*Devices" r6/scripts/BetterNetrunning/Common/

   # Check if any module imports betterNetrunning.reds (entry point - should return empty)
   grep -r "import.*betterNetrunning[^C]" r6/scripts/BetterNetrunning/
   ```

5. **Code Review Checklist Addition**:
   - [ ] No imports from lower layers to higher layers
   - [ ] Common modules do not import Feature modules
   - [ ] No imports to entry point file (betterNetrunning.reds)
   - [ ] New imports verified with grep for circular patterns

### Directory Organization

```
BetterNetrunning/
├── betterNetrunning.reds  - Entry point & coordination
├── config.reds            - Configuration (overridden by Native Settings)
├── Breach/                - Minigame processing
├── Common/                - Shared utilities
├── CustomHacking/         - RemoteBreach system
├── Devices/               - Device quickhacks
├── Minigame/              - Daemon injection & filtering
├── NPCs/                  - NPC quickhacks
├── Progression/           - Cyberdeck/Intelligence checks
└── RadialUnlock/          - 50m radius breach tracking
```

**Guidelines:**
- Max 10 files per directory (split if exceeds)
- Related functionality grouped together
- Clear module boundaries

---

### File Encoding & Line Endings (Critical for REDscript)

**⚠️ CRITICAL: REDscript Requires UTF-8 Without BOM + CRLF Line Endings**

REDscript compiler has **strict encoding requirements**. Violating these will cause **compilation failure** even with syntactically correct code.

#### Required File Format

| Property | Required Value | Violation Result |
|----------|---------------|------------------|
| **Encoding** | UTF-8 **WITHOUT BOM** | `syntax error, expected one of "@", EOF` at line 1 |
| **Line Endings** | CRLF (`0D 0A`) | Parser treats multi-line statements as single line |
| **File Extension** | `.reds` | File not recognized by compiler |

---

#### Anti-Pattern: PowerShell File Editing (Case Study - 2025-10-18)

**Context**: Phase 4A Step 2 (Core/Utils separation) required batch updating 25 files with new import statements.

**Initial Approach** (FAILED):
```powershell
# ❌ WRONG: Set-Content adds BOM, uses LF-only line breaks
$content = Get-Content $file.FullName -Raw
$newContent = $content -replace 'import BetterNetrunning\.Common\.\*',
                                 "import BetterNetrunning.Core.*`nimport BetterNetrunning.Utils.*"
Set-Content $file.FullName $newContent -NoNewline
```

**Problems**:
1. **LF-only line breaks** (`` `n `` = `0A`): PowerShell's `` `n `` produces `\n` (LF) instead of `\r\n` (CRLF)
   - **Result**: 2-line import became 1 line → `import BetterNetrunning.Core.*\nimport BetterNetrunning.Utils.*`
   - **Error**: Parser treats as single malformed statement

2. **[System.IO.File]::WriteAllText() default behavior** (UTF-8 WITH BOM):
   ```powershell
   # ❌ WRONG: Default UTF-8 encoding includes BOM (EF BB BF)
   [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
   ```
   - **Result**: Files start with `﻿module` (BOM visible as `﻿`)
   - **Error**: `syntax error, expected one of "@", EOF, a top-level definition` at line 1

**Symptoms**:
```
[ERROR] At betterNetrunning.reds:1:1:
﻿module BetterNetrunning
^
syntax error, expected one of "@", EOF, a top-level definition
```

---

#### ✅ Correct PowerShell File Editing Pattern

**Batch File Updates** (Write operations):
```powershell
# ✅ CORRECT: Explicit UTF-8 without BOM + CRLF line endings
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$files = Get-ChildItem "path\to\scripts" -Recurse -Filter "*.reds"

foreach ($file in $files) {
    # Read with UTF-8 (handles BOM automatically)
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)

    # Replace with EXPLICIT CRLF (use `r`n, not just `n)
    $newContent = $content -replace 'old_pattern', "new_value`r`nnext_line"

    # Write with UTF-8 NO BOM
    [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8NoBom)
}
```

**Key Points**:
1. **Use `` `r`n ``** for line breaks (CRLF), never `` `n `` alone (LF)
2. **Create UTF-8 encoder**: `New-Object System.Text.UTF8Encoding $false` (no BOM)
3. **Use [System.IO.File]** methods: Avoid `Set-Content` (always adds BOM)

---

#### Verification Commands

**Check for BOM** (UTF-8 BOM = `EF BB BF`):
```powershell
$files = Get-ChildItem "path\to\scripts" -Recurse -Filter "*.reds"
$bomFiles = @()

foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bomFiles += $file.FullName
    }
}

Write-Host "Files with BOM: $($bomFiles.Count)"
$bomFiles | ForEach-Object { Write-Host "  $_" }
```

**Check Line Endings** (LF = `0A`, CRLF = `0D 0A`):
```powershell
$file = "path\to\file.reds"
$bytes = [System.IO.File]::ReadAllBytes($file)
$content = [System.Text.Encoding]::UTF8.GetString($bytes)

# Find first line break
$lfCount = ($content -split "`n").Count - 1
$crlfCount = ($content -split "`r`n").Count - 1

if ($crlfCount -eq $lfCount) {
    Write-Host "✅ CRLF line endings detected"
} else {
    Write-Host "❌ Mixed or LF-only line endings detected"
}
```

---

#### Fixing Encoding Issues

**Remove BOM from all files**:
```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$files = Get-ChildItem "path\to\scripts" -Recurse -Filter "*.reds"

foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        # Read with UTF-8 (strips BOM automatically)
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        # Write without BOM
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
        Write-Host "Fixed: $($file.Name)"
    }
}
```

**Fix LF line endings to CRLF**:
```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$files = Get-ChildItem "path\to\scripts" -Recurse -Filter "*.reds"

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)

    # Detect LF-only line breaks (not preceded by CR)
    if ($content -match '[^\r]\n') {
        # Replace all LF with CRLF (handles mixed line endings)
        $content = $content -replace '\r?\n', "`r`n"
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
        Write-Host "Fixed: $($file.Name)"
    }
}
```

---

#### Best Practices Summary

**DO**:
- ✅ Use `` `r`n `` for line breaks in PowerShell string replacements
- ✅ Create explicit UTF-8 no-BOM encoder: `New-Object System.Text.UTF8Encoding $false`
- ✅ Use `[System.IO.File]::WriteAllText()` with explicit encoding
- ✅ Verify encoding after batch operations (BOM + line ending checks)
- ✅ Test compilation after any file encoding changes

**DON'T**:
- ❌ Never use `Set-Content` for `.reds` files (adds BOM)
- ❌ Never use `` `n `` alone (produces LF, not CRLF)
- ❌ Never use `[System.Text.Encoding]::UTF8` in WriteAllText (adds BOM)
- ❌ Never assume PowerShell defaults are correct (they're Windows-centric, not REDscript-compatible)

---

#### Anti-Pattern: Unicode Box Drawing Characters Corruption

**Problem**: PowerShell's `WriteAllText()` with default UTF-8 encoding can corrupt Unicode Box Drawing Characters (U+2500-U+257F) in string literals, resulting in compilation errors.

**Example of Corrupted Code**:

```redscript
// Expected:
BNInfo("BreachStats", "╔═══════════════════════════════════════════════════════════╗");
BNInfo("BreachStats", "║         BREACH SESSION SUMMARY                           ║");
BNInfo("BreachStats", "└───────────────────────────────────────────────────────────┘");

// Actual (corrupted):
BNInfo("BreachStats", "╔═══════════════════════════════════════════════════════════╁E);
//                                                                                  ^^^ Missing closing quote

BNInfo("BreachStats", "╁E         BREACH SESSION SUMMARY                           ╁E);
//                     ^^                                                          ^^^ Both quotes missing

BNInfo("BreachStats", "━EType         : " + stats.breachType);
//                     ^^ Opening quote corrupted
```

**Compilation Error**:
```
[ERROR] At BreachSessionStats.reds:107:11:
  BNInfo("BreachStats", "╁E         BREACH SESSION SUMMARY                           ╁E);
          ^
syntax error, expected one of "!=", "%", "&", ...
```

**Root Cause**:

PowerShell string replacement (`-replace`) operates on character level, but `WriteAllText()` operates on byte level. When replacing strings containing multi-byte UTF-8 sequences (Box Drawing Characters), the operation may:
- Misalign byte boundaries
- Corrupt adjacent characters (especially ASCII quotes `"`)
- Insert incomplete UTF-8 sequences

**Corruption Pattern Examples**:

| Character | Unicode | UTF-8 Bytes | Potential Corruption |
|-----------|---------|-------------|---------------------|
| `╔` | U+2554 | `E2 95 94` | May corrupt adjacent `"` |
| `╗` | U+2557 | `E2 95 97` | May become `╁E` |
| `║` | U+2551 | `E2 95 91` | May become `╁E` |
| `┐` | U+2510 | `E2 94 90` | May become `━E` |
| `│` | U+2502 | `E2 94 82` | May become `━E` |
| `✓` | U+2713 | `E2 9C 93` | May become `✁E` |

**Technical Explanation**: When `WriteAllText()` processes multi-byte UTF-8 sequences during string replacement operations, it may:
1. Misinterpret final UTF-8 byte as part of string terminator
2. Apply incorrect byte-to-character conversion
3. Corrupt adjacent ASCII characters (especially quotes)

---

#### ✅ Correct Handling of Unicode Box Drawing Characters

**Pattern 1: Avoid Box Drawing Characters (Safest)**

```redscript
// ✅ SAFE: Use ASCII-only characters
BNInfo("BreachStats", "===========================================================");
BNInfo("BreachStats", "         BREACH SESSION SUMMARY                           ");
BNInfo("BreachStats", "===========================================================");
BNInfo("BreachStats", "--- BASIC INFO --------------------------------------------");
BNInfo("BreachStats", "  Type         : " + stats.breachType);
BNInfo("BreachStats", "-----------------------------------------------------------");
```

**Pattern 2: Test Encoding Before Batch Operations (If Box Drawing Required)**

```powershell
# ✅ SAFE: Test file with special characters first
$testFile = "path\to\test.reds"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# Create test content with box drawing characters
$testContent = @"
module Test
public func TestBoxDrawing() -> Void {
  BNInfo("Test", "╔═══╗");
  BNInfo("Test", "║ OK║");
  BNInfo("Test", "╚═══╝");
}
"@

# Write test file
[System.IO.File]::WriteAllText($testFile, $testContent, $utf8NoBom)

# Read back and verify
$readBack = [System.IO.File]::ReadAllText($testFile, [System.Text.Encoding]::UTF8)
if ($readBack -eq $testContent) {
    Write-Host "✓ Encoding test passed - safe to proceed"
} else {
    Write-Host "✗ Encoding test failed - characters corrupted"
    Write-Host "Expected: $testContent"
    Write-Host "Got:      $readBack"
    exit 1
}

# If test passes, proceed with batch operations
```

**Pattern 3: Use replace_string_in_file Tool (Recommended for Complex Unicode)**

```
When editing files with Unicode box drawing characters:
- ✅ Use replace_string_in_file tool (handles encoding correctly)
- ❌ Avoid PowerShell batch operations with -replace and WriteAllText()
```

---

#### Diagnosis Commands

**Detect Corrupted String Literals** (unclosed quotes):
```powershell
# Search for BNInfo/BNLog calls with potential corruption
$files = Get-ChildItem "path\to\scripts" -Recurse -Filter "*.reds"

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    # Look for BNInfo/BNLog calls with box drawing chars but missing closing quote
    if ($content -match 'BN(Info|Log|Debug|Warn|Error)\([^)]*"[^"]*[╔╗║╚╝┌┐│└━✓✗](?!.*")') {
        Write-Host "⚠️ Potential corruption in: $($file.FullName)"
        # Extract the suspicious line
        $lines = $content -split "`r`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'BN(Info|Log|Debug|Warn|Error)\([^)]*"[^"]*[╔╗║╚╝┌┐│└━✓✗]') {
                Write-Host "  Line $($i+1): $($lines[$i])"
            }
        }
    }
}
```

**Verify Box Drawing Character Encoding**:
```powershell
# Check if box drawing characters are correctly encoded as UTF-8
$file = "path\to\file.reds"
$bytes = [System.IO.File]::ReadAllBytes($file)
$content = [System.Text.Encoding]::UTF8.GetString($bytes)

# Look for box drawing characters
$boxDrawingChars = @('╔', '╗', '║', '╚', '╝', '┌', '┐', '│', '└', '┘')
foreach ($char in $boxDrawingChars) {
    $count = ($content.ToCharArray() | Where-Object { $_ -eq $char }).Count
    if ($count -gt 0) {
        Write-Host "Found $count instances of '$char' (U+$([int][char]$char).ToString('X4'))"
    }
}
```

---

#### Repair Corrupted Files

**Automated Fix for Common Corruption Patterns**:
```powershell
$files = Get-ChildItem "path\to\scripts" -Recurse -Filter "*.reds"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$fixCount = 0

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $originalContent = $content

    # Fix common corruption patterns (add closing quotes)
    $content = $content -replace '(BN(?:Info|Log|Debug|Warn|Error)\([^)]*"[^"]*[╔╗║╚╝┌┐│└━✓✗][^"]*)(╁E|━E|✁E)\)', '$1");'

    # Restore correct box drawing characters
    $content = $content -replace '╁E', '║'  # Restore vertical double line
    $content = $content -replace '━E', '│'  # Restore vertical single line
    $content = $content -replace '✁E', '✓'  # Restore checkmark

    if ($content -ne $originalContent) {
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
        Write-Host "Fixed: $($file.Name)"
        $fixCount++
    }
}

Write-Host "Total files fixed: $fixCount"
```

**Manual Verification** (Recommended After Automated Fix):
```powershell
# Compile and check for remaining errors
# If compilation still fails, manually inspect the corrupted lines reported by compiler
```

---

#### Best Practices for Unicode Content

**DO**:
- ✅ Use `replace_string_in_file` tool for files with Unicode box drawing characters
- ✅ Test encoding with small sample file before batch operations
- ✅ Verify file integrity after batch operations (grep for unclosed quotes)
- ✅ Use ASCII-only characters when possible (avoid Unicode decoration)
- ✅ Keep box drawing characters in separate, rarely-modified files

**DON'T**:
- ❌ Use PowerShell `-replace` + `WriteAllText()` on files with Unicode box drawing characters
- ❌ Assume UTF-8 encoding is "just text" (multi-byte sequences require careful handling)
- ❌ Batch-edit files without verifying encoding integrity
- ❌ Mix encoding operations (e.g., read with UTF-8, write with default encoding)

---

## REDscript Language Standards

### Language Constraints & Limitations

**⚠️ Unsupported Keywords:**

REDscript does **NOT** support the following control flow keywords commonly found in other languages:

1. **`continue`** - NOT AVAILABLE
```redscript
// ❌ INVALID: continue keyword does not exist
while i >= 0 {
    if ShouldSkip(i) {
        continue;  // ❌ COMPILATION ERROR
    }
    ProcessItem(i);
    i -= 1;
}

// ✅ CORRECT: Use if-else blocks instead
while i >= 0 {
    if ShouldSkip(i) {
        // Skip logic (empty or minimal processing)
    } else {
        ProcessItem(i);
    }
    i -= 1;
}

// ✅ ALTERNATIVE: Invert condition
while i >= 0 {
    if !ShouldSkip(i) {
        ProcessItem(i);
    }
    i -= 1;
}
```

2. **`break`** - Limited Support
```redscript
// ⚠️ Use with caution - may have limitations
while condition {
    if shouldExit {
        break;  // May not work in all contexts
    }
}

// ✅ PREFERRED: Use flag-based exit
let shouldContinue: Bool = true;
while shouldContinue && condition {
    if shouldExit {
        shouldContinue = false;
    }
}
```

**Workarounds for Control Flow:**

- **Early Return Pattern**: Preferred over complex conditionals
```redscript
// ✅ Good: Early return
public func ProcessDevice(device: ref<DeviceComponentPS>) -> Void {
    if !IsDefined(device) { return; }
    if !device.IsConnected() { return; }
    // Main logic here
}
```

- **Flag-Based Iteration Control**: When `break`/`continue` needed
```redscript
// ✅ Good: Use flags for complex iteration
let i: Int32 = 0;
let foundTarget: Bool = false;
while i < count && !foundTarget {
    if IsTarget(items[i]) {
        foundTarget = true;
    }
    i += 1;
}
```

### Array & Collection Operations

**⚠️ Method Availability:**

REDscript arrays do **NOT** have `.Size()` method when used with `script_ref<array<T>>`:

```redscript
// ❌ INVALID: .Size() not available on Deref(script_ref)
let actions: script_ref<array<ref<PuppetAction>>>;
let count: Int32 = Deref(actions).Size();  // ❌ COMPILATION ERROR

// ✅ CORRECT: Use ArraySize() function
let count: Int32 = ArraySize(Deref(actions));
```

**Common Array Operations:**
```redscript
// Get array size
let size: Int32 = ArraySize(array);

// Add element
ArrayPush(array, element);

// Remove element by index
ArrayErase(array, index);

// Remove element by value
ArrayRemove(array, element);

// Check if contains
let hasElement: Bool = ArrayContains(array, element);

// Clear array
ArrayClear(array);
```

**Working with script_ref:**
```redscript
// ✅ Correct pattern for script_ref<array<T>>
public func ModifyArray(arr: script_ref<array<ref<DeviceAction>>>) -> Void {
    let size: Int32 = ArraySize(Deref(arr));  // ✅ Use ArraySize()

    let i: Int32 = 0;
    while i < size {
        let element: ref<DeviceAction> = Deref(arr)[i];  // ✅ Deref for access
        // Process element
        i += 1;
    }

    ArrayPush(Deref(arr), newElement);  // ✅ Deref for modification
}
```

### Method Annotations

**Mod Compatibility Priority:**

1. **@wrapMethod** (Preferred)
```redscript
// ✅ Allows other mods to hook the same method
@wrapMethod(MinigameGenerationRuleScalingPrograms)
public func Process(minigame: ref<HackingMinigameGameController>) -> Void {
    wrappedMethod(minigame); // Call vanilla first
    // Add Better Netrunning logic
}
```

2. **@addMethod** (Safe)
```redscript
// ✅ Adds new method without affecting vanilla
@addMethod(ScriptableDeviceComponentPS)
public func SetActionsInactiveUnbreached(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
    // New functionality
}
```

3. **@replaceMethod** (Avoid When Possible)
```redscript
// ⚠️ BREAKS MOD COMPATIBILITY - Avoid unless absolutely necessary
@replaceMethod(ClassName)
public func MethodName() -> Void {
    // Complete replacement (must document why wrapping is impossible)
}
```

**When to use @replaceMethod:**
- Vanilla logic is fundamentally incompatible with requirements
- Cannot achieve desired behavior with wrapping
- **ALWAYS document why in comments**
- **ALWAYS verify compatibility with popular mods** (see COLLABORATION_THREAD.md)

**Before Using @replaceMethod:**
1. ✅ Try `@wrapMethod` first
2. ✅ Check if vanilla method can be extended with `@addMethod` helper
3. ✅ Review COLLABORATION_THREAD.md for known conflicts
4. ✅ Test with CustomHackingSystem, RadialBreach, and Daemon Netrunning (Revamp)
5. ✅ Document specific mod compatibility issues in comments
6. ⚠️ Only use if all above attempts fail

### Conditional Compilation

**External Mod Dependencies:**

```redscript
// CustomHackingSystem (HackingExtensions) integration
@if(ModuleExists("HackingExtensions"))
public class RemoteBreachAction extends BaseScriptableAction {
    // RemoteBreach code
}

@if(!ModuleExists("HackingExtensions"))
public class RemoteBreachAction extends BaseScriptableAction {
    // Fallback implementation (minimal or no-op)
}
```

**Guidelines:**
- Wrap all external mod code with `@if(ModuleExists())`
- Provide fallback implementations when possible
- Document required dependencies in file headers

### Persistent Fields

**Save Compatibility:**

```redscript
// ✅ Correct: Use specific types
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedCameras: Bool;

// ❌ Wrong: Changing types breaks saves
// v1.0: public persistent let m_flags: Bool;
// v1.1: public persistent let m_flags: Int32; // BREAKS SAVES!
```

**Guidelines:**
- Never change persistent field types
- Use descriptive names: `m_betterNetrunning*` prefix
- Document in `Events.reds` for centralized management

### Type System

**Common Types:**
```redscript
ref<T>          // Reference type (nullable)
wref<T>         // Weak reference (no ownership)
script_ref<T>   // Pass-by-reference for script types
TweakDBID       // Game database identifiers (t"...")
CName           // Compile-time name hash (n"...")
```

**Type Safety:**
```redscript
// ✅ Good: Explicit type checks
if IsDefined(device as SurveillanceCameraControllerPS) {
    // Safe camera-specific operations
}

// ❌ Bad: Unchecked casts
let camera: ref<SurveillanceCameraControllerPS> = device as SurveillanceCameraControllerPS;
camera.DoSomething(); // May crash if device is not a camera
```

### Game API Constraints

**⚠️ DeviceAction / ObjectAction API:**

The `DeviceAction` class has **limited or version-specific action identification methods**:

```redscript
// ❌ INVALID: GetObjectActionID() does not exist
let action: ref<DeviceAction> = Deref(actions)[i];
let actionID: TweakDBID = action.GetObjectActionID();  // ❌ COMPILATION ERROR

// ❌ INVALID: GetObjectActionRecord() may not exist (game version dependent)
let action: ref<DeviceAction> = Deref(actions)[i];
let actionRecord: ref<ObjectAction_Record> = action.GetObjectActionRecord();  // ❌ COMPILATION ERROR
let actionID: TweakDBID = actionRecord.GetID();

// ⚠️ GAME VERSION ISSUE: These APIs may work in some game versions but not others
// GetObjectActionRecord() was available in earlier development but failed in production

// ✅ WORKAROUND 1: Type-based identification (when TweakDBID not required)
if IsDefined(action as SpecificActionType) {
    // Process action based on type
}

// ✅ WORKAROUND 2: Direct TweakDB queries (complex, high implementation cost)
// Query TweakDB for action definitions and compare

// ✅ WORKAROUND 3: Graceful degradation (current approach)
// Temporarily disable action filtering functionality
private func RemoveVanillaActions(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
    return;  // Temporarily disabled
    // TODO: Re-implement when action identification API is available
}
```

**Impact:**
- Cannot reliably identify vanilla actions by TweakDBID
- Cannot remove duplicate actions (vanilla + custom both shown)
- Severity: MEDIUM (functionality degraded but not broken)

**Examples of Affected Code:**
- `TurretExtensions.reds` - RemoveVanilla*Actions() functions (4 functions disabled)
- `CameraExtensions.reds` - RemoveVanilla*Actions() functions (may have same issue)

**Guidelines for Action Identification:**
1. **Prefer type-based checks** when TweakDBID not required
2. **Document API unavailability** with NOTE comments
3. **Provide TODO comments** for future re-implementation
4. **Test across game versions** before assuming API availability

---

**⚠️ TargetingSystem API:**

The `TargetSearchFilter` struct may have limited or version-specific members:

```redscript
// ⚠️ MAY NOT WORK: API varies by game version
let filter: TargetSearchFilter;
filter.queryPreset = n"Interaction";  // ❌ May not exist
filter.maxDistance = 50.0;            // ❌ May not exist

// ✅ ALTERNATIVE: Use simplified queries or fallback logic
// Document API unavailability and provide graceful degradation
if !IsDefined(targetingSystem) {
    BNLog("TargetingSystem unavailable - using fallback");
    // Fallback logic (e.g., allow all types)
}
```

**Guidelines for External APIs:**
1. Always check game version compatibility
2. Provide fallback implementations for unavailable APIs
3. Document API limitations in comments
4. Use `IsDefined()` checks before calling methods
5. Wrap experimental APIs with try-catch equivalent (early returns)

---

## Naming Conventions

### Variables

```redscript
// Local variables: camelCase
let deviceType: DeviceType;
let breachRadius: Float;
let unlockFlags: BreachUnlockFlags;

// Constants: UPPER_SNAKE_CASE (if REDscript supports)
let MAX_BREACH_RADIUS: Float = 100.0;

// Persistent fields: m_prefixCamelCase
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedBasic: Bool;
```

### Functions

```redscript
// Public functions: PascalCase
public func GetDeviceType() -> DeviceType { }
public func ApplyBreachUnlock() -> Void { }

// Private functions: PascalCase (same as public)
private func ValidatePrerequisites() -> Bool { }

// Static utility functions: PascalCase
public static func GetRadialBreachRange(gameInstance: GameInstance) -> Float { }
```

### Classes & Structs

```redscript
// Classes: PascalCase
public class DeviceTypeUtils { }
public class CameraUnlockStrategy extends IDaemonUnlockStrategy { }

// Structs: PascalCase
public struct BreachUnlockFlags {
    public let unlockBasic: Bool;
    public let unlockCameras: Bool;
}

// Enums: PascalCase
public enum DeviceType {
    NPC = 0,
    Camera = 1,
    Turret = 2
}
```

### Events

```redscript
// Event classes: PascalCase (noun)
public class SetBreachedSubnet extends ActionBool { }

// Event handlers: OnEventName
@addMethod(SharedGameplayPS)
public func OnSetBreachedSubnet(evt: ref<SetBreachedSubnet>) -> EntityNotificationType { }
```

---

## Module Design Patterns

### Utility Module Pattern

**Structure:**
```redscript
// DeviceTypeUtils.reds - Centralized utility functions
module BetterNetrunning.Common

public class DeviceTypeUtils {
    // Static utility functions only (no state)
    public static func GetDeviceType(devicePS: ref<ScriptableDeviceComponentPS>) -> DeviceType { }
    public static func IsBreached(deviceType: DeviceType, sharedPS: ref<SharedGameplayPS>) -> Bool { }
    public static func GetRadialBreachRange(gameInstance: GameInstance) -> Float { }
}
```

**Guidelines:**
- Pure functions (no side effects)
- Static methods only
- No instance state
- Single responsibility

### Strategy Pattern

**Implementation:**
```redscript
// 1. Define strategy interface
public abstract class IDaemonUnlockStrategy {
    public abstract func Execute(devicePS: ref<SharedGameplayPS>, flags: BreachUnlockFlags) -> Void;
}

// 2. Implement concrete strategies
public class CameraUnlockStrategy extends IDaemonUnlockStrategy {
    public func Execute(devicePS: ref<SharedGameplayPS>, flags: BreachUnlockFlags) -> Void {
        if !flags.unlockCameras { return; }
        let camera = devicePS as SurveillanceCameraControllerPS;
        // Camera-specific unlock logic
    }
}

// 3. Strategy factory
public static func GetUnlockStrategy(deviceType: DeviceType) -> ref<IDaemonUnlockStrategy> {
    switch deviceType {
        case DeviceType.Camera: return new CameraUnlockStrategy();
        case DeviceType.Turret: return new TurretUnlockStrategy();
        default: return new BasicDeviceUnlockStrategy();
    }
}
```

**Benefits:**
- Easy to add new device types
- Testable in isolation
- Follows Open/Closed Principle

### Event-Driven Pattern

**Implementation:**
```redscript
// 1. Define event
public class SetBreachedSubnet extends ActionBool {
    public let breachedBasic: Bool;
    public let breachedCameras: Bool;

    public final func SetProperties() -> Void {
        this.actionName = n"SetBreachedSubnet";
        this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(
            this.actionName, true, n"SetBreachedSubnet", n"SetBreachedSubnet"
        );
    }
}

// 2. Send event
public func PropagateBreachState() -> Void {
    let evt: ref<SetBreachedSubnet> = new SetBreachedSubnet();
    evt.breachedBasic = true;
    evt.breachedCameras = true;
    device.QueueEvent(evt);
}

// 3. Handle event
@addMethod(SharedGameplayPS)
public func OnSetBreachedSubnet(evt: ref<SetBreachedSubnet>) -> EntityNotificationType {
    if evt.breachedBasic { this.m_betterNetrunningBreachedBasic = true; }
    if evt.breachedCameras { this.m_betterNetrunningBreachedCameras = true; }
    return EntityNotificationType.DoNotNotifyEntity;
}
```

**Benefits:**
- Decoupled communication
- Network-wide state propagation
- Event-driven architecture

---

## Mod Compatibility

### Method Wrapping Guidelines

**1. Always Prefer @wrapMethod:**
```redscript
@wrapMethod(MinigameGenerationRuleScalingPrograms)
public func Process(minigame: ref<HackingMinigameGameController>) -> Void {
    wrappedMethod(minigame); // Call vanilla first
    // Better Netrunning modifications after
}
```

**2. Document Why @replaceMethod is Used (Critical):**
```redscript
/*
 * VANILLA DIFF: Replaces SetActionsInactiveAll() with progressive unlock logic
 * RATIONALE: Vanilla implementation unconditionally disables all quickhacks.
 *            Cannot wrap because we need to prevent vanilla from running.
 * MOD COMPATIBILITY IMPACT: May conflict with mods that also replace this method.
 * ALTERNATIVE ATTEMPTS:
 *   - @wrapMethod: Failed - vanilla logic runs before our logic can prevent it
 *   - Helper method: Failed - no hook points in vanilla code
 * COMPATIBILITY VERIFICATION:
 *   - ✅ Tested with CustomHackingSystem v1.2.3 - No conflicts
 *   - ⚠️ Potential conflict with [ModName] - see COLLABORATION_THREAD.md
 * REVIEW DATE: 2025-10-12
 */
@replaceMethod(ScriptableDeviceComponentPS)
public func SetActionsInactiveAll() -> Void {
    // Progressive unlock logic
}
```

**3. Acceptable Trade-offs for @wrapMethod (2025-10-12 Policy):**

When converting @replaceMethod to @wrapMethod for mod compatibility:

**✅ Acceptable Compromises:**
- **Composed Method Pattern Degradation**: `wrappedMethod()` becomes a black box (76 lines of vanilla code). This is acceptable because:
  - Vanilla source code is available for reference (`tools\redmod\scripts\`)
  - Vanilla logic is stable (infrequent patches)
  - Mod compatibility gains outweigh design purity
- **Debug Complexity**: Cannot trace inside `wrappedMethod()` with Better Netrunning logs. Use vanilla source code + deduction for debugging.
- **Redundant Processing**: Vanilla daemon effects (180s camera/turret shutdown) + Better Netrunning permanent unlocks run concurrently. This is acceptable as it provides progressive enhancement.

**Implementation Pattern:**
```redscript
@wrapMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
    // Phase 1: Pre-processing (inject bonus daemons into Blackboard)
    this.InjectBonusDaemons();

    // Phase 2: Vanilla processing (76-line black box - acceptable)
    // Executes: FilterRedundantPrograms, ProcessLoot, ProcessMinigameNetworkActions,
    //           RewardMoney, RPGManager.GiveReward
    wrappedMethod(devices);

    // Phase 3: Post-processing (Better Netrunning extensions)
    this.ApplyProgressiveSubnetUnlocking(devices);
    this.RecordNetworkBreachPosition(devices);
    this.ExecuteNPCBreachPingIfNeeded();
}
```

**Rationale for Policy Change:**
- **2025-10-12 Decision**: Mod compatibility is higher priority than Composed Method pattern adherence
- **Risk Assessment**: Debug complexity is manageable with vanilla source code access
- **Compatibility Verification**: Must test with CustomHackingSystem, RadialBreach, Daemon Netrunning (see COLLABORATION_THREAD.md)

**3. Check Existing Mod Compatibility:**

See `COLLABORATION_THREAD.md` for discussions with:
- Daemon Netrunning (Revamp)
- Breach Takedown Improved
- RadialBreach MOD

**4. Test with Popular Mods:**
- CustomHackingSystem (HackingExtensions)
- RadialBreach
- Daemon Netrunning (Revamp)

**5. When @replaceMethod is Unavoidable:**

Only use @replaceMethod if ALL of the following are true:
- ✅ Vanilla logic fundamentally conflicts with requirements (e.g., must prevent vanilla execution)
- ✅ @wrapMethod cannot achieve desired behavior (documented with specific technical reason)
- ✅ No helper method workaround exists
- ✅ Compatibility impact is documented and verified with popular mods
- ✅ Benefits outweigh mod compatibility cost

**Example: When @replaceMethod is justified:**
```redscript
/*
 * VANILLA DIFF: Replaces vanilla daemon processing with Progressive Subnet Unlocking
 * RATIONALE: Vanilla executes ProcessMinigameNetworkActions(devices[i]) which triggers
 *            180-second camera/turret shutdown daemons. Better Netrunning replaces this
 *            with permanent quickhack unlocks. Cannot wrap because vanilla daemon
 *            execution is embedded in RefreshSlaves() (lines 481-484) with no hook point.
 * @wrapMethod ATTEMPT (2025-10-12): Considered but rejected because:
 *   - Composed Method pattern degradation is acceptable
 *   - Mod compatibility is higher priority
 *   - Vanilla + Better Netrunning daemons can coexist
 * DECISION: Convert to @wrapMethod to prioritize mod compatibility
 * MOD COMPATIBILITY IMPACT: None (wrapping allows other mods to hook)
 * REVIEW DATE: 2025-10-12
 */
```

### Conditional Compilation for External Mods

```redscript
// RadialBreach integration
@if(ModuleExists("RadialBreach"))
public static func GetRadialBreachRange(gameInstance: GameInstance) -> Float {
    let settings: ref<RadialBreachSettings> = new RadialBreachSettings();
    return settings.breachRange;
}

@if(!ModuleExists("RadialBreach"))
public static func GetRadialBreachRange(gameInstance: GameInstance) -> Float {
    return 50.0; // Default fallback
}
```

**Guidelines:**
- Always provide fallback implementations
- Document external dependencies in file headers
- Test both with and without optional mods

---

## Error Handling & Validation

### Defensive Programming

**1. Null Checks:**
```redscript
// ✅ Good: Check before using
public func ProcessDevice(device: ref<DeviceComponentPS>) -> Void {
    if !IsDefined(device) {
        BNLog("[ProcessDevice] ERROR: Device is null");
        return;
    }

    let sharedPS = device as SharedGameplayPS;
    if !IsDefined(sharedPS) {
        BNLog("[ProcessDevice] ERROR: Device is not SharedGameplayPS");
        return;
    }

    // Safe to use sharedPS
}

// ❌ Bad: No null checks
public func ProcessDevice(device: ref<DeviceComponentPS>) -> Void {
    let sharedPS = device as SharedGameplayPS;
    sharedPS.DoSomething(); // May crash if device is null or wrong type
}
```

**2. Boundary Validation:**
```redscript
// ✅ Good: Validate ranges
public func SetBreachRadius(radius: Float) -> Void {
    if radius <= 0.0 {
        BNLog("[SetBreachRadius] ERROR: Invalid radius: " + ToString(radius));
        return;
    }
    if radius > 1000.0 {
        BNLog("[SetBreachRadius] WARNING: Unusually large radius: " + ToString(radius));
    }
    this.m_breachRadius = radius;
}
```

**3. Early Validation:**
```redscript
// ✅ Good: Validate at function entry
public func ApplyBreach(device: ref<DeviceComponentPS>, flags: BreachUnlockFlags) -> Bool {
    if !IsDefined(device) { return false; }
    if !flags.unlockBasic && !flags.unlockCameras { return false; }

    // Proceed with breach logic
    return true;
}
```

### Logging Guidelines

**Use BNLog() Wrapper:**
```redscript
// Common/Logger.reds provides BNLog()
public func BNLog(message: String) -> Void {
    if BetterNetrunningSettings.EnableDebugLog() {
        ModLog(n"BetterNetrunning", message);
    }
}
```

**Log Levels (by context):**
```redscript
// Information: Normal flow
BNLog("[Breach] Processing breach completion");

// Warning: Unexpected but recoverable
BNLog("[Breach] WARNING: No devices found in network");

// Error: Operation failed
BNLog("[Breach] ERROR: Failed to apply unlock - device is null");
```

**Structured Logging:**
```redscript
// ✅ Good: Context + Message
BNLog("[RemoteBreach] Starting breach on Computer device");
BNLog("[RemoteBreach] Found " + ToString(deviceCount) + " network devices");
BNLog("[RemoteBreach] Breach complete - unlocked " + ToString(unlockedCount) + " devices");

// ❌ Bad: Vague messages
BNLog("Starting");
BNLog("Found some devices");
BNLog("Done");
```

---

## Performance Considerations

### 1. Avoid Expensive Operations in Loops

**❌ Bad Example:**
```redscript
// Fetches range every iteration
for device in devices {
    let range: Float = DeviceTypeUtils.GetRadialBreachRange(gameInstance); // Expensive!
    if this.IsWithinRange(device, range) {
        // Process
    }
}
```

**✅ Good Example:**
```redscript
// Fetch once before loop
let range: Float = DeviceTypeUtils.GetRadialBreachRange(gameInstance);
for device in devices {
    if this.IsWithinRange(device, range) {
        // Process
    }
}
```

### 2. Use Early Returns to Skip Processing

```redscript
// ✅ Good: Skip unnecessary work
public func ShouldRemoveProgram(actionID: TweakDBID) -> Bool {
    if !this.IsBreached() { return false; } // Early exit
    if !this.IsNetworkConnected() { return false; } // Early exit

    // Expensive operations only if needed
    return this.CheckComplexCondition(actionID);
}
```

### 3. Cache Frequently Accessed Data

```redscript
// ✅ Good: Cache player reference
private let m_cachedPlayer: wref<PlayerPuppet>;

public func GetPlayer(gameInstance: GameInstance) -> ref<PlayerPuppet> {
    if !IsDefined(this.m_cachedPlayer) {
        this.m_cachedPlayer = GetPlayer(gameInstance);
    }
    return this.m_cachedPlayer;
}
```

### 4. Optimize Distance Calculations

```redscript
// ✅ Good: Use squared distance (avoids sqrt)
let distanceSq: Float = Vector4.DistanceSquared(pos1, pos2);
let radiusSq: Float = radius * radius;
if distanceSq <= radiusSq {
    // Within range
}

// ❌ Bad: Unnecessary sqrt operation
let distance: Float = Vector4.Distance(pos1, pos2); // Calls sqrt()
if distance <= radius {
    // Within range
}
```

---

## Testing Guidelines

### Manual Testing Checklist

**1. Breach Scenarios:**
- [ ] AP Breach (AccessPoint interaction)
- [ ] Unconscious NPC Breach (regular NPC)
- [ ] Unconscious NPC Breach (netrunner)
- [ ] RemoteBreach on Computer
- [ ] RemoteBreach on Camera
- [ ] RemoteBreach on Turret
- [ ] RemoteBreach on Terminal
- [ ] RemoteBreach on Vehicle

**2. Network Scenarios:**
- [ ] Networked devices (connected to AP)
- [ ] Standalone devices (no AP connection)
- [ ] Mixed network (some connected, some standalone)

**3. RadialBreach Integration:**
- [ ] With RadialBreach MOD installed
- [ ] Without RadialBreach MOD (fallback to 50m)
- [ ] User-configured breach radius

**4. Settings Validation:**
- [ ] EnableClassicMode = true (vanilla behavior)
- [ ] UnlockIfNoAccessPoint = true (standalone auto-unlock)
- [ ] RemoteBreachEnabled* toggles
- [ ] AutoDatamineBySuccessCount

**5. Save Compatibility:**
- [ ] Load saves from previous version
- [ ] Persistent fields maintain values
- [ ] No corruption or crashes

### Debug Logging

**Enable Debug Mode:**
```redscript
// config.reds
public static func EnableDebugLog() -> Bool { return true; }
```

**Check Logs:**
- Location: `r6/logs/`
- Look for `[BetterNetrunning]` prefix
- Verify flow: Injection → Filtering → Completion → Unlock

**Common Debug Points:**
```redscript
BNLog("[FilterPlayerPrograms] Starting daemon filtering");
BNLog("[FilterPlayerPrograms] Programs after injection: " + ToString(count));
BNLog("[ApplyBreachUnlock] Unlocking " + ToString(deviceCount) + " devices");
BNLog("[RemoteBreach] Breach complete - success");
```

---

## Documentation Requirements

### File Header Template

```redscript
// ============================================================================
// [Module Name] - [Purpose]
// ============================================================================
//
// PURPOSE:
// [Simple description of what this module does]
//
// FUNCTIONALITY:
// - [Feature 1]: [Description]
// - [Feature 2]: [Description]
//
// ARCHITECTURE:
// - [Design Pattern]: [Usage]
// - [Structure]: [Max nesting depth, helper structure]
//
// DEPENDENCIES:
// - [Module 1]: [Purpose]
// - [Module 2]: [Purpose]
//
// EXTERNAL MOD DEPENDENCIES:
// - [Optional Mod 1]: [Conditional compilation details]
// ============================================================================
```

### Function Documentation Template

```redscript
/*
 * [Function purpose in one sentence]
 *
 * PURPOSE: [What this function does]
 * PARAMETERS:
 *   - param1: [Description]
 *   - param2: [Description]
 * RETURNS: [Return value description]
 * RATIONALE: [Why this implementation exists]
 * ARCHITECTURE: [Pattern used, nesting depth]
 * VANILLA DIFF: [Only for @replaceMethod - what changed from vanilla]
 */
@[annotation](ClassName)
public func FunctionName(param1: Type1, param2: Type2) -> ReturnType {
```

### Inline Comment Guidelines

**✅ Good Comments:**
```redscript
// Step 1: Validate prerequisites
if !this.ValidateDevice(device) { return; }

// Step 2: Parse daemon unlock flags from program list
let flags = this.ParseUnlockFlags(programs);

// Physical distance check (RadialBreach integration)
let withinRange = this.IsWithinRange(device, breachPos, maxDistance);
```

**❌ Bad Comments:**
```redscript
// Call function (obvious)
this.DoSomething();

// i = 0 (redundant)
let i = 0;

// Loop through devices (obvious)
for device in devices {
```

**Comment Requirements:**
- Explain "why", not "what"
- Document complex algorithms
- Reference external dependencies
- Note performance optimizations
- Flag known issues with TODO/FIXME

---

## Code Review Checklist

### Architecture & Design
- [ ] Follows Single Responsibility Principle
- [ ] No duplicate code (DRY violated)
- [ ] Uses appropriate design patterns
- [ ] Max 3 levels of nesting (4+ allowed if small blocks with comments)
- [ ] Functions under 30 lines
- [ ] Clear module boundaries

### REDscript Standards
- [ ] Prefers @wrapMethod over @replaceMethod
- [ ] @replaceMethod usage: Documented with RATIONALE + ALTERNATIVE ATTEMPTS + COMPATIBILITY VERIFICATION
- [ ] @replaceMethod usage: Verified with popular mods (see COLLABORATION_THREAD.md)
- [ ] External mod code wrapped with @if(ModuleExists())
- [ ] Persistent fields use descriptive names
- [ ] Proper null checks before use
- [ ] Type casting validated with IsDefined()

### Naming & Style
- [ ] Variables: camelCase
- [ ] Functions: PascalCase
- [ ] Classes: PascalCase
- [ ] Persistent fields: m_betterNetrunning* prefix
- [ ] Consistent naming across module

### Error Handling
- [ ] Null pointer checks
- [ ] Boundary validation
- [ ] Early returns for invalid input
- [ ] Structured logging with BNLog()

### Performance
- [ ] No expensive operations in loops
- [ ] Squared distance for range checks
- [ ] Cached frequently accessed data
- [ ] Early exits to skip unnecessary work

### Documentation
- [ ] File header with PURPOSE/FUNCTIONALITY
- [ ] Function comments for complex logic
- [ ] Inline comments explain "why"
- [ ] No prohibited documentation patterns (see CODING_STANDARDS.md)

### Testing
- [ ] Manually tested in-game
- [ ] Verified with/without optional mods
- [ ] Checked save compatibility
- [ ] Debug logs reviewed

### Mod Compatibility
- [ ] Uses @wrapMethod where possible
- [ ] Documents why @replaceMethod is necessary
- [ ] Conditional compilation for external mods
- [ ] Tested with popular mods

### Circular Dependency Prevention
- [ ] No imports from lower layers to higher layers (Common → Feature forbidden)
- [ ] Common modules do not import Feature modules (CustomHacking, Breach, Devices, etc.)
- [ ] No imports to entry point file (betterNetrunning.reds)
- [ ] New imports verified with grep for circular patterns: `grep -r "import.*ModuleName" r6/scripts/`
- [ ] Module hierarchy respected (Entry → Feature → Common → Config)

---

## Quick Reference

### Common Patterns

**Device Type Detection:**
```redscript
let deviceType = DeviceTypeUtils.GetDeviceType(devicePS);
```

**Breach Range (Dynamic):**
```redscript
let range = DeviceTypeUtils.GetRadialBreachRange(gameInstance);
```

**Null-Safe Device Cast:**
```redscript
if IsDefined(device as SurveillanceCameraControllerPS) {
    let camera = device as SurveillanceCameraControllerPS;
    // Safe to use camera
}
```

**Event Propagation:**
```redscript
let evt = new SetBreachedSubnet();
evt.breachedCameras = true;
device.QueueEvent(evt);
```

**Structured Logging:**
```redscript
BNLog("[Context] Message with " + ToString(value));
```

---

## Related Documents

- **ARCHITECTURE_DESIGN.md** - System architecture (991 lines)
- **BREACH_SYSTEM_REFERENCE.md** - Breach system technical reference (939 lines)
- **CODING_STANDARDS.md** - Documentation style guide (462 lines)
- **TODO.md** - Development roadmap (1,048 lines)

---

**Issue Date:** 2025-10-12
**Version:** 1.0
**Scope:** All Better Netrunning REDscript files
**Revision History:**
- v1.0 (2025-10-12) - Initial release based on ARCHITECTURE_DESIGN.md and BREACH_SYSTEM_REFERENCE.md
