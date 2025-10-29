# Vanilla RemoteBreach ドキュメント構造

**最終更新**: 2025年10月26日

---

## 📚 ドキュメント一覧と役割

### 1. VANILLA_ALTERNATIVE_APPROACHES.md
**役割**: **技術検証リファレンス**

**内容**:
- @wrapMethod(ScriptableDeviceAction)戦略の技術的妥当性検証
- ソースコードレベルの実装可能性検証
- ActiveProgramsパターンの実証
- IsPossibleシグネチャの正確性確認
- ScriptableSystemの利用可能性検証

**使用場面**:
- 技術的実現可能性を確認したいとき
- 実装戦略の根拠を確認したいとき
- ソースコードレベルの詳細を参照したいとき

**Key Findings**:
- ✅ 技術的実現性85%
- ✅ UX品質90%（ActiveProgramsで成功daemon追跡）
- ✅ パフォーマンス影響<1%（IsA()早期チェック）
- ✅ リスク🟢低（実証済みパターン）

---

### 2. VANILLA_REMOTEBREACH_MIGRATION_REQUIREMENTS.md
**役割**: **移行要件・判断基準ドキュメント**

**内容**:
- HackingExtensions依存を削除すべきかの判断基準
- 移行の投資対効果分析
- バニラアーキテクチャ分析（RemoteBreachクラス、FinalizeNetrunnerDive()フロー）
- 技術要件サマリー
- 移行実施時のアクションプラン概要

**使用場面**:
- HackingExtensionsの状況が変化したとき
- バニラ移行を検討するとき
- バニラアーキテクチャを理解したいとき
- 移行の影響範囲を把握したいとき

**重要な結論**:
- **現状（2025-10-26）**: 移行不要（HackingExtensions安定動作）
- **HackingExtensions終了時**: 移行可能（工数39-61h、UX品質90%）

---

### 3. VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md
**役割**: **実装作業計画書**

**内容**:
- Phase 1-3の段階的実装手順（詳細）
- ファイル単位の修正内容
- コード例とテスト手順
- 工数見積もり（タスク単位）
- 完了基準とチェックリスト

**使用場面**:
- 実際にバニラ移行を実施するとき
- 実装の詳細手順を確認したいとき
- 各Phaseの工数を見積もりたいとき

**Phase構成**:
- **Phase 1**: Core Infrastructure（10-15h）
  - @wrapMethod実装、VanillaRemoteBreachStateSystem
- **Phase 2**: Daemon Processing（6-10h + 8-12h）
  - FinalizeNetrunnerDive()フック、ExtractUnlockFlags統合
- **Phase 3**: Settings & Cleanup（10-16h + 調整）
  - CustomHackingSystem削除、統合テスト

---

## 🔄 ドキュメント間の関係

```
移行判断
    ↓
VANILLA_REMOTEBREACH_MIGRATION_REQUIREMENTS.md
    ├─ 技術的根拠 → VANILLA_ALTERNATIVE_APPROACHES.md
    └─ 実装詳細 → VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md

技術検証
    ↓
VANILLA_ALTERNATIVE_APPROACHES.md
    └─ 実装戦略を提供 → VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md

実装作業
    ↓
VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md
    ├─ 技術リファレンス → VANILLA_ALTERNATIVE_APPROACHES.md
    └─ 要件定義 → VANILLA_REMOTEBREACH_MIGRATION_REQUIREMENTS.md
```

---

## 📖 読むべき順序

### ケース1: 「バニラ移行すべきか判断したい」
1. **VANILLA_REMOTEBREACH_MIGRATION_REQUIREMENTS.md** - 移行判断基準
2. **VANILLA_ALTERNATIVE_APPROACHES.md** - 技術的実現可能性
3. **VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md** - 工数見積もり

### ケース2: 「実装の技術的詳細を知りたい」
1. **VANILLA_ALTERNATIVE_APPROACHES.md** - 技術検証結果
2. **VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md** - 実装手順

### ケース3: 「バニラ移行を実施する」
1. **VANILLA_REMOTEBREACH_MIGRATION_REQUIREMENTS.md** - Phase 0準備
2. **VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md** - Phase 1-3実施
3. **VANILLA_ALTERNATIVE_APPROACHES.md** - 技術的問題発生時の参照

---

## 📝 削除されたドキュメント（理由）

### VANILLA_REMOTEBREACH_FEASIBILITY_ANALYSIS.md
**削除理由**: 技術的誤認が多数
- ❌ @wrapMethod戦略の誤解（RemoteBreachではなく親クラスをwrap）
- ❌ ActiveProgramsの誤解（成功daemon情報が含まれる）
- ❌ タイミング問題の誤解（CompleteAction+StateSystemで解決）
- ✅ VANILLA_ALTERNATIVE_APPROACHES.mdで完全に置き換え

### VANILLA_REMOTEBREACH_IMPLEMENTATION_PLAN.md
**削除理由**: EXECUTION_PLANと重複
- EXECUTION_PLANの方が詳細で実装に特化
- ファイル構造、工数見積もりが重複
- EXECUTION_PLANに統合済み

### VANILLA_REMOTEBREACH_MIGRATION.md
**削除理由**: 実装詳細と要件が混在
- 実装詳細 → EXECUTION_PLANに移譲
- 移行要件 → MIGRATION_REQUIREMENTS.mdに特化
- 3,483行の巨大ファイルを整理

---

## ✅ 整理完了チェックリスト

- [x] FEASIBILITY_ANALYSIS.md削除（技術的誤認、ALTERNATIVE_APPROACHESに置き換え）
- [x] IMPLEMENTATION_PLAN.md削除（EXECUTION_PLANと重複）
- [x] MIGRATION.md削除（MIGRATION_REQUIREMENTS.mdに再構成）
- [x] ALTERNATIVE_APPROACHES.md更新（関連ドキュメント参照追加）
- [x] EXECUTION_PLAN.md更新（技術的根拠追加、工数修正）
- [x] MIGRATION_REQUIREMENTS.md作成（移行要件特化）
- [x] README作成（本ドキュメント）

---

## 🎯 結論

**ドキュメント構造の目的を達成**:
- ✅ **役割分離**: 技術検証/移行要件/実装計画が明確
- ✅ **冗長性削除**: 重複ドキュメント3つを削除
- ✅ **相互参照**: ドキュメント間の関係が明確
- ✅ **実用性**: 各使用ケースで必要なドキュメントが明確

**最終ドキュメント数**: 3ファイル + README
- VANILLA_ALTERNATIVE_APPROACHES.md (技術検証)
- VANILLA_REMOTEBREACH_MIGRATION_REQUIREMENTS.md (移行要件)
- VANILLA_REMOTEBREACH_IMPLEMENTATION_EXECUTION_PLAN.md (実装計画)

**Next Action**: HackingExtensions status変化時にMIGRATION_REQUIREMENTS.mdレビュー

---

**Document Status**: ✅ COMPLETE
**Last Updated**: 2025-10-26
