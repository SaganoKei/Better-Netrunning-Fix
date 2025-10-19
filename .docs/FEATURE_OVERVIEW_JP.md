# Better Netrunning - 機能概要ドキュメント

**最終更新日:** 2025年10月18日
**バージョン:** 2.0
**対象:** ユーザー・開発者向け総合ガイド

---

## 📋 目次

1. [概要](#概要)
2. [主要機能](#主要機能)
3. [ブリーチシステム](#ブリーチシステム)
4. [リモートブリーチ](#リモートブリーチ)
5. [プログレッシブサブネットシステム](#プログレッシブサブネットシステム)
6. [オートデーモンシステム](#オートデーモンシステム)
7. [RadialUnlockシステム](#radialunlockシステム)
8. [意識不明NPC ブリーチ](#意識不明npc-ブリーチ)
9. [デバイス種別制御](#デバイス種別制御)
10. [ネットワークアクセス緩和](#ネットワークアクセス緩和)
11. [デバッグロギングシステム](#デバッグロギングシステム)
12. [設定システム](#設定システム)
13. [必須要件・推奨環境](#必須要件推奨環境)
14. [MOD互換性](#mod互換性)

---

## 概要

### Better Netrunningとは

Better Netrunningは、Cyberpunk 2077のネットランニング体験を大幅に強化する包括的なMODです。段階的なサブネット解除、リモートブリーチ機能、詳細なデバイス制御を導入し、バニラのブリーチプロトコルを拡張します。

**オリジナル作者:** finley243
**Fix Project:** SaganoKei
**Nexus Mods:** [Better Netrunning – Hacking Reworked](https://www.nexusmods.com/cyberpunk2077/mods/2302)

### 設計思想

- **モジュール性:** 各機能が独立して動作し、他のMODとの互換性を最大化
- **段階的な成長:** プレイヤーの進行に応じてネットワークアクセスが拡大
- **プレイスタイルの尊重:** クラシックモードで旧バージョンのバニラ動作に戻すことが可能
- **パフォーマンス重視:** 最適化されたコードで最小限のパフォーマンス影響
- **デバッグ支援:** 5段階のログレベル、統計収集、重複抑制による効率的なデバッグ

### 技術スタック

- **言語:** REDscript (Cyberpunk 2077専用スクリプト言語)
- **必須フレームワーク:**
  - Red4ext
  - Redscript
  - CustomHackingSystem (HackingExtensions) - リモートブリーチ機能用
- **設定UI:** Native Settings UI (推奨)
- **ローカライゼーション:** WolvenKit JSON形式

---

## 主要機能

### 1. プログレッシブサブネットシステム
カメラ・タレット・NPCのサブネットを個別に解除可能。段階的にネットワークアクセスを拡大します。

### 2. リモートブリーチ
物理的なアクセスポイントなしでデバイスを直接ブリーチ。コンピュータ・カメラ・タレット・ターミナル・車両に対応。

### 3. オートデーモンシステム
ブリーチ成功回数に応じてPING・Datamineを自動実行。繰り返し作業を軽減します。

### 4. RadialUnlockシステム
50m半径内のスタンドアロンデバイスを自動追跡・解除。物理的な距離に基づいたリアルなブリーチ体験。

### 5. 意識不明NPCブリーチ
意識不明のNPCに対して直接ブリーチを実行可能。ネットランナーNPCは完全なネットワークアクセスを提供。

### 6. デバイス種別制御
各デバイスタイプ（コンピュータ・カメラ・タレット・車両等）ごとにリモートブリーチの有効/無効を個別設定可能。

### 7. ネットワークアクセス緩和
ドアのクイックハックメニュー表示制限を解除。スタンドアロンデバイスでもリモートブリーチが可能。

### 8. デバッグロギングシステム
5段階のログレベル、重複抑制、統計収集による効率的なデバッグ環境を提供。詳細は[デバッグロギングシステム](#デバッグロギングシステム)を参照。

---

## ブリーチシステム

Better Netrunningは3種類のブリーチタイプをサポートしています。

### ブリーチタイプ比較表

| 項目 | APブリーチ | 意識不明NPCブリーチ | リモートブリーチ |
|------|-----------|-------------------|----------------|
| **起動方法** | アクセスポイント操作 | 意識不明NPCに「Breach Unconscious Officer」 | デバイスへのクイックハック |
| **対象エンティティ** | AccessPoint | ScriptedPuppet (意識不明) | Computer/Camera/Turret/Terminal/Device/Vehicle |
| **ネットワーク要件** | ❌ 不要 (AP自体がハブ) | ✅ 必要 (緩和機能で常にtrue) | ⚠️ 緩和 (スタンドアロンも可能) |
| **デーモン注入** | Turret + Camera + NPC + Basic | 通常NPC: NPC + Basic<br>ネットランナーNPC: 全種類 | デバイス種別依存 |
| **ネットワーク解除** | ✅ 完全なネットワーク解除 | ✅ 完全なネットワーク解除 | ✅ 完全なネットワーク解除 |
| **統計収集** | ✅ 実装済み | ✅ 実装済み | ✅ 実装済み |

### デーモン注入ルール

各ブリーチポイントタイプによって利用可能なデーモンが決定されます：

| ブリーチポイント | 注入されるデーモン | 説明 |
|----------------|------------------|------|
| **アクセスポイント** | Turret + Camera + NPC + Basic | 完全なネットワークアクセス |
| **コンピュータ** | Camera + Basic | 制限付きネットワークアクセス |
| **バックドアデバイス** | Camera + Basic | カメラサブネットと基本機能のみ |
| **意識不明NPC (通常)** | NPC + Basic | 制限付きアクセス |
| **意識不明NPC (ネットランナー)** | Turret + Camera + NPC + Basic | 完全なネットワークアクセス |
| **リモートブリーチ (コンピュータ)** | Camera + Basic | デバイス固有のデーモン |
| **リモートブリーチ (カメラ)** | Camera + Basic | デバイス固有のデーモン |
| **リモートブリーチ (タレット)** | Turret + Basic | デバイス固有のデーモン |
| **リモートブリーチ (ターミナル)** | NPC + Basic | デバイス固有のデーモン |
| **リモートブリーチ (その他)** | Basic only | 最小限のアクセス |
| **リモートブリーチ (車両)** | Basic only | 最小限のアクセス |

### フィルタリングパイプライン

ブリーチ時のデーモンは以下の3段階でフィルタリングされます：

```
1. ProgramInjection (注入時制御)
   ├─ ブリーチポイントタイプ検出
   ├─ デバイスタイプ利用可能性チェック
   └─ プログレッシブ解除状態チェック

2. ProgramFiltering (フィルター時制御)
   ├─ すでにブリーチ済みのデーモンを除外
   ├─ ネットワーク接続性フィルター
   ├─ バックドアデバイス制限
   ├─ 非アクセスポイントタイプのプログラム除外
   ├─ 非ネットランナーNPC制限
   ├─ デバイスタイプ利用可能性
   └─ Datamine自動追加フィルター

3. RadialBreach (物理範囲制御)
   └─ 50m半径内のデバイスのみ再追加
```

---

## リモートブリーチ

### 概要

**目的:** 物理的なアクセスポイントなしでデバイスを直接ブリーチ可能にする

**重要な依存関係:** リモートブリーチ機能には **CustomHackingSystem (HackingExtensions MOD)** が必須です。このMODがインストールされていない場合、リモートブリーチ関連のコードはコンパイルされません。

### サポートデバイス

| デバイスタイプ | 対応 | 注入デーモン | 説明 |
|--------------|------|-------------|------|
| **コンピュータ** | ✅ | Camera + Basic | カメラサブネット + 基本機能 |
| **カメラ** | ✅ | Camera + Basic | カメラサブネット + 基本機能 |
| **タレット** | ✅ | Turret + Basic | タレットサブネット + 基本機能 |
| **ターミナル** | ✅ | NPC + Basic | NPCサブネット + 基本機能 |
| **車両** | ✅ | Basic only | 基本機能のみ |
| **その他デバイス** | ✅ | Basic only | 基本機能のみ |

### リモートブリーチの起動条件

```
✅ CustomHackingSystem (HackingExtensions) がインストール済み
✅ デバイス種別のRemoteBreachEnabledが有効
✅ UnlockIfNoAccessPoint = false (自動解除モードではない)
✅ 対象デバイスが有効な状態
```

### 可視性制御（二層防御）

リモートブリーチの表示は2段階でチェックされます：

**1. 予防層 (RemoteBreach/UI/RemoteBreachVisibility.reds)**
```redscript
// TryAddCustomRemoteBreach()
if !RemoteBreachEnabled { return; }              // 設定で無効
if UnlockIfNoAccessPoint = true { return; }       // 自動解除モード
```

**2. 実行層 (RemoteBreach/Actions/RemoteBreachAction_*.reds)**
```redscript
// GetQuickHackActions()
if !RemoteBreachEnabledForDeviceType { return; }  // デバイス種別設定
if UnlockIfNoAccessPoint = true { return; }       // 自動解除モード (OR条件)
```

### リモートブリーチの動作フロー

```
1. プレイヤーがデバイスにクイックハックメニューを開く
   └─ RemoteBreach/UI/RemoteBreachVisibility.reds が可視性チェック

2. プレイヤーが「Remote Breach」を選択
   └─ RemoteBreach/Actions/RemoteBreachAction_*.reds が実行権限チェック

3. ミニゲーム開始
   ├─ デバイス種別に応じたデーモン注入
   ├─ フィルタリングパイプライン適用
   └─ ミニゲームUI表示

4. ミニゲーム成功
   ├─ ネットワーク内のデバイス解除
   ├─ プログレッシブフラグ更新
   └─ RadialUnlock位置記録

5. ブリーチ完了
   └─ 解除されたデバイスでクイックハック使用可能
```

### デバイス固有のデーモン実装

リモートブリーチでは8種類のデーモンが登録されています：

**デバイス用デーモン (4種類):**
1. `Device_Daemon_Basic` - 基本機能
2. `Device_Daemon_Camera` - カメラサブネット
3. `Device_Daemon_Turret` - タレットサブネット
4. `Device_Daemon_NPC` - NPCサブネット

**車両用デーモン (4種類):**
1. `Vehicle_Daemon_Basic` - 基本機能
2. `Vehicle_Daemon_Camera` - カメラサブネット (車両版)
3. `Vehicle_Daemon_Turret` - タレットサブネット (車両版)
4. `Vehicle_Daemon_NPC` - NPCサブネット (車両版)

**実装ファイル:**
- `RemoteBreach/Core/DaemonRegistration.reds` - CustomHackingSystemへの登録
- `RemoteBreach/Core/DaemonImplementation.reds` - デーモン実行ロジック

---

## プログレッシブサブネットシステム

### 概要

バニラのCyberpunk 2077では、ブリーチプロトコルとクイックハックは独立した機能です。Better Netrunningでは、**ブリーチで成功したデーモン種別に応じて、特定デバイスタイプへのクイックハックを段階的に解除する**新機能を追加します。

### 仕組み

Better Netrunningが追加する専用デーモン：
- `UnlockQuickhacks` (Basic Daemon) - 基本デバイスへのクイックハックを解除
- `UnlockCameraQuickhacks` (Camera Daemon) - カメラへのクイックハックを解除
- `UnlockTurretQuickhacks` (Turret Daemon) - タレットへのクイックハックを解除
- `UnlockNPCQuickhacks` (NPC Daemon) - NPCへのクイックハックを解除

これらのデーモンをブリーチミニゲームで成功させることで、対応するデバイスタイプのクイックハックが使用可能になります。

### サブネット種別

| サブネット | 対象デバイス | 解除条件 |
|-----------|-------------|---------|
| **Basic** | ドア、エレベータ、自販機、ラジオ等 | 常に利用可能 |
| **Camera** | 監視カメラ | Camera Daemonの成功 |
| **Turret** | セキュリティタレット | Turret Daemonの成功 |
| **NPC** | NPC (ハッキング可能) | NPC Daemonの成功 |

### プログレッシブ解除の動作

#### 初回ブリーチ

```
[アクセスポイント発見]
  ↓
[ミニゲーム開始]
  ├─ 利用可能: Basic Daemon (常時)
  ├─ 利用可能: Camera Daemon (カメラあり)
  ├─ 利用可能: Turret Daemon (タレットあり)
  └─ 利用可能: NPC Daemon (NPCあり)
  ↓
[Basic Daemon成功]
  ↓
[解除結果]
  ✅ ドア、エレベータ等が解除
  ❌ カメラはまだロック (Camera Daemon未成功)
  ❌ タレットはまだロック (Turret Daemon未成功)
```

#### 二回目以降のブリーチ

```
[同じアクセスポイントに再度ブリーチ]
  ↓
[ミニゲーム開始]
  ├─ 除外: Basic Daemon (すでに成功済み)
  ├─ 利用可能: Camera Daemon
  ├─ 利用可能: Turret Daemon
  └─ 利用可能: NPC Daemon
  ↓
[Camera Daemon成功]
  ↓
[解除結果]
  ✅ カメラが解除
  ❌ タレットはまだロック
```

### 永続化メカニズム

プログレッシブ解除状態は **Persistent Fields** として保存されます：

**プログレッシブ解除フラグ (SharedGameplayPS):**
- `m_betterNetrunningBreachedBasic`: Basicサブネット解除状態
- `m_betterNetrunningBreachedCameras`: Cameraサブネット解除状態
- `m_betterNetrunningBreachedTurrets`: Turretサブネット解除状態
- `m_betterNetrunningBreachedNPCs`: NPCサブネット解除状態

**タイムスタンプフィールド (SharedGameplayPS):**
- `m_betterNetrunningUnlockTimestampBasic`: Basic解除時刻 (Float, 0.0=未解除/期限切れ)
- `m_betterNetrunningUnlockTimestampCameras`: Camera解除時刻
- `m_betterNetrunningUnlockTimestampTurrets`: Turret解除時刻
- `m_betterNetrunningUnlockTimestampNPCs`: NPC解除時刻

**その他の永続フィールド:**
- `m_betterNetrunningWasDirectlyBreached` (ScriptedPuppetPS): NPC直接ブリーチ済みフラグ
- `m_betterNetrunning_breachedAccessPointPositions` (PlayerPuppet): ブリーチ位置配列
- `m_betterNetrunning_breachTimestamps` (PlayerPuppet): ブリーチ時刻配列
- `m_betterNetrunning_remoteBreachFailedPositions` (PlayerPuppet): RemoteBreach失敗位置配列
- `m_betterNetrunning_remoteBreachFailedTimestamps` (PlayerPuppet): RemoteBreach失敗時刻配列

**Persistent Fieldsの特徴:**
- セーブデータに自動保存される
- ロード時に自動復元される
- ネットワーク全体で共有される (SetBreachedSubnetイベント経由)
- TimeUtils.SetDeviceUnlockTimestamp()で一元管理

### ネットワーク伝播

1つのデバイスでのブリーチ成功は、**ネットワーク全体に伝播**します。

**動作フロー:**
1. アクセスポイントでCamera Daemon成功
2. SetBreachedSubnetイベント送信 (breachedCameras = true)
3. ネットワーク内の全デバイスに伝播
4. 全カメラの`m_betterNetrunningBreachedCameras`フラグが`true`に設定
5. ネットワーク内の全カメラが解除状態になる

**利点:**
- 1回のブリーチで同種デバイス全てが解除
- ネットワークトポロジーに基づく論理的な伝播
- 再ブリーチ時に解除済みデーモンは表示されない

**実装ファイル:**
- `Core/Events.reds` - SetBreachedSubnetイベント定義、永続フィールド定義
- `Breach/Processing/BreachProcessing.reds` - ネットワーク解除ロジック、イベント送信
- `Core/TimeUtils.reds` - タイムスタンプ管理ユーティリティ

---

## オートデーモンシステム

### 概要

ブリーチの繰り返し作業を軽減するため、**成功回数に応じて自動的にPING・Datamineを実行**するシステムです。

### PING自動実行

**目的:** ネットワーク内のデバイスを自動的に検出

**動作条件:**
- AutoPingOnBreach = true
- ブリーチ成功
- ネットワーク接続あり

**実装:** BreachProcessing.redsがブリーチ成功時にExecutePingOnNetwork()を呼び出し、ネットワーク内の全デバイスを自動検出します。

### Datamine自動実行

**目的:** ブリーチ成功回数に応じてDatamineを自動追加・実行

**スケーリングルール:**

| 成功回数 | Datamine追加数 |
|---------|--------------|
| 1回成功 | +1 Datamine |
| 2回成功 | +2 Datamine |
| 3回成功 | +3 Datamine |
| 4回以上 | +4 Datamine |

**動作条件:**
- AutoDatamineBySuccessCount = true
- ブリーチミニゲーム成功
- 成功回数が1以上

**実装:** Minigame/ProgramFiltering.redsのAddDataminePrograms()がミニゲーム成功回数を取得し、成功回数に応じたDatamineプログラムを追加します（最大4個）。

### 設定による制御

**設定関数:**
- `AutoPingOnBreach()`: PING自動実行の有効/無効
- `AutoDatamineBySuccessCount()`: Datamine自動追加の有効/無効

**設定方法:** Native Settings UIから切り替え、またはsettings.jsonを直接編集。config.redsはフォールバック用のデフォルト値を提供します。

---

## RadialUnlockシステム

### 概要

**50m半径内のスタンドアロンデバイス**を自動的に追跡・解除するシステムです。物理的な距離に基づいたリアルなブリーチ体験を提供します。

### 動作モード

**UnlockIfNoAccessPoint = false の場合のみ有効**

このモードでは：
- ネットワーク接続がないデバイスは自動解除されない
- ただし、**50m半径内**であればブリーチ位置から範囲判定で解除可能
- RadialBreach MODと統合され、ユーザー設定の範囲を使用可能

### 範囲設定

**デフォルト:** 50m
**カスタマイズ:** RadialBreach MODインストール時、ユーザー設定値を使用

**実装:** DeviceTypeUtils.GetRadialBreachRange()が条件付きコンパイル(@if)でRadialBreachの存在をチェック。MODがある場合はRadialBreachSettings.breachRangeを返し、ない場合は50.0mをデフォルトで返します。

### ブリーチ位置の記録

**動作フロー:**
1. ブリーチ成功
2. RadialUnlockSystem.RecordBreachPosition()呼び出し
3. ブリーチ位置 (Vector4) を配列に記録
4. ブリーチ時刻 (Uint64) を配列に記録
5. 最大50件を超えた場合、古い記録を自動削除

**実装ファイル:**
- `RadialUnlock/Core/RadialUnlockSystem.reds` - 位置追跡システム (PlayerPuppet永続フィールド管理)
- `RadialUnlock/Integration/RadialBreachGating.reds` - RadialBreach MOD統合 (条件付きコンパイル)

### 範囲内判定

**判定ロジック:**
1. DeviceTypeUtils.GetRadialBreachRange()でブリーチ半径取得
2. 記録された全ブリーチ位置を走査
3. デバイス位置との距離を平方計算 (Vector4.DistanceSquared)
4. 半径の二乗と比較 (平方根計算を回避して高速化)
5. 範囲内なら`true`を返す

**最適化:**
- 平方根計算を回避 (`DistanceSquared`使用)
- キャッシュされた位置リストで高速判定
- 最大50件の記録で配列サイズ制限


**最適化:**
- 平方根計算を回避 (`DistanceSquared` 使用)
- キャッシュされた位置リストで高速判定

### RadialBreach MOD統合

**統合ファイル:** `RadialUnlock/Integration/RadialBreachGating.reds`

**統合方法:**
1. `@if(ModuleExists("RadialBreach"))` で条件付きコンパイル
2. RadialBreachSettings から範囲値を取得
3. ユーザー設定に従った動作

**互換性:**
- RadialBreach MODがない場合: デフォルト50m動作
- RadialBreach MODがある場合: ユーザー設定範囲で動作

---

## 意識不明NPC ブリーチ

### 概要

意識不明のNPCに対して直接ブリーチを実行可能にする機能です。

### 起動条件

```
✅ AllowBreachingUnconsciousNPCs = true
✅ NPCが意識不明状態 (Unconscious/Defeated)
✅ RadialUnlockモード有効 (UnlockIfNoAccessPoint = false)
   OR ネットワーク接続あり
✅ 直接ブリーチ済みでない
```

### NPC種別による違い

| NPC種別 | 注入デーモン | ネットワークアクセス |
|---------|-------------|-------------------|
| **通常NPC** | NPC + Basic | 制限付き (NPCサブネット + 基本機能) |
| **ネットランナーNPC** | Turret + Camera + NPC + Basic | 完全なネットワークアクセス |

**ネットランナー判定:**
```redscript
// NPCLifecycle.reds
public static func IsNetrunner(puppet: ref<ScriptedPuppet>) -> Bool {
    let tags = puppet.GetTags();
    return ArrayContains(tags, n"Netrunner");
}
```

### 動作フロー

```
1. プレイヤーが意識不明NPCに近づく
   └─ "Breach Unconscious Officer" インタラクション表示

2. プレイヤーが選択
   ├─ NPCLifecycle.reds が起動条件チェック
   └─ ミニゲーム開始

3. ミニゲーム
   ├─ 通常NPC: NPC + Basic デーモン
   └─ ネットランナーNPC: 全デーモン

4. ブリーチ成功
   ├─ m_betterNetrunningWasDirectlyBreached = true (再ブリーチ防止)
   ├─ ネットワーク解除
   └─ プログレッシブフラグ更新
```

### 制限事項

**一度だけブリーチ可能:**

ScriptedPuppetPSに`m_betterNetrunningWasDirectlyBreached`フラグ (Bool型) が追加されており、このフラグが`true`の場合、同じNPCに対して再度ブリーチはできません。この状態はセーブデータに永続化されます。

**実装ファイル:**
- `NPCs/NPCLifecycle.reds` - NPC状態監視・ブリーチ起動条件チェック
- `NPCs/NPCBreachExperience.reds` - ブリーチアクション定義
- `Core/Events.reds` - 永続フィールド定義 (m_betterNetrunningWasDirectlyBreached)

---

## デバイス種別制御

### 概要

各デバイスタイプごとに **リモートブリーチの有効/無効を個別設定** できる機能です。

### サポートデバイス種別

| デバイス種別 | 設定項目 | デフォルト |
|------------|---------|----------|
| **コンピュータ** | `RemoteBreachEnabledComputer` | ✅ 有効 |
| **カメラ** | `RemoteBreachEnabledCamera` | ✅ 有効 |
| **タレット** | `RemoteBreachEnabledTurret` | ✅ 有効 |
| **ターミナル** | `RemoteBreachEnabledTerminal` | ✅ 有効 |
| **車両** | `RemoteBreachEnabledVehicle` | ✅ 有効 |
| **その他** | `RemoteBreachEnabledOther` | ✅ 有効 |

### デバイスタイプ検出

**中央管理ユーティリティ:** `Core/DeviceTypeUtils.reds`

**提供関数:**
- `IsComputerDevice()`: ComputerControllerPSか判定
- `IsCameraDevice()`: SurveillanceCameraControllerPSか判定
- `IsTurretDevice()`: SecurityTurretControllerPSか判定
- `IsTerminalDevice()`: TerminalControllerPSか判定
- `IsVehicleDevice()`: VehicleComponentPSか判定
- `GetDeviceType()`: DeviceType列挙型を返す統合判定関数

これらの関数はRemoteBreachVisibilityやRemoteBreachActionクラスから呼び出され、設定に基づいてリモートブリーチの可視性を制御します。

### 設定による制御

RemoteBreachVisibility.redsがデバイスタイプを検出し、対応する設定をチェックします。例えば、`IsComputerDevice()`が`true`で`RemoteBreachEnabledComputer()`が`false`の場合、コンピュータへのリモートブリーチは表示されません。

### Native Settings UI連携

Native Settings UIから各デバイス種別の有効/無効を切り替え可能です。設定はsettings.jsonに保存され、CETのsettingsManager.luaを経由してREDscriptから読み取られます。

**実装ファイル:**
- `Core/DeviceTypeUtils.reds` - デバイスタイプ検出ロジック
- `RemoteBreach/UI/RemoteBreachVisibility.reds` - 可視性制御（設定チェック）
- `config.reds` - 設定定義とデフォルト値
- `bin/.../nativeSettingsUI.lua` - UI構築

---

## ネットワークアクセス緩和

### 概要

バニラのCyberpunk 2077では、ネットワークトポロジーによる制限が多数存在します。Better Netrunningでは、これらの制限を緩和し、**より自由なネットランニング体験**を提供します。

### 緩和機能

#### 1. ドアのクイックハックメニュー

**バニラの制限:**
- ドアはアクセスポイントに接続されていない場合、クイックハックメニューが表示されない

**Better Netrunningの緩和:**
- **全てのドア**でクイックハックメニューを表示
- ネットワーク接続状態に関係なく操作可能

**実装:**
```redscript
// DeviceNetworkAccess.reds
@wrapMethod(DoorControllerPS)
public func CanRevealDevicesGrid() -> Bool {
    return true; // 常にtrueを返す
}
```

#### 2. スタンドアロンデバイスのリモートブリーチ

**バニラの制限:**
- ネットワーク接続がないデバイスはリモートブリーチ不可

**Better Netrunningの緩和:** DeviceNetworkAccess.redsがIsConnectedToBackdoorDevice()メソッドをラップし、UnlockIfNoAccessPoint設定が`true`の場合は常に`true`を返します。これにより、スタンドアロンデバイスでもリモートブリーチが可能になります。

#### 3. 全デバイスでPing使用可能

**バニラの制限:**
- 一部のデバイスではPingが使用できない

**Better Netrunningの緩和:**
- **全デバイス**でPingを使用可能
- 偵察能力の向上

**実装:** DeviceNetworkAccess.redsがCanPlayerUseQuickHackVulnerability()メソッドをラップし、常に`true`を返すことで全デバイスでのPing使用を可能にします。

### 緩和モード設定

**UnlockIfNoAccessPoint = true の場合:**
- 上記の全緩和機能が有効
- スタンドアロンデバイスも自動解除
- ネットワークトポロジーの制限が最小化

**UnlockIfNoAccessPoint = false の場合:**
- RadialUnlockモード（50m範囲制限あり）
- よりリアルなネットワークトポロジー
- 物理的な距離による制限

**実装ファイル:**
- `Devices/DeviceNetworkAccess.reds` - 3つの@wrapMethodによるネットワークアクセス緩和

---

## デバッグロギングシステム

### 概要

Better Netrunning 1.1では、開発者向けに**5段階ログレベルシステム**を導入しました。効率的なデバッグとパフォーマンス最適化を実現します。

### 主要機能

#### 1. 5段階ログレベル

| レベル | 数値 | 説明 | 用途 |
|-------|------|------|------|
| **ERROR** | 0 | エラーのみ | クリティカルな障害、null チェック失敗 |
| **WARNING** | 1 | 警告 + エラー | 非推奨パス、フォールバックロジック |
| **INFO** | 2 | 情報 + 上記 | ブリーチサマリー、主要イベント（**デフォルト**） |
| **DEBUG** | 3 | デバッグ + 上記 | 中間計算、状態変更 |
| **TRACE** | 4 | トレース + 上記 | 全関数呼び出し、全変数値 |

**API関数:**
- BNError(): エラーメッセージ（レベル0、常に出力）
- BNWarn(): 警告メッセージ（レベル1以上）
- BNInfo(): 情報メッセージ（レベル2以上、デフォルト）
- BNDebug(): デバッグメッセージ（レベル3以上）
- BNTrace(): トレースメッセージ（レベル4）

#### 2. 完全なON/OFF制御

**EnableDebugLog = false (デフォルト):**
- `GetCurrentLogLevel()` が `-1` を返す（完全抑制）
- 全ての `BN*` ログ関数が早期リターン（出力なし）
- ログレベルセレクタが設定UIに表示されない
- パフォーマンスオーバーヘッドゼロ

**EnableDebugLog = true:**
- `GetCurrentLogLevel()` が `0-4` を返す（`DebugLogLevel` 設定に基づく）
- `BNError/Warn/Info/Debug/Trace` がレベルに応じてフィルタリング
- ログレベルセレクタが設定UIに表示
- 重複抑制が有効（5秒ウィンドウ）

**UI動作:**
- EnableDebugLogトグル時に設定UIが自動更新
- ログレベルセレクタが動的に表示/非表示
- ゲーム再起動不要（nativeSettings.refresh()による即時反映）

#### 3. 重複抑制

**目的:** ループ内の繰り返しメッセージによるコンソールスパムを防止

**動作:**
- 5秒以内の同一メッセージを自動検出
- 重複時はカウントを増やし、サマリー出力
- 最初の発生は常に記録（デバッグ用）

**出力例:**
```
[22:15:30][BN][DeviceUnlock] Unlocking camera: cam_123
[22:15:30][BN][DeviceUnlock] ↑ repeated 5 times (suppressed)
```

**利点:**
- コンソールの可読性向上
- 繰り返し回数でパターン識別
- パフォーマンス改善（文字列処理削減）

#### 4. 統計収集システム

**目的:** 散在したログ呼び出しを包括的なサマリーに統合（50+ logs → 4 summaries）

**BreachSessionStats - 収集データ (20+ フィールド):**

**基本情報:**
- breachType: ブリーチ種別 ("AccessPoint" / "RemoteBreach" / "UnconsciousNPC")
- breachTarget: ターゲット名（デバイス/NPC）
- timestamp: 開始時刻

**ミニゲームフェーズ:**
- programsInjected: 注入されたボーナスデーモン数
- minigameSuccess: ミニゲーム成功/失敗

**解除フラグ:**
- unlockBasic/Cameras/Turrets/NPCs: 各サブネット解除状態

**ネットワーク結果:**
- networkDeviceCount: ネットワーク内総デバイス数
- devicesUnlocked: 解除成功数
- devicesSkipped: スキップ数（条件不一致）

**デバイス内訳:**
- cameraCount/turretCount/npcCount/doorCount/terminalCount/otherCount: 各デバイス種別数

**RadialBreach（該当時）:**
- radialBreachUsed: RadialBreach MOD使用有無
- radialBreachDistance: ブリーチ点からの距離

**パフォーマンス:**
- processingTimeMs: 処理時間（自動計算）

**収集フロー:**
1. **CREATE**: ブリーチ開始時に統計オブジェクト作成
2. **COLLECT**: 処理中に各フィールドを更新
3. **FINALIZE**: 処理時間を計算
4. **OUTPUT**: ボックス描画フォーマットで1回出力

**出力形式:**
```
╔══════════════════════════════════════════════════════════════════════════════╗
║ BREACH SESSION: AccessPoint - "corp_server_01" (2025-10-15 22:15:30)        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ ┌─ ミニゲームフェーズ ────────────────────────────────────────────────────┐  ║
║ │ 注入プログラム: 2 (PING, Datamine V2)                                  │  ║
║ │ ミニゲーム結果: ✓ 成功                                                 │  ║
║ └────────────────────────────────────────────────────────────────────────┘  ║
║ ┌─ ネットワーク結果 ──────────────────────────────────────────────────────┐  ║
║ │ 総デバイス数: 15                                                        │  ║
║ │ 解除成功: 12 (80.0%)                                                    │  ║
║ │ スキップ: 3 (20.0%)                                                     │  ║
║ └────────────────────────────────────────────────────────────────────────┘  ║
║ ┌─ デバイス内訳 ──────────────────────────────────────────────────────────┐  ║
║ │ カメラ: 4 | タレット: 2 | NPC: 5 | ドア: 2 | ターミナル: 1 | その他: 1 │  ║
║ └────────────────────────────────────────────────────────────────────────┘  ║
║ ┌─ 解除フラグ ────────────────────────────────────────────────────────────┐  ║
║ │ Basic: ✓ | Cameras: ✓ | Turrets: ✓ | NPCs: ✗                          │  ║
║ └────────────────────────────────────────────────────────────────────────┘  ║
║ 処理時間: 23.5ms                                                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

#### 5. ログ削減の影響

統計収集システムは、構造化されたサマリー出力により可読性とパフォーマンスを提供します。統計ロジックは`Debug/BreachSessionStats.reds`に集約され、保守性が確保されています。

### 多言語対応

**Localization_Keys_LogLevel.json テンプレート:**
- 英語・日本語の14エントリ（UI表示用）
- ログレベル名: ERROR, WARNING, INFO, DEBUG, TRACE
- 各レベルの説明文
- WolvenKitプロジェクトに手動挿入 + アーカイブ再ビルド必要

### 実装ファイル

- `Core/Logger.reds` (240行) - レベルベースロギング、重複抑制、LogMessageTracker
- `Core/TimeUtils.reds` (58行) - タイムスタンプ管理ユーティリティ
- `Debug/BreachSessionStats.reds` (260行) - 統計収集クラス、フィールド定義、出力フォーマット
- `bin/.../nativeSettingsUI.lua` - 条件付きUI表示 (EnableDebugLog連動)
- `.docs/Localization_Keys_LogLevel.json` - 多言語テンプレート (en-us + jp-jp、14エントリ)

---

## 設定システム

### 概要

Better Netrunningは、**ハイブリッド設定システム**を採用しています：

```
settings.json (永続化)
     ↕ (読み込み/保存)
settingsManager.lua (CETランタイム)
     ↕ (オーバーライド)
BetterNetrunningSettings.* (REDscript静的関数)
     ↕ (クエリ)
REDscriptゲームロジック
```

**3つの設定方法:**
1. **Native Settings UI** (推奨) - ゲーム内メニューから直接変更
2. **settings.json** (手動編集) - `bin/x64/plugins/cyber_engine_tweaks/mods/BetterNetrunning/settings.json`
3. **config.reds** (フォールバック) - Lua設定がない場合のデフォルト値

**設定カテゴリ (11種類, 合計71項目):**
1. **Controls** - ブリーチホットキー設定
2. **Breaching** - クラシックモード、意識不明NPCブリーチ切り替え
3. **RemoteBreach** - デバイス種別ごとの切り替え、RAMコスト
4. **AccessPoints** - オートDatamine、オートPing、デーモン表示
5. **RemovedQuickhacks** - カメラ/タレット無効化クイックハックブロック
6. **UnlockedQuickhacks** - 常時利用可能なクイックハック (Ping, Whistle, Distract)
7. **Progression** - 要件切り替え (Cyberdeck, Intelligence, Rarity)
8. **ProgressionCyberdeck** - サブネット別Cyberdeckティア要件
9. **ProgressionIntelligence** - サブネット別Intelligence値要件
10. **ProgressionEnemyRarity** - サブネット別敵レアリティ要件
11. **Debug** - デバッグログ制御

### 主要設定項目

#### プログレッシブシステム

| 設定項目 | デフォルト | 説明 |
|---------|----------|------|
| `EnableClassicMode` | `false` | 旧バージョンのバニラ動作に戻す (全機能無効化) |
| `UnlockIfNoAccessPoint` | `false` | スタンドアロンデバイス自動解除 |

#### リモートブリーチ制御

| 設定項目 | デフォルト | 説明 |
|---------|----------|------|
| `RemoteBreachEnabledComputer` | `true` | コンピュータのリモートブリーチ |
| `RemoteBreachEnabledDevice` | `true` | デバイス（カメラ/タレット以外）のリモートブリーチ |
| `RemoteBreachEnabledVehicle` | `true` | 車両のリモートブリーチ |
| `RemoteBreachRAMCostPercent` | `35` | RAMコスト (最大RAMの%) |

#### オートデーモン

| 設定項目 | デフォルト | 説明 |
|---------|----------|------|
| `AutoExecutePingOnSuccess` | `true` | ブリーチ成功時に自動PING実行 |
| `AutoDatamineBySuccessCount` | `true` | 成功回数に応じたDatamine自動追加<br>1成功→V1, 2成功→V2, 3+成功→V3 |

#### NPC関連

| 設定項目 | デフォルト | 説明 |
|---------|----------|------|
| `AllowBreachingUnconsciousNPCs` | `true` | 意識不明NPCのブリーチ許可 |

#### デバッグ

| 設定項目 | デフォルト | 説明 |
|---------|----------|------|
| `EnableDebugLog` | `false` | デバッグログ出力 ON/OFF |
| `DebugLogLevel` | `2` | ログレベル（0=ERROR, 1=WARNING, 2=INFO, 3=DEBUG, 4=TRACE） |

**補足:**
- `EnableDebugLog = false` の場合、`DebugLogLevel` 設定は無視され、全てのログが抑制されます
- Native Settings UI では、`EnableDebugLog = true` の時のみログレベル選択肢が表示されます
- 重複抑制機能により、5秒以内の同一メッセージは「↑ repeated N times」形式で出力されます

### Native Settings UI

**推奨される設定方法**

Native Settings UIをインストールすると、ゲーム内のSettingsメニューから直接設定変更が可能です。

**メニュー構造 (13カテゴリ):**
```
Settings
  └─ Mods
      └─ Better Netrunning
          ├─ Controls
          │   └─ Breaching Hotkey (Choice1-4)
          ├─ Breaching
          │   ├─ Enable Classic Mode
          │   └─ Allow Breaching Unconscious NPCs
          ├─ Remote Breach
          │   ├─ Computer Enabled
          │   ├─ Device Enabled
          │   ├─ Vehicle Enabled
          │   └─ RAM Cost Percent (10-100%)
          ├─ Access Points
          │   ├─ Unlock If No Access Point
          │   ├─ Auto Datamine By Success Count
          │   ├─ Auto Execute Ping On Success
          │   └─ Allow All Daemons On Access Points
          ├─ Removed Quickhacks
          │   ├─ Block Camera Disable
          │   └─ Block Turret Disable
          ├─ Unlocked Quickhacks
          │   ├─ Always Allow Ping
          │   ├─ Always Allow Whistle
          │   └─ Always Allow Distract
          ├─ Progression
          │   ├─ Progression Require All
          │   ├─ Cyberdeck Enabled
          │   ├─ Intelligence Enabled
          │   └─ Enemy Rarity Enabled
          ├─ Progression Cyberdeck
          │   └─ (Per-subnet tier requirements)
          ├─ Progression Intelligence
          │   └─ (Per-subnet level requirements)
          ├─ Progression Enemy Rarity
          │   └─ (Per-subnet rarity requirements)
          └─ Debug
              ├─ Enable Debug Log (スイッチ)
              └─ Log Level (0-4セレクタ, Enable Debug Log = true時のみ表示)
```

**UI動作:**
- Enable Debug Logトグル時、Log Levelセレクタが動的に表示/非表示
- ゲーム再起動不要（即時反映）

### settings.json 手動編集

**ファイルパス:** `bin/x64/plugins/cyber_engine_tweaks/mods/BetterNetrunning/settings.json`

**主要設定例:**
```json
{
    "EnableClassicMode": false,
    "RemoteBreachEnabledComputer": true,
    "AutoExecutePingOnSuccess": true,
    "AutoDatamineBySuccessCount": true,
    "UnlockIfNoAccessPoint": false,
    "EnableDebugLog": false,
    "DebugLogLevel": 2
}
```

**注意:**
- settings.jsonの変更は即座に反映されます（ゲーム再起動不要）
- Native Settings UIから変更すると自動保存されます

### config.reds (フォールバック)

**ファイルパス:** `r6/scripts/BetterNetrunning/config.reds`

このファイルはLua設定システムがない場合のデフォルト値を提供します。

```redscript
module BetterNetrunningConfig

public class BetterNetrunningSettings {
    // プログレッシブシステム
    public static func EnableClassicMode() -> Bool { return false; }
    public static func UnlockIfNoAccessPoint() -> Bool { return false; }

    // リモートブリーチ
    public static func RemoteBreachEnabledComputer() -> Bool { return true; }
    public static func RemoteBreachEnabledDevice() -> Bool { return true; }
    public static func RemoteBreachEnabledVehicle() -> Bool { return true; }
    public static func RemoteBreachRAMCostPercent() -> Int32 { return 35; }

    // オートデーモン
    public static func AutoExecutePingOnSuccess() -> Bool { return true; }
    public static func AutoDatamineBySuccessCount() -> Bool { return true; }

    // NPC
    public static func AllowBreachUnconscious() -> Bool { return true; }

    // デバッグ
    public static func EnableDebugLog() -> Bool { return false; }
}
```

**重要:**
- CETがインストールされている場合、`settingsManager.lua`が`config.reds`の関数をオーバーライドします
- 設定変更は`settingsManager.OverrideConfigFunctions()`で実装されています

---

## 必須要件・推奨環境

### 必須要件

| 要件 | バージョン | 説明 |
|------|-----------|------|
| **Cyberpunk 2077** | 2.X以降 | ゲーム本体 |
| **Red4ext** | 最新版 | スクリプトエクステンダー |
| **Redscript** | 最新版 | スクリプトコンパイラ |
| **CustomHackingSystem** | 最新版 | リモートブリーチ機能用 (HackingExtensions) |

### 推奨環境

| 要件 | バージョン | 説明 |
|------|-----------|------|
| **Native Settings UI** | 最新版 | ゲーム内設定UI (強く推奨) |
| **RadialBreach MOD** | 最新版 | カスタマイズ可能な範囲設定 (オプション) |

### インストール方法

**手順:**

1. **必須MODのインストール**
   ```
   Red4ext
   Redscript
   CustomHackingSystem (HackingExtensions)
   ```

2. **Better Netrunningのインストール**
   - [Releases](https://github.com/SaganoKei/Better-Netrunning-Fix/releases) から最新版をダウンロード
   - 全ファイルをCyberpunk 2077ゲームディレクトリに展開

3. **推奨MODのインストール (オプション)**
   ```
   Native Settings UI
   RadialBreach MOD
   ```

4. **ゲーム起動**
   - REDmod が自動的にスクリプトをコンパイル
   - `REDmodLog.txt` でコンパイルエラーを確認

### トラブルシューティング

**コンパイルエラーが発生する場合:**

1. `REDmodLog.txt` を確認
   ```
   場所: Cyberpunk 2077/REDmodLog.txt
   ```

2. CustomHackingSystemがインストールされているか確認
   ```
   必須: r6/scripts/HackingExtensions/ が存在すること
   ```

3. Redscriptバージョンを確認
   ```
   最新版を使用していることを確認
   ```

**リモートブリーチが表示されない場合:**

1. CustomHackingSystemがインストールされているか確認
2. 設定を確認:
   ```
   RemoteBreachEnabled* が有効か
   UnlockIfNoAccessPoint = false か
   ```

**ブリーチが動作しない場合:**

1. EnableClassicMode が無効か確認
2. デバッグログを有効化:
   ```
   EnableDebugLog = true
   r6/logs/ でログを確認
   ```

---

## MOD互換性

### 互換性テスト済みMOD

| MOD名 | 互換性 | 備考 |
|-------|-------|------|
| **CustomHackingSystem** | ✅ 完全互換 | 必須依存関係 |
| **RadialBreach MOD** | ✅ 完全互換 | オプション統合済み |
| **Daemon Netrunning (Revamp)** | ✅ 互換 | DNRGating.redsで統合 |
| **Breach Takedown Improved** | ✅ 互換 | 技術協力により互換性確保 |
| **Native Settings UI** | ✅ 完全互換 | 推奨UI |

### MOD互換性の設計方針

Better Netrunningは、**MOD互換性を最優先**に設計されています：

**1. @wrapMethod優先**
```redscript
// ✅ 推奨: 他のMODもフックできる
@wrapMethod(ClassName)
public func MethodName() -> Void {
    wrappedMethod(); // バニラ処理を呼び出し
    // Better Netrunning処理
}

// ❌ 非推奨: 他のMODが動作しなくなる
@replaceMethod(ClassName)
public func MethodName() -> Void {
    // 完全置き換え (他MODと競合)
}
```

**2. 条件付きコンパイル**
```redscript
// CustomHackingSystemが存在する場合のみコンパイル
@if(ModuleExists("HackingExtensions"))
public class RemoteBreachAction { }

// RadialBreachが存在する場合のみ統合
@if(ModuleExists("RadialBreach"))
public static func GetRadialBreachRange() -> Float { }
```

**3. イベント駆動アーキテクチャ**
- グローバル状態を避ける
- イベント経由で疎結合な通信
- 他MODとの競合を最小化

### 既知の互換性問題

**なし (2025年10月12日時点)**

互換性問題が発生した場合は、[GitHub Issues](https://github.com/SaganoKei/Better-Netrunning-Fix/issues) で報告してください。

### 開発者向け情報

**MOD統合を検討している開発者の方へ:**

1. **COLLABORATION_THREAD.md** を参照
   - 他MOD開発者との協力履歴
   - 互換性確保のベストプラクティス

2. **ARCHITECTURE_DESIGN.md** を参照
   - システムアーキテクチャ
   - 拡張ポイント

3. **DEVELOPMENT_GUIDELINES.md** を参照
   - コーディング規約
   - MOD互換性チェックリスト

4. **GitHubでIssue/PRを作成**
   - 互換性問題の報告
   - 統合提案

---

## 関連ドキュメント

### ユーザー向け

- **README.md** - 基本情報・インストール・クレジット
- **FEATURE_OVERVIEW_JP.md** (本ドキュメント) - 機能概要 (日本語)

### 開発者向け

- **ARCHITECTURE_DESIGN.md** - システムアーキテクチャ (991行)
- **BREACH_SYSTEM_REFERENCE.md** - ブリーチシステム技術リファレンス (939行)
- **DEVELOPMENT_GUIDELINES.md** - 開発ガイドライン (コーディング規約)
- **CODING_STANDARDS.md** - ドキュメントスタイルガイド (462行)
- **TODO.md** - 開発ロードマップ (1,048行)

### リリースノート

- **RELEASE_NOTES_v0.5.0.md** - v0.5.0リリースノート

---

## よくある質問 (FAQ)

### Q1: リモートブリーチが表示されません

**A:** 以下を確認してください：

1. CustomHackingSystem (HackingExtensions) がインストールされているか
2. Native Settings UIで該当デバイス種別のRemoteBreachが有効か
3. UnlockIfNoAccessPoint = false か (trueの場合自動解除モード)

### Q2: 全デバイスが自動解除されてしまいます

**A:** `UnlockIfNoAccessPoint = true` になっています。以下のいずれかを実行：

- Native Settings UIで "Unlock If No Access Point" を無効化
- `config.reds` で `UnlockIfNoAccessPoint() -> Bool { return false; }` に変更

### Q3: 旧バージョンのバニラの動作に戻したい

**A:** `EnableClassicMode = true` に設定してください：

- Native Settings UIで "Enable Classic Mode" を有効化
- `config.reds` で `EnableClassicMode() -> Bool { return true; }` に変更

### Q4: 意識不明NPCのブリーチができません

**A:** 以下を確認してください：

1. `AllowBreachingUnconsciousNPCs = true` か
2. `UnlockIfNoAccessPoint = false` か (RadialUnlockモード)
3. NPCが完全に意識不明状態か (Unconscious/Defeated)

### Q5: ブリーチ範囲を変更したい

**A:** RadialBreach MODをインストールしてください：

1. RadialBreach MODをインストール
2. Native Settings UIで範囲を設定 (例: 100m)
3. Better Netrunningが自動的にその範囲を使用

### Q6: セーブデータは互換性がありますか?

**A:** はい、互換性があります：

- Persistent Fieldsはセーブデータに保存されます
- MOD削除後もセーブデータは破損しません
- ただし、MOD削除後は通常のバニラ動作に戻ります

### Q7: 他のハッキングMODと併用できますか?

**A:** はい、多くのMODと互換性があります：

- Daemon Netrunning (Revamp) - ✅ 互換
- Breach Takedown Improved - ✅ 互換
- CustomHackingSystem - ✅ 必須依存
- RadialBreach - ✅ オプション統合

詳細は「MOD互換性」セクションを参照してください。

### Q8: デバッグログはどこで確認できますか?

**A:** 以下の手順で確認：

1. `EnableDebugLog = true` に設定
2. ゲームを起動してブリーチを実行
3. `r6/logs/` ディレクトリのログファイルを確認
4. `[BetterNetrunning]` プレフィックスで検索

---

## サポート・フィードバック

### バグ報告

**GitHub Issues:** [Better-Netrunning-Fix/issues](https://github.com/SaganoKei/Better-Netrunning-Fix/issues)

**報告時に含めるべき情報:**
1. 発生した問題の詳細
2. 再現手順
3. インストール済みMODのリスト
4. `REDmodLog.txt` の内容
5. `r6/logs/` のデバッグログ (EnableDebugLog有効時)

### 機能要望

**GitHub Issues** または **GitHub Discussions** で提案してください。

### 貢献

コントリビューションを歓迎します！

1. [TODO.md](TODO.md) で現在の開発優先度を確認
2. GitHubでIssue/PRを作成
3. [DEVELOPMENT_GUIDELINES.md](DEVELOPMENT_GUIDELINES.md) のコーディング規約に従う

---

## ライセンス・クレジット

### オリジナルMOD

**Better Netrunning** by **finley243**
Nexus Mods: [Better Netrunning – Hacking Reworked](https://www.nexusmods.com/cyberpunk2077/mods/2302)

### Fix Project

**SaganoKei**
GitHub: [Better-Netrunning-Fix](https://github.com/SaganoKei/Better-Netrunning-Fix)

### コントリビューター

- **[@schizoabe](https://github.com/schizoabe)** - バグ修正コントリビューション

### 協力・互換性

- **BiasNil** - [Daemon Netrunning (Revamp)](https://www.nexusmods.com/cyberpunk2077/mods/12523) 開発者、互換性統合
- **lorddarkflare** - [Breach Takedown Improved](https://www.nexusmods.com/cyberpunk2077/mods/14171) 開発者、技術協力
- **rpierrecollado** - 統合機能、CustomHackingSystemプロトタイピング、テスト
