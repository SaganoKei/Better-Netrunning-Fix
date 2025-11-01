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

### A. Class/Module Headers (Detailed Documentation)

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
// ============================================================================
```
---

### B. Method Comments (Simplified Format)

**Methods with Parameters/Return Values - Detailed Format:**
```redscript
/*
 * Applies progressive unlock restrictions to device quickhacks
 *
 * @param actions - Array of device actions to filter
 * @param deviceType - Type of device being processed
 * @return Number of actions processed
 */
@addMethod(ScriptableDeviceComponentPS)
public func SetActionsInactiveUnbreached(actions: script_ref<array<ref<DeviceAction>>>, deviceType: DeviceType) -> Int32 {
```

**Methods without Parameters/Return Values - Single Line:**
```redscript
// Initializes the breach processing system
@addMethod(AccessPointControllerPS)
public func InitializeBreachSystem() -> Void {
```

**Methods with Multiple Features - Bulleted List Format:**
```redscript
/*
 * Checks if device is breached with expiration support
 *
 * Features:
 * - Returns true if device has valid (non-expired) breach timestamp
 * - Supports permanent unlock (duration = 0)
 * - Supports temporary unlock with expiration check
 * - Applies to all breach types (AP/NPC/Remote)
 */
@addMethod(ScriptableDeviceComponentPS)
public func IsBreached() -> Bool {
```

**Complex Methods - Extended Format:**
```redscript
/*
 * Processes breach completion and unlocks quickhacks network-wide
 *
 * ARCHITECTURE: Composed Method pattern with shallow nesting (max 2 levels)
 * @param devices - Array of network devices to process
 * @param unlockFlags - Flags indicating which device types to unlock
 * @return True if processing completed successfully
 */
@wrapMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Bool {
```

**Override Methods - Vanilla Diff Required:**
```redscript
/*
 * Replaces SetActionsInactiveAll() with progressive unlock logic
 *
 * VANILLA DIFF: Removes power state checks to allow unlocking disabled devices
 * @param actions - Array of device actions to process
 * @param deviceState - Current state of the device
 * @return Number of actions made available
 */
@replaceMethod(ScriptableDeviceComponentPS)
public func SetActionsInactiveAll(actions: script_ref<array<ref<DeviceAction>>>, deviceState: DeviceState) -> Int32 {
```

**Guidelines for Method Comments:**
- **Methods with Parameters/Return Values**: Use `/* */` format with `@param` and `@return` documentation
- **Simple Methods (no params/return)**: Single line describing purpose
- **Multiple Features**: Use bulleted list format (`Features:`, `Behavior:`, `Operations:`) to avoid long prose
- **Complex Methods**: Add ARCHITECTURE line if using design patterns
- **Override Methods**: Include VANILLA DIFF for @replaceMethod/@wrapMethod
- **Critical Methods**: Add specific warnings or constraints
- **Parameter Documentation**: `@param name - Description of parameter purpose and type`
- **Return Documentation**: `@return Description of return value and meaning`
- **Avoid Long Prose**: Use bullet points instead of multiple connected sentences

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

### D. Category Headers (Code Section Organization)

**Purpose:** Group related methods within the same file to improve code readability and navigation

**Mandatory Format:**
```redscript
// ============================================================================
// Category Name
// ============================================================================
```

**Usage Guidelines:**

1. **When to Use:**
   - Files with 10+ methods
   - Files with 300+ lines
   - Files with multiple functional responsibilities
   - Utility classes with diverse static methods

2. **When NOT to Use:**
   - Files with 5 or fewer methods
   - Single-responsibility classes
   - Files under 200 lines with clear structure

3. **Naming Conventions:**
   - Use Title Case: `Device Type Classification`
   - Be specific and concise (3-5 words maximum)
   - Use function-based names, not generic labels
   - ✅ Good: `Distance Calculations`, `Network Traversal`, `Breach State Management`
   - ❌ Bad: `Helpers`, `Utilities`, `Misc`, `Other Functions`

4. **Placement Rules:**
   - Place directly before the first method of the group
   - Insert 1 blank line before the header (after previous method's closing brace)
   - No blank line between header and first method
   - Group related methods consecutively under each header

5. **Hierarchy Limit:**
   - Maximum 2 levels of categorization
   - Level 1: `// ============================================================================`
   - Level 2: `// --- Subcategory Name ---`
   - Never use 3+ levels (indicates need for class splitting)

**Example - Utility Class:**
```redscript
module BetterNetrunning.Utils

public abstract class DeviceTypeUtils {
  // ============================================================================
  // Device Type Classification
  // ============================================================================

  // Checks if device is a camera
  public static func IsCamera(device: ref<DeviceComponentPS>) -> Bool {
    return device.IsA(n"SecurityCameraController");
  }

  // Checks if device is a turret
  public static func IsTurret(device: ref<DeviceComponentPS>) -> Bool {
    return device.IsA(n"TurretController");
  }

  // ============================================================================
  // Device State Queries
  // ============================================================================

  // Checks if device is currently online
  public static func IsOnline(device: ref<DeviceComponentPS>) -> Bool {
    return device.IsON();
  }
}
```

**Example - With Subcategories:**
```redscript
// ============================================================================
// Progressive Unlock Rules
// ============================================================================

// --- Basic Devices ---

@wrapMethod(ScriptableDeviceComponentPS)
public func SetActionsInactiveUnbreached(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Implementation
}

// --- Cameras ---

@wrapMethod(SecurityCameraControllerPS)
public func GetActions(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Implementation
}

// ============================================================================
// Unlock Expiration
// ============================================================================

@addMethod(SharedGameplayPS)
public func HasUnlockExpired(unlockTime: Uint32, currentTime: Uint32) -> Bool {
  // Implementation
}
```

**Anti-Patterns to Avoid:**

❌ **Over-categorization** (one header per method):
```redscript
// ============================================================================
// Camera Check
// ============================================================================
public static func IsCamera() { }

// ============================================================================
// Turret Check
// ============================================================================
public static func IsTurret() { }
```

✅ **Correct** (group related methods):
```redscript
// ============================================================================
// Device Type Classification
// ============================================================================
public static func IsCamera() { }
public static func IsTurret() { }
public static func IsComputer() { }
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

### 🔍 Code Review Checklist

Check the following during review:

**Class/Module Level:**
- [ ] Detailed PURPOSE section present
- [ ] Complete FUNCTIONALITY list
- [ ] ARCHITECTURE patterns specified
- [ ] DEPENDENCIES clearly listed

**Method Level:**
- [ ] Single-line comment for methods without parameters/return values
- [ ] `/* */` format with `@param` and `@return` for methods with parameters/return values
- [ ] ARCHITECTURE line added for complex methods only
- [ ] VANILLA DIFF included for @replaceMethod/@wrapMethod
- [ ] All parameters documented with `@param name - description`
- [ ] Return values documented with `@return description`
- [ ] No excessive detail (save for class documentation)

**Category Headers:**
- [ ] Consistent format used: `// ============================================================================`
- [ ] Only used in files with 10+ methods or 300+ lines
- [ ] Title Case naming (e.g., `Device Type Classification`)
- [ ] Specific, function-based names (not `Helpers`, `Utilities`, `Misc`)
- [ ] Proper placement: 1 blank line before header, no blank line after
- [ ] Maximum 2 hierarchy levels (no deeper categorization)
- [ ] No over-categorization (avoid headers for 1-2 methods)
- [ ] Consistent format throughout the file

**General Standards:**
- [ ] No VERSION HISTORY section
- [ ] No "Release version" / "Latest version" descriptions
- [ ] No "PHASE N" references
- [ ] No "Reduced from X to Y" metrics comparisons
- [ ] No "Improved" / "Better" / "Enhanced" relative evaluations
- [ ] No "Before / After" comparisons

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

### Example 2: Method Comment

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

**✅ Good Example (Simple Method - No Parameters):**
```redscript
// Processes breach completion and unlocks quickhacks network-wide
@wrapMethod(AccessPointControllerPS)
private final func ProcessBreachCompletion() -> Void {
```

**✅ Good Example (Method with Parameters):**
```redscript
/*
 * Processes breach completion and unlocks quickhacks network-wide
 *
 * @param devices - Array of network devices to unlock
 * @param unlockFlags - Flags indicating which device types to process
 * @return True if processing completed successfully
 */
@wrapMethod(AccessPointControllerPS)
private final func ProcessBreachCompletion(devices: array<ref<DeviceComponentPS>>, unlockFlags: BreachUnlockFlags) -> Bool {
```

**✅ Good Example (Multiple Features - Bulleted List):**
```redscript
/*
 * Returns RadialBreach MOD's configured breach range
 *
 * Behavior:
 * - Reads config.breachRange from RadialBreach Native Settings (10-50m, default 25m)
 * - Falls back to 50m if RadialBreach disabled or invalid
 *
 * @param gameInstance - Game instance
 * @return Breach range in meters
 */
public static func GetRadialBreachRange(gameInstance: GameInstance) -> Float {
```

**❌ Bad Example (Long Prose):**
```redscript
/*
 * Returns RadialBreach MOD's configured breach range
 *
 * Reads config.breachRange from RadialBreach Native Settings which can be configured
 * between 10-50m with a default of 25m, and falls back to 50m if RadialBreach is
 * disabled or if the value is invalid.
 *
 * @param gameInstance - Game instance
 * @return Breach range in meters
 */
```

**✅ Good Example (Complex Method with Architecture):**
```redscript
/*
 * Processes breach completion and unlocks quickhacks network-wide
 *
 * ARCHITECTURE: Composed Method pattern with shallow nesting (max 2 levels)
 * @param devices - Array of network devices to unlock
 * @param unlockFlags - Flags indicating which device types to process
 * @return True if processing completed successfully
 */
@wrapMethod(AccessPointControllerPS)
private final func ProcessBreachCompletion(devices: array<ref<DeviceComponentPS>>, unlockFlags: BreachUnlockFlags) -> Bool {
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

### Class Documentation Sections (Detailed)

1. **PURPOSE**: Module purpose (1-2 sentences)
2. **FUNCTIONALITY**: Feature list
3. **ARCHITECTURE**: Design patterns, structure
4. **DEPENDENCIES**: Dependencies

### Method Documentation Formats (Enhanced)

1. **Single Line**: Simple methods without parameters/return values
2. **Detailed Format**: Methods with parameters/return values using `@param` and `@return`
3. **Bulleted List Format**: Methods with multiple features using `Features:`, `Behavior:`, or `Operations:` section
4. **Extended Format**: Add ARCHITECTURE line for complex methods
5. **Override Methods**: Include VANILLA DIFF for @replaceMethod/@wrapMethod
6. **Parameter Documentation**: `@param name - Description of purpose and constraints`
7. **Return Documentation**: `@return Description of value and meaning`

**Recommended Section Names for Bulleted Lists:**
- `Features:` - List of functional capabilities
- `Behavior:` - Description of method behavior patterns
- `Operations:` - Step-by-step operation descriptions
- `Conditions:` - Conditional logic descriptions

**Key Principle:** Use bullet points instead of long prose to improve readability and maintainability.

### Category Header Format (Mandatory)

**Format:**
```redscript
// ============================================================================
// Category Name
// ============================================================================
```

**Usage Criteria:**
- Files with 10+ methods or 300+ lines
- Title Case naming
- Function-based, specific names
- Maximum 2 hierarchy levels
- 1 blank line before header, no blank line after

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
