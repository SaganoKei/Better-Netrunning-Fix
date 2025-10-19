# Better Netrunning - Documentation Standards

**Last Updated:** 2025-10-12

---

## 📋 Basic Principles

### 1. Document Current Specification Only

**❌ Prohibited:**
```redscript
// VERSION HISTORY:
// - Release version: Used @replaceMethod
// - Latest version: Changed to @wrapMethod
```

**✅ Recommended:**
```redscript
// FUNCTIONALITY:
// - Uses @wrapMethod for better mod compatibility
```

---

### 2. No Version Comparisons

**❌ Prohibited:**
- "Release version vs Latest version"
- "Before / After"
- "Improved from..."
- "Better than..."
- "Enhanced version"

**✅ Recommended:**
- "Current implementation"
- "Functionality"
- "Architecture"
- "Uses [Pattern]"

---

### 3. No Metrics Comparisons

**❌ Prohibited:**
```redscript
// REFACTORED: Reduced from 95 lines with 5-level nesting to 30 lines with 2-level nesting
```

**✅ Recommended:**
```redscript
// ARCHITECTURE: Composed Method pattern with shallow nesting (max 2 levels)
```

---

### 4. No Development Phase References

**❌ Prohibited:**
```redscript
// PHASE 1 IMPLEMENTATION (Partial Network Unlock):
// PHASE 2 IMPLEMENTATION (Full Network Unlock):
// Phase 3 feature
```

**✅ Recommended:**
```redscript
// FUNCTIONALITY:
// - Target device unlock: Immediate unlock of breached device
// - Network-wide unlock: Propagates unlock to all connected devices
```

---

## 📝 Comment Writing Standards

### A. File Headers

**Structure:**
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
// - [Structure]: [Description]
//
// DEPENDENCIES:
// - [Module 1]: [Purpose]
// - [Module 2]: [Purpose]
// ============================================================================
```

**Example:**
```redscript
// ============================================================================
// BetterNetrunning - RemoteBreach Network Unlock
// ============================================================================
//
// PURPOSE:
// Extends RemoteBreach to apply network effects similar to AccessPoint breach
//
// FUNCTIONALITY:
// - Target device unlock: Immediate unlock of breached device
// - Network-wide unlock: Propagates unlock to all connected devices
// - Radial Unlock: Records breach position (50m radius)
//
// ARCHITECTURE:
// - Blackboard listener for minigame completion detection
// - DeviceTypeUtils for unified device unlock logic
// - Shallow nesting (max 2 levels) using helper methods
//
// DEPENDENCIES:
// - BetterNetrunning.Common.* (DeviceTypeUtils, BNLog)
// - BetterNetrunning.CustomHacking.* (RemoteBreachStateSystem)
// ============================================================================
```

---

### B. Function Comments

**Structure:**
```redscript
/*
 * [Function purpose in one sentence]
 *
 * VANILLA DIFF: [How it differs from vanilla if @replaceMethod]
 * RATIONALE: [Why this implementation exists]
 * ARCHITECTURE: [Pattern used, nesting depth, helper structure]
 */
