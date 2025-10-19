# Better Netrunning - Architecture Design Document

**Version:** 2.2
**Last Updated:** 2025-10-19
**Major Changes:** モジュール階層化、外部依存100%一元化 (Integration/)、バグ修正とコード統合

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Module Structure](#module-structure)
4. [Core Subsystems](#core-subsystems)
5. [Data Flow](#data-flow)
6. [Design Patterns](#design-patterns)
7. [Configuration System](#configuration-system)
8. [Extension Points](#extension-points)
9. [Performance Considerations](#performance-considerations)

---

## Overview

### Purpose

Better Netrunning is a comprehensive Cyberpunk 2077 mod that enhances the netrunning gameplay by introducing progressive subnet unlocking, remote breach capabilities, and granular device control.

### Key Features

- **Progressive Subnet System:** Unlock Camera/Turret/NPC subnets independently
- **Remote Breach:** Breach devices (Computer/Camera/Turret/Device/Vehicle) without physical Access Points
- **Unconscious NPC Breach:** Breach unconscious NPCs directly
- **RadialUnlock Integration:** 50m radius breach tracking for standalone devices
- **Granular Control:** RemoteBreach toggles (Computer/Device/Vehicle)
- **Auto-Daemon System:** Automatic PING and Datamine execution based on success count
- **Enhanced Logging:** 5-level logging system (ERROR/WARN/INFO/DEBUG/TRACE)

### Technology Stack

- **Language:**
  - REDscript (Cyberpunk 2077 scripting language) - Game logic implementation
  - Lua (CET scripting) - Configuration, UI, TweakDB setup
- **Framework:** CustomHackingSystem (HackingExtensions) - Required for RemoteBreach functionality
- **Configuration:**
  - CET (Cyber Engine Tweaks) - Runtime initialization and TweakDB manipulation
  - Native Settings UI - In-game settings interface
  - JSON - Settings persistence (`settings.json`)
- **Localization:** Codeware ModLocalizationPackage (REDscript)

**IMPORTANT:** Better Netrunning requires the CustomHackingSystem mod (HackingExtensions). All RemoteBreach-related code is wrapped with `@if(ModuleExists("HackingExtensions"))` conditions and will not compile without this dependency.

---

## System Architecture

### Architectural Philosophy

Better Netrunning follows a **modular, layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                     │
│  (Native Settings UI, Quickhack Actions, Breach Minigame)  │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  CET Initialization Layer                   │
│    (init.lua - Module loading, TweakDB setup, Settings)    │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Coordination Layer                        │
│          (betterNetrunning.reds - Entry Point)              │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────┬──────────────┬──────────────┬───────────────┐
│  Breach      │  Quickhacks  │  Remote      │  RadialUnlock │
│  Protocol    │  System      │  Breach      │  System       │
│  (Minigame)  │  (NPCs/Dev)  │  (Remote)    │  (50m radius) │
└──────────────┴──────────────┴──────────────┴───────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 Foundation & Utilities Layer                │
│  Core/ - Base functionality (Constants, Logger, Events)    │
│  Utils/ - Business logic (BonusDaemon, Daemon, Debug)      │
│  Integration/ - External MOD dependencies                   │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Configuration Layer                       │
│    (config.reds ↔ settingsManager.lua ↔ settings.json)     │
└─────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Single Responsibility Principle:** Each module handles one specific concern
2. **DRY (Don't Repeat Yourself):** Shared logic consolidated into Core/Utils modules
3. **Strategy Pattern:** Device-specific unlock strategies encapsulated in separate classes
4. **Composed Method Pattern:** Large functions decomposed into small, focused helpers
5. **Mod Compatibility:** Prioritize `@wrapMethod` over `@replaceMethod` (5 uses only)
6. **Early Return Pattern:** Reduce nesting depth for readability (max 4 levels)
7. **Template Method Pattern:** Consistent processing workflows across subsystems
8. **Hierarchical Organization:** 3-tier structure for complex modules (RemoteBreach, Breach), 2-tier for RadialUnlock
9. **External Dependency Isolation:** Integration/ directory for MOD dependencies (100% isolation rate)

---

## Module Structure

### Directory Layout

**Last Updated:** 2025-10-19

```
bin/x64/plugins/cyber_engine_tweaks/mods/BetterNetrunning/
│
├── init.lua                           - CET entry point, module loader
├── settingsManager.lua                - Settings load/save/get/set
├── tweakdbSetup.lua                   - TweakDB configuration
├── nativeSettingsUI.lua               - Native Settings UI builder
├── remoteBreach.lua                   - RemoteBreach TweakDB setup
└── settings.json                      - Settings persistence (JSON)

r6/scripts/BetterNetrunning/
│
├── betterNetrunning.reds              (253 lines) - Main entry point
├── config.reds                        (65 lines)  - Configuration settings
│
├── Core/                              ✅ (7 files, 1,629 lines) - Foundation layer
│   ├── Constants.reds                 (355 lines) - 44 constants (Class/Action names, TweakDBIDs)
│   ├── DeviceTypeUtils.reds           (196 lines) - Device type detection & classification
│   ├── DeviceUnlockUtils.reds         (436 lines) - Shared device/vehicle/NPC unlock logic
│   ├── Events.reds                    (197 lines) - Breach event definitions & SharedGameplayPS fields
│   ├── Logger.reds                    (198 lines) - 5-level logging (ERROR/WARN/INFO/DEBUG/TRACE)
│   ├── MinigameProgramUtils.reds      (195 lines) - Program manipulation utilities
│   └── TimeUtils.reds                 (52 lines)  - Timestamp management
│
├── Utils/                             ✅ (3 files, 895 lines) - Business logic utilities
│   ├── BonusDaemonUtils.reds          (356 lines) - Auto PING/Datamine execution
│   ├── DaemonUtils.reds               (195 lines) - Daemon type identification
│   └── DebugUtils.reds                (344 lines) - Diagnostic tools & formatted output
│
├── Integration/                       ✅ (3 files, 602 lines) - External MOD dependencies (100% centralization)
│   ├── DNRGating.reds                 (87 lines)  - Daemon Netrunning Revamp integration
│   ├── TracePositionOverhaulGating.reds (199 lines) - Trace MOD integration
│   └── RadialBreachGating.reds        (316 lines) - RadialBreach MOD integration
│   Note: All external MOD dependencies centralized in Integration/
│
├── Breach/                            ✅ (3-tier, 4 files, 1,221 lines)
│   ├── Core/
│   │   └── BreachHelpers.reds         (136 lines) - Network hierarchy traversal
│   ├── Processing/
│   │   └── BreachProcessing.reds      (528 lines) - Breach completion, RefreshSlaves wrapper, Radius unlock
│   └── Systems/
│       ├── BreachPenaltySystem.reds   (341 lines) - Skip/Failure detection, Trace initiation
│       └── RemoteBreachLock.reds      (216 lines) - Position-based breach lock
│
├── RemoteBreach/                      ✅ (3-tier, 12 files, 3,085 lines)
│   ├── Core/ (6 files, 2,154 lines)
│   │   ├── BaseRemoteBreachAction.reds    (315 lines) - Base class for RemoteBreach actions
│   │   ├── DaemonImplementation.reds      (194 lines) - Daemon execution logic (8 daemons)
│   │   ├── DaemonRegistration.reds        (78 lines)  - TweakDB daemon registration
│   │   ├── DaemonUnlockStrategy.reds      (313 lines) - Strategy pattern (Computer/Device/Vehicle)
│   │   ├── RemoteBreachHelpers.reds       (945 lines) - Utilities, Callbacks, JackIn 🟡
│   │   └── RemoteBreachStateSystem.reds   (101 lines) - State management (3 systems)
│   ├── Actions/ (4 files, 508 lines)
│   │   ├── RemoteBreachAction_Computer.reds (101 lines) - Computer RemoteBreach
│   │   ├── RemoteBreachAction_Device.reds   (136 lines) - Device RemoteBreach (Camera/Turret/etc)
│   │   ├── RemoteBreachAction_Vehicle.reds  (100 lines) - Vehicle RemoteBreach
│   │   └── RemoteBreachProgram.reds         (171 lines) - Daemon program definitions
│   └── UI/ (2 files, 624 lines)
│       ├── CustomHackingIntegration.reds  (212 lines) - CustomHackingSystem menu integration
│       └── RemoteBreachVisibility.reds    (412 lines) - Visibility control + settings
│
├── RadialUnlock/                      ✅ (2-tier, 2 files, 940 lines)
│   └── Core/
│       ├── RadialUnlockSystem.reds        (289 lines) - Position tracking (50m radius)
│       └── RemoteBreachNetworkUnlock.reds (651 lines) - Network unlock + Nearby device 🟡
│   Note: RadialBreachGating.reds in Integration/ - External MOD dependencies
│
├── Devices/                           ✅ (4 files, 733 lines)
│   ├── DeviceNetworkAccess.reds       (83 lines)  - Network access relaxation
│   ├── DeviceProgressiveUnlock.reds   (308 lines) - Progressive unlock logic
│   ├── DeviceQuickhackFilters.reds    (233 lines) - Quickhack filtering
│   └── DeviceRemoteActions.reds       (109 lines) - Remote action execution
│
├── Minigame/                          ✅ (3 files, 712 lines)
│   ├── ProgramFilteringCore.reds      (147 lines) - Core filtering logic
│   ├── ProgramFilteringRules.reds     (440 lines) - Filtering rules (7 filters)
│   └── ProgramInjection.reds          (125 lines) - Subnet program injection
│
├── NPCs/                              ✅ (3 files, 494 lines)
│   ├── NPCBreachExperience.reds       (92 lines)  - Breach rewards
│   ├── NPCLifecycle.reds              (192 lines) - Unconscious breach, lifecycle
│   └── NPCQuickhacks.reds             (210 lines) - Progressive unlock, permissions, Event interception
│
├── Progression/                       ✅ (1 file, 209 lines)
│   └── ProgressionSystem.reds         (209 lines) - Cyberdeck/Intelligence/Rarity requirements
│
├── Localization/                      ✅ (3 files, 430 lines)
│   ├── English.reds                   (194 lines) - English localization (142 entries)
│   ├── Japanese.reds                  (194 lines) - Japanese localization (142 entries)
│   └── LocalizationProvider.reds      (42 lines)  - Localization provider
│
└── Debug/                             ✅ (1 file, 153 lines)
    └── BreachSessionStats.reds        (153 lines) - Breach statistics collection

TOTAL: 47 files, 11,319 lines (11 directories, 18 modules)
```

**Architecture Notes:**
- ✅ **Module Separation**: Core/, Utils/, Integration/ provide foundation functionality
- ✅ **RemoteBreach Architecture**: 3-tier hierarchy (Core/Actions/UI)
- ✅ **Breach Architecture**: 3-tier hierarchy (Core/Processing/Systems)
- ✅ **RadialUnlock Architecture**: 2-tier hierarchy (Core only)
- ✅ **Integration Directory**: All external MOD dependencies centralized (100% isolation)
- ✅ **Bug Fixes**: Standalone device unlock, Vehicle unlock, NPC false unlock prevention
- ✅ **Code Consolidation**: DeviceUnlockUtils.reds (436 lines), Timestamp logic DRY (-41 lines)
- 🟡 **500-line Exceptions**: RemoteBreachHelpers.reds (945), RemoteBreachNetworkUnlock.reds (651) - intentional deferral
- 🟢 **Devices/Minigame**: Already optimized

### Module Dependencies

```
betterNetrunning.reds (Entry Point)
    ├── imports Core.*
    ├── imports Utils.*
    ├── imports Integration.*
    └── imports config.*

Breach/ modules
    ├── depends on Core.* (DeviceTypeUtils, Events, Logger, Constants)
    ├── depends on Integration.* (TracePositionOverhaulGating)
    └── depends on Debug.* (BreachSessionStats)

RemoteBreach/ modules
    ├── Core/: depends on Core.*, Utils.*
    ├── Actions/: depends on RemoteBreach.Core.*
    ├── UI/: depends on RemoteBreach.Core.*, config.*
    └── Note: HackingExtensions guards distributed (20+ @if conditions)

Devices/ modules
    ├── depends on Core.* (DeviceTypeUtils, Logger, Constants)
    ├── depends on Utils.* (DaemonUtils)
    └── depends on Progression.* (ProgressionSystem)

Minigame/ modules
    ├── depends on Core.* (Logger, Constants)
    ├── depends on Utils.* (DaemonUtils)
    └── depends on Integration.* (DNRGating)

NPCs/ modules
    ├── depends on Core.* (DeviceTypeUtils, Events, Logger)
    ├── depends on Utils.* (BonusDaemonUtils)
    └── depends on Progression.* (ProgressionSystem)

RadialUnlock/ modules
    ├── Core/: depends on Core.*, Utils.*
    └── Integration/: depends on RadialUnlock.Core.*

CET Lua modules (bin/x64/plugins/cyber_engine_tweaks/mods/BetterNetrunning/)
init.lua
    ├── requires settingsManager
    ├── requires tweakdbSetup
    ├── requires nativeSettingsUI
    └── requires remoteBreach

settingsManager.lua
    └── interacts with settings.json (JSON I/O)

tweakdbSetup.lua
    └── modifies TweakDB (Access Programs, Unconscious Breach)

nativeSettingsUI.lua
    ├── depends on nativeSettings (GetMod)
    ├── depends on settingsManager
    └── depends on tweakdbSetup

remoteBreach.lua
    └── depends on CustomHackingSystem.API (GetMod)
```

### Lua-REDscript Integration

```
┌──────────────────────────────────────────────────────────────┐
│                        Game Start                            │
└──────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  CET onInit Event (init.lua)                                 │
│  ├─ Load settings.json → settingsManager                     │
│  ├─ Build Native Settings UI → nativeSettingsUI             │
│  ├─ Setup TweakDB (Access Programs, Unconscious Breach)     │
│  └─ Setup RemoteBreach (CustomHackingSystem API)            │
└──────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  REDscript Initialization (betterNetrunning.reds)            │
│  └─ BetterNetrunningSettings static functions                │
│     (Override config.reds with CET settings)                 │
└──────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Runtime Operation                                           │
│  ├─ REDscript: Game logic implementation                     │
│  │   └─ Read settings via BetterNetrunningSettings.*()      │
│  └─ Lua: Settings UI, TweakDB manipulation, state mgmt      │
│      └─ Write settings via SettingsManager.Set()            │
└──────────────────────────────────────────────────────────────┘
```

---

## Core Subsystems

### 0. Configuration & Initialization System (CET Lua)

**Purpose:** Initialize mod, manage settings, configure TweakDB

**Key Components:**
- `init.lua`: Module loader, orchestrates initialization sequence
- `settingsManager.lua`: Settings persistence (JSON), get/set operations
- `tweakdbSetup.lua`: Configure Access Programs, Unconscious Breach prerequisites
- `nativeSettingsUI.lua`: Build Native Settings UI with 11 categories
- `remoteBreach.lua`: Register RemoteBreach ProgramActions with CustomHackingSystem

**Initialization Sequence:**

```lua
-- init.lua (onInit event)
1. SettingsManager.Load()
   → Load settings.json (69 settings)

2. nativeSettingsUI.Build()
   → Create 11 settings categories
   → Register callbacks (auto-save on change)

3. tweakdbSetup.SetupAccessPrograms()
   → Create 4 Access Programs (TweakDB cloning)
   → NetworkBasicAccess, NetworkNPCAccess, NetworkCameraAccess, NetworkTurretAccess

4. tweakdbSetup.SetupUnconsciousBreach()
   → Configure Takedown.BreachUnconsciousOfficer
   → Set instigatorPrereqs, targetActivePrereqs, targetPrereqs, startEffects, completionEffects

5. tweakdbSetup.ApplyBreachingHotkey()
   → Map breaching hotkey to Choice1-4

6. remoteBreach.Setup()
   → Check CustomHackingSystem availability
   → Register Computer/Device/Vehicle RemoteBreach actions
   → Register 8 daemon ProgramActions
   → Register with CustomHackingSystem.API
```

**Settings Management Architecture:**

```
settings.json (Persistent)
     ↕ (Load/Save)
settingsManager.lua (Runtime State)
     ↕ (Get/Set)
BetterNetrunningSettings.* (REDscript)
     ↕ (Query)
REDscript Game Logic
```

**TweakDB Operations:**

```lua
-- tweakdbSetup.lua
TweakDB:CloneRecord()     -- Clone vanilla records
TweakDB:SetFlat()         -- Set record properties
```

**RemoteBreach Registration:**

```lua
-- remoteBreach.lua
CustomHackingSystem.API
  ├─ CreateHackingMinigameCategory("BetterNetrunning")
  ├─ AddDeviceProgramAction(ComputerRemoteBreachAction)
  ├─ AddDeviceProgramAction(DeviceRemoteBreachAction)
  ├─ AddDeviceProgramAction(VehicleRemoteBreachAction)
  └─ Register 8 daemon ProgramActions
```

### 1. Foundation Layer (Core/ & Utils/)

**Purpose:** Provide base functionality and shared utilities

**Core/ (7 files, 1,629 lines):**

| File | Lines | Purpose |
|------|-------|---------|
| **Constants.reds** | 355 | 44 constants (Class names, Action names, TweakDBIDs) |
| **DeviceTypeUtils.reds** | 196 | Device type detection & classification |
| **DeviceUnlockUtils.reds** | 436 | Shared device/vehicle/NPC unlock logic (radius-based) |
| **Events.reds** | 197 | Breach event definitions, SharedGameplayPS field extensions |
| **Logger.reds** | 198 | 5-level logging (ERROR/WARN/INFO/DEBUG/TRACE), duplicate suppression |
| **MinigameProgramUtils.reds** | 195 | Program manipulation utilities |
| **TimeUtils.reds** | 52 | Timestamp management for unlock duration |

**Utils/ (3 files, 895 lines):**

| File | Lines | Purpose |
|------|-------|---------|
| **BonusDaemonUtils.reds** | 356 | Auto PING/Datamine execution POST-breach |
| **DaemonUtils.reds** | 195 | Daemon type identification (Basic/Camera/Turret/NPC) |
| **DebugUtils.reds** | 344 | Diagnostic tools & formatted output |

**Integration/ (3 files, 602 lines):**

| File | Lines | Purpose |
|------|-------|---------|
| **DNRGating.reds** | 87 | Daemon Netrunning Revamp MOD integration |
| **TracePositionOverhaulGating.reds** | 199 | Trace MOD integration (real NPC vs virtual netrunner) |
| **RadialBreachGating.reds** | 316 | RadialBreach MOD physical distance filtering |

**Note:** All external MOD dependencies are centralized in Integration/ directory (100% isolation rate). HackingExtensions integration is intentionally distributed across RemoteBreach/ files (20+ `@if(ModuleExists("HackingExtensions"))` guards).

### 2. Breach Protocol System (Minigame)

**Purpose:** Controls daemon availability and filtering in Breach Protocol minigames

**Key Components:**
- `Minigame/ProgramInjection.reds`: Inject subnet daemons based on breach point type
- `Minigame/ProgramFilteringCore.reds`: Core filtering logic
- `Minigame/ProgramFilteringRules.reds`: 7 filtering rules (Already-breached, Network, Device type, etc.)
- `Breach/Processing/BreachProcessing.reds`: Breach completion, RefreshSlaves wrapper, Radius unlock
- `Breach/Core/BreachHelpers.reds`: Network hierarchy traversal
- `Core/DeviceUnlockUtils.reds`: Shared radius-based device/vehicle/NPC unlock utilities

**Breach Point Types:**

| Type | Daemon Injection | Features |
|------|------------------|----------|
| **Access Point** | Turret + Camera + NPC + Basic | Full network access |
| **Computer** | Camera + Basic | Limited network access |
| **Backdoor Device** | Camera + Basic | Camera subnet + basics only |
| **Unconscious NPC (Regular)** | NPC + Basic | Limited access |
| **Unconscious NPC (Netrunner)** | Turret + Camera + NPC + Basic | Full network access |
| **Remote Breach (Computer)** | Camera + Basic | Device-specific daemons |
| **Remote Breach (Camera)** | Camera + Basic | Device-specific daemons |
| **Remote Breach (Turret)** | Turret + Basic | Device-specific daemons |
| **Remote Breach (Terminal)** | NPC + Basic | Device-specific daemons |
| **Remote Breach (Other)** | Basic only | Minimum access |
| **Remote Breach (Vehicle)** | Basic only | Minimum access |

**Filtering Pipeline:**

```
1. ProgramInjection (Injection-time control)
   ├─ Breach point type detection (AccessPoint/Computer/Backdoor/NPC)
   ├─ Device type availability check (based on UnlockIfNoAccessPoint)
   └─ Progressive unlock state check (m_betterNetrunningBreached* flags)

2. ProgramFiltering (Filter-time control, 7 rules)
   ├─ ShouldRemoveBreachedPrograms() - Already breached daemons
   ├─ ShouldRemoveNetworkPrograms() - Network connectivity filter
   ├─ ShouldRemoveDeviceBackdoorPrograms() - Backdoor device restrictions
   ├─ ShouldRemoveAccessPointPrograms() - Non-AccessPoint type filter (deprecated)
   ├─ ShouldRemoveNonNetrunnerPrograms() - Non-netrunner NPC restrictions
   ├─ ShouldRemoveDeviceTypePrograms() - Device type availability filter
   └─ ShouldRemoveDataminePrograms() - Datamine auto-addition filter

3. RadialBreach (Physical range control)
   └─ Re-add only devices within 50m radius (UnlockIfNoAccessPoint = false)
```

**Penalty System (Breach/Systems/BreachPenaltySystem.reds):**

```
FinalizeNetrunnerDive() - Apply Breach Failure/Skip Penalties
   ├─ Skip Detection: TimerLeftPercent >= 0.99 (99%+ timer remaining)
   ├─ Failure Detection: ActualSuccess < FullSuccess
   ├─ Trace Initiation: TracePositionOverhaulGating or Virtual Netrunner
   └─ Position Recording: Failed breach positions for duplicate prevention
```

**Trace System Architecture:**

```
SOFT DEPENDENCY: TracePositionOverhaul MOD (Integration/TracePositionOverhaulGating.reds)
  When absent: Virtual netrunner approach (works standalone)
  When installed: Enhanced features (real NPC, auto-interrupt, visual feedback)

Trace Advantages over Instant Alert:
  ✅ 30-60s delay (player can escape or interrupt)
  ✅ Predictable danger (red skull icon, countdown timer)
  ✅ Non-lethal failure (no instant combat alert)
  ✅ No immediate AlertPuppet() (NPCs stay in normal patrol state)

Virtual Netrunner Design:
  - No real NPC required (works in wilderness, rooftops, underground)
  - Recorded position for duplicate trace prevention
  - Guarantees penalty in all locations (game balance)
```

### 3. Remote Breach System (RemoteBreach/)

**Purpose:** Enable breaching devices remotely without physical Access Points

**DEPENDENCY:** All RemoteBreach functionality requires CustomHackingSystem (HackingExtensions mod). Code is wrapped with `@if(ModuleExists("HackingExtensions"))` conditions.

**3-Tier Architecture:**

```
RemoteBreach/
├── Core/ (6 files, 2,195 lines) - State management, Strategy pattern, Helpers
│   ├── BaseRemoteBreachAction.reds - Base class for all RemoteBreach actions
│   ├── RemoteBreachStateSystem.reds - 3 state systems (Computer/Device/Vehicle)
│   ├── DaemonUnlockStrategy.reds - Strategy pattern (Computer/Device/Vehicle)
│   ├── DaemonImplementation.reds - 8 daemon execution logic
│   ├── DaemonRegistration.reds - TweakDB daemon registration
│   └── RemoteBreachHelpers.reds - Utility classes, Callbacks, JackIn control
├── Actions/ (4 files, 508 lines) - Action implementations
│   ├── RemoteBreachAction_Computer.reds - ComputerControllerPS
│   ├── RemoteBreachAction_Device.reds - Camera/Turret/Terminal/Other
│   ├── RemoteBreachAction_Vehicle.reds - VehicleComponentPS
│   └── RemoteBreachProgram.reds - Daemon program definitions
└── UI/ (2 files, 624 lines) - UI control & visibility
    ├── RemoteBreachVisibility.reds - Visibility control + settings
    └── CustomHackingIntegration.reds - CustomHackingSystem menu integration
```

**RemoteBreach Action Architecture:**

```
BaseRemoteBreachAction (RemoteBreach/Core/BaseRemoteBreachAction.reds)
  extends CustomAccessBreach (HackingExtensions)
  ├─ ComputerRemoteBreachAction      → ComputerControllerPS
  ├─ DeviceRemoteBreachAction        → Camera/Turret/Terminal/Other
  └─ VehicleRemoteBreachAction       → VehicleComponentPS
```

**Device-Specific Daemon Injection:**

```redscript
// Computer (RemoteBreachAction_Computer.reds)
Computer  → "basic,camera"  (Camera + Basic daemons)

// Device (RemoteBreachAction_Device.reds: GetAvailableDaemonsForDevice())
Camera    → "basic,camera"  (Camera + Basic daemons)
Turret    → "basic,turret"  (Turret + Basic daemons)
Terminal  → "basic,npc"     (NPC + Basic daemons)
Other     → "basic"         (Basic daemon only)

// Vehicle (RemoteBreachAction_Vehicle.reds)
Vehicle   → "basic"         (Basic daemon only)
```

**Visibility Control (Two-Layer Defense):**

1. **Prevention Layer:** `RemoteBreachVisibility.reds` - `TryAddCustomRemoteBreach()`
   - Early return if RemoteBreachEnabled setting = false
   - Early return if UnlockIfNoAccessPoint = true (auto-unlock mode)

2. **Enforcement Layer:** `RemoteBreachAction_*.reds` - `GetQuickHackActions()` @wrapMethod
   - Check device-specific RemoteBreachEnabled setting
   - Check UnlockIfNoAccessPoint setting (OR condition)

**State Management:**

- `RemoteBreachStateSystem`: Computer RemoteBreach state
- `DeviceRemoteBreachStateSystem`: Device RemoteBreach state (Camera/Turret/Terminal/Other)
- `VehicleRemoteBreachStateSystem`: Vehicle RemoteBreach state

### 4. RadialUnlock System (RadialUnlock/)

**Purpose:** Track breach positions and unlock standalone devices within 50m radius

**2-Tier Architecture:**

```
RadialUnlock/
└── Core/ (2 files, 940 lines)
    ├── RadialUnlockSystem.reds - Position tracking (breach coordinates + timestamps)
    └── RemoteBreachNetworkUnlock.reds - Network unlock + Nearby device unlock

Note: RadialBreachGating.reds moved to Integration/ (100% external MOD centralization)
```

**Functionality:**

1. **Breach Position Tracking:**
   - Store breach coordinates when minigame succeeds
   - Store timestamp for unlock duration management
   - Prevent duplicate RemoteBreach on unlocked devices

2. **50m Radius Unlock:**
   - Check distance from breach position to target device
   - Auto-unlock standalone devices within range
   - Filter daemons to show only physically reachable devices

3. **RadialBreach MOD Integration:**
   - Detect RadialBreach MOD presence via `@if(ModuleExists("RadialBreach"))`
   - Use RadialBreach physical distance calculation if available
   - Fallback to internal logic if not installed
   - **Implementation**: `Integration/RadialBreachGating.reds` (centralized external MOD dependency)

4. **Nearby Standalone Device Unlock:**
   - Auto-unlock nearby standalone devices after RemoteBreach success
   - Device type determines breach flag (Camera → m_betterNetrunningBreachedCameras, etc.)
   - Prevents manual breach requirement for nearby devices

**Activation Condition:**

```
UnlockIfNoAccessPoint = false (default):
  → RadialUnlock Mode ENABLED
  → Physical range tracking active
  → RemoteBreach enabled

UnlockIfNoAccessPoint = true:
  → RadialUnlock Mode DISABLED
  → Auto-unlock all devices immediately
  → RemoteBreach disabled
```

### 5. Device Management & Progressive Unlock (Devices/)

**Purpose:** Control device quickhack availability and network access

**Key Components:**
- `DeviceProgressiveUnlock.reds`: Progressive unlock logic based on breach state
- `DeviceQuickhackFilters.reds`: Quickhack filtering rules
- `DeviceRemoteActions.reds`: Remote action execution
- `DeviceNetworkAccess.reds`: Network access relaxation

**Network Access Relaxation (DeviceNetworkAccess.reds):**

Removes vanilla network topology restrictions:

1. **Door QuickHack Menu:** All doors show menu (not just AP-connected)
2. **Standalone RemoteBreach:** Standalone devices can use RemoteBreach
3. **Universal Ping:** Ping works on all devices for reconnaissance

**Implementation:**
- `ExposeQuickHakcsIfNotConnnectedToAP()` - Returns true for non-AP doors (@wrapMethod)
- `IsConnectedToBackdoorDevice()` - Returns true for standalone devices (@wrapMethod)
- `HasNetworkBackdoor()` - Always returns true (@replaceMethod)

**Philosophy:** Player-driven gameplay without arbitrary network limitations

### 6. NPC Quickhack System (NPCs/)

**Purpose:** Control NPC quickhack availability and unconscious breach

**Key Components:**
- `NPCQuickhacks.reds`: Progressive unlock based on NPC subnet breach
- `NPCLifecycle.reds`: Unconscious NPC breach, lifecycle management
- `NPCBreachExperience.reds`: Breach rewards

**Progressive Unlock Logic:**

```
NPC Quickhacks:
  Covert    → Unlocked when NPC Subnet breached (low-risk hacks)
  Control   → Unlocked when NPC Subnet breached (medium-risk hacks)
  Combat    → Unlocked when NPC Subnet breached (high-risk hacks)
  Ultimate  → Unlocked when NPC Subnet breached (ultimate hacks)
```

**Unconscious NPC Breach:**

```
Activation Conditions:
  ✅ AllowBreachingUnconsciousNPCs = true
  ✅ NPC is unconscious
  ✅ IsConnectedToBackdoorDevice() = true (relaxed by DeviceNetworkAccess.reds)
  ✅ RadialUnlock Mode enabled (UnlockIfNoAccessPoint = false) OR physically connected to AP
  ✅ Not directly breached (m_betterNetrunningWasDirectlyBreached = false)
```

### 7. Progression System (Progression/)

**Purpose:** Control unlock requirements based on player progression

**Key Components:**
- `ProgressionSystem.reds`: Cyberdeck tier, Intelligence level, Enemy rarity requirements

**Progression Checks:**

```
Cyberdeck Requirements:
  Basic Subnet   → Tier 1+ (Militech Falcon)
  Camera Subnet  → Tier 2+ (Stephenson Tech Mk.1)
  Turret Subnet  → Tier 3+ (Biotech Σ Mk.1)
  NPC Subnet     → Tier 4+ (NetWatch Netdriver Mk.1)

Intelligence Requirements:
  Basic Subnet   → Intelligence 3+
  Camera Subnet  → Intelligence 6+
  Turret Subnet  → Intelligence 9+
  NPC Subnet     → Intelligence 12+

Enemy Rarity Requirements:
  Basic Subnet   → Any (Trash+)
  Camera Subnet  → Normal+
  Turret Subnet  → Rare+
  NPC Subnet     → Epic+
```

### 8. Debug Logging System (Core/Logger.reds + Debug/BreachSessionStats.reds)

**Purpose:** Centralized logging infrastructure with level-based filtering, duplicate suppression, and statistics collection

**5-Level Log System:**

```redscript
// Log levels (0-4)
ERROR   (0) → Errors only (critical failures, null checks)
WARNING (1) → Warnings + Errors (deprecated paths, fallback logic)
INFO    (2) → Info + Warning + Error (breach summaries, major events) [DEFAULT]
DEBUG   (3) → Debug + all above (intermediate calculations, state changes)
TRACE   (4) → Trace + all above (every function call, all variable values)

// Public API
BNError(context: String, message: String)   // Always outputs (level 0)
BNWarn(context: String, message: String)    // Outputs when level ≥ 1
BNInfo(context: String, message: String)    // Outputs when level ≥ 2
BNDebug(context: String, message: String)   // Outputs when level ≥ 3
BNTrace(context: String, message: String)   // Outputs when level ≥ 4
```

**Duplicate Suppression:**

```redscript
// Suppress identical messages within 5 seconds
BNInfo("MyContext", "Same message");  // Outputs
BNInfo("MyContext", "Same message");  // Suppressed (< 5s)
// After 5 seconds
BNInfo("MyContext", "Same message");  // Outputs again
```

**Breach Statistics Collection (Debug/BreachSessionStats.reds):**

```
Collected Data:
  - Breach type (AccessPoint/UnconsciousNPC/RemoteBreach)
  - Target device type
  - Success count (uploaded daemons)
  - Applied bonuses (Auto PING, Auto Datamine)
  - Unlocked subnets (Basic/Camera/Turret/NPC)

Output Format:
  ═══════════════════════════════════════════════════════════
   Breach Session Statistics
  ═══════════════════════════════════════════════════════════
   Target:      AccessPoint (Computer)
   Success:     3 daemons uploaded
   Bonuses:     Auto PING, Auto Datamine V2
   Unlocked:    Basic, Camera, Turret
  ═══════════════════════════════════════════════════════════
```

### 9. Localization System (Localization/)

**Purpose:** Multi-language support for UI text

**Key Components:**
- `English.reds`: English localization (142 entries)
- `Japanese.reds`: Japanese localization (142 entries)
- `LocalizationProvider.reds`: Localization provider interface

**Implementation:**

```redscript
// English.reds / Japanese.reds
module BetterNetrunning.Localization
import Codeware.Localization.*

public class English extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("Category-Controls", "Controls");
    this.Text("DisplayName-BetterNetrunning-BreachingHotkey", "Unconscious Breaching Hotkey");
    // ... 142 entries total
  }
}
```

**Localization Flow:**

```
REDscript (English.reds, Japanese.reds)
     ↓ Codeware.Localization.ModLocalizationPackage
Game Localization System
     ↓
In-Game Text (based on game language setting)
```

**Categories (11 total):**
- Controls, Breaching, RemoteBreach, AccessPoints, RemovedQuickhacks, UnlockedQuickhacks
- Progression, ProgressionCyberdeck, ProgressionIntelligence, ProgressionEnemyRarity, Debug

---

## Data Flow

### Breach Initialization Flow

```
1. User Interaction (AccessPoint/NPC/Device/Vehicle)
   ↓
2. CET: Check settings (RemoteBreachEnabled*, AllowBreachingUnconsciousNPCs)
   ↓
3. REDscript: Initialize minigame (ProgramInjection)
   ├─ Breach point type detection
   ├─ Daemon injection (Basic/Camera/Turret/NPC)
   └─ UnlockIfNoAccessPoint check
   ↓
4. Minigame Execution
   ├─ Player uploads daemons
   └─ Success/Failure determination
   ↓
5. Post-Breach Processing (BreachProcessing/NPCLifecycle/RemoteBreachNetworkUnlock)
   ├─ Apply bonus daemons (Auto PING, Auto Datamine)
   ├─ Unlock network devices (RefreshSlaves)
   ├─ Unlock nearby standalone devices (RadialUnlock)
   └─ Record statistics (BreachSessionStats)
   ↓
6. Penalty Application (if skip/failure)
   ├─ Trace initiation (TracePositionOverhaulGating or Virtual Netrunner)
   └─ Position recording (duplicate prevention)
```

### Settings Update Flow

```
1. User changes setting in Native Settings UI
   ↓
2. CET: nativeSettingsUI callback
   ↓
3. CET: SettingsManager.Set(key, value)
   ├─ Update runtime state
   └─ Save to settings.json
   ↓
4. REDscript: BetterNetrunningSettings.*() query
   ├─ Override config.reds defaults
   └─ Return CET setting value
   ↓
5. Game Logic: Use updated setting
```

### RemoteBreach Action Flow

```
1. Player selects RemoteBreach quickhack on device
   ↓
2. RemoteBreach/UI/RemoteBreachVisibility.reds: TryAddCustomRemoteBreach()
   ├─ Check RemoteBreachEnabled setting
   ├─ Check UnlockIfNoAccessPoint setting
   └─ Early return if disabled
   ↓
3. RemoteBreach/Actions/RemoteBreachAction_*.reds: GetQuickHackActions()
   ├─ Device-specific RemoteBreachEnabled check
   └─ Add RemoteBreach action to menu
   ↓
4. Player confirms action
   ↓
5. RemoteBreach/Core/BaseRemoteBreachAction.reds: SetActionOwner()
   ├─ Set minigame entity
   ├─ Set blackboard flags (isRemoteBreach = true)
   └─ Set RAM cost
   ↓
6. RemoteBreach/Core/DaemonUnlockStrategy.reds: GetAvailableDaemons()
   ├─ Computer: "camera,basic"
   ├─ Device: Device-specific (Camera: "camera,basic", Turret: "turret,basic", etc.)
   └─ Vehicle: "basic"
   ↓
7. Minigame Execution (same as Breach Initialization Flow step 4)
   ↓
8. Post-Breach: RemoteBreach/Core/RemoteBreachNetworkUnlock.reds
   ├─ Unlock network devices
   ├─ Unlock nearby standalone devices (50m radius)
   └─ Apply bonus daemons
```

---

## Design Patterns

### 1. Strategy Pattern (RemoteBreach/Core/DaemonUnlockStrategy.reds)

**Purpose:** Encapsulate device-specific unlock logic

```redscript
// Base strategy
public abstract class BaseDaemonUnlockStrategy {
  public abstract func GetAvailableDaemons() -> String;
}

// Concrete strategies
public class ComputerDaemonUnlockStrategy extends BaseDaemonUnlockStrategy {
  public func GetAvailableDaemons() -> String {
    return "camera,basic";  // Fixed daemons for Computer
  }
}

public class DeviceDaemonUnlockStrategy extends BaseDaemonUnlockStrategy {
  public func GetAvailableDaemons() -> String {
    // Dynamic daemon detection based on device type
    if IsCamera() { return "camera,basic"; }
    if IsTurret() { return "turret,basic"; }
    if IsTerminal() { return "npc,basic"; }
    return "basic";  // Other devices
  }
}

public class VehicleDaemonUnlockStrategy extends BaseDaemonUnlockStrategy {
  public func GetAvailableDaemons() -> String {
    return "basic";  // Minimum access for vehicles
  }
}
```

### 2. Template Method Pattern (Breach Processing)

**Purpose:** Define processing skeleton, allow subclasses to override steps

```redscript
// Base template (BreachProcessing.reds)
@wrapMethod(AccessPointControllerPS)
private func OnBreachComplete() {
  this.PreBreachProcessing();        // Hook
  wrappedMethod();                    // Vanilla processing
  this.PostBreachProcessing();        // Hook
}

// Concrete implementations
private func PreBreachProcessing() {
  // Log breach start
  BNInfo("Breach", "Starting breach processing");
}

private func PostBreachProcessing() {
  // Apply bonus daemons
  BonusDaemonUtils.ApplyBonusDaemons();
  // Record statistics
  BreachSessionStats.RecordBreach();
}
```

### 3. Composed Method Pattern (DEVELOPMENT_GUIDELINES.md)

**Purpose:** Decompose large functions into small, focused helpers (max 30 lines)

```redscript
// Before (100 lines)
public func ProcessBreach() {
  // 100 lines of mixed logic
}

// After (4 functions × 25 lines)
public func ProcessBreach() {
  this.ValidateBreachState();
  this.InjectDaemons();
  this.UnlockNetwork();
  this.RecordStatistics();
}

private func ValidateBreachState() { /* 25 lines */ }
private func InjectDaemons() { /* 25 lines */ }
private func UnlockNetwork() { /* 25 lines */ }
private func RecordStatistics() { /* 25 lines */ }
```

### 4. Guard Clause Pattern (DEVELOPMENT_GUIDELINES.md)

**Purpose:** Reduce nesting depth for readability (max 4 levels)

```redscript
// Before (nesting depth 4)
public func ProcessDevice(device: ref<DeviceComponentPS>) {
  if IsDefined(device) {
    if device.IsValid() {
      if device.HasTag("Hackable") {
        if !device.IsBreached() {
          // 20 lines of logic
        }
      }
    }
  }
}

// After (nesting depth 1)
public func ProcessDevice(device: ref<DeviceComponentPS>) {
  if !IsDefined(device) { return; }
  if !device.IsValid() { return; }
  if !device.HasTag("Hackable") { return; }
  if device.IsBreached() { return; }

  // 20 lines of logic at indent level 1
}
```

### 5. Hierarchical Organization Pattern (FILE_STRUCTURE_OPTIMIZATION_V2.2_INTEGRATED.md)

**Purpose:** Organize complex modules into logical tiers

```
RemoteBreach/ (3-tier)
├── Core/ - Foundation (State, Strategy, Helpers)
├── Actions/ - Implementation (Computer/Device/Vehicle)
└── UI/ - Presentation (Visibility, Integration)

Breach/ (3-tier)
├── Core/ - Foundation (Helpers)
├── Processing/ - Workflow (BreachProcessing)
└── Systems/ - Specialized (Penalty, Lock)

RadialUnlock/ (2-tier)
├── Core/ - Foundation (Tracking, Network unlock)
└── Integration/ - External MOD (RadialBreach)
```

### 6. Constants Management Pattern (Core/Constants.reds)

**Purpose:** Eliminate magic strings, enable IDE autocomplete

```redscript
// Before (magic strings)
let system = container.Get(n"BetterNetrunning.CustomHacking.RemoteBreachStateSystem");

// After (constants)
let system = container.Get(BNConstants.SYSTEM_REMOTE_BREACH_STATE());

// Constants.reds (44 constants)
public abstract class BNConstants {
  // System class names (3)
  public static func SYSTEM_REMOTE_BREACH_STATE() -> CName = n"BetterNetrunning.RemoteBreach.Core.RemoteBreachStateSystem"
  public static func SYSTEM_DEVICE_REMOTE_BREACH_STATE() -> CName = n"BetterNetrunning.RemoteBreach.Core.DeviceRemoteBreachStateSystem"
  public static func SYSTEM_VEHICLE_REMOTE_BREACH_STATE() -> CName = n"BetterNetrunning.RemoteBreach.Core.VehicleRemoteBreachStateSystem"

  // Action names (4)
  public static func ACTION_REMOTE_BREACH() -> CName = n"RemoteBreach"
  // ... (40 more constants)
}
```

---

## Configuration System

### Settings Architecture

Better Netrunning uses a hybrid configuration system combining **CET Lua** (initialization, UI, persistence) and **REDscript** (runtime queries).

```
settings.json (JSON file)
     ↕ (Load/Save)
settingsManager.lua (CET Runtime)
     ↕ (Override)
BetterNetrunningSettings.* (REDscript static functions)
     ↕ (Query)
REDscript Game Logic
```

**Implementation Files:**
- `bin/x64/plugins/cyber_engine_tweaks/mods/BetterNetrunning/settingsManager.lua` - Settings management
- `bin/x64/plugins/cyber_engine_tweaks/mods/BetterNetrunning/settings.json` - Persistent storage
- `bin/x64/plugins/cyber_engine_tweaks/mods/BetterNetrunning/nativeSettingsUI.lua` - UI builder
- `r6/scripts/BetterNetrunning/config.reds` - Default values (overridden by Lua)

**Settings Categories (11 total):**
1. Controls - Breaching hotkey configuration
2. Breaching - Classic mode, Unconscious NPC breach toggle
3. RemoteBreach - Device-specific toggles (Computer/Camera/Turret/Device/Vehicle), RAM cost
4. AccessPoints - Auto-datamine, Auto-ping, Daemon visibility
5. RemovedQuickhacks - Block camera/turret disable quickhacks
6. UnlockedQuickhacks - Always-available quickhacks (Ping, Whistle, Distract)
7. Progression - Requirement toggles (Cyberdeck, Intelligence, Rarity)
8. ProgressionCyberdeck - Cyberdeck tier requirements per subnet
9. ProgressionIntelligence - Intelligence level requirements per subnet
10. ProgressionEnemyRarity - Enemy rarity requirements per subnet
11. Debug - Debug logging toggle (5 levels)

**Total Settings:** 69 configuration options

### Key Settings

| Setting | Default | Purpose |
|---------|---------|---------|
| **EnableClassicMode** | `false` | Disable all Better Netrunning features (vanilla behavior) |
| **AllowBreachingUnconsciousNPCs** | `true` | Enable Unconscious NPC breach |
| **UnlockIfNoAccessPoint** | `false` | RadialUnlock Mode (false = 50m radius, true = auto-unlock all) |
| **AutoDatamineBySuccessCount** | `true` | Auto-add Datamine POST-breach based on success count |
| **AutoExecutePingOnSuccess** | `true` | Auto-execute PING on any daemon success |
| **RemoteBreachEnabledComputer** | `true` | Enable Computer RemoteBreach |
| **RemoteBreachEnabledCamera** | `true` | Enable Camera RemoteBreach |
| **RemoteBreachEnabledTurret** | `true` | Enable Turret RemoteBreach |
| **RemoteBreachEnabledDevice** | `true` | Enable Device RemoteBreach (Terminal/Other) |
| **RemoteBreachEnabledVehicle** | `true` | Enable Vehicle RemoteBreach |
| **RemoteBreachRAMCostPercent** | `35` | RAM cost as % of max RAM (0-100) |
| **QuickhackUnlockDurationHours** | `0` | Unlock duration in game hours (0 = permanent) |
| **LogLevel** | `2` (INFO) | Log level (0=ERROR, 1=WARN, 2=INFO, 3=DEBUG, 4=TRACE) |

---

## Extension Points

### 1. Adding New Device Types

**Steps:**
1. Add device type detection in `Core/DeviceTypeUtils.reds`
2. Add daemon unlock strategy in `RemoteBreach/Core/DaemonUnlockStrategy.reds`
3. Add RemoteBreach action in `RemoteBreach/Actions/`
4. Register with CustomHackingSystem in `remoteBreach.lua`

### 2. Adding New Filtering Rules

**Steps:**
1. Add filter function in `Minigame/ProgramFilteringRules.reds`
2. Call filter in `Minigame/ProgramFilteringCore.reds` pipeline
3. Add test cases in `Debug/BreachSessionStats.reds`

### 3. Adding New External MOD Integration

**Steps:**
1. Create gating file in `Integration/`
2. Add `@if(ModuleExists("ModName"))` conditional compilation
3. Implement dual path (MOD-enabled + fallback)
4. Document in `Integration/README.md`

### 4. Adding New Localization Languages

**Steps:**
1. Create new `.reds` file in `Localization/` directory (e.g., `French.reds`)
2. Extend `ModLocalizationPackage` from Codeware
3. Implement `DefineTexts()` method with translated strings
4. Update `LocalizationProvider.reds` to register new language

**Example:**
```redscript
// French.reds
module BetterNetrunning.Localization
import Codeware.Localization.*

public class French extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("Category-Controls", "Contrôles");
    this.Text("DisplayName-BetterNetrunning-BreachingHotkey", "Raccourci pour le piratage inconscient");
    // ... translate all 142 entries
  }
}
```

---

## Performance Considerations

### 1. Caching Strategies

**Blackboard Caching:**
```redscript
// Bad: Repeated GetAllBlackboardDefs() calls
let minigameBB = GameInstance.GetBlackboardSystem(gameInstance).Get(GetAllBlackboardDefs().HackingMinigame);

// Good: Cache GetAllBlackboardDefs()
let defs = GetAllBlackboardDefs();
let minigameBB = GameInstance.GetBlackboardSystem(gameInstance).Get(defs.HackingMinigame);
```

**Device Type Caching:**
```redscript
// Bad: Multiple IsCamera() calls
if IsCamera(device) { ... }
if IsCamera(device) { ... }

// Good: Cache result
let isCamera = IsCamera(device);
if isCamera { ... }
if isCamera { ... }
```

### 2. Distance Calculations

**Squared Distance (RadialUnlock/):**
```redscript
// Bad: sqrt() is expensive
let distance = Vector4.Distance2D(pos1, pos2);
if distance <= 50.0 { ... }

// Good: Compare squared values (no sqrt)
let distanceSq = Vector4.DistanceSquared2D(pos1, pos2);
if distanceSq <= 2500.0 { ... }  // 50m^2 = 2500
```

### 3. Early Exits

**Guard Clauses:**
```redscript
// Bad: Full processing for invalid input
public func ProcessDevice(device: ref<DeviceComponentPS>) {
  if IsDefined(device) {
    // 50 lines of processing
  }
}

// Good: Early exit on invalid input
public func ProcessDevice(device: ref<DeviceComponentPS>) {
  if !IsDefined(device) { return; }  // Exit immediately
  // 50 lines of processing only for valid input
}
```

### 4. Array Iteration

**Reverse Deletion:**
```redscript
// Bad: Forward deletion (index shift)
for i in 0 to ArraySize(arr) - 1 {
  if ShouldDelete(arr[i]) {
    ArrayErase(arr, i);  // Shifts all elements after i
  }
}

// Good: Reverse deletion (no index shift)
let i = ArraySize(arr) - 1;
while i >= 0 {
  if ShouldDelete(arr[i]) {
    ArrayErase(arr, i);  // Safe deletion
  }
  i -= 1;
}
```

### 5. Logging Performance

**Conditional Logging:**
```redscript
// Bad: String concatenation always executes
BNDebug("Context", "Value: " + ToString(ExpensiveFunction()));

// Good: Logging function checks level first, skips string concatenation if disabled
BNDebug("Context", "Value: " + ToString(ExpensiveFunction()));  // ToString() only called if DEBUG level active
```

**Duplicate Suppression:**
- Logger.reds automatically suppresses identical messages within 5 seconds
- Reduces log spam in hot paths (e.g., `onUpdate` loops)

---

**作成者**: Better Netrunning Development Team
**承認日**: 2025-10-19
**次回レビュー**: Major feature addition or structural change
