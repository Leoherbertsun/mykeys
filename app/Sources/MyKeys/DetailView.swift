import SwiftUI

/// 详情页里选中别的条目（附属配置、所属密钥）时发出，主界面据此切换选中项
extension Notification.Name {
    static let selectKey = Notification.Name("MyKeys.selectKey")
}

struct DetailView: View {
    @EnvironmentObject var store: KeyStore
    let item: KeyItem

    @State private var draft: [String: String] = [:]
    @State private var draftKind = "secret"
    @State private var draftGroup = ""
    @State private var revealed: String?
    @State private var hideTask: Task<Void, Never>?
    @State private var confirmDelete = false
    @State private var showRotate = false
    @State private var showAddChild = false
    @State private var saving = false

    private var children: [KeyItem] { store.children(of: item.name) }
    private var parent: KeyItem? { store.items.first { $0.name == item.group } }

    private var dirty: Bool {
        editableFields.contains { (draft[$0.key] ?? "") != item.m($0.key) }
            || draftKind != item.kind || draftGroup != item.group
    }

    private var expiryInvalid: Bool {
        let e = (draft["expires"] ?? "").trimmingCharacters(in: .whitespaces)
        return !e.isEmpty && DateFormats.day.date(from: e) == nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                valueBox
                if !item.isConfig || !children.isEmpty { childrenBox }
                fieldsForm
                if !item.notes.isEmpty { notesBox }
                infoBox
                HStack {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label(L("删除这个条目", "Delete Item"), systemImage: "trash")
                    }
                    .disabled(!children.isEmpty)
                    .help(children.isEmpty ? "" : L("下面还挂着相关配置，先删掉它们", "Delete the related items under it first."))
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .onAppear { resetDraft() }
        .onChange(of: item) { _, _ in if !dirty { resetDraft() } }
        .onDisappear { hideTask?.cancel() }
        .onReceive(NotificationCenter.default.publisher(for: SelfCheck.reveal)) { _ in Task { await reveal() } }
        .confirmationDialog(L("删除 \(item.name)？", "Delete \(item.name)?"), isPresented: $confirmDelete) {
            Button(L("删除", "Delete"), role: .destructive) { Task { await store.delete(item.name) } }
        } message: {
            Text(L("用到它的脚本会取不到值。旧值会留在本地快照里，需要时可以找回。",
                   "Scripts that use it will no longer get a value. The old value stays in a local snapshot, so you can recover it if needed."))
        }
        .sheet(isPresented: $showRotate) { RotateView(name: item.name) }
        .sheet(isPresented: $showAddChild) {
            AddKeyView(presetSection: item.section, presetGroup: item.name, presetKind: "config") { _ in }
        }
    }

    private func resetDraft() {
        draft = Dictionary(uniqueKeysWithValues: editableFields.map { ($0.key, item.m($0.key)) })
        draftKind = item.kind
        draftGroup = item.group
    }

    private func select(_ name: String) {
        NotificationCenter.default.post(name: .selectKey, object: name)
    }

