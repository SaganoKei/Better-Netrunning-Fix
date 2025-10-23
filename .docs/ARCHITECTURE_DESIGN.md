# Better Netrunning - Architecture Design Document

**Version:** 2.4
**Last Updated:** 2025-10-24

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
├── betterNetrunning.reds              (383 lines) - Main entry point
├── config.reds                        (81 lines)  - Configuration settings
│
├── Core/                              ✅ (8 files, 2,266 lines) - Foundation layer
│   ├── Constants.reds                 (431 lines) - 44 constants (Class/Action names, TweakDBIDs)
│   ├── DeviceDistanceUtils.reds       (102 lines) - Physical distance calculations (DRY principle)
│   ├── DeviceTypeUtils.reds           (203 lines) - Device type detection & classification
│   ├── DeviceUnlockUtils.reds         (810 lines) - Shared device/vehicle/NPC unlock logic
│   ├── Events.reds                    (251 lines) - Breach event definitions & SharedGameplayPS fields
│   ├── Logger.reds                    (204 lines) - 5-level logging (ERROR/WARN/INFO/DEBUG/TRACE)
│   ├── MinigameProgramUtils.reds      (208 lines) - Program manipulation utilities
│   └── TimeUtils.reds                 (57 lines)  - Timestamp management
│
├── Utils/                             ✅ (6 files, 1,942 lines) - Business logic utilities
│   ├── BonusDaemonUtils.reds          (385 lines) - Auto PING/Datamine execution
│   ├── BreachLockUtils.reds           (153 lines) - Entity/Player/Position retrieval (DRY principle)
│   ├── BreachSessionLogger.reds       (397 lines) - Breach statistics formatting & output
│   ├── BreachStatisticsCollector.reds (276 lines) - Breach statistics data collection (DTO)
│   ├── DaemonUtils.reds               (311 lines) - Daemon type identification
│   └── DebugUtils.reds                (420 lines) - Diagnostic tools & formatted output
│
├── Integration/                       ✅ (3 files, 638 lines) - External MOD dependencies (100% centralization)
│   ├── DNRGating.reds                 (105 lines) - Daemon Netrunning Revamp integration
│   ├── RadialBreachGating.reds        (304 lines) - RadialBreach MOD integration
│   └── TracePositionOverhaulGating.reds (229 lines) - Trace MOD integration (breach failure trace)
│   Note: All external MOD dependencies centralized in Integration/
│
├── Breach/                            ✅ (4 files, 1,594 lines)
│   ├── BreachHelpers.reds             (164 lines) - Network hierarchy traversal
│   ├── BreachLockSystem.reds          (168 lines) - Unified breach lock logic (AP/NPC/RemoteBreach)
│   ├── BreachPenaltySystem.reds       (736 lines) - Failure detection, VFX, RemoteBreach lock, Trace
│   └── BreachProcessing.reds          (526 lines) - Breach completion, RefreshSlaves wrapper, Radius unlock
│   Note: Flat structure
│
├── RemoteBreach/                      ✅ (4-tier, 14 files, 4,000 lines)
│   ├── Core/ (7 files, 2,689 lines)
│   │   ├── BaseRemoteBreachAction.reds    (373 lines) - Base class for RemoteBreach actions
│   │   ├── DaemonImplementation.reds      (260 lines) - Daemon execution logic (8 daemons)
│   │   ├── DaemonRegistration.reds        (97 lines)  - TweakDB daemon registration
│   │   ├── DaemonUnlockStrategy.reds      (372 lines) - Strategy pattern (Computer/Device/Vehicle)
│   │   ├── RemoteBreachHelpers.reds       (1092 lines) - Utilities, Callbacks, JackIn 🟡
│   │   ├── RemoteBreachLockSystem.reds    (369 lines) - Timestamp-based hybrid RemoteBreach locking
│   │   └── RemoteBreachStateSystem.reds   (126 lines) - State management (3 systems)
│   ├── Actions/ (4 files, 699 lines)
│   │   ├── RemoteBreachAction_Computer.reds (148 lines) - Computer RemoteBreach
│   │   ├── RemoteBreachAction_Device.reds   (191 lines) - Device RemoteBreach (Camera/Turret/etc)
│   │   ├── RemoteBreachAction_Vehicle.reds  (147 lines) - Vehicle RemoteBreach
│   │   └── RemoteBreachProgram.reds         (213 lines) - Daemon program definitions
│   ├── Common/ (2 files, 332 lines)
│   │   ├── DeviceInteractionUtils.reds    (92 lines)  - JackIn interaction control utilities
│   │   └── UnlockExpirationUtils.reds     (240 lines) - Unlock duration expiration logic
│   └── UI/ (1 file, 318 lines)
│       └── RemoteBreachVisibility.reds    (318 lines) - Visibility control + settings
│   Note: 4-tier structure with Common/ utilities tier
│
├── RadialUnlock/                      ✅ (2 files, 947 lines)
│   ├── RadialUnlockSystem.reds        (344 lines) - Position tracking (50m radius)
│   └── RemoteBreachNetworkUnlock.reds (603 lines) - Network unlock + Nearby device 🟡
│   Note: No Core/ subdirectory, flat structure
│
├── Devices/                           ✅ (4 files, 754 lines)
│   ├── DeviceNetworkAccess.reds       (90 lines)  - Network access relaxation
│   ├── DeviceProgressiveUnlock.reds   (307 lines) - Progressive unlock logic
│   ├── DeviceQuickhackFilters.reds    (244 lines) - HackingExtensions integration, RemoteBreach replacement
│   └── DeviceRemoteActions.reds       (113 lines) - Remote action execution
│
├── Minigame/                          ✅ (3 files, 971 lines)
│   ├── ProgramFilteringCore.reds      (161 lines) - Core filtering logic
│   ├── ProgramFilteringRules.reds     (665 lines) - Filtering rules (7 filters)
│   └── ProgramInjection.reds          (145 lines) - Subnet program injection
│
├── NPCs/                              ✅ (3 files, 537 lines)
│   ├── NPCBreachExperience.reds       (78 lines)  - Breach rewards
│   ├── NPCLifecycle.reds              (219 lines) - Unconscious breach, lifecycle
│   └── NPCQuickhacks.reds             (240 lines) - Progressive unlock, permissions, Event interception
│
├── Systems/                           ✅ (1 file, 231 lines)
│   └── ProgressionSystem.reds         (231 lines) - Cyberdeck/Intelligence/Rarity requirements
│   Note: Top-level Systems/ directory for cross-cutting concerns
│
├── Localization/                      ✅ (3 files, 566 lines)
│   ├── English.reds                   (261 lines) - English localization (142 entries)
│   ├── Japanese.reds                  (260 lines) - Japanese localization (142 entries)
│   └── LocalizationProvider.reds      (45 lines)  - Localization provider
│
TOTAL: 54 files, 14,094 lines (11 directories, 19 modules)

