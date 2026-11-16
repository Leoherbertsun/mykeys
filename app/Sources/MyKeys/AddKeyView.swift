import SwiftUI

struct AddKeyView: View {
    @EnvironmentObject var store: KeyStore
    @Environment(\.dismiss) var dismiss
    let presetSection: String?
    var presetGroup: String = ""
    var presetKind: String = "secret"
    var onAdded: (String) -> Void

    @State private var name = ""
    @State private var value = ""
    @State private var kind = "secret"
    @State private var group = ""
    /// 分类选择器的值：已有分类名、空（未分类），或 newSectionTag（新建分类，名字在 newSection 里）
    @State private var section = ""
    @State private var newSection = ""
    @State private var meta: [String: String] = [:]
    @State private var error: String?
    @State private var busy = false

    // 按名字自动补全：base 是打开表单时各字段的值，auto 是最近一次自动填进去的值。
    // 字段的当前值既不等于 auto 也不等于 base，就说明用户手动改过，之后不再覆盖。
    @State private var base: [String: String] = [:]
    @State private var auto: [String: String] = [:]
    /// 从某个密钥详情里“加一条”时，类型和归属是明确指定的，不参与自动补全
    @State private var locked: Set<String> = []

    private static let newSectionTag = "\u{1}new-section"
    private static let guessedFields = ["platform", "url", "kind", "group", "section"]

