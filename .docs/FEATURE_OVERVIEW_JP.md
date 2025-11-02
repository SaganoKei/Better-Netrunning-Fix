# Better Netrunning - 機能概要ドキュメント

**最終更新日:** 2025年11月02日
**バージョン:** 2.2
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
13. [MOD互換性](#mod互換性)

---

## 概要

### Better Netrunningとは

Better Netrunningは、Cyberpunk 2077のネットランニング体験を大幅に強化する包括的なMODです。段階的なサブネット解除、リモートブリーチ機能、詳細なデバイス制御を導入し、バニラのブリーチプロトコルを拡張します。

**オリジナル作者:** finley243
**Fix Project:** SaganoKei
**Nexus Mods:** [Better Netrunning – Hacking Reworked](https://www.nexusmods.com/cyberpunk2077/mods/2302)

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

> **⚠️ 無効化:** この機能はゲームソフトロックバグにより無効化されています。バニラのネットワークトポロジー制限が適用されます。詳細は[ネットワークアクセス緩和](#ネットワークアクセス緩和)セクションを参照。

### 8. RemoteBreach失敗ペナルティシステム
ブリーチ失敗時に50m半径・10分間のRemoteBreach使用制限を適用。リスクフリーなRemoteBreachプレイを防止し、ゲームバランスを維持します。

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
- `m_betterNetrunning_breachedAccessPointPositions` (PlayerPuppet): ブリーチ位置配列（RadialUnlock用）
- `m_betterNetrunning_breachTimestamps` (PlayerPuppet): ブリーチ時刻配列（RadialUnlock用）

**ブリーチ失敗ペナルティフィールド:**
- `m_betterNetrunningAPBreachFailedTimestamp` (SharedGameplayPS): APブリーチ失敗時刻
- `m_betterNetrunningNPCBreachFailedTimestamp` (ScriptedPuppetPS): NPCブリーチ失敗時刻
- `m_betterNetrunningRemoteBreachFailedTimestamp` (SharedGameplayPS): RemoteBreach失敗時刻

**実装詳細:**
- `Utils/BreachLockUtils.reds`によりAP/NPC/RemoteBreachのロック判定を一元化
- Float→Doubleへの変換処理によるタイムスタンプ精度保証
- 各ブリーチシステムが統一されたBreachLockUtils APIを利用

**Persistent Fieldsの特徴:**
- セーブデータに自動保存される
- ロード時に自動復元される
- ネットワーク全体で共有される (SetBreachedSubnetイベント経由)
- TimeUtils.SetDeviceUnlockTimestamp()で一元管理

### ネットワーク伝播

1つのデバイスでのブリーチ成功は、**ネットワーク全体に伝播**します。

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

**動作条件:**
- AutoDatamineBySuccessCount = true
- ブリーチミニゲーム成功
- 成功回数が1以上

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

---

## RemoteBreach失敗ペナルティシステム

### 概要

ブリーチプロトコルミニゲームに失敗した際、**意味のあるペナルティ**を適用してゲームバランスを維持し、リスクフリーなRemoteBreachプレイを防止する機能です。

### ペナルティ内容

ブリーチ失敗時（タイムアウト・ESCキースキップ両方）、以下の3つのペナルティが適用されます：

#### 1. 赤色VFX (視覚フィードバック)

- **効果:** 画面全体に赤色のグリッチエフェクト (`disabling_connectivity_glitch_red`)
- **持続時間:** 2-3秒
- **目的:** プレイヤーに失敗を明確にフィードバック

#### 2. RemoteBreach使用制限 (主要ペナルティ)

- **制限範囲:** 失敗位置から **50m半径**
- **制限時間:** **10分間** (デフォルト、設定で変更可能)
- **対象:** RemoteBreachアクション**のみ** (APブリーチ、意識不明NPCブリーチは影響なし)
- **永続化:** セーブデータに保存され、ロード後も有効

**制限判定ロジック:**
```
デバイスへのRemoteBreach試行
  ↓
失敗位置配列をチェック (PlayerPuppet.m_betterNetrunning_remoteBreachFailedPositions)
  ├─ 各失敗位置との距離を計算 (Vector4.DistanceSquared2D)
  ├─ 50m以内 かつ 10分以内 の失敗位置が存在
  └─ → RemoteBreachアクションをQuickHackメニューから削除
```

#### 3. 位置露出トレース (オプション、TracePositionOverhaul MOD連携)

- **効果:** 最寄りのネットランナーNPCが60秒間のアップロードトレースを開始
- **条件:** TracePositionOverhaul MODがインストールされている
- **範囲:** 失敗位置から100m以内の実在ネットランナーNPC
- **目的:** ブリーチ失敗を敵ネットランナーに検知させる

### 適用条件

**ペナルティが適用されるケース:**
- ✅ ブリーチミニゲームのタイムアウト (`HackingMinigameState.Failed`)
- ✅ ESCキーでのスキップ (`HackingMinigameState.Failed`)

**ペナルティが適用されないケース:**
- ❌ ブリーチ成功 (`HackingMinigameState.Succeeded`)
- ❌ 設定で無効化 (`BreachFailurePenaltyEnabled = false`)

**重要:** 現在の実装では、**スキップと失敗を区別していません**。どちらも `HackingMinigameState.Failed` として扱われ、全ペナルティが適用されます。

### 設定項目

| 設定項目 | デフォルト値 | 説明 |
|---------|------------|------|
| `APBreachFailurePenaltyEnabled` | `true` | APブリーチ失敗時のJackInロック |
| `NPCBreachFailurePenaltyEnabled` | `true` | NPCブリーチ失敗時のBreachアクションロック |
| `RemoteBreachFailurePenaltyEnabled` | `true` | RemoteBreach失敗時のネットワーク/範囲ロック |
| `BreachPenaltyDurationMinutes` | `10` | ペナルティ制限時間（分、全タイプ共通） |

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

### 設定による制御

RemoteBreachVisibility.redsがデバイスタイプを検出し、対応する設定をチェックします。例えば、`IsComputerDevice()`が`true`で`RemoteBreachEnabledComputer()`が`false`の場合、コンピュータへのリモートブリーチは表示されません。

### Native Settings UI連携

Native Settings UIから各デバイス種別の有効/無効を切り替え可能です。設定はsettings.jsonに保存され、CETのsettingsManager.luaを経由してREDscriptから読み取られます。

**実装ファイル:**
- `Core/DeviceTypeUtils.reds` - デバイスタイプ検出ロジック
- `RemoteBreach/UI/RemoteBreachVisibility.reds` - 可視性制御（設定チェック）
- `Integration/RadialBreachGating.reds` - RadialBreach MOD統合、範囲取得
- `config.reds` - 設定定義とデフォルト値
- `bin/.../nativeSettingsUI.lua` - UI構築

---

## ネットワークアクセス緩和

### 概要

バニラのCyberpunk 2077では、ネットワークトポロジーによる制限が多数存在します。Better Netrunningでは、`UnlockIfNoAccessPoint`設定により、これらの制限を緩和し、**より自由なネットランニング体験**を提供します。

### UnlockIfNoAccessPoint設定

この設定は、**スタンドアロンデバイス(ネットワーク未接続)の解除モード**を制御します。

**UnlockIfNoAccessPoint = false (デフォルト):**
- RadialUnlockモード: 50m範囲内のAPブリーチ位置からデバイス解除
- よりリアルなネットワークトポロジー
- 物理的な距離による制限
- RemoteBreachが利用可能

**UnlockIfNoAccessPoint = true:**
- スタンドアロンデバイスを**常に自動解除** (APブリーチ不要)
- ネットワークトポロジーの制限が最小化
- RemoteBreachは無効化 (自動解除のため不要)
- より自由なプレイスタイル

### 緩和機能

#### 1. ドアのクイックハックメニュー

**バニラの制限:**
- ドアはアクセスポイントに接続されていない場合、クイックハックメニューが表示されない

**Better Netrunningの緩和:**
- **全てのドア**でクイックハックメニューを表示
- ネットワーク接続状態に関係なく操作可能

#### 2. スタンドアロンデバイスの解除制御

**UnlockIfNoAccessPoint設定による動作:**
- `true`: スタンドアロンデバイスは常に自動解除
- `false`: RadialUnlockシステムで50m範囲制限あり

---

## デバッグロギングシステム

### 概要

Better Netrunningは、開発者向けに**5段階ログレベルシステム**を提供します。効率的なデバッグとパフォーマンス最適化を実現します。

### 主要機能

#### 1. 5段階ログレベル

| レベル | 数値 | 説明 | 用途 |
|-------|------|------|------|
| **ERROR** | 0 | エラーのみ | クリティカルな障害、null チェック失敗 |
| **WARNING** | 1 | 警告 + エラー | 非推奨パス、フォールバックロジック |
| **INFO** | 2 | 情報 + 上記 | ブリーチサマリー、主要イベント（**デフォルト**） |
| **DEBUG** | 3 | デバッグ + 上記 | 中間計算、状態変更 |
| **TRACE** | 4 | トレース + 上記 | 内部処理詳細（プログラム抽出、復元、注入） |

#### 2. 統計収集システム

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

**デバイス内訳 (絵文字アイコン付き):**
- 🔧 basicCount: 基本デバイス数（ドア、エレベータ、自販機等）
- 📷 cameraCount: カメラ数
- 🔫 turretCount: タレット数
- 👤 npcNetworkCount: ネットワーク接続NPC数

**RadialBreach（該当時）:**
- radialBreachUsed: RadialBreach MOD使用有無
- 🔌 standaloneDeviceCount: スタンドアロンデバイス数
- 🚗 vehicleCount: 車両数
- 🚶 npcStandaloneCount: スタンドアロンNPC数

**パフォーマンス:**
- processingTimeMs: 処理時間（自動計算）

---

## 設定システム

### 概要
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

**設定カテゴリ (12種類, 合計73項目):**
1. **Controls** - ブリーチホットキー設定
2. **Breaching** - クラシックモード、意識不明NPCブリーチ切り替え
3. **RemoteBreach** - デバイス種別ごとの切り替え、RAMコスト
4. **BreachPenalty** - 失敗ペナルティ、RemoteBreach制限時間
5. **AccessPoints** - オートDatamine、オートPing、デーモン表示
6. **RemovedQuickhacks** - カメラ/タレット無効化クイックハックブロック
7. **UnlockedQuickhacks** - 常時利用可能なクイックハック (Ping, Whistle, Distract)
8. **Progression** - 要件切り替え (Cyberdeck, Intelligence, Rarity)
9. **ProgressionCyberdeck** - サブネット別Cyberdeckティア要件
10. **ProgressionIntelligence** - サブネット別Intelligence値要件
11. **ProgressionEnemyRarity** - サブネット別敵レアリティ要件
12. **Debug** - デバッグログ制御

### 主要設定項目

#### プログレッシブシステム

| 設定項目 | デフォルト | 説明 |
|---------|----------|------|
| `EnableClassicMode` | `false` | 旧バージョンのバニラ動作に戻す (全機能無効化) |
| `UnlockIfNoAccessPoint` | `false` | スタンドアロンデバイス解除モード<br>`false`: RadialUnlock (50m範囲制限)<br>`true`: 常に自動解除 (RemoteBreach無効) |

#### リモートブリーチ制御

| 設定項目 | デフォルト | 説明 |
|---------|----------|------|
| `RemoteBreachEnabledComputer` | `false` | コンピュータのリモートブリーチ |
| `RemoteBreachEnabledDevice` | `true` | デバイス（カメラ/タレット以外）のリモートブリーチ |
| `RemoteBreachEnabledVehicle` | `true` | 車両のリモートブリーチ |
| `RemoteBreachRAMCostPercent` | `50` | RAMコスト (最大RAMの%) |

#### ブリーチペナルティ

| 設定項目 | デフォルト | 説明 |
|---------|----------|------|
| `BreachFailurePenaltyEnabled` | `true` | ブリーチ失敗ペナルティの有効/無効 |
| `RemoteBreachLockDurationMinutes` | `10` | RemoteBreach制限時間（分） |

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

**UI動作:**
- Enable Debug Logトグル時、Log Levelセレクタが動的に表示/非表示
- ゲーム再起動不要（即時反映）

### settings.json 手動編集

**ファイルパス:** `bin/x64/plugins/cyber_engine_tweaks/mods/BetterNetrunning/settings.json`

**主要設定例:**
```json
{
    "EnableClassicMode": false,
    "RemoteBreachEnabledComputer": false,
    "AutoExecutePingOnSuccess": true,
    "AutoDatamineBySuccessCount": true,
    "UnlockIfNoAccessPoint": false,
    "RadialUnlockCrossNetwork": true,
    "EnableDebugLog": false,
    "DebugLogLevel": 2
}
```

**注意:**
- settings.jsonの変更は即座に反映されます（ゲーム再起動不要）
- Native Settings UIから変更すると自動保存されます

---

## MOD互換性

### 互換性テスト済みMOD

| MOD名 | 互換性 | 備考 |
|-------|-------|------|
| **CustomHackingSystem** | ✅ 完全互換 | 必須依存関係 |
| **RadialBreach MOD** | ✅ 完全互換 | オプション統合済み |
| **Daemon Netrunning (Revamp)** | ✅ 互換 | DNRGating.redsで統合 |
| **TracePositionOverhaul** | ✅ 統合 | ブリーチ失敗時の位置露出トレース |
| **Native Settings UI** | ✅ 完全互換 | 推奨UI |
