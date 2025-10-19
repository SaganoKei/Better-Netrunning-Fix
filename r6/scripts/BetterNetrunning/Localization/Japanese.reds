// ============================================================================
// BetterNetrunning - Japanese Localization
// ============================================================================
//
// PURPOSE:
// Japanese language definitions for Better Netrunning mod.
//
// TOTAL ENTRIES: 142
//
// CATEGORIES:
// - Controls (3 entries)
// - Breaching (7 entries)
// - RemoteBreach (13 entries)
// - BreachPenalty (5 entries)
// - AccessPoints (7 entries)
// - UnlockedQuickhacks (21 entries)
// - Progression (71 entries: Cyberdeck/Intelligence/EnemyRarity)
// - Debug (12 entries)
// - Daemon Names/Descriptions (8 entries)
//
// DEPENDENCIES:
// - Codeware.Localization.ModLocalizationPackage
// ============================================================================

module BetterNetrunning.Localization
import Codeware.Localization.*

public class Japanese extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // ===== CONTROLS =====
    this.Text("Category-Controls", "操作");
    this.Text("DisplayName-BetterNetrunning-BreachingHotkey", "気絶NPCに対するブリーチホットキー");
    this.Text("Description-BetterNetrunning-BreachingHotkey", "どのホットキーに気絶NPCに対するブリーチを割り当てるか選択します");

    // ===== BREACHING =====
    this.Text("Category-Breaching", "ブリーチ");
    this.Text("DisplayName-BetterNetrunning-EnableClassicMode", "クラシックモードを有効化");
    this.Text("Description-BetterNetrunning-EnableClassicMode", "有効の場合、任意のデーモンをアップロードすることでネットワーク全体をブリーチできます。サブネットシステムは無効化されます");

    this.Text("DisplayName-BetterNetrunning-AllowBreachingUnconsciousNPCs", "気絶したNPCのブリーチを許可");
    this.Text("Description-BetterNetrunning-AllowBreachingUnconsciousNPCs", "有効の場合、ネットワークに接続された気絶中のNPCにもブリーチを実行できます");

    this.Text("DisplayName-BetterNetrunning-QuickhackUnlockDurationHours", "クイックハック アンロック持続期間（時）");
    this.Text("Description-BetterNetrunning-QuickhackUnlockDurationHours",
              "ブリーチ成功後、クイックハックのアンロック状態が持続する時間を設定します（ゲーム内時間）。\n0に設定すると、一度ブリーチしたデバイスは期限切れなしで永続的にアンロック状態を維持します。\n1以上に設定すると、指定時間経過後に再ロックされ、再度ブリーチが必要になります");

    // ===== REMOTE BREACH =====
    this.Text("Category-RemoteBreach", "リモートブリーチ");
    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledDevice", "リモートブリーチ - デバイス");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledDevice",
              "デバイス類（カメラ/タレット/端末/etc）に対するリモートブリーチの有効/無効を切り替えます。\n無効にすると、これらのデバイスに『ブリーチプロトコル』クイックハックが表示されなくなります");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledComputer", "リモートブリーチ - コンピュータ");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledComputer",
              "コンピュータに対するリモートブリーチの有効/無効を切り替えます。\n無効にすると、コンピュータに『ブリーチプロトコル』クイックハックが表示されなくなります");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledCamera", "リモートブリーチ - カメラ");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledCamera",
              "カメラに対するリモートブリーチの有効/無効を切り替えます。\n無効にすると、カメラに『ブリーチプロトコル』クイックハックが表示されなくなります");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledTurret", "リモートブリーチ - タレット");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledTurret",
              "タレットに対するリモートブリーチの有効/無効を切り替えます。\n無効にすると、タレットに『ブリーチプロトコル』クイックハックが表示されなくなります");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachEnabledVehicle", "リモートブリーチ - 車両");
    this.Text("Description-BetterNetrunning-RemoteBreachEnabledVehicle",
              "車両に対するリモートブリーチの有効/無効を切り替えます。\n無効にすると、車両に『ブリーチプロトコル』クイックハックが表示されなくなります");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachRAMCostPercent", "RAM消費コスト割合");
    this.Text("Description-BetterNetrunning-RemoteBreachRAMCostPercent",
              "リモートブリーチが消費するRAM最大値の割合 (初期値: 50% = 1/2. 100% = 全RAM)。\nリモートブリーチのコストバランスを調整できます");

    // ===== BREACH FAILURE PENALTY =====
    this.Text("Category-BreachPenalty", "ブリーチ失敗ペナルティ");
    this.Text("DisplayName-BetterNetrunning-BreachFailurePenaltyEnabled", "ブリーチ失敗ペナルティを有効化");
    this.Text("Description-BetterNetrunning-BreachFailurePenaltyEnabled",
              "ブリーチプロトコルの失敗またはスキップ時にペナルティを適用します。\n失敗時: 赤色VFX + スタン効果（2秒） + リモートブリーチロック（10分間、ブリーチ範囲内）。\nスキップ時: 軽度のVFXのみ（スタンなし、ロックなし）");

    this.Text("DisplayName-BetterNetrunning-RemoteBreachLockDurationMinutes", "リモートブリーチ ロック期間（分）");
    this.Text("Description-BetterNetrunning-RemoteBreachLockDurationMinutes",
              "ブリーチ失敗後、『リモートブリーチ』クイックハックが一時的に使用不可になる時間（ゲーム内時間）。\n失敗位置からブリーチ範囲内で『リモートブリーチ』クイックハックが使用できなくなります。\nロック範囲は“Radial Breach”設定の「ブリーチ範囲」に従います（デフォルト50m）");

    // ===== ACCESS POINTS =====
    this.Text("Category-AccessPoints", "アクセスポイント");
    this.Text("DisplayName-BetterNetrunning-UnlockIfNoAccessPoint", "アクセスポイントが無いネットワークをアンロック");
    this.Text("Description-BetterNetrunning-UnlockIfNoAccessPoint",
              "有効の場合、アクセスポイントがないデバイスは常にアンロックされます（ブリーチ不要）。\n無効の場合、スタンドアロンデバイスは範囲アンロックシステム（Radial Unlock System）を通じてブリーチが必要です\n（ブリーチ済みネットワークの中心からブリーチ範囲内で自動アンロック。範囲は“Radial Breach”設定で変更可能）");

    this.Text("DisplayName-BetterNetrunning-AutoDatamineBySuccessCount", "成功数に応じた自動データマイニング");
    this.Text("Description-BetterNetrunning-AutoDatamineBySuccessCount",
              "成功したデーモン数に応じて自動的にデータマイニングV1/V2/V3を適用します（1つ=V1、2つ=V2、3つ以上=V3）。\n全てのデータマイニングプログラムはブリーチ画面から非表示になります");

    this.Text("DisplayName-BetterNetrunning-AutoExecutePingOnSuccess", "成功時に自動PING実行");
    this.Text("Description-BetterNetrunning-AutoExecutePingOnSuccess", "いずれかのデーモンが成功した際、自動的にPINGデーモンを(非表示のまま)実行します。ボーナス報酬としてネットワーク可視性を提供します");

    // ===== ALWAYS UNLOCKED QUICKHACKS =====
    this.Text("Category-UnlockedQuickhacks", "常時アンロックされるクイックハック");
    this.Text("DisplayName-BetterNetrunning-AlwaysAllowPing", "PING");
    this.Text("Description-BetterNetrunning-AlwaysAllowPing", "有効の場合、未ブリーチのネットワークでも『PING』クイックハックが常に利用可能になります");

    this.Text("DisplayName-BetterNetrunning-AlwaysAllowWhistle", "疑似餌");
    this.Text("Description-BetterNetrunning-AlwaysAllowWhistle", "有効の場合、未ブリーチのネットワークでも『疑似餌』クイックハックが常に利用可能になります");

    this.Text("DisplayName-BetterNetrunning-AlwaysAllowDistract", "かく乱");
    this.Text("Description-BetterNetrunning-AlwaysAllowDistract", "有効の場合、未ブリーチのネットワークでも『かく乱』クイックハックが常に利用可能になります");

    this.Text("DisplayName-BetterNetrunning-AlwaysBasicDevices", "一般デバイス");
    this.Text("Description-BetterNetrunning-AlwaysBasicDevices", "有効の場合、未ブリーチのネットワークでも一般デバイスのクイックハックが常に利用可能になります");

    this.Text("DisplayName-BetterNetrunning-AlwaysCameras", "カメラ");
    this.Text("Description-BetterNetrunning-AlwaysCameras", "有効の場合、未ブリーチのネットワークでもカメラクイックハックが常に利用可能になります");

    this.Text("DisplayName-BetterNetrunning-AlwaysTurrets", "タレット");
    this.Text("Description-BetterNetrunning-AlwaysTurrets", "有効の場合、未ブリーチのネットワークでもタレットクイックハックが常に利用可能になります");

    this.Text("DisplayName-BetterNetrunning-AlwaysNPCsCovert", "NPC - ステルス");
    this.Text("Description-BetterNetrunning-AlwaysNPCsCovert", "有効の場合、未ブリーチのネットワークでもステルスクイックハックが常に利用可能になります");

    this.Text("DisplayName-BetterNetrunning-AlwaysNPCsCombat", "NPC - コンバット");
    this.Text("Description-BetterNetrunning-AlwaysNPCsCombat", "有効の場合、未ブリーチのネットワークでもコンバットクイックハックが常に利用可能になります");

    this.Text("DisplayName-BetterNetrunning-AlwaysNPCsControl", "NPC - コントロール");
    this.Text("Description-BetterNetrunning-AlwaysNPCsControl", "有効の場合、未ブリーチのネットワークでもコントロールクイックハックが常に利用可能になります");

    this.Text("DisplayName-BetterNetrunning-AlwaysNPCsUltimate", "NPC - アルティメット");
    this.Text("Description-BetterNetrunning-AlwaysNPCsUltimate", "有効の場合、未ブリーチのネットワークでもアルティメットクイックハックが常に利用可能になります");

    // ===== 進行状況 =====
    this.Text("Category-Progression", "進行状況");
    this.Text("DisplayName-BetterNetrunning-ProgressionRequireAll", "全て必須");
    this.Text("Description-BetterNetrunning-ProgressionRequireAll", "有効の場合、無効化されていない全ての進行状況カテゴリを満たす必要があります。無効の場合は、いずれか1つを満たせばアンロックされます");

    // ===== PROGRESSION - CYBERDECK QUALITY =====
    this.Text("Category-BetterNetrunning-ProgressionCyberdeck", "進行状況 - サイバーデッキクラス");
    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckEnabled", "サイバーデッキ進行機能を有効化");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckEnabled", "有効の場合、クイックハックへのアクセスにサイバーデッキクラスの要件が適用されます。無効にするとサイバーデッキクラスの制限を無視します");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckBasicDevices", "一般デバイス");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckBasicDevices", "一般デバイス（カメラ・タレット除く）にクイックハックに必要なサイバーデッキの最小クラス");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckCameras", "カメラ");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckCameras", "カメラにクイックハックに必要なサイバーデッキの最小クラス");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckTurrets", "タレット");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckTurrets", "タレットにクイックハックに必要なサイバーデッキの最小クラス");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsCovert", "NPC - ステルス");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckNPCsCovert", "NPCに対するステルスクイックハックに必要なサイバーデッキの最小クラス");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsCombat", "NPC - コンバット");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckNPCsCombat", "NPCに対するコンバットクイックハックに必要なサイバーデッキの最小クラス");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsControl", "NPC - コントロール");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckNPCsControl", "NPCに対するコントロールクイックハックに必要なサイバーデッキの最小クラス");

    this.Text("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsUltimate", "NPC - アルティメット");
    this.Text("Description-BetterNetrunning-ProgressionCyberdeckNPCsUltimate", "NPCに対するアルティメットクイックハックに必要なサイバーデッキの最小クラス");

    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Common", "クラス1");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-CommonPlus", "クラス1+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Uncommon", "クラス2");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-UncommonPlus", "クラス2+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Rare", "クラス3");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-RarePlus", "クラス3+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Epic", "クラス4");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-EpicPlus", "クラス4+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-Legendary", "クラス5");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-LegendaryPlus", "クラス5+");
    this.Text("DisplayValues-BetterNetrunning-cyberdeckQuality-LegendaryPlusPlus", "クラス5++");

    // ===== PROGRESSION - INTELLIGENCE =====
    this.Text("Category-BetterNetrunning-ProgressionIntelligence", "進行状況 - 知力");
    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceEnabled", "知力進行機能を有効化");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceEnabled", "有効の場合、クイックハックへのアクセスに知力の要件が適用されます。無効にすると知力の制限を無視します");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceBasicDevices", "一般デバイス");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceBasicDevices", "一般デバイス（カメラ・タレット除く）にクイックハックに必要な最小知力");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceCameras", "カメラ");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceCameras", "カメラにクイックハックに必要な最小知力");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceTurrets", "タレット");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceTurrets", "タレットにクイックハックに必要な最小知力");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsCovert", "NPC - ステルス");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceNPCsCovert", "NPCに対するステルスクイックハックに必要な最小知力");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsCombat", "NPC - コンバット");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceNPCsCombat", "NPCに対するコンバットクイックハックに必要な最小知力");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsControl", "NPC - コントロール");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceNPCsControl", "NPCに対するコントロールクイックハックに必要な最小知力");

    this.Text("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsUltimate", "NPC - アルティメット");
    this.Text("Description-BetterNetrunning-ProgressionIntelligenceNPCsUltimate", "NPCに対するアルティメットクイックハックに必要な最小知力");

    // ===== PROGRESSION - ENEMY TIER =====
    this.Text("Category-BetterNetrunning-ProgressionEnemyRarity", "進行状況 - NPCランク");
    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityEnabled", "NPCランク進行機能を有効化");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityEnabled", "有効の場合、クイックハックへのアクセスにNPCランクの要件が適用されます。無効にするとNPCランクの制限を無視します");

    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsCovert", "NPC - ステルス");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityNPCsCovert", "ステルスクイックハックが可能な最大NPCランク");

    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsCombat", "NPC - コンバット");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityNPCsCombat", "コンバットクイックハックが可能な最大NPCランク");

    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsControl", "NPC - コントロール");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityNPCsControl", "コントロールクイックハックが可能な最大NPCランク");

    this.Text("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsUltimate", "NPC - アルティメット");
    this.Text("Description-BetterNetrunning-ProgressionEnemyRarityNPCsUltimate", "アルティメットクイックハックが可能な最大NPCランク");

    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Trash", "トラッシュ");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Weak", "ウィーク");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Normal", "ノーマル");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Rare", "レア");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Officer", "オフィサー");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Elite", "エリート");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-Boss", "ボス");
    this.Text("DisplayValues-BetterNetrunning-NPCRarity-MaxTac", "マックスタック");

    // ===== DEBUG =====
    this.Text("Category-Debug", "デバッグ");
    this.Text("DisplayName-BetterNetrunning-EnableDebugLog", "デバッグログを有効化");
    this.Text("Description-BetterNetrunning-EnableDebugLog", "有効の場合、デバッグログを出力します");

    this.Text("DisplayName-BetterNetrunning-DebugLogLevel", "ログレベル");
    this.Text("Description-BetterNetrunning-DebugLogLevel",
              "デバッグログの詳細度を設定します。デバッグログが有効の場合のみ出力されます。\n0=ERROR（重大なエラーのみ）\n1=WARNING（エラー + 警告）\n2=INFO（デフォルト、通常の情報）\n3=DEBUG（詳細なデバッグ情報）\n4=TRACE（非常に詳細、パフォーマンスに影響する可能性があります）");

    this.Text("DisplayValues-BetterNetrunning-LogLevel-ERROR", "ERROR（エラーのみ）");
    this.Text("DisplayValues-BetterNetrunning-LogLevel-WARNING", "WARNING（エラー + 警告）");
    this.Text("DisplayValues-BetterNetrunning-LogLevel-INFO", "INFO（デフォルト）");
    this.Text("DisplayValues-BetterNetrunning-LogLevel-DEBUG", "DEBUG（詳細）");
    this.Text("DisplayValues-BetterNetrunning-LogLevel-TRACE", "TRACE（非常に詳細）");
    this.Text("Better-Netrunning-Basic-Access-Name", "ルートネットワークをブリーチ");
    this.Text("Better-Netrunning-Basic-Access-Description", "接続された一般デバイスに対するクイックハックをアンロックする");
    this.Text("Better-Netrunning-NPC-Access-Name", "人員管理システムをブリーチ");
    this.Text("Better-Netrunning-NPC-Access-Description", "接続された人員管理システムに対するクイックハックをアンロックする");
    this.Text("Better-Netrunning-Camera-Access-Name", "監視システムをブリーチ");
    this.Text("Better-Netrunning-Camera-Access-Description", "接続された監視カメラに対するクイックハックをアンロックする");
    this.Text("Better-Netrunning-Turret-Access-Name", "防衛システムをブリーチ");
    this.Text("Better-Netrunning-Turret-Access-Description", "接続されたタレットに対するクイックハックをアンロックする");
    this.Text("Better-Netrunning-Quickhacks-Locked", "ネットワーク アクセス権限無し");
  }
}