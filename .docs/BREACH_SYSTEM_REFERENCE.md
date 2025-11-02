# Better Netrunning - Breach System Technical Reference

**Last Updated:** 2025-11-02
**Purpose:** Technical reference for Breach System functionality
**Version:** Current

**IMPORTANT DEPENDENCY:** Remote Breach functionality requires CustomHackingSystem (HackingExtensions mod). All RemoteBreach-related code is wrapped with `@if(ModuleExists("HackingExtensions"))`.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Breach Initialization Methods](#breach-initialization-methods)
3. [Daemon Injection](#daemon-injection)
4. [Program Filtering](#program-filtering)
5. [Minigame Parameters](#minigame-parameters)
6. [Post-Breach Processing](#post-breach-processing)
7. [Settings Control](#settings-control)
8. [Processing Flow Comparison](#processing-flow-comparison)
9. [Processing Timing Details](#processing-timing-details)
10. [Key Functional Differences Summary](#key-functional-differences-summary)
11. [Statistics Collection System](#statistics-collection-system)

---

## Overview

Better Netrunning supports three breach types with distinct characteristics:

- **AP Breach:** Traditional breach via Access Points
- **Unconscious NPC Breach:** Direct breach on unconscious NPCs
- **Remote Breach:** Remote breach on devices (Computer/Camera/Turret/Device/Vehicle)

### Network Access Relaxation

**Status:** ⚠️ **DISABLED**

**Reason:** Network access relaxation caused softlock bugs where devices would remain permanently locked. The feature has been disabled to maintain game stability.

**Previous Features (now disabled):**
1. ~~Door QuickHack Menu: All doors show QuickHack menu regardless of AP connection~~
2. ~~Standalone Device RemoteBreach: All devices can use RemoteBreach (not just networked ones)~~
3. ~~Universal Ping: Ping works on all devices for reconnaissance~~

**Current Behavior:**
- Default vanilla network topology restrictions apply
- Devices require proper network connections for RemoteBreach
- Standard accessibility rules enforced

---

## Breach Initialization Methods

### Comparison Table

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Entity & Interaction** | AccessPoint entity interaction | Unconscious NPC interaction<br>("Breach Unconscious Officer") | CustomHackingSystem API<br>(Quickhack on Computer/Device/Camera/etc.) |
| **Blackboard Flags** | `RemoteBreach = false`<br>`OfficerBreach = false` | `RemoteBreach = false`<br>`OfficerBreach = true` | `RemoteBreach = true`<br>`OfficerBreach = false` |
| **Target Entity** | AccessPoint | ScriptedPuppet (unconscious state) | Device, Computer, Camera, Turret, Vehicle, ScriptedPuppet |
| **Network Connection Requirement** | ❌ Not required (AP itself is hub) | ✅ Required via `IsConnectedToBackdoorDevice()` | ⚠️ Network access relaxation<br>(Always returns true for standalone devices) |
| **Breach Failure Penalty** | ✅ Applied (all penalties) | ✅ Applied (all penalties) | ✅ Applied (all penalties) |
| **Statistics Collection** | ✅ Implemented | ✅ Implemented | ✅ Implemented |

### Detailed Activation Conditions

#### AP Breach
```
✅ AccessPoint entity exists
✅ Interaction available
```

#### Unconscious NPC Breach
```
✅ AllowBreachingUnconsciousNPCs = true
✅ NPC is unconscious
✅ IsConnectedToBackdoorDevice() = true
   (Network access relaxation - always true for standalone)
✅ RadialUnlock Mode enabled (UnlockIfNoAccessPoint = false)
   OR physically connected to AP
✅ Not directly breached (m_betterNetrunningWasDirectlyBreached = false)
```

#### Remote Breach
```
✅ Corresponding RemoteBreachEnabled setting = true
   - RemoteBreachEnabledComputer (Computer)
   - RemoteBreachEnabledCamera (Camera)
   - RemoteBreachEnabledTurret (Turret)
   - RemoteBreachEnabledDevice (Device)
   - RemoteBreachEnabledVehicle (Vehicle)
✅ RadialUnlock Mode enabled (UnlockIfNoAccessPoint = false)
✅ Target available (network connection relaxed)
✅ Not breached
```

#### Breach Failure Penalty
```
✅ BreachFailurePenaltyEnabled = true
✅ Breach minigame failed (HackingMinigameState.Failed)
   Includes:
   - Timeout (timer expires)
   - ESC skip (player aborts)
```

---

## Daemon Injection

### Injected Subnet Daemons

**Note:** Remote Breach has three action types (Computer/Device/Vehicle) based on target device type
- **Computer RemoteBreach:** For ComputerControllerPS (always `camera,basic` daemons)
- **Device RemoteBreach:** For Camera/Turret/Terminal/Other devices (daemons dynamically determined by device type)
  - Camera: `camera,basic` daemons
  - Turret: `turret,basic` daemons
  - Terminal: `npc,basic` daemons
  - Other: `basic` daemon only
- **Vehicle RemoteBreach:** Vehicle-specific (always `basic` daemon only)

**Architecture:**
- Computer: Dedicated state management for Computer devices
- Device: Dedicated state management for non-Computer/non-Vehicle devices
- Vehicle: Dedicated state management for vehicles
- Daemon determination: Computer uses fixed "camera,basic", Device uses dynamic detection

| Daemon Type | AP Breach | Unconscious NPC Breach<br>(Regular NPC) | Unconscious NPC Breach<br>(Netrunner) | Remote Breach<br>(Device - Computer) | Remote Breach<br>(Device - Camera) | Remote Breach<br>(Device - Turret) | Remote Breach<br>(Device - Terminal) | Remote Breach<br>(Device - Other) | Remote Breach<br>(Vehicle) |
|------------|-----------|--------------------------|------------------------------|-------------------------------|------------------------|------------------------|---------------------------|------------------------|-------------------------|
| **Turret Subnet** | ✅ Injected | ❌ | ✅ Injected | ❌ | ❌ | ✅ Injected | ❌ | ❌ | ❌ |
| **Camera Subnet** | ✅ Injected | ❌ | ✅ Injected | ✅ Injected | ✅ Injected | ❌ | ❌ | ❌ | ❌ |
| **NPC Subnet** | ✅ Injected | ✅ Injected | ✅ Injected | ❌ | ❌ | ❌ | ✅ Injected | ❌ | ❌ |
| **Basic Subnet** | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected |

### Injection Logic (AP Breach / Unconscious NPC Breach)

```redscript
// Breach point type detection
isAccessPoint  = IsDefined(this.m_entity as AccessPoint)
isUnconsciousNPC = IsDefined(this.m_entity as ScriptedPuppet)
isNetrunner    = isUnconsciousNPC && IsNetrunnerPuppet()
isComputer     = !isAccessPoint && DaemonFilterUtils.IsComputer(devicePS)
isBackdoor     = !isAccessPoint && !isComputer && DaemonFilterUtils.IsRegularDevice(entity)

// Injection conditions (injected if included in conditional expression)
TURRETS: (isAccessPoint || isNetrunner)
  → Injected only during AP Breach or Netrunner NPC Breach

CAMERAS: (isAccessPoint || isComputer || isBackdoor || isNetrunner)
  → Injected during AP Breach, Computer RemoteBreach, Backdoor device, Netrunner NPC Breach

NPCs: (isAccessPoint || isUnconsciousNPC || isNetrunner)
  → Injected during AP Breach, Unconscious NPC Breach, Netrunner NPC Breach

BASIC: Always injected
```

**Important Design Constraints:**
- In-game, you can interact directly with Computer/Terminal devices to initiate AP Breach
- AP Breach is also possible from regular devices like Camera/Door/Vending
- `isBackdoor` judgment uses different detection methods depending on context:
  - Type-based detection (regular device like Camera/Door?)
  - Network connection state detection (actually via Backdoor?)
  - This difference is intentional design (different purposes and performance requirements)

**Conclusion:** `isComputer` and `isBackdoor` code are normal code used in regular gameplay

**Important:** Not all injected daemons are **necessarily displayed**
- Filtered based on network scan results according to `UnlockIfNoAccessPoint` setting
- Example: After Camera Subnet injection, it may be removed if no Cameras exist in the network

### Injection Logic (Remote Breach)

```redscript
// Remote Breach daemon injection is determined by target device type and RemoteBreach action class

Computer RemoteBreach:
  → Computer → Camera/Basic injection (fixed: "camera,basic")

Device RemoteBreach:
  → Camera → Camera/Basic injection
  → Turret → Turret/Basic injection
  → Terminal → NPC/Basic injection
  → Other → Basic only injection

Vehicle RemoteBreach:
  → Vehicle → Basic only injection
```

**Architecture:**
- Computer: Three separate action classes handle daemon injection
- Device: Dynamic daemon detection based on device type
- Vehicle: Dedicated action class for vehicles

**Important:** Remote Breach uses direct device type detection via three separate action classes

### Daemon Injection Design Philosophy

- **AP Breach:** Access rights to all subnets as network gateway
- **Unconscious NPC (Regular):** Limited access (NPC Subnet + Basic Subnet)
- **Unconscious NPC (Netrunner):** Full subnet access with Netrunner privileges
- **Computer RemoteBreach:** Fixed access (Camera Subnet + Basic Subnet)
- **Device RemoteBreach:** Restricted access based on target device type
  - Camera: Camera Subnet + Basic Subnet
  - Turret: Turret Subnet + Basic Subnet
  - Terminal: NPC Subnet + Basic Subnet
  - Other: Basic Subnet only
- **Vehicle RemoteBreach:** Minimum access (Basic Subnet only)

---

## Program Filtering

### Filtering Application Order

**Injection-time Control:**
- Backdoor device detection (Camera + Basic only injection)
- Device type availability check (injection control based on UnlockIfNoAccessPoint setting)
- Breach point type detection (AccessPoint/Computer/NPC/Netrunner)

**Filter-time Control:**
```
1. ShouldRemoveBreachedPrograms() - Remove already breached daemons
2. ShouldRemoveNetworkPrograms() - Network connectivity filter
3. ShouldRemoveDeviceBackdoorPrograms() - Backdoor device restrictions
4. ShouldRemoveAccessPointPrograms() - Non-AccessPoint type program filter
5. ShouldRemoveNonNetrunnerPrograms() - Non-netrunner NPC restrictions
6. ShouldRemoveDeviceTypePrograms() - Device type availability filter
7. ShouldRemoveDataminePrograms() - Datamine auto-addition filter (when AutoDatamineBySuccessCount=true)
```

**Current Architecture:**
- **Injection-time control:** Backdoor device detection, device type availability detection, breach point type detection
- **Filter-time control:** Network state, user settings, breach state, device type filters
- **Benefits:** Performance improvement, code consistency, RadialBreach normal operation

**AccessPoint Type Programs:**
- All have `type = "MinigameAction.AccessPoint"` + `category = "MinigameAction.DataAccess"`
- NetworkLootShard (Shard)
- NetworkLootMaterials (Materials)
- NetworkLootMoney (Money)
- NetworkDataMineLootAll/Advanced/Master (Datamine V1/V2/V3) ← Added post-breach by BonusDaemonUtils
- NetworkLootQ003/MQ024/MQ015 etc. (Quest-specific)

### 1. Already-Breached Program Filter

**Description:** Removes programs for device types that have already been breached on the current network.

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Applied** | ✅ | ✅ | ✅ |
| **Removal Condition** | Device type already breached | Same | Same |
| **Removal Target** | Unlock programs for breached subnets | Same | Same |
| **Timing** | After vanilla `wrappedMethod()` | Same | Same |

**Breached State Flags:**
- `m_betterNetrunningBreachedBasic` - Basic subnet unlocked
- `m_betterNetrunningBreachedCameras` - Camera subnet unlocked
- `m_betterNetrunningBreachedTurrets` - Turret subnet unlocked
- `m_betterNetrunningBreachedNPCs` - NPC subnet unlocked

**Purpose:** Prevent duplicate unlock programs from appearing in subsequent breaches on the same network.

---

### 2. Non-AccessPoint Type Program Filter

**Description:** Removes non-AccessPoint type programs (except Subnet type programs).

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Applied** | ❌ Removed (deprecated) | ❌ Removed (deprecated) | ❌ Never applied |
| **Removal Condition** | - | - | - |
| **Removal Target** | - | - | - |

**Important 1:** Remote Breach completely bypasses this filter

**Important 2:** Programs defined in Remote Breach are all Subnet type programs

**Behavior (Post-deletion):**
```
Non-AccessPoint type program filter (deprecated):
  ❌ Removed in maintenance refactoring
  ✅ AccessPoint type programs: Always displayed (Shard, Materials, Money, Quest-specific etc.)
  ✅ Subnet type programs: Always displayed
  ⚠️ Non-AccessPoint type programs: Now always displayed (previous filter removed)
```

---

### 3. RadialBreach Physical Range Filter

**Operation:**
- Injection-time control: Control injection based on UnlockIfNoAccessPoint setting
- RadialBreach integration: Unlock devices within physical range based on injected programs

| Item | AP Breach | Unconscious NPC Breach<br>(Regular NPC) | Unconscious NPC Breach<br>(Netrunner) | Remote Breach<br>(Regular) | Remote Breach<br>(Netrunner NPC) |
|------|-----------|--------------------------|------------------------------|---------------------|------------------------------|
| **Applied** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Injection Strategy** | Depends on UnlockIfNoAccessPoint setting | Same | Same | - | Same |
| **RadialBreach** | Unlock physical range with successful programs | Same | Same | - | Same |

**Injection Strategy:**
```
UnlockIfNoAccessPoint = true (Network priority):
  → Inject based on network scan results
  → Don't inject Camera Subnet if no Cameras exist

UnlockIfNoAccessPoint = false (RadialBreach priority):
  → Always inject (delegate physical range control to RadialBreach)
  → Inject Camera Subnet even if no Cameras exist
```

**RadialBreach Operation:**
1. After minigame success, retrieve successful programs
2. Unlock devices within physical range based on successful programs
3. Devices not on network can be controlled if within physical range

**Important:** Remote Breach basically skips physical range filter, except for Netrunner NPC targets

**Result:** Only devices within physical range can be breached

---

### 4. Datamine Program Filter

**Description:** Removes ALL Datamine programs when auto-datamine feature is enabled. Datamine programs are automatically added POST-breach based on success count.

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Applied** | ✅ | ✅ | ✅ |
| **Removal Condition** | `AutoDatamineBySuccessCount = true` | Same | Same |
| **Removal Target** | ALL Datamine variants (V1/V2/V3) | Same | Same |
| **Timing** | During `FilterPlayerPrograms()` | Same | Same |

**Purpose:** Prevent duplicate Datamine programs from appearing in minigame when auto-datamine feature handles them POST-breach.

**Setting Effects:**
```
AutoDatamineBySuccessCount = true (default):
  → ALL Datamine programs filtered during minigame
  → Appropriate Datamine added POST-breach based on success count

AutoDatamineBySuccessCount = false:
  → Datamine programs visible during minigame (vanilla behavior)
  → Player manually selects Datamine
```

**Related Features:**
- Pre-Breach: This filter removes Datamine from display
- Post-Breach: Auto-add appropriate Datamine based on success count
- See Also: [Auto Datamine Operation](#auto-datamine-operation) section

---

## Minigame Parameters

### Timer Multiplier

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Timer Multiplier** | 1.0x (standard) | **1.5x (50% increase)** | 1.0x (standard) |
| **Reason** | Normal breach | Time leeway with physical direct connection | Same difficulty even remotely |

### Minigame Configuration Source

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Configuration Source** | NetworkTDBID | Character Record<br>`characterRecord.MinigameInstance()` | NetworkTDBID<br>(Registered in TweakDB via CET) |
| **Difficulty** | Target's PowerLevel | Target NPC's record definition | Target's PowerLevel |

### RAM Cost

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **RAM Cost** | ❌ None | ❌ None | ✅ Yes (configurable) |
| **Cost Calculation** | - | - | `RemoteBreachRAMCostPercent` × Max RAM |
| **Default** | - | - | 35% |

---

## Post-Breach Processing

### Bonus Daemon Auto-Add

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Auto PING** | ✅ Implemented | ✅ Implemented | ✅ Implemented |
| **Auto Datamine** | ✅ Implemented | ✅ Implemented | ✅ Implemented |
| **Application Conditions** | `AutoExecutePingOnSuccess = true`<br>`AutoDatamineBySuccessCount = true` | Same | Same |

### Auto PING Operation

```
Condition: AutoExecutePingOnSuccess = true
Operation:
  - Any daemon succeeds
  - PING not yet uploaded by player
  → Automatically add and execute PING (silent execution)
```

**Debug Logging:**
When `EnableDebugLog = true`, the following logs are output:
- `ApplyBonusDaemons called - Success count: X`
- `AutoExecutePingOnSuccess setting: true/false`
- `PING already in active programs: true/false`
- `Bonus Daemon: Auto-added PING (silent execution)` (if added)
- `PING already uploaded by player, skipping auto-add` (if skipped)

**Troubleshooting:**
If PING is not auto-executing:
1. Check `AutoExecutePingOnSuccess` setting is `true`
2. Verify at least one daemon was successfully uploaded
3. Enable `EnableDebugLog` and check game logs
4. If "PING already uploaded by player" appears, player manually uploaded PING

### Auto Datamine Operation

```
Condition: AutoDatamineBySuccessCount = true
Operation:
  - Count successful daemons (excluding Datamine itself)
  - Datamine not yet uploaded
  → Automatically add and execute based on success count
    - 1 success → Datamine V1 (NetworkDataMineLootAll)
    - 2 successes → Datamine V2 (NetworkDataMineLootAdvanced)
    - 3+ successes → Datamine V3 (NetworkDataMineLootMaster)
```

**Important:** Datamine programs are NOT displayed during minigame. They are added POST-breach based on success count.

**Architecture:**

1. Pre-Breach Filtering:
   - Removes ALL Datamine programs from minigame display
   - Only active when `AutoDatamineBySuccessCount = true`
   - Removes: DatamineV1, DatamineV2, DatamineV3

2. Post-Breach Addition:
   - Adds appropriate Datamine based on success count
   - Counts non-Datamine daemons
   - Adds only ONE Datamine variant matching success level

**Setting Effects:**
```
AutoDatamineBySuccessCount = true (default):
  - Pre-Breach: ALL Datamine programs filtered (not visible)
  - Post-Breach: ONE Datamine auto-added based on success count
    - 1 daemon → DatamineV1
    - 2 daemons → DatamineV2
    - 3+ daemons → DatamineV3

AutoDatamineBySuccessCount = false:
  - Pre-Breach: Datamine programs visible (vanilla behavior)
  - Post-Breach: No auto-add
  - Player manually selects Datamine during minigame
```

### Breach Failure Penalties

```
Condition: BreachFailurePenaltyEnabled = true AND state == HackingMinigameState.Failed
Operation:
  - Breach minigame fails (timeout or ESC skip)
  - Both treated as "Failed" (no differentiation)
  → Apply full failure penalty
```

**Penalties Applied (All "Failed" States):**

1. **Red VFX (Visual Feedback)**
   - Effect: Red glitch screen effect (`disabling_connectivity_glitch_red`)
   - Duration: 2-3 seconds
   - Purpose: Clear failure feedback to player

2. **RemoteBreach Lock Recording**
   - Scope: Hybrid locking (network hierarchy + radial scan)
   - Duration: 10 minutes (default, configurable via `BreachPenaltyDurationMinutes`)
   - Target: Only affects RemoteBreach actions (no effect on AP Breach, Unconscious NPC Breach)
   - Persistence: Timestamp stored on device PS

   **Lock Logic:**
   ```
   Device RemoteBreach failure
     ↓
   Phase 1: Lock failed device itself
   Phase 2: Lock entire connected network (via GetNetworkDevices, no distance limit)
   Phase 3: Lock standalone/network devices in radius (configurable, default 25m)
   Phase 3B: Lock vehicles in radius (configurable, default 25m)
     ↓
   Device RemoteBreach attempt
     ↓
   Check device timestamp
     ├─ Timestamp > 0 AND (currentTime - timestamp) <= lockDuration
     └─ → Remove RemoteBreach actions from QuickHack menu
   ```

3. **Position Reveal Trace (Optional, TracePositionOverhaul Integration)**
   - Effect: Nearest netrunner NPC initiates 60-second upload trace
   - Condition: TracePositionOverhaul MOD installed
   - Range: Within 100m of failure position, real netrunner NPC exists
   - Purpose: Failure detected by enemy netrunner

**Coverage:**
- AP Breach: Covered via minigame wrapper
- Unconscious NPC Breach: Covered via action completion
- Remote Breach: Covered via program execution

**Skip vs Failure:**
- Currently: Both ESC skip and timeout treated as `HackingMinigameState.Failed`
- No differentiation: All Failed states receive full penalty
- Rationale: HackingMinigameState enum has no "Skipped" state, TimerLeftPercent unreliable

**Debug Logging:**
When `EnableDebugLog = true`, the following logs are output:
- `Phase 1: Locked failed device: <EntityID>`
- `Locked X devices (Network: Y [connected network], Standalone: Z [Rm], Vehicles: W [Rm])`
- `Red VFX applied (2-3 seconds)`
- `Trace triggered at nearest netrunner: NPC_ID` (if TracePositionOverhaul)

---

### Network Unlock

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Unlock Range** | Entire network | Entire network | Entire network + Nearby standalone devices |
| **Subnet Progression** | ✅ Individual management of Turret/Camera/NPC subnets | ✅ Same | ✅ Same |
| **Breached State Sharing** | ✅ | ✅ | ✅ |
| **Nearby Device Unlock** | ❌ | ❌ | ✅ Auto-unlock standalone devices within 50m |

**Shared Flags:**
- `m_betterNetrunningBreachedBasic`
- `m_betterNetrunningBreachedCameras`
- `m_betterNetrunningBreachedTurrets`
- `m_betterNetrunningBreachedNPCs`

**Remote Breach Enhancement:**

After Remote Breach success, nearby standalone devices are automatically unlocked:

```
Main logic:
  ├─ UnlockNearbyStandaloneDevices() - Main logic
  ├─ FindNearbyDevices() - Search within 50m radius
  ├─ UnlockStandaloneDevices() - Filter standalone + unlock
  └─ UnlockSingleDevice() - Device-type-specific unlock
```

**Unlock Criteria:**
- Device within 50m radius of breach position
- No AccessPoints (standalone device)
- Device type determines breach flag:
  - Camera → `m_betterNetrunningBreachedCameras`
  - Turret → `m_betterNetrunningBreachedTurrets`
  - Other → `m_betterNetrunningBreachedBasic`

**Important:** AP Breach, Remote Breach, and Unconscious NPC Breach share the same network's breached state

---

## Settings Control

### Settings Architecture

Better Netrunning uses a hybrid configuration system combining **CET Lua** (initialization, UI, persistence) and **REDscript** (runtime queries).

```
settings.json (JSON file)
     ↕ (Load/Save)
CET Settings Manager (Runtime)
     ↕ (Override)
BetterNetrunningSettings.* (REDscript static functions)
     ↕ (Query)
REDscript Game Logic
```

**Settings Categories (12 total):**
1. Controls - Breaching hotkey configuration
2. Breaching - Classic mode, Unconscious NPC breach toggle
3. RemoteBreach - Device-specific toggles, RAM cost
4. BreachPenalty - Failure penalties, RemoteBreach lock duration
5. AccessPoints - Auto-datamine, Auto-ping, Daemon visibility
6. RemovedQuickhacks - Block camera/turret disable quickhacks
7. UnlockedQuickhacks - Always-available quickhacks (Ping, Whistle, Distract)
8. Progression - Requirement toggles (Cyberdeck, Intelligence, Rarity)
9. ProgressionCyberdeck - Cyberdeck tier requirements per subnet
10. ProgressionIntelligence - Intelligence level requirements per subnet
11. ProgressionEnemyRarity - Enemy rarity requirements per subnet
12. Debug - Debug logging toggle

**Total Settings:** 76 configuration options

### Settings Affecting Each Breach Type

| Setting | AP Breach | Unconscious NPC Breach | Remote Breach | Default Value |
|---------|-----------|------------------------|---------------|---------------|
| **EnableClassicMode** | ✅ No injection when Classic enabled | ✅ Same | ✅ Same | `false` |
| **AllowBreachingUnconsciousNPCs** | ❌ | ✅ Disable with false | ❌ | `true` |
| **UnlockIfNoAccessPoint** | ✅ RadialBreach enabled with false | ✅ Affects activation conditions | ✅ Enabled with false | `false` |
| **RadialUnlockCrossNetwork** | ✅ Control cross-network unlock | ✅ Same | ✅ Same | `true` |
| **AutoDatamineBySuccessCount** | ✅ Remove Datamine + auto-add with true | ✅ Same | ✅ Same | `true` |
| **AutoExecutePingOnSuccess** | ✅ Auto-add PING with true | ✅ Same | ✅ Same | `true` |
| **RemoteBreachEnabledComputer** | ❌ | ❌ | ✅ Control Computer Device RemoteBreach | `false` |
| **RemoteBreachEnabledCamera** | ❌ | ❌ | ✅ Control Camera Device RemoteBreach | `true` |
| **RemoteBreachEnabledTurret** | ❌ | ❌ | ✅ Control Turret Device RemoteBreach | `true` |
| **RemoteBreachEnabledDevice** | ❌ | ❌ | ✅ Control non-Computer/Camera/Turret Device RemoteBreach | `true` |
| **RemoteBreachEnabledVehicle** | ❌ | ❌ | ✅ Control Vehicle RemoteBreach | `true` |
| **RemoteBreachRAMCostPercent** | ❌ | ❌ | ✅ Control RAM cost | `50` |
| **BreachFailurePenaltyEnabled** | ✅ Apply penalties on failure | ✅ Same | ✅ Same | `true` |
| **APBreachFailurePenaltyEnabled** | ✅ Enable/disable AP Breach penalties | ❌ | ❌ | `true` |
| **NPCBreachFailurePenaltyEnabled** | ❌ | ✅ Enable/disable NPC Breach penalties | ❌ | `true` |
| **RemoteBreachFailurePenaltyEnabled** | ❌ | ❌ | ✅ Enable/disable RemoteBreach penalties | `true` |
| **BreachPenaltyDurationMinutes** | ✅ Lock duration (all breach types) | ✅ Same | ✅ Same | `10` |

### Detailed Settings Explanation

#### EnableClassicMode
```
false (default): Progressive Mode
  - Better Netrunning's daemon injection system enabled
  - Subnet progression system enabled

true: Classic Mode
  - Vanilla behavior
  - No Better Netrunning injection
```

#### AllowBreachingUnconsciousNPCs
```
true (default): Unconscious NPC Breach enabled
false: Unconscious NPC Breach disabled
```

#### UnlockIfNoAccessPoint
```
false (default): RadialUnlock Mode enabled
  - RadialBreach: Enabled (physical range-based)
  - RemoteBreach: Enabled
  - Standalone devices: Breach required

true: RadialUnlock Mode disabled
  - RadialBreach: Disabled
  - RemoteBreach: Disabled
  - Standalone devices: Auto-unlock
```

#### RadialUnlockCrossNetwork
```
true (default): Cross-network unlock enabled
  - Radial breach unlocks ALL devices/NPCs within 50m radius
  - Ignores network boundaries
  - Unlocks standalone targets regardless of network connection

false: Network-restricted unlock
  - Radial breach only unlocks standalone targets (no network connection)
  - Devices with DeviceLink or network connection are excluded
  - NPCs with DeviceLink are excluded
```

**Purpose:** Controls whether radial breach respects network boundaries

**Affects:**
- Device unlock during radial breach
- NPC unlock during radial breach
- Network topology enforcement

#### AutoDatamineBySuccessCount
```
true (default):
  All breach types:
    - During minigame: Datamine programs NOT visible (not defined in TweakDB)
    - After breach success: Auto-add based on daemon success count
      * 1 success → Datamine V1
      * 2 successes → Datamine V2
      * 3+ successes → Datamine V3

false:
  - During minigame: Datamine programs NOT visible (not defined in TweakDB)
  - After breach success: No auto-add

Note: Datamine is NEVER displayed during minigame regardless of this setting.
      This setting only controls POST-breach auto-add behavior.
```

#### AutoExecutePingOnSuccess

```
true (default):
  All breach types:
    - On daemon success: Auto-add and execute PING

false:
  - No auto-add
```

#### BreachFailurePenaltyEnabled

```
true (default):
  All breach types:
    - On minigame failure (timeout or ESC skip):
      1. Red VFX (2-3 seconds)
      2. RemoteBreach Lock (10 minutes default)
      3. Position Reveal Trace (optional, TracePositionOverhaul MOD)

false:
  - No penalties applied on failure
  - Minigame failure has no consequences
```

**See Also:** [Breach Failure Penalties](#breach-failure-penalties) section for detailed mechanics and penalty system

#### APBreachFailurePenaltyEnabled

```
true (default):
  AP Breach:
    - Apply all penalties on failure (Red VFX, RemoteBreach Lock, Trace)

false:
  AP Breach:
    - No penalties applied on failure
```

**Note:** Works in conjunction with `BreachFailurePenaltyEnabled` (both must be true for penalties to apply)

#### NPCBreachFailurePenaltyEnabled

```
true (default):
  Unconscious NPC Breach:
    - Apply all penalties on failure (Red VFX, RemoteBreach Lock, Trace)

false:
  Unconscious NPC Breach:
    - No penalties applied on failure
```

**Note:** Works in conjunction with `BreachFailurePenaltyEnabled` (both must be true for penalties to apply)

#### RemoteBreachFailurePenaltyEnabled

```
true (default):
  Remote Breach:
    - Apply all penalties on failure (Red VFX, RemoteBreach Lock, Trace)

false:
  Remote Breach:
    - No penalties applied on failure
```

**Note:** Works in conjunction with `BreachFailurePenaltyEnabled` (both must be true for penalties to apply)

#### BreachPenaltyDurationMinutes

```
Range: 1-60 minutes
Default: 10 minutes

Controls how long devices remain locked after breach failure (all breach types).
Applies to RemoteBreach lock duration.
```

**Lock Mechanism:**
- Timestamp stored on device PS (`m_betterNetrunningRemoteBreachFailedTimestamp`)
- Checked when attempting RemoteBreach QuickHack
- If `(currentTime - timestamp) <= lockDuration`, RemoteBreach actions removed from menu

**Related Settings:**
- Works with `BreachFailurePenaltyEnabled` (must be true for locking to occur)
- Radial scan range configurable via RadialBreach MOD settings (10-50m, default 25m)

#### (Deprecated Setting: AllowAllDaemonsOnAccessPoints)

**Note:** This setting was removed in maintenance refactoring due to:
- Default `false` = minimal user impact
- Warning text ("bugs possible, enable at own risk")
- Bypassed in Remote Breach (main feature)
- Unclear purpose

**Previous behavior (deprecated):**
```
false (default):
  AP Breach / Unconscious NPC Breach:
    - AccessPoint type programs: Displayed (Shard, Materials, Money, Quest-specific)
    - Non-AccessPoint type programs: Removed (except Subnet type programs)
    - Subnet type programs: Always displayed

  Remote Breach:
    - Filter was bypassed (isRemoteBreach = true)
    - All programs were Subnet type, so no practical effect

true:
  AP Breach / Unconscious NPC Breach:
    - All programs: Displayed (including AccessPoint and non-AccessPoint types)
    - Subnet type programs: Always displayed

  Remote Breach:
    - No change (already all displayed)
```
```

---

## Processing Flow Comparison

### AP Breach

```
1. AccessPoint Interaction
   ↓
2. NetworkBlackboard Setup
   - RemoteBreach = false
   - OfficerBreach = false
   ↓
3. InjectBetterNetrunningPrograms()
   - isAccessPoint = true
   - Inject Turret/Camera/NPC/Basic
   ↓
4. FilterPlayerPrograms()
   ├─ Already breached filter
   ├─ Network connection filter
   ├─ Backdoor filter (skip)
   ├─ AccessPoint type program filter
   │   └─ AutoDatamineBySuccessCount = true → Remove V1/V2/V3
   ├─ Non-AccessPoint type program filter (deprecated, removed)
   ├─ Non-Netrunner NPC filter (skip)
   └─ Device type filter
       └─ Check network device existence
   ↓
5. RadialBreach.FilterPlayerPrograms()
   └─ UnlockIfNoAccessPoint = false
       → Re-add only devices within physical range
   ↓
6. Start Minigame (standard timer)
   ↓
7. Player Operation (daemon upload)
   ↓
8. Breach Success
   ↓
9. BonusDaemonUtils.ApplyBonusDaemons()
   ├─ AutoExecutePingOnSuccess = true → Add PING
   └─ AutoDatamineBySuccessCount = true → Add Datamine V1/V2/V3
   ↓
10. Network Unlock
```

---

### Unconscious NPC Breach (Regular NPC)

```
1. Unconscious NPC Interaction
   ↓
2. Activation Condition Check
   - AllowBreachingUnconsciousNPCs = true
   - IsConnectedToAccessPoint() = true
   - RadialUnlock Mode enabled OR physical AP connection
   - Not directly breached
   ↓
3. NetworkBlackboard Setup
   - RemoteBreach = false
   - OfficerBreach = true
   ↓
4. InjectBetterNetrunningPrograms()
   - isUnconsciousNPC = true
   - isNetrunner = false
   - Inject NPC/Basic only
   ↓
5. FilterPlayerPrograms()
   ├─ Already breached filter
   ├─ Network connection filter
   ├─ Backdoor filter (skip)
   ├─ AccessPoint type program filter
   │   └─ AutoDatamineBySuccessCount = true → Remove V1/V2/V3
   ├─ Non-AccessPoint type program filter (deprecated, removed)
   ├─ Non-Netrunner NPC filter (skip)
   └─ Device type filter
       └─ Check network device existence
   ↓
6. RadialBreach.FilterPlayerPrograms()
   └─ UnlockIfNoAccessPoint = false
       → Re-add only devices within physical range
   ↓
7. Start Minigame (timer increase: timerNotRemoteMultiplier)
   ↓
8. Player Operation (daemon upload)
   ↓
9. Breach Success
   ↓
10. BonusDaemonUtils.ApplyBonusDaemons()
   ├─ AutoExecutePingOnSuccess = true → Add PING
   └─ AutoDatamineBySuccessCount = true → Add Datamine V1/V2/V3
   ↓
11. Network Unlock
```

---

### Remote Breach (Device)

```
1. RemoteBreach Quickhack on Device
   ↓
2. Activation Condition Check (setting branches by device type)
   - Computer: RemoteBreachEnabledComputer = true
   - Camera: RemoteBreachEnabledCamera = true
   - Turret: RemoteBreachEnabledTurret = true
   - Other: RemoteBreachEnabledDevice = true
   - RadialUnlock Mode enabled (UnlockIfNoAccessPoint = false)
   - Target connected to network
   - Not breached
   ↓
3. CET Remote Breach Registration
   - Register static program list to TweakDB
   ↓
4. NetworkBlackboard Setup
   - RemoteBreach = true
   - OfficerBreach = false
   ↓
5. InjectBetterNetrunningPrograms()
   - Determine daemon injection pattern by device type detection
   - Inject Turret/Camera/NPC/Basic
   ↓
6. FilterPlayerPrograms()
   ├─ Already breached filter
   ├─ Network connection filter
   ├─ Backdoor filter (skip)
   ├─ AccessPoint type program filter
   │   └─ AutoDatamineBySuccessCount = true → Remove V1/V2/V3
   ├─ Non-AccessPoint type program filter (skip)
   │   └─ isRemoteBreach = true → Always display all
   ├─ Non-Netrunner NPC filter (skip - Computer target)
   └─ Device type filter
       └─ Check network device existence
   ↓
7. RadialBreach.FilterPlayerPrograms()
   └─ isRemoteBreach = true → Early return (skip)
   ↓
8. Start Minigame (standard timer)
   ↓
9. Player Operation (daemon upload)
   ↓
10. Breach Success
   ↓
11. BonusDaemonUtils.ApplyBonusDaemons()
   ├─ AutoExecutePingOnSuccess = true → Add PING
   └─ AutoDatamineBySuccessCount = true → Add Datamine V1/V2/V3
   ↓
12. Network Unlock
```

---

## Processing Timing Details

### Filter Processing Stages

Better Netrunning Mod filters programs at **three stages**:

#### Stage 1: Injection-time Control
```
Timing: When injecting programs into network
Control:
  - Backdoor device detection
  - Device type availability check
  - Breach point type detection
Purpose: Optimize injected daemons, minimize filtering overhead
```

#### Stage 2: Filter-time Control
```
Timing: Before minigame start (after vanilla wrappedMethod)
Control:
  1. Already breached daemon removal (ShouldRemoveBreachedPrograms)
  2. Network connectivity filter (ShouldRemoveNetworkPrograms)
  3. Backdoor device restrictions (ShouldRemoveDeviceBackdoorPrograms)
  4. Non-AccessPoint type program filter (ShouldRemoveAccessPointPrograms)
  5. Non-netrunner NPC restrictions (ShouldRemoveNonNetrunnerPrograms)
  6. Device type availability filter (ShouldRemoveDeviceTypePrograms)
Purpose: Filter based on user settings, network state, and breach state
```

#### Stage 3: RadialBreach Control
```
Timing: Before minigame start (after Stage 2)
Control:
  - Physical range-based filtering
  - Re-add only devices within physical range
Purpose: Control based on physical distance (UnlockIfNoAccessPoint setting)
```

---

## Key Functional Differences Summary

### 1. Activation Conditions

| Breach Type | Requirement | Special Conditions |
|-------------|-------------|-------------------|
| **AP Breach** | AccessPoint entity | None |
| **Unconscious NPC Breach** | Unconscious NPC + Network connection (relaxed) | `AllowBreachingUnconsciousNPCs = true`<br>RadialUnlock Mode enabled |
| **Remote Breach** | Any scannable device (network relaxed) | Device-specific RemoteBreachEnabled settings<br>RadialUnlock Mode enabled<br>Network access relaxation provides universal access |

**Network Access Relaxation:**
- Removes network topology restrictions
- Connection check always returns true for standalone devices
- Network backdoor check always returns true for all devices
- This enables RemoteBreach and QuickHack access regardless of AP connection

---

### 2. Daemon Injection Patterns

| Breach Type | Turret Subnet | Camera Subnet | NPC Subnet | Basic Subnet |
|-------------|--------------|--------------|-----------|-------------|
| **AP Breach** | ✅ | ✅ | ✅ | ✅ |
| **Unconscious NPC (Regular)** | ❌ | ❌ | ✅ | ✅ |
| **Unconscious NPC (Netrunner)** | ✅ | ✅ | ✅ | ✅ |
| **Remote (Computer)** | ❌ | ✅ | ❌ | ✅ |
| **Remote (Camera)** | ❌ | ✅ | ❌ | ✅ |
| **Remote (Turret)** | ✅ | ❌ | ❌ | ✅ |
| **Remote (Terminal)** | ❌ | ❌ | ✅ | ✅ |
| **Remote (Other Device)** | ❌ | ❌ | ❌ | ✅ |
| **Remote (Vehicle)** | ❌ | ❌ | ❌ | ✅ |

---

### 3. Filter Application

| Filter Type | AP Breach | Unconscious NPC Breach | Remote Breach |
|------------|-----------|------------------------|---------------|
| **Already-Breached Filter** | ✅ Applied | ✅ Applied | ✅ Applied |
| **Network Connectivity Filter** | ✅ Applied | ✅ Applied | ✅ Applied |
| **Backdoor Device Filter** | ✅ Applied | ✅ Applied | ✅ Applied |
| **Non-AccessPoint Program Filter** | ✅ Applied | ✅ Applied | ❌ Skipped |
| **Non-Netrunner NPC Filter** | ❌ N/A | ⚠️ Applied (if remote) | ⚠️ Applied (if NPC target) |
| **Device Type Filter** | ✅ Applied | ✅ Applied | ✅ Applied |
| **RadialBreach Physical Range Filter** | ✅ Applied | ✅ Applied | ❌ Skipped (except Netrunner NPC) |

**Note on Datamine:** Datamine programs are NOT filtered because they are NOT present during minigame. They are added POST-breach by bonus daemon utilities.

---

### 4. Minigame Parameters

| Parameter | AP Breach | Unconscious NPC Breach | Remote Breach |
|-----------|-----------|------------------------|---------------|
| **Timer** | 1.0x | **1.5x** | 1.0x |
| **RAM Cost** | ❌ None | ❌ None | ✅ Yes (35% default) |
| **Configuration Source** | NetworkTDBID | Character Record | TweakDB (CET Registration) |

---

### 5. Post-Breach Processing

All breach types support:
- ✅ Auto PING (`AutoExecutePingOnSuccess = true`)
- ✅ Auto Datamine (`AutoDatamineBySuccessCount = true`)
- ✅ Network unlock
- ✅ Breached state sharing

**Remote Breach Enhancement:**
- ✅ Auto-unlock nearby standalone devices within 50m radius
- ✅ Device-type-specific breach flag assignment
- ✅ Integration with RadialUnlock system

**Design:**
- Extract Method pattern with shallow nesting
- Nesting depth: Maximum 3 levels
- Modular design: 4 separate helper methods for maintainability

---

## Statistics Collection System

### Overview

**Purpose:** Replace scattered debug logs with comprehensive structured statistics output

**Integration Status:**
- ✅ AP Breach: Fully integrated
- ✅ Remote Breach: Fully integrated
- ✅ Unconscious NPC Breach: Fully integrated

**Components:**
- Data collection
- Formatting & output with emoji icons
- Minigame display tracking

### DisplayedDaemonsStateSystem

**Purpose:** Track daemons displayed in minigame vs daemons successfully executed

**Problem Solved:**
- ActivePrograms array only contains successfully executed daemons (available after minigame completion)
- No way to distinguish "displayed in minigame" vs "successfully executed"
- Statistics collection needed both sets for accurate reporting

**Data Flow:**

```
FilterPlayerPrograms
  ↓ Step 1-6: Filter programs
  ↓ Step 7: Store displayed daemons
DisplayedDaemonsStateSystem.SetDisplayedDaemons()
  ↓ Minigame executes
  ↓ Success/Failure
RefreshSlaves
  ├─ GetDisplayedDaemons() → CollectDisplayedDaemons()
  └─ ActivePrograms → CollectExecutedDaemons()
     ↓
BreachSessionStats (complete statistics)
  ↓
LogBreachSummary() (formatted output)
```

**Timing Guarantee:**
1. **FilterPlayerPrograms end:** Displayed daemons recorded
2. **Minigame completion:** Executed daemons available in ActivePrograms
3. **RefreshSlaves execution:** Both datasets available for statistics

**Usage Pattern:**

```redscript
// Retrieve displayed daemons from state system
let stateSystem: ref<DisplayedDaemonsStateSystem> = ...;
let displayedDaemons: array<TweakDBID> = stateSystem.GetDisplayedDaemons();

// Collect both datasets
BreachStatisticsCollector.CollectDisplayedDaemons(displayedDaemons, stats);
BreachStatisticsCollector.CollectExecutedDaemons(activePrograms, stats);
```

**Benefits:**
- ✅ Accurate "displayed vs executed" distinction
- ✅ No timing dependencies on ActivePrograms
- ✅ Single source of truth for displayed daemons
- ✅ Clean separation of concerns

### BreachSessionStats Structure (DTO)

**Field Categories (20+ fields):**

```redscript
public class BreachSessionStats {
  // 1. Basic Information
  public let breachType: String;           // "AccessPoint" / "RemoteBreach" / "UnconsciousNPC"
  public let breachTarget: String;         // Target device/NPC name
  public let timestamp: String;            // Start time (YYYY-MM-DD HH:MM:SS)

  // 2. Minigame Phase
  public let programsInjected: Int32;      // Bonus daemons added (PING, Datamine)
  public let minigameSuccess: Bool;        // Minigame result (success/failure)

  // 3. Unlock Flags
  public let unlockBasic: Bool;            // Basic subnet unlocked
  public let unlockCameras: Bool;          // Camera subnet unlocked
  public let unlockTurrets: Bool;          // Turret subnet unlocked
  public let unlockNPCs: Bool;             // NPC subnet unlocked

  // 4. Network Results
  public let networkDeviceCount: Int32;    // Total devices in network
  public let devicesUnlocked: Int32;       // Successfully unlocked count
  public let devicesSkipped: Int32;        // Skipped (no unlock flag) count

  // 5. Device Breakdown
  public let cameraCount: Int32;           // Camera devices
  public let turretCount: Int32;           // Turret devices
  public let npcCount: Int32;              // NPC devices
  public let doorCount: Int32;             // Door devices
  public let terminalCount: Int32;         // Terminal devices
  public let otherCount: Int32;            // Other devices

  // 6. Radial Breach (optional)
  public let radialBreachUsed: Bool;       // RadialBreach MOD detected
  public let radialBreachDistance: Float;  // Distance from breach point (meters)

  // 7. Performance
  public let processingTimeMs: Float;      // Auto-calculated in Finalize()
}
```

### Collection Pattern

```
┌─ CREATE ─────────────────────────────────────────────────┐
│ RefreshSlaves() {                                         │
│   let stats = BreachSessionStats.Create("AccessPoint",   │
│       this.GetDeviceName());                              │
│   // Initialize timestamp, breach type, target name      │
│ }                                                         │
└──────────────────────────────────────────────────────────┘
                      ▼
┌─ COLLECT (Phase 1: Minigame) ───────────────────────────┐
│ InjectBonusDaemons() {                                    │
│   let programCountBefore = ArraySize(minigamePrograms);  │
│   // ... add PING, Datamine ...                          │
│   stats.programsInjected = ArraySize(programs) - before; │
│ }                                                         │
│                                                           │
│ ExtractUnlockFlags() {                                    │
│   stats.unlockBasic = hasBasicDaemon;                    │
│   stats.unlockCameras = hasCameraDaemon;                 │
│   stats.unlockTurrets = hasTurretDaemon;                 │
│   stats.unlockNPCs = hasNPCDaemon;                       │
│ }                                                         │
│                                                           │
│ stats.minigameSuccess = true;                            │
└──────────────────────────────────────────────────────────┘
                      ▼
┌─ COLLECT (Phase 2: Network Unlock) ──────────────────────┐
│ ApplyBreachUnlockToDevices(devices, unlockFlags, stats)  │
│ {                                                         │
│   Deref(stats).networkDeviceCount = ArraySize(devices);  │
│                                                           │
│   for device in devices {                                │
│     ProcessSingleDeviceUnlock(device, unlockFlags,       │
│         stats);                                           │
│   }                                                       │
│ }                                                         │
│                                                           │
│ ProcessSingleDeviceUnlock(..., stats) {                  │
│   let deviceType = DeviceClassifier.GetDeviceType(...);  │
│                                                           │
│   // Increment device type counter                       │
│   switch deviceType {                                    │
│     case DeviceType.Camera:                              │
│       Deref(stats).cameraCount += 1;                     │
│     case DeviceType.Turret:                              │
│       Deref(stats).turretCount += 1;                     │
│     // ... other types ...                               │
│   }                                                       │
│                                                           │
│   // Track unlock results                                │
│   if shouldUnlock {                                      │
│     Deref(stats).devicesUnlocked += 1;                   │
│   } else {                                               │
│     Deref(stats).devicesSkipped += 1;                    │
│   }                                                       │
│ }                                                         │
└──────────────────────────────────────────────────────────┘
                      ▼
┌─ FINALIZE ───────────────────────────────────────────────┐
│ stats.Finalize();                                         │
│ // Calculate processingTimeMs = endTime - startTime      │
└──────────────────────────────────────────────────────────┘
                      ▼
┌─ OUTPUT ─────────────────────────────────────────────────┐
│ LogBreachSummary(stats);                                  │
│ // Formatted box-drawing output (see below)             │
└──────────────────────────────────────────────────────────┘
```

---

## Related Documents

- `ARCHITECTURE_DESIGN.md` - Better Netrunning overall architecture (Version 2.5)
- Source modules:
  - Devices/ - Network access, device unlock, QuickHack filters, remote actions
  - RadialUnlock/ - Network unlock with nearby device support
  - Logging/ - Auto PING/Datamine, statistics collection, session logging, debug utilities
  - NPCs/ - Unconscious NPC breach
  - Minigame/ - Daemon injection, program filtering
  - Core/ - Timestamp utilities, event definitions
  - Utils/ - Breach lock utilities

---

**Last Updated:** 2025-11-02

