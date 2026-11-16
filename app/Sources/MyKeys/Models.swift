import Foundation

/// 可以编辑的说明字段：文件里的英文键 → 界面上的中文名
let editableFields: [(key: String, label: String, placeholder: String)] = [
    ("platform", "平台", "例如 DeepSeek"),
    ("url", "网址", "去哪里登录、续费、重新生成"),
    ("account", "登录账号", "用哪个账号登录"),
    ("purpose", "用途", "拿它做什么"),
    ("tags", "标签", "用逗号分开，例如 常用,付费"),
    ("expires", "到期日", "2027-01-11，没有就留空"),
    ("note", "备注", "余额、额度、注意事项……"),
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
    func m(_ k: String) -> String { meta[k] ?? "" }

    var isConfig: Bool { kind == "config" }
    var sectionTitle: String { section.isEmpty ? "未分类" : section }
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
        f.locale = Locale(identifier: "zh_CN")
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