    // MARK: 各块

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let p = parent {
                Button { select(p.name) } label: {
                    Label(L("属于 \(p.name)", "Part of \(p.name)"), systemImage: "arrow.turn.left.up")
                }
                .buttonStyle(.link)
                .font(.callout)
            }
            Text(item.name)
                .font(.system(.title2, design: .monospaced).weight(.semibold))
                .textSelection(.enabled)
            HStack(spacing: 8) {
                Text(item.sectionTitle)
                    .font(.caption).padding(.horizontal, 7).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                Text(item.isConfig ? L("配置", "Config") : L("密钥", "Secret"))
                    .font(.caption).padding(.horizontal, 7).padding(.vertical, 2)
                    .background((item.isConfig ? Color.gray : Color.green).opacity(0.18), in: Capsule())
                ForEach(item.tags, id: \.self) { t in
                    Text(t).font(.caption).padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                if !item.m("expires").isEmpty { ExpiryText(item: item).font(.caption) }
            }
        }
    }

    private var valueBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    if item.isConfig {
                        Text(item.value ?? item.masked).textSelection(.enabled)
                    } else if let v = revealed {
                        Text(v).textSelection(.enabled)
                    } else {
                        Text(item.masked).foregroundStyle(.secondary)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    if !item.isConfig {
                        Button {
                            if revealed != nil { revealed = nil } else { Task { await reveal() } }
                        } label: {
                            Label(revealed == nil ? L("显示", "Show") : L("隐藏", "Hide"), systemImage: revealed == nil ? "eye" : "eye.slash")
                        }
                    }
                    Button { Task { await store.copy(item.name) } } label: {
                        Label(L("复制", "Copy"), systemImage: "doc.on.doc")
                    }
                    .help(L("复制到剪贴板，45 秒后自动清空", "Copy to the clipboard. It clears after 45 seconds."))
                    Spacer()
                    Button { showRotate = true } label: {
                        Label(item.isConfig ? L("改值", "Change Value") : L("换新值", "Replace Value"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .help(L("平台上重新生成了密钥后，在这里换掉旧值", "After regenerating the key on the platform, replace the old value here."))
                }
                if revealed != nil {
                    Text(L("30 秒后自动隐藏", "Hides automatically after 30 seconds")).font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(6)
        } label: {
            Text(item.isConfig ? L("值（配置不是秘密，直接显示）", "Value (config isn't secret, so it's shown)") : L("密钥值", "Secret Value"))
        }
    }

    private func reveal() async {
        guard !item.isConfig, let v = await store.reveal(item.name) else { return }
        revealed = v
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(30))
            if !Task.isCancelled { revealed = nil }
        }
    }

    /// 挂在它下面的接口地址、编号等
    private var childrenBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if children.isEmpty {
                    Text(L("接口地址、地域、配套的编号这类和它一起用的条目，可以挂在这里。",
                           "Keep things used alongside it here, like the API endpoint, region, or matching IDs."))
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(children) { c in
                    HStack(spacing: 8) {
                        Text(c.isConfig ? L("配置", "Config") : L("密钥", "Secret"))
                            .font(.caption2).padding(.horizontal, 5).padding(.vertical, 1)
                            .background((c.isConfig ? Color.gray : Color.green).opacity(0.18), in: Capsule())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.name).font(.system(.callout, design: .monospaced))
                            Text(c.displayValue).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        }
                        Spacer()
                        Button { Task { await store.copy(c.name) } } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.borderless).help(L("复制", "Copy"))
                        Button { select(c.name) } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.borderless).help(L("打开它的详情", "Show Details"))
                    }
                }
                HStack {
                    Spacer()
                    Button { showAddChild = true } label: { Label(L("加一条", "Add Item"), systemImage: "plus") }
                        .controlSize(.small)
                }
            }
            .padding(6)
        } label: {
            Text(L("相关配置", "Related Items") + (children.isEmpty ? "" : L("（\(children.count)）", " (\(children.count))")))
        }
    }

    private var fieldsForm: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                row(L("类型", "Type")) {
                    Picker("", selection: $draftKind) {
                        Text(L("密钥", "Secret")).tag("secret")
                        Text(L("配置", "Config")).tag("config")
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 160)
                    Spacer()
                }
                row(L("属于", "Part of")) {
                    Picker("", selection: $draftGroup) {
                        Text(L("不属于别的条目", "None")).tag("")
                        ForEach(store.topLevel.filter { $0.name != item.name }) { Text($0.name).tag($0.name) }
                    }
                    .labelsHidden()
                    .disabled(!children.isEmpty)
                }
                ForEach(editableFields, id: \.key) { f in
                    row(f.label) {
                        TextField(f.placeholder, text: binding(f.key), axis: f.key == "note" ? .vertical : .horizontal)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(f.key == "note" ? 2...5 : 1...1)
                        if f.key == "url", let url = URL(string: draft["url"] ?? ""), url.scheme?.hasPrefix("http") == true {
                            Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.right.square") }
                                .buttonStyle(.borderless)
                                .help(L("在浏览器里打开", "Open in Browser"))
                        }
                    }
                }
                if expiryInvalid {
                    Text(L("到期日要写成 2027-01-11 这样的格式", "Write the expiry date like 2027-01-11")).font(.caption).foregroundStyle(.red)
                        .padding(.leading, 72)
                }
                HStack {
                    Spacer()
                    if dirty { Button(L("还原", "Revert")) { resetDraft() } }
                    Button { Task { await save() } } label: { Text(saving ? L("保存中…", "Saving…") : L("保存修改", "Save Changes")) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!dirty || saving || expiryInvalid)
                        .keyboardShortcut("s")
                }
            }
            .padding(6)
        } label: {
            Text(L("说明", "Details"))
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).frame(width: 64, alignment: .trailing).foregroundStyle(.secondary)
            content()
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { draft[key] ?? "" }, set: { draft[key] = $0 })
    }

    private func save() async {
        saving = true
        defer { saving = false }
        var changes: [String: String] = [:]
        for f in editableFields {
            let v = (draft[f.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if v != item.m(f.key) { changes[f.key] = v }
        }
        if draftKind != item.kind { changes["kind"] = draftKind }
        if draftGroup != item.group { changes["group"] = draftGroup }
        _ = await store.saveMeta(item.name, changes: changes)
    }

    private var notesBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(item.notes.enumerated()), id: \.offset) { _, n in
                    Text(n).font(.callout).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(6)
        } label: {
            Text(L("文件里的注释", "Comments in File"))
        }
    }

    private var infoBox: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                infoRow(L("录入", "Added"), item.m("added").isEmpty ? "—" : item.m("added"))
                infoRow(L("上次换新", "Last Replaced"), item.m("rotated").isEmpty ? "—" : item.m("rotated"))
                infoRow(L("上次使用", "Last Used"), item.lastUsed.map {
                    let when = $0.replacingOccurrences(of: "T", with: " ")
                    return L("\(DateFormats.relativeText(item.lastUsedDate))（\(when)）", "\(DateFormats.relativeText(item.lastUsedDate)) (\(when))")
                } ?? L("还没记录到", "Not recorded yet"))
                infoRow(L("长度", "Length"), L("\(item.length) 位", plural(item.length, "character")))
                infoRow(L("在脚本里", "In Scripts"), "$\(item.name)")
            }
            .font(.callout)
            .padding(6)
            Text(L("“上次使用”只记录通过 key 取用的情况（如 MCP 服务启动、key get）；脚本直接读环境变量不会记录。",
                   "“Last Used” only counts access through key (such as an MCP server starting, or key get). Scripts that read the environment variable directly aren't recorded."))
                .font(.caption).foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
        } label: {
            Text(L("记录", "History"))
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).foregroundStyle(.secondary)
            Text(v).textSelection(.enabled)
        }
    }
}

