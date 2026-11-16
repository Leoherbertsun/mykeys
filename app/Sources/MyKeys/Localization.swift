import Foundation

/// 界面语言：环境变量 MYKEYS_LANG（zh / en）优先，否则看系统首选语言，中文以外一律用英文。
enum Lang {
    static let isChinese: Bool = {
        if let v = ProcessInfo.processInfo.environment["MYKEYS_LANG"]?.trimmingCharacters(in: .whitespaces).lowercased(),
           !v.isEmpty {
            return v.hasPrefix("zh")
        }
        return (Locale.preferredLanguages.first ?? "").lowercased().hasPrefix("zh")
    }()

    /// 传给命令行工具 key 的语言代码，让它的提示和界面同一种语言
    static var code: String { isChinese ? "zh" : "en" }

    /// 相对时间（“3 天前”）用的语言
    static var locale: Locale { Locale(identifier: isChinese ? "zh_CN" : "en_US") }
}

/// 双语文字：中文界面用前者，其余用后者
func L(_ zh: String, _ en: String) -> String { Lang.isChinese ? zh : en }

/// 英文里按数量选单复数，例如 plural(3, "key") → "3 keys"
func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String {
    "\(n) " + (n == 1 ? one : (many ?? one + "s"))
}
