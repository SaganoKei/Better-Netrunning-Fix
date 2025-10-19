// ============================================================================
// BetterNetrunning - Localization Provider
// ============================================================================
//
// PURPOSE:
// Core localization routing for Better Netrunning mod using Codeware's
// ModLocalizationProvider system. Routes game language selection to
// appropriate language-specific packages.
//
// ARCHITECTURE:
// - Extends ModLocalizationProvider (Codeware framework)
// - GetPackage(): Returns language-specific ModLocalizationPackage instance
// - GetFallback(): Defines default language when requested language unavailable
//
// SUPPORTED LANGUAGES:
// - en-us (English) - Primary/fallback language
// - ja-jp (Japanese) - Full translation
//
// ADDING NEW LANGUAGES:
// 1. Create new language file (e.g., Polish.reds)
// 2. Add case to GetPackage() switch statement
// 3. Implement ModLocalizationPackage with DefineTexts() method
//
// DEPENDENCIES:
// - Codeware.Localization.*
// - English.reds (fallback language)
// - Japanese.reds (additional languages)
// ============================================================================

module BetterNetrunning.Localization
import Codeware.Localization.*

public class LocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    switch language {
      case n"en-us": return new English();
      case n"jp-jp": return new Japanese();
      default: return null;
    }
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}