/// 给已有条目换新值
struct RotateView: View {
    @EnvironmentObject var store: KeyStore
    @Environment(\.dismiss) var dismiss
    let name: String
    @State private var value = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("给 \(name) 换新值", "Replace Value of \(name)")).font(.title3.weight(.semibold))
            Text(L("旧值会留在本地快照里。说明字段不变，“上次换新”记为今天。",
                   "The old value stays in a local snapshot. Details stay the same, and “Last Replaced” is set to today."))
                .font(.callout).foregroundStyle(.secondary)
            ValueField(value: $value)
            if let e = error { Text(e).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button(L("取消", "Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(busy ? L("保存中…", "Saving…") : L("保存", "Save")) {
                    Task {
                        busy = true
                        error = await store.add(name: name, value: value, section: nil, meta: [:])
                        busy = false
                        if error == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}

/// 输入值：默认隐藏，可一键从剪贴板粘贴
struct ValueField: View {
    @Binding var value: String
    var secret = true
    @State private var visible = false

    var body: some View {
        HStack {
            Group {
                if visible || !secret {
                    TextField(secret ? L("密钥值", "Secret value") : L("值，例如 https://api.example.com/v1", "Value, e.g. https://api.example.com/v1"), text: $value)
                } else {
                    SecureField(L("密钥值", "Secret value"), text: $value)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            if secret {
                Button { visible.toggle() } label: { Image(systemName: visible ? "eye.slash" : "eye") }
                    .buttonStyle(.borderless)
                    .help(visible ? L("隐藏", "Hide") : L("显示", "Show"))
            }
            Button(L("从剪贴板粘贴", "Paste from Clipboard")) {
                value = (NSPasteboard.general.string(forType: .string) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}