    private var nameValid: Bool { name.range(of: "^[A-Z][A-Z0-9_]*$", options: .regularExpression) != nil }
    private var exists: Bool { store.items.contains { $0.name == name } }
    private var expiryInvalid: Bool {
        let e = (meta["expires"] ?? "").trimmingCharacters(in: .whitespaces)
        return !e.isEmpty && DateFormats.day.date(from: e) == nil
    }
    private var existingSections: [String] { store.sections.filter { $0 != KeyItem.uncategorized } }
    /// 实际要存的分类名；空表示未分类
    private var effectiveSection: String {
        section == Self.newSectionTag ? newSection.trimmingCharacters(in: .whitespaces) : section
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(group.isEmpty ? L("添加密钥", "Add Key") : L("给 \(group) 加一条相关配置", "Add a Related Item to \(group)"))
                .font(.title2.weight(.semibold))

            Picker(L("类型", "Type"), selection: $kind) {
                Text(L("密钥：要保密的", "Secret: keep it private")).tag("secret")
                Text(L("配置：接口地址、地域、编号等", "Config: endpoint, region, IDs, etc.")).tag("config")
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()

            VStack(alignment: .leading, spacing: 6) {
                Text(L("名字（脚本里就用这个名字取）", "Name (scripts read it by this name)"))
                    .font(.callout).foregroundStyle(.secondary)
                TextField(kind == "config" ? L("例如 DEEPSEEK_BASE_URL", "e.g. DEEPSEEK_BASE_URL")
                                           : L("例如 TAVILY_API_KEY_5", "e.g. TAVILY_API_KEY_5"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: name) { _, n in
                        let fixed = n.uppercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
                        if fixed != n { name = fixed } else { applyGuess() }
                    }
                if !name.isEmpty && !nameValid {
                    Text(L("只能用大写字母、数字和下划线，并以字母开头",
                           "Use only capital letters, digits, and underscores, starting with a letter"))
                        .font(.caption).foregroundStyle(.red)
                } else if exists {
                    Text(L("这个名字已经有了：保存会把它换成新值，说明字段只补充不清空",
                           "This name already exists. Saving replaces its value; details are added to, never cleared."))
                        .font(.caption).foregroundStyle(.orange)
                } else if autoFilled {
                    Label(L("已按名字自动补全，可修改", "Filled in from the name. You can change anything."),
                          systemImage: "wand.and.stars")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(kind == "config" ? L("值", "Value") : L("密钥值", "Secret Value")).font(.callout).foregroundStyle(.secondary)
                ValueField(value: $value, secret: kind == "secret")
            }

            HStack(spacing: 18) {
                Picker(L("属于", "Part of"), selection: $group) {
                    Text(L("不属于别的条目", "None")).tag("")
                    ForEach(store.topLevel) { Text($0.name).tag($0.name) }
                }
                .frame(maxWidth: 300)
                if group.isEmpty {
                    Picker(L("分类", "Category"), selection: $section) {
                        Text(KeyItem.uncategorized).tag("")
                        ForEach(existingSections, id: \.self) { Text($0).tag($0) }
                        Divider()
                        Text(L("新建分类…", "New Category…")).tag(Self.newSectionTag)
                    }
                }
            }
            if !group.isEmpty {
                Text(L("会挂在 \(group) 下面，主列表里不单独占一行。",
                       "It's grouped under \(group) instead of getting its own row in the list."))
                    .font(.caption).foregroundStyle(.secondary)
            } else if section == Self.newSectionTag {
                HStack {
                    TextField(L("新分类的名字，例如 大模型", "New category name, e.g. AI Models"), text: $newSection)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    Text(L("保存时会在文件末尾新建这个分类", "Created at the end of the file when you save"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                ForEach(editableFields.filter { kind == "secret" || ["purpose", "note"].contains($0.key) }, id: \.key) { f in
                    GridRow {
                        Text(f.label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        TextField(f.placeholder, text: Binding(get: { meta[f.key] ?? "" }, set: { meta[f.key] = $0 }))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            if expiryInvalid {
                Text(L("到期日要写成 2027-01-11 这样的格式", "Write the expiry date like 2027-01-11"))
                    .font(.caption).foregroundStyle(.red)
            }
            Text(kind == "secret" ? L("说明都可以以后再补。填了到期日，会在“提醒事项”里提前 7 天提醒。",
                                      "You can fill in details later. With an expiry date, Reminders alerts you 7 days ahead.")
                                  : L("配置不是秘密，会直接显示出来。", "Config isn't secret, so its value is shown as is."))
                .font(.caption).foregroundStyle(.tertiary)

            if let e = error {
                Text(e).foregroundStyle(.red).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button(L("取消", "Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(busy ? L("保存中…", "Saving…") : (exists ? L("换成新值", "Replace Value") : L("保存", "Save"))) {
                    Task { await save() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!nameValid || value.trimmingCharacters(in: .whitespaces).isEmpty || busy || expiryInvalid)
            }
        }
        .padding(24)
        .frame(width: 560)
        .onAppear {
            setSection(presetSection.flatMap { $0 == KeyItem.uncategorized ? nil : $0 } ?? "")
            group = presetGroup
            kind = presetKind
            if !presetGroup.isEmpty { locked = ["kind", "group"] }
            base = Dictionary(uniqueKeysWithValues: Self.guessedFields.map { ($0, current($0)) })
            if !presetGroup.isEmpty { name = presetGroup.replacingOccurrences(of: "_API_KEY", with: "") + "_" }
        }
        .task {
            await store.loadCatalog()
            applyGuess()
        }
        .onChange(of: store.catalog == nil) { _, _ in applyGuess() }
    }

    // MARK: 按名字自动补全（规则同 bin/key 的 guess / guess_parent / find_section）

    private func current(_ key: String) -> String {
        switch key {
        case "kind": return kind
        case "group": return group
        case "section":
            // 选了“新建分类”还没起名，也算用户自己动过
            if section == Self.newSectionTag && effectiveSection.isEmpty { return Self.newSectionTag }
            return effectiveSection
        default: return meta[key] ?? ""
        }
    }

    private func set(_ key: String, _ v: String) {
        switch key {
        case "kind": kind = v
        case "group": group = v
        case "section": setSection(v)
        default: meta[key] = v.isEmpty ? nil : v
        }
    }

    /// 已有的分类直接选上；没有的切到“新建分类”并填好名字
    private func setSection(_ s: String) {
        if s.isEmpty || existingSections.contains(s) {
            section = s
        } else {
            section = Self.newSectionTag
            newSection = s
        }
    }

    /// 这个字段还没被用户改过，可以由自动补全接管
    private func isOurs(_ key: String) -> Bool {
        !locked.contains(key) && current(key) == (auto[key] ?? base[key] ?? "")
    }

    private var autoFilled: Bool {
        Self.guessedFields.contains { k in
            guard let a = auto[k], a != (base[k] ?? "") else { return false }
            return current(k) == a
        }
    }

    private func applyGuess() {
        guard let catalog = store.catalog, !base.isEmpty else { return }
        var guessed: [String: String] = [:]
        // 和命令行一样，只给新名字猜；已有的名字是换新值，不动说明
        if nameValid && !exists {
            let platform = catalog.guess(name)
            if let p = platform {
                guessed["platform"] = p.platform
                guessed["url"] = p.url
            }
            // 和命令行一样：找到所属的密钥才自动切成配置（DATABASE_URL 这类可能含密码的，找不到主人就留作密钥）
            if catalog.looksLikeConfig(name),
               let parent = catalog.guessParent(name, in: store.items),
               store.topLevel.contains(where: { $0.name == parent }) {
                guessed["kind"] = "config"
                guessed["group"] = parent
            }
            // 有归属的条目跟着主条目走，不单独选分类
            let finalGroup = isOurs("group") ? (guessed["group"] ?? base["group"] ?? "") : group
            if finalGroup.isEmpty, let p = platform,
               let s = catalog.section(for: p.category, existing: existingSections) {
                guessed["section"] = s
            }
        }
        for key in Self.guessedFields where isOurs(key) {
            let g = guessed[key] ?? ""
            let v = g.isEmpty ? (base[key] ?? "") : g
            if current(key) != v { set(key, v) }
            auto[key] = v
        }
    }

    private func save() async {
        busy = true
        defer { busy = false }
        var m = meta
        m["kind"] = kind
        if !group.isEmpty { m["group"] = group }
        let s = effectiveSection
        error = await store.add(name: name, value: value, section: group.isEmpty && !s.isEmpty ? s : nil, meta: m)
        if error == nil {
            onAdded(name)
            dismiss()
        }
    }
}
