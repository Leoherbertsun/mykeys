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
                        Label("删除这个条目", systemImage: "trash")
                    }
                    .disabled(!children.isEmpty)
                    .help(children.isEmpty ? "" : "下面还挂着相关配置，先删掉它们")
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
        .confirmationDialog("删除 \(item.name)？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) { Task { await store.delete(item.name) } }
        } message: {
            Text("用到它的脚本会取不到值。旧值会留在本地快照里，需要时可以找回。")
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
                    Label("属于 \(p.name)", systemImage: "arrow.turn.left.up")
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
                Text(item.isConfig ? "配置" : "密钥")
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
                            Label(revealed == nil ? "显示" : "隐藏", systemImage: revealed == nil ? "eye" : "eye.slash")
                        }
                    }
                    Button { Task { await store.copy(item.name) } } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .help("复制到剪贴板，45 秒后自动清空")
                    Spacer()
                    Button { showRotate = true } label: {
                        Label(item.isConfig ? "改值" : "换新值", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .help("平台上重新生成了密钥后，在这里换掉旧值")
                }
                if revealed != nil {
                    Text("30 秒后自动隐藏").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(6)
        } label: {
            Text(item.isConfig ? "值（配置不是秘密，直接显示）" : "密钥值")
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
                    Text("接口地址、地域、配套的编号这类和它一起用的条目，可以挂在这里。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(children) { c in
                    HStack(spacing: 8) {
                        Text(c.isConfig ? "配置" : "密钥")
                            .font(.caption2).padding(.horizontal, 5).padding(.vertical, 1)
                            .background((c.isConfig ? Color.gray : Color.green).opacity(0.18), in: Capsule())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.name).font(.system(.callout, design: .monospaced))
                            Text(c.displayValue).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        }
                        Spacer()
                        Button { Task { await store.copy(c.name) } } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.borderless).help("复制")
                        Button { select(c.name) } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.borderless).help("打开它的详情")
                    }
                }
                HStack {
                    Spacer()
                    Button { showAddChild = true } label: { Label("加一条", systemImage: "plus") }
                        .controlSize(.small)
                }
            }
            .padding(6)
        } label: {
            Text("相关配置\(children.isEmpty ? "" : "（\(children.count)）")")
        }
    }

    private var fieldsForm: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                row("类型") {
                    Picker("", selection: $draftKind) {
                        Text("密钥").tag("secret")
                        Text("配置").tag("config")
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 160)
                    Spacer()
                }
                row("属于") {
                    Picker("", selection: $draftGroup) {
                        Text("不属于别的条目").tag("")
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
                                .help("在浏览器里打开")
                        }
                    }
                }
                if expiryInvalid {
                    Text("到期日要写成 2027-01-11 这样的格式").font(.caption).foregroundStyle(.red)
                        .padding(.leading, 72)
                }
                HStack {
                    Spacer()
                    if dirty { Button("还原") { resetDraft() } }
                    Button { Task { await save() } } label: { Text(saving ? "保存中…" : "保存修改") }
                        .buttonStyle(.borderedProminent)
                        .disabled(!dirty || saving || expiryInvalid)
                        .keyboardShortcut("s")
                }
            }
            .padding(6)
        } label: {
            Text("说明")
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
            Text("文件里的注释")
        }
    }

    private var infoBox: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                infoRow("录入", item.m("added").isEmpty ? "—" : item.m("added"))
                infoRow("上次换新", item.m("rotated").isEmpty ? "—" : item.m("rotated"))
                infoRow("上次使用", item.lastUsed.map { "\(DateFormats.relativeText(item.lastUsedDate))（\($0.replacingOccurrences(of: "T", with: " "))）" } ?? "还没记录到")
                infoRow("长度", "\(item.length) 位")
                infoRow("在脚本里", "$\(item.name)")
            }
            .font(.callout)
            .padding(6)
            Text("“上次使用”只记录通过 key 取用的情况（如 MCP 服务启动、key get）；脚本直接读环境变量不会记录。")
                .font(.caption).foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
        } label: {
            Text("记录")
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
            Text("给 \(name) 换新值").font(.title3.weight(.semibold))
            Text("旧值会留在本地快照里。说明字段不变，“上次换新”记为今天。")
                .font(.callout).foregroundStyle(.secondary)
            ValueField(value: $value)
            if let e = error { Text(e).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(busy ? "保存中…" : "保存") {
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
                    TextField(secret ? "密钥值" : "值，例如 https://api.example.com/v1", text: $value)
                } else {
                    SecureField("密钥值", text: $value)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            if secret {
                Button { visible.toggle() } label: { Image(systemName: visible ? "eye.slash" : "eye") }
                    .buttonStyle(.borderless)
                    .help(visible ? "隐藏" : "显示")
            }
            Button("从剪贴板粘贴") {
                value = (NSPasteboard.general.string(forType: .string) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}