**File Structure Notes:**
- **Statistics Split**: BreachStatisticsCollector.reds (DTO data collection) + BreachSessionLogger.reds (formatting/output)
- **RemoteBreach/Common/**: Utility classes for JackIn control and unlock expiration (2 files, 332 lines)
- **Core/DeviceDistanceUtils.reds**: Centralized physical distance calculations (DRY principle)
- **Breach/**: Flat structure (4 files, alphabetical order)
- **Systems/**: Top-level directory for ProgressionSystem (cross-cutting progression logic)
```

**Architecture Notes:**
- ✅ **Module Separation**: Core/, Utils/, Integration/ provide foundation functionality
- ✅ **RemoteBreach Architecture**: 4-tier hierarchy (Core/Actions/Common/UI)
- ✅ **Breach Architecture**: Flat structure (4 files)
- ✅ **RadialUnlock Architecture**: Flat structure (2 files)
- ✅ **Integration Directory**: All external MOD dependencies centralized (100% isolation)
- ✅ **Systems Directory**: Top-level Systems/ for cross-cutting concerns (Progression)
- ✅ **Statistics Split**: BreachStatisticsCollector (DTO) + BreachSessionLogger (formatting)
- 🟡 **500-line Exceptions**: RemoteBreachHelpers.reds (1092), DeviceUnlockUtils.reds (810), BreachPenaltySystem.reds (736), ProgramFilteringRules.reds (665), RemoteBreachNetworkUnlock.reds (603)

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
    └── depends on Utils.* (BreachSessionLogger)

RemoteBreach/ modules
    ├── Core/: depends on Core.*, Utils.*
    ├── Actions/: depends on RemoteBreach.Core.*
    ├── Common/: depends on Core.*, Utils.*
    ├── UI/: depends on RemoteBreach.Core.*, config.*
    └── Note: HackingExtensions guards distributed (20+ @if conditions)

Devices/ modules
    ├── depends on Core.* (DeviceTypeUtils, Logger, Constants)
    ├── depends on Utils.* (DaemonUtils)
    └── depends on Systems.* (ProgressionSystem)

Minigame/ modules
    ├── depends on Core.* (Logger, Constants)
    ├── depends on Utils.* (DaemonUtils)
    └── depends on Integration.* (DNRGating)

NPCs/ modules
    ├── depends on Core.* (DeviceTypeUtils, Events, Logger)
    ├── depends on Utils.* (BonusDaemonUtils)
    └── depends on Systems.* (ProgressionSystem)

RadialUnlock/ modules
    └── depends on Core.*, Utils.*

Systems/ modules
    └── ProgressionSystem.reds (standalone, cross-cutting concerns)

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

**Core/ (8 files, 2,266 lines):**

| File | Lines | Purpose |
|------|-------|---------|
| **Constants.reds** | 431 | 44 constants (Class names, Action names, TweakDBIDs) |
| **DeviceDistanceUtils.reds** | 102 | Physical distance calculations (DRY principle) |
| **DeviceTypeUtils.reds** | 203 | Device type detection & classification |
| **DeviceUnlockUtils.reds** | 810 | Shared device/vehicle/NPC unlock logic (radius-based) |
| **Events.reds** | 251 | Breach event definitions, SharedGameplayPS field extensions |
| **Logger.reds** | 204 | 5-level logging (ERROR/WARN/INFO/DEBUG/TRACE), duplicate suppression |
| **MinigameProgramUtils.reds** | 208 | Program manipulation utilities |
| **TimeUtils.reds** | 57 | Timestamp management for unlock duration |

**Utils/ (6 files, 1,942 lines):**

| File | Lines | Purpose |
|------|-------|---------|
| **BonusDaemonUtils.reds** | 385 | Auto PING/Datamine execution POST-breach |
| **BreachLockUtils.reds** | 153 | Entity/Player/Position retrieval (DRY principle) |
| **BreachSessionLogger.reds** | 397 | Breach statistics formatting & output with emoji icons (🔧📷🔫👤) |
| **BreachStatisticsCollector.reds** | 276 | Breach statistics data collection (DTO pattern) |
| **DaemonUtils.reds** | 311 | Daemon type identification (Basic/Camera/Turret/NPC) |
| **DebugUtils.reds** | 420 | Diagnostic tools & formatted output |

**Integration/ (3 files, 638 lines):**

| File | Lines | Purpose |
|------|-------|---------|
| **DNRGating.reds** | 105 | Daemon Netrunning Revamp MOD integration |
| **RadialBreachGating.reds** | 304 | RadialBreach MOD physical distance filtering |
| **TracePositionOverhaulGating.reds** | 229 | Trace MOD integration (real NPC vs virtual netrunner) |

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

**Penalty System (Breach/BreachPenaltySystem.reds):**

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

**4-Tier Architecture:**

```
RemoteBreach/ (4-tier, 14 files, 4,000 lines)
├── Core/ (7 files, 2,689 lines) - State management, Strategy pattern, Helpers
│   ├── BaseRemoteBreachAction.reds (373 lines) - Base class for all RemoteBreach actions
│   ├── DaemonImplementation.reds (260 lines) - 8 daemon execution logic
│   ├── DaemonRegistration.reds (97 lines) - TweakDB daemon registration
│   ├── DaemonUnlockStrategy.reds (372 lines) - Strategy pattern (Computer/Device/Vehicle)
│   ├── RemoteBreachHelpers.reds (1092 lines) - Utility classes, Callbacks, JackIn control
│   ├── RemoteBreachLockSystem.reds (369 lines) - Timestamp-based hybrid RemoteBreach locking
│   └── RemoteBreachStateSystem.reds (126 lines) - 3 state systems (Computer/Device/Vehicle)
├── Actions/ (4 files, 699 lines) - Action implementations
│   ├── RemoteBreachAction_Computer.reds (148 lines) - ComputerControllerPS
│   ├── RemoteBreachAction_Device.reds (191 lines) - Camera/Turret/Terminal/Other
│   ├── RemoteBreachAction_Vehicle.reds (147 lines) - VehicleComponentPS
│   └── RemoteBreachProgram.reds (213 lines) - Daemon program definitions
├── Common/ (2 files, 332 lines) - Utility classes
│   ├── DeviceInteractionUtils.reds (92 lines) - JackIn interaction control utilities
│   └── UnlockExpirationUtils.reds (240 lines) - Unlock duration expiration logic
└── UI/ (1 file, 318 lines) - UI control & visibility
    └── RemoteBreachVisibility.reds (318 lines) - Visibility control + settings
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

**Flat Architecture:**

```
RadialUnlock/ (2 files, 947 lines)
    ├── RadialUnlockSystem.reds (344 lines) - Position tracking (breach coordinates + timestamps)
    └── RemoteBreachNetworkUnlock.reds (603 lines) - Network unlock + Nearby device unlock

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

### 7. Progression System (Systems/)

**Purpose:** Control unlock requirements based on player progression

**Key Components:**
- `Systems/ProgressionSystem.reds` (231 lines): Cyberdeck tier, Intelligence level, Enemy rarity requirements

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

### 8. Breach Penalty System (Breach/)

**Purpose:** Apply meaningful penalties when players fail breach protocol minigames to maintain game balance and prevent risk-free RemoteBreach gameplay.

**Components:**

#### A. BreachPenaltySystem.reds (736 lines)

**Failure Detection & Penalty Application:**

```redscript
@wrapMethod(ScriptableDeviceComponentPS)
public func FinalizeNetrunnerDive(state: HackingMinigameState) -> Void {
  // Early Return: Success or penalty disabled
  if NotEquals(state, HackingMinigameState.Failed) ||
     !BetterNetrunningSettings.BreachFailurePenaltyEnabled() {
    wrappedMethod(state);
    return;
  }

  // Apply full failure penalty
  ApplyFailurePenalty(player, this, gameInstance);
  wrappedMethod(state);
}
```

**Penalties Applied (Failure Only):**
1. **Red VFX** (2-3 seconds, `disabling_connectivity_glitch_red`)
2. **RemoteBreach Lock** (10 minutes default, 50m radius)
3. **Position Reveal Trace** (60s upload, requires real netrunner NPC via TracePositionOverhaul)

**State Handling:**
- `HackingMinigameState.Succeeded` → No penalty (early return)
- `HackingMinigameState.Failed` → Full penalty (both ESC skip and timeout)
- No differentiation between skip and timeout (HackingMinigameState has no "Skipped" state)

**Coverage:**
- AP Breach: Covered via `FinalizeNetrunnerDive()` wrapper
- Unconscious NPC Breach: Covered via `AccessBreach.CompleteAction()` → `FinalizeNetrunnerDive()`
- Remote Breach: Covered via `RemoteBreachProgram` → `FinalizeNetrunnerDive()`

**Architecture:**
- Single `@wrapMethod` covers all breach types (maintainability)
- Early Return pattern for clean control flow
- Max nesting depth: 2 levels

#### B. RemoteBreachLockSystem.reds (369 lines)

**Timestamp-Based Hybrid RemoteBreach Locking:**

```redscript
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningRemoteBreachFailedTimestamp: Float;
```

**Lock Logic (4-Phase Hybrid Locking):**

```
Device RemoteBreach failure
  ↓
Phase 1: Lock failed device itself
  └─ Set m_betterNetrunningRemoteBreachFailedTimestamp on device PS

Phase 2: Lock entire connected network (no distance limit)
  └─ Get all network devices via GetNetworkDevices()
  └─ Set timestamp on each device PS

Phase 3: Lock standalone/network devices in radius (configurable, default 25m)
  └─ Radial scan from failure position
  └─ Set timestamp on devices within range

Phase 3B: Lock vehicles in radius (configurable, default 25m)
  └─ Radial scan from failure position
  └─ Set timestamp on vehicles within range
```

**Lock Duration:**
- **Default:** 10 minutes (configurable via `BreachPenaltyDurationMinutes`)
- **Expiration:** Checked at RemoteBreach attempt time (`currentTime - timestamp > lockDuration`)
- **Scope:** Only affects RemoteBreach actions (no effect on AP Breach, Unconscious NPC Breach)

**QuickHack Filtering:**

```redscript
@wrapMethod(ScriptableDeviceComponentPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>,
                                   context: GetActionsContext) {
  wrappedMethod(actions, context);

  // Remove RemoteBreach if device is locked by timestamp
  if BreachLockUtils.IsDeviceLockedByBreachFailure(this) {
    RemoveAllRemoteBreachActions(actions);
  }
}
```

**Performance Optimization:**
- Timestamp-based check (O(1) per device, no position array iteration)
- Squared distance calculation for radial scan (Phase 3/3B)
- Range configurable via RadialBreach MOD settings (10-50m, default 25m)

#### C. BreachLockUtils.reds (153 lines, Utils/)

**DRY Principle Application:**

Aggregates duplicate Entity/Player/Position retrieval patterns across 9 locations (~100 lines total) into 2 static methods:

```redscript
public static func IsDeviceLockedByBreachFailure(
  devicePS: ref<ScriptableDeviceComponentPS>
) -> Bool

public static func IsNPCLockedByBreachFailure(
  npcPS: ref<ScriptedPuppetPS>
) -> Bool
```

**Called From (8 files):**
- RemoteBreachAction_Computer.reds
- RemoteBreachAction_Device.reds
- RemoteBreachAction_Vehicle.reds
- DeviceProgressiveUnlock.reds (2 occurrences)
- DeviceRemoteActions.reds
- RemoteBreachVisibility.reds (2 occurrences)
- NPCQuickhacks.reds

**Dependencies:**
- BetterNetrunningConfig: `BreachFailurePenaltyEnabled()`, `RemoteBreachLockDurationMinutes()`
- Core/Logger.reds: Debug logging
- Integration/TracePositionOverhaulGating.reds: Optional trace integration

**Design Patterns:**
- Early Return pattern for clean control flow
- Max nesting depth: 2 levels
- DRY principle: Single source of truth for lock checking logic

### 9. Debug Logging System (Core/Logger.reds + Utils/BreachSessionLogger.reds + Utils/BreachStatisticsCollector.reds)

**Purpose:** Centralized logging infrastructure with level-based filtering, duplicate suppression, and statistics collection

**Components:**
- `Core/Logger.reds` (204 lines): 5-level logging system with duplicate suppression
- `Utils/BreachSessionLogger.reds` (397 lines): Statistics formatting & output with emoji icons
- `Utils/BreachStatisticsCollector.reds` (276 lines): Statistics data collection (DTO pattern)

**5-Level Log System:**

```redscript
// Log levels (0-4)
ERROR   (0) → Errors only (critical failures, null checks)
WARNING (1) → Warnings + Errors (deprecated paths, fallback logic)
INFO    (2) → Info + Warning + Error (breach summaries, major events) [DEFAULT]
DEBUG   (3) → Debug + all above (intermediate calculations, state changes)
TRACE   (4) → Trace + all above (internal processing details)

// Public API
BNError(context: String, message: String)   // Always outputs (level 0)
BNWarn(context: String, message: String)    // Outputs when level ≥ 1
BNInfo(context: String, message: String)    // Outputs when level ≥ 2
BNDebug(context: String, message: String)   // Outputs when level ≥ 3
BNTrace(context: String, message: String)   // Outputs when level ≥ 4 (internal details)
```

**Internal Level Filtering:**

```redscript
// Logger.reds handles all level filtering (SRP compliance)
public static func BNTrace(context: String, message: String) -> Void {
  if EnumInt(GetCurrentLogLevel()) >= EnumInt(LogLevel.TRACE) {
    LogWithLevel(LogLevel.TRACE, context, message);
  }
}

// Callers provide content only (no level checks required)
BNTrace("Context", "Internal processing detail");
```

**Duplicate Suppression:**

```redscript
// Suppress identical messages within 5 seconds
BNInfo("MyContext", "Same message");  // Outputs
BNInfo("MyContext", "Same message");  // Suppressed (< 5s)
// After 5 seconds
BNInfo("MyContext", "Same message");  // Outputs again
```

**Breach Statistics Collection:**

**Design Pattern:** Data Transfer Object (DTO) with separation of concerns
- **BreachStatisticsCollector.reds** (276 lines): Data collection & aggregation (DTO)
- **BreachSessionLogger.reds** (397 lines): Formatting & output with emoji icons
- **Separation Rationale**: Statistics gathering logic separated from presentation logic

**BreachStatisticsCollector.reds (DTO):**
```redscript
public class BreachSessionStats {
  // Data fields (20+)
  public let breachType: String;
  public let deviceType: String;
  public let successCount: Int32;
  public let bonusApplied: Bool;
  // ... (20+ fields)
}

// Data collection methods
public func RecordDeviceUnlock(deviceType: String) -> Void
public func RecordRadialUnlock(deviceType: String) -> Void
public func RecordSubnetUnlock(subnetType: String) -> Void
```

**BreachSessionLogger.reds (Formatting):**
```redscript
// Output formatting with emoji icons
public static func LogBreachSummary(stats: ref<BreachSessionStats>) -> Void {
  // Format output with box drawing, emoji icons
}
```

**Collected Data (20+ fields):**
  - Breach type (AccessPoint/UnconsciousNPC/RemoteBreach)
  - Target device type
  - Success count (uploaded daemons)
  - Applied bonuses (Auto PING, Auto Datamine)
  - Unlocked subnets (Basic/Camera/Turret/NPC)
  - Device breakdown with emoji icons:
    🔧 Basic     - General devices
    📷 Cameras   - Surveillance cameras
    🔫 Turrets   - Security turrets
    👤 NPCs      - Network-connected NPCs
  - RadialUnlock details:
    🔌 Devices   - Standalone devices
    🚗 Vehicles  - Unlocked vehicles
    🚶 NPCs      - Standalone NPCs
  - Unlock status:
    ✅ UNLOCKED  - Successfully unlocked
    🔒 Locked    - Locked state

Output Format (with emoji icons):
  ╔═══════════════════════════════════════════════════════════╗
  ║             BREACH SESSION SUMMARY                        ║
  ╠═══════════════════════════════════════════════════════════╣
  ║ Target:      AccessPoint (Computer)                       ║
  ║ Success:     3 daemons uploaded                           ║
  ║ Device Type Breakdown:                                    ║
  ║ │ 🔧 Basic     : 5                                        ║
  ║ │ 📷 Cameras   : 3                                        ║
  ║ │ 🔫 Turrets   : 2                                        ║
  ║ │ 👤 NPCs      : 4                                        ║
  ║ Radial Unlock:                                            ║
  ║ │ 🔌 Devices   : 2                                        ║
  ║ │ 🚗 Vehicles  : 1                                        ║
  ║ │ 🚶 NPCs      : 3                                        ║
  ║ Unlock Flags:                                             ║
  ║ │ Basic Subnet   : ✅ UNLOCKED                            ║
  ║ │ Camera Subnet  : ✅ UNLOCKED                            ║
  ║ │ Turret Subnet  : 🔒 Locked                              ║
  ║ │ NPC Subnet     : 🔒 Locked                              ║
  ╚═══════════════════════════════════════════════════════════╝
```

### 10. Localization System (Localization/)

**Purpose:** Multi-language support for UI text

**Key Components:**
- `English.reds` (261 lines): English localization (142 entries)
- `Japanese.reds` (260 lines): Japanese localization (142 entries)
- `LocalizationProvider.reds` (45 lines): Localization provider interface

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
   └─ Record statistics (BreachStatisticsCollector + BreachSessionLogger)
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
  BreachStatisticsCollector.RecordBreach();
  BreachSessionLogger.LogBreachSummary();
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

### 5. Hierarchical Organization Pattern

**Purpose:** Organize complex modules into logical tiers

```
RemoteBreach/ (4-tier)
├── Core/ - Foundation (State, Strategy, Helpers, Lock)
├── Actions/ - Implementation (Computer/Device/Vehicle)
├── Common/ - Utilities (JackIn control, Unlock expiration)
└── UI/ - Presentation (Visibility)

Breach/ (Flat, 4 files)
├── BreachHelpers.reds - Network hierarchy traversal
├── BreachLockSystem.reds - Unified breach lock logic
├── BreachPenaltySystem.reds - Penalty logic
└── BreachProcessing.reds - Workflow

RadialUnlock/ (Flat, 2 files)
├── RadialUnlockSystem.reds - Position tracking
└── RemoteBreachNetworkUnlock.reds - Network unlock
```

### 6. Constants Management Pattern (Core/Constants.reds)

**Purpose:** Eliminate magic strings, enable IDE autocomplete

```redscript
// Before (magic strings)
let system = container.Get(n"BetterNetrunning.RemoteBreach.Core.RemoteBreachStateSystem");

// After (constants)
let system = container.Get(BNConstants.SYSTEM_REMOTE_BREACH_STATE());

// Constants.reds (431 lines, 44 constants)
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

**Settings Categories (12 total):**
1. Controls - Breaching hotkey configuration
2. Breaching - Classic mode, Unconscious NPC breach toggle
3. RemoteBreach - Device-specific toggles (Computer/Camera/Turret/Device/Vehicle), RAM cost
4. BreachPenalty - Failure penalties, RemoteBreach lock duration
5. AccessPoints - Auto-datamine, Auto-ping, Daemon visibility
6. RemovedQuickhacks - Block camera/turret disable quickhacks
7. UnlockedQuickhacks - Always-available quickhacks (Ping, Whistle, Distract)
8. Progression - Requirement toggles (Cyberdeck, Intelligence, Rarity)
9. ProgressionCyberdeck - Cyberdeck tier requirements per subnet
10. ProgressionIntelligence - Intelligence level requirements per subnet
11. ProgressionEnemyRarity - Enemy rarity requirements per subnet
12. Debug - Debug logging toggle (5 levels)

**Total Settings:** 76 configuration options

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
| **RemoteBreachRAMCostPercent** | `50` | RAM cost as % of max RAM (0-100) |
| **BreachFailurePenaltyEnabled** | `true` | Master switch for all breach failure penalties |
| **APBreachFailurePenaltyEnabled** | `true` | Enable/disable AP Breach specific penalties |
| **NPCBreachFailurePenaltyEnabled** | `true` | Enable/disable Unconscious NPC Breach specific penalties |
| **RemoteBreachFailurePenaltyEnabled** | `true` | Enable/disable RemoteBreach specific penalties |
| **BreachPenaltyDurationMinutes** | `10` | RemoteBreach lock duration after failure (1-60 minutes) |
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