@[annotation](ClassName)
public func FunctionName() -> ReturnType {
```

**Example:**
```redscript
/*
 * Applies progressive unlock restrictions to device quickhacks before breach
 *
 * VANILLA DIFF: Replaces SetActionsInactiveAll() with progressive unlock logic
 * RATIONALE: Allow players to access more quickhacks as they progress
 * ARCHITECTURE: Shallow nesting (max 2 levels) using Extract Method pattern
 */
@addMethod(ScriptableDeviceComponentPS)
public func SetActionsInactiveUnbreached(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
```

---

### C. Inline Comments

**Good Examples:**
```redscript
// Step 1: Get active minigame programs
let programs: array<TweakDBID> = this.GetActivePrograms();

// Step 2: Apply device-specific unlock
this.ApplyDeviceUnlock(programs);

// Physical distance check (RadialBreach integration)
let withinRadius: Bool = this.IsWithinRadius(device, position, maxDistance);
```

**Bad Examples:**
```redscript
// Phase 1: Get programs ❌
// Improved version (was buggy before) ❌
// Reduced from 50 lines to 10 lines ❌
// Better than old implementation ❌
```

---

## 🎯 Allowed Descriptions

### 1. Functionality Descriptions

**✅ OK:**
```redscript
// FUNCTIONALITY:
// - Auto-execute PING on daemon success
// - Auto-apply Datamine based on success count
```

### 2. Architecture Patterns

**✅ OK:**
```redscript
// ARCHITECTURE: Strategy Pattern for device-specific unlock
// Uses Composed Method pattern with shallow nesting (max 2 levels)
```

### 3. Implementation Rationale

**✅ OK:**
```redscript
// RATIONALE:
// Vanilla checks device power state, which prevents unlocking disabled devices.
// Better Netrunning removes these checks to allow unlocking all devices.
```

### 4. Technical Constraints

**✅ OK:**
```redscript
// CRITICAL: Remove already-breached programs AFTER wrappedMethod()
// This ensures actionID fields are properly initialized by vanilla logic
```

### 5. Dependencies

**✅ OK:**
```redscript
// DEPENDENCY: Requires CustomHackingSystem (HackingExtensions mod)
// @if(ModuleExists("HackingExtensions"))
```

---

## 🚫 Prohibited Descriptions

### 1. Version History

**❌ Prohibited:**
```redscript
// VERSION HISTORY:
// - v1.0: Initial implementation
// - v1.1: Added feature X
// - v1.2: Improved performance
```

### 2. Metrics Comparisons

**❌ Prohibited:**
```redscript
// REFACTORED: Reduced from 100 lines to 25 lines
// Reduced nesting from 6 levels to 2 levels
// Eliminated 509 lines of duplicate code
```

### 3. Relative Evaluations

**❌ Prohibited:**
```redscript
// Improved version (old version was slow)
// Better implementation than before
// Enhanced performance compared to v1.0
// More efficient than previous code
```

### 4. Development Phases

**❌ Prohibited:**
```redscript
// PHASE 1 IMPLEMENTATION
// Phase 2 feature
// TODO: Phase 3 will add...
```

### 5. Release Comparisons

**❌ Prohibited:**
```redscript
// Release version: Used approach A
// Latest version: Changed to approach B
// Current version: Uses approach C
```

---

## 🔍 Code Review Checklist

Check the following during review:

- [ ] No VERSION HISTORY section
- [ ] No "Release version" / "Latest version" descriptions
- [ ] No "PHASE N" references
- [ ] No "Reduced from X to Y" metrics comparisons
- [ ] No "Improved" / "Better" / "Enhanced" relative evaluations
- [ ] No "Before / After" comparisons
- [ ] Architecture patterns are clearly specified
- [ ] Functionality descriptions are objective

---

## 📊 Good vs Bad Examples

### Example 1: File Header

**❌ Bad Example:**
```redscript
// ============================================================================
// RemoteBreach System
// ============================================================================
// VERSION HISTORY:
// - v1.0: Basic implementation
// - v1.1: Added Phase 2 features
// - v1.2: Improved performance (50% faster)
//
// PHASE 1 IMPLEMENTATION:
// - Basic device unlock
// PHASE 2 IMPLEMENTATION:
// - Network-wide unlock (better than Phase 1)
// ============================================================================
```

**✅ Good Example:**
```redscript
// ============================================================================
// RemoteBreach System
// ============================================================================
// PURPOSE:
// Enables breaching devices remotely without physical Access Points
//
// FUNCTIONALITY:
// - Target device unlock: Immediate unlock of breached device
// - Network-wide unlock: Propagates unlock to all connected devices
//
// ARCHITECTURE:
// - Strategy Pattern for device-specific unlock logic
// - Shallow nesting (max 2 levels) using helper methods
// ============================================================================
```

---

### Example 2: Function Comment

**❌ Bad Example:**
```redscript
/*
 * Processes breach completion
 *
 * VERSION HISTORY:
 * - Release version: 95 lines with 5-level nesting (hard to read)
 * - Latest version: 30 lines with 2-level nesting (much better)
 *
 * REFACTORED: Reduced complexity by 65% using Composed Method pattern
 */
```

**✅ Good Example:**
```redscript
/*
 * Processes breach completion and unlocks quickhacks network-wide
 *
 * FUNCTIONALITY:
 * - Auto-execute PING on daemon success
 * - Auto-apply Datamine based on daemon count
 * - Record breach position for radial unlock
 *
 * ARCHITECTURE: Composed Method pattern with shallow nesting (max 2 levels)
 */
```

---

### Example 3: Inline Comment

**❌ Bad Example:**
```redscript
// Phase 1: Parse programs
let programs = this.ParsePrograms();

// Phase 2: Apply unlock (improved version)
this.ApplyUnlock(programs);

// Reduced from 20 lines to 3 lines
return true;
```

**✅ Good Example:**
```redscript
// Step 1: Parse minigame programs
let programs = this.ParsePrograms();

// Step 2: Apply device-specific unlock
this.ApplyUnlock(programs);

// Record breach position for standalone device support
this.RecordBreachPosition();
```

---

## 🛠️ Automated Validation Script

### PowerShell Validation Script

```powershell
# check-coding-standards.ps1
# Better Netrunning Coding Standards Checker

$violations = @()
$files = Get-ChildItem -Path "r6\scripts\BetterNetrunning" -Recurse -Filter "*.reds"

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw

    # Check for prohibited patterns
    if ($content -match "VERSION HISTORY") {
        $violations += "$($file.Name): Contains VERSION HISTORY"
    }
    if ($content -match "Release version|Latest version|Current version") {
        $violations += "$($file.Name): Contains version comparison"
    }
    if ($content -match "PHASE \d+") {
        $violations += "$($file.Name): Contains PHASE reference"
    }
    if ($content -match "Reduced from .+ to .+ lines") {
        $violations += "$($file.Name): Contains metrics comparison"
    }
    if ($content -match "Improved|Better|Enhanced|Eliminated") {
        $violations += "$($file.Name): Contains relative evaluation"
    }
}

if ($violations.Count -eq 0) {
    Write-Host "✅ All files comply with coding standards" -ForegroundColor Green
} else {
    Write-Host "❌ Found $($violations.Count) violations:" -ForegroundColor Red
    $violations | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
```

---

## 📚 References

### Recommended Comment Sections

1. **PURPOSE**: Module purpose (1-2 sentences)
2. **FUNCTIONALITY**: Feature list
3. **ARCHITECTURE**: Design patterns, structure
4. **RATIONALE**: Implementation rationale
5. **DEPENDENCIES**: Dependencies
6. **VANILLA DIFF**: Differences from vanilla (for @replaceMethod)

### Discouraged/Prohibited Sections

1. ❌ **VERSION HISTORY**: Version history
2. ❌ **REFACTORED**: Refactoring history
3. ❌ **PHASE N**: Development phases
4. ❌ **BEFORE/AFTER**: Before/after comparisons
5. ❌ **IMPROVEMENTS**: List of improvements

---

**Issue Date:** 2025-10-11
**Scope:** All Better Netrunning modules
**Revision History:** v1.0 (2025-10-11) - Initial release
