import Foundation

/// 可以编辑的说明字段：文件里的英文键 → 界面上的名字
let editableFields: [(key: String, label: String, placeholder: String)] = [
    ("platform", L("平台", "Platform"), L("例如 DeepSeek", "e.g. DeepSeek")),
    ("url", L("网址", "URL"), L("去哪里登录、续费、重新生成", "Where to sign in, top up, or regenerate")),
    ("account", L("登录账号", "Account"), L("用哪个账号登录", "Which account you sign in with")),
    ("purpose", L("用途", "Purpose"), L("拿它做什么", "What it's used for")),
    ("tags", L("标签", "Tags"), L("用逗号分开，例如 常用,付费", "Comma-separated, e.g. daily,paid")),
    ("expires", L("到期日", "Expires"), L("2027-01-11，没有就留空", "2027-01-11, or leave blank")),
    ("note", L("备注", "Notes"), L("余额、额度、注意事项……", "Balance, quota, caveats…")),
]

struct KeyItem: Identifiable, Decodable, Hashable {
    let name: String
    let masked: String
    let length: Int
    let section: String
    let notes: [String]
    let meta: [String: String]
    let kind: String
    let group: String
    let lastUsed: String?
    /// 只有“配置”类条目会带明文值（它们不是秘密）
    let value: String?

    var id: String { name }
    /// 没写分类的条目在界面上归到这一类
    static let uncategorized = L("未分类", "Uncategorized")
    func m(_ k: String) -> String { meta[k] ?? "" }

    var isConfig: Bool { kind == "config" }
    var sectionTitle: String { section.isEmpty ? Self.uncategorized : section }
    var expiry: Date? { DateFormats.day.date(from: m("expires")) }

    var daysLeft: Int? {
        guard let e = expiry else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: e).day
    }

    var isExpiringSoon: Bool { (daysLeft ?? Int.max) <= 30 }
    var lastUsedDate: Date? { lastUsed.flatMap { DateFormats.iso.date(from: $0) } }

    var tags: [String] {
        m("tags").split(whereSeparator: { ",，、 ".contains($0) }).map(String.init)
    }

    var displayValue: String { isConfig ? (value ?? masked) : masked }

    var searchText: String {
        ([name, section] + Array(meta.values) + notes).joined(separator: " ").lowercased()
    }

    // 表格排序用
    var sortPlatform: String { m("platform").isEmpty ? "\u{FFFF}" : m("platform") }
    var sortExpiry: String { m("expires").isEmpty ? "9999" : m("expires") }
    var sortLastUsed: String { lastUsed ?? "" }
    var sortAccount: String { m("account").isEmpty ? "\u{FFFF}" : m("account") }
}

enum DateFormats {
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()
    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Lang.locale
        f.unitsStyle = .full
        return f
    }()

    static func relativeText(_ d: Date?) -> String {
        guard let d else { return "—" }
        return relative.localizedString(for: d, relativeTo: Date())
    }
}

enum SidebarFilter: Hashable {
    case all
    case expiring
    case section(String)
    case tag(String)
}

/// 命令行 key catalog --json 的输出：认识的平台、通用分类、配置类名字的结尾。
/// 下面几个猜测函数和 bin/key 里的 guess() / guess_parent() / find_section() 是同一套规则。
struct KeyCatalog: Decodable {
    struct Category: Decodable {
        let name: String
        let keywords: [String]
    }
    struct Platform: Decodable {
        let prefix: String
        let platform: String
        let url: String
        let category: String
    }
    let categories: [String: Category]
    let platforms: [Platform]
    let configSuffixes: [String]

    /// 按名字找平台：取最长的匹配前缀（名字等于去掉末尾下划线的前缀也算）
    func guess(_ name: String) -> Platform? {
        var best: Platform?
        for p in platforms where name.hasPrefix(p.prefix) || name == String(p.prefix.trimmingSuffix("_")) {
            if best == nil || p.prefix.count > best!.prefix.count { best = p }
        }
        return best
    }

    func looksLikeConfig(_ name: String) -> Bool {
        configSuffixes.contains { name.hasSuffix($0) }
    }

    /// 配置类名字（如 OPENAI_BASE_URL）找它所属的密钥：同前缀、本身是密钥且不归属别人的条目里，公共前缀最长的那个
    func guessParent(_ name: String, in items: [KeyItem]) -> String? {
        guard looksLikeConfig(name) else { return nil }
        var best: (len: Int, name: String)?
        for e in items where e.name != name && !e.isConfig && e.group.isEmpty {
            let common = String(zip(e.name, name).prefix { $0 == $1 }.map(\.0))
            if common.contains("_") && !common.trimmingSuffix("_").isEmpty && (best == nil || common.count > best!.len) {
                best = (common.count, e.name)
            }
        }
        guard let best, best.len >= 3 else { return nil }
        return best.name
    }

    /// 在已有分类名里找和目录分类对得上的（按关键词，不分大小写）
    func findSection(_ categoryID: String, in sections: [String]) -> String? {
        guard let kws = categories[categoryID]?.keywords else { return nil }
        return sections.first { s in kws.contains { Self.keywordHit($0, s) } }
    }

    /// 中文关键词按子串匹配；英文关键词要出现在词首，免得 ai 命中 Email（和 bin/key 的 keyword_hit 一致）
    static func keywordHit(_ k: String, _ text: String) -> Bool {
        let t = text.lowercased()
        guard k.allSatisfy(\.isASCII) else { return t.contains(k) }
        let words = t.split { !$0.isLetter && !$0.isNumber }
        return words.contains { $0.hasPrefix(k) }
    }

    /// 名字对应的分类：已有分类里对得上的优先，否则用目录里的分类名（保存时会新建）
    func section(for categoryID: String, existing sections: [String]) -> String? {
        findSection(categoryID, in: sections) ?? categories[categoryID]?.name
    }
}

private extension String {
    /// 去掉末尾连续的某个字符，相当于 Python 的 rstrip(ch)
    func trimmingSuffix(_ ch: Character) -> Substring {
        var s = Substring(self)
        while s.last == ch { s = s.dropLast() }
        return s
    }
}
