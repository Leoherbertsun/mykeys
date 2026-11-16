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
    @State private var section = ""
    @State private var meta: [String: String] = [:]
    @State private var error: String?
    @State private var busy = false

    private var nameValid: Bool { name.range(of: "^[A-Z][A-Z0-9_]*$", options: .regularExpression) != nil }
    private var exists: Bool { store.items.contains { $0.name == name } }
    private var expiryInvalid: Bool {
        let e = (meta["expires"] ?? "").trimmingCharacters(in: .whitespaces)
        return !e.isEmpty && DateFormats.day.date(from: e) == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(group.isEmpty ? "添加密钥" : "给 \(group) 加一条相关配置").font(.title2.weight(.semibold))

            Picker("类型", selection: $kind) {
                Text("密钥：要保密的").tag("secret")
                Text("配置：接口地址、地域、编号等").tag("config")
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()

            VStack(alignment: .leading, spacing: 6) {
                Text("名字（脚本里就用这个名字取）").font(.callout).foregroundStyle(.secondary)
                TextField(kind == "config" ? "例如 DEEPSEEK_BASE_URL" : "例如 TAVILY_API_KEY_5", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: name) { _, n in
                        let fixed = n.uppercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
                        if fixed != n { name = fixed }
                    }
                if !name.isEmpty && !nameValid {
                    Text("只能用大写字母、数字和下划线，并以字母开头").font(.caption).foregroundStyle(.red)
                } else if exists {
                    Text("这个名字已经有了：保存会把它换成新值，说明字段只补充不清空").font(.caption).foregroundStyle(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(kind == "config" ? "值" : "密钥值").font(.callout).foregroundStyle(.secondary)
                ValueField(value: $value, secret: kind == "secret")
            }

            HStack(spacing: 18) {
                Picker("属于", selection: $group) {
                    Text("不属于别的条目").tag("")
                    ForEach(store.topLevel) { Text($0.name).tag($0.name) }
                }
                .frame(maxWidth: 300)
                if group.isEmpty {
                    Picker("分类", selection: $section) {
                        Text("未分类").tag("")
                        ForEach(store.sections.filter { $0 != "未分类" }, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            if !group.isEmpty {
                Text("会挂在 \(group) 下面，主列表里不单独占一行。").font(.caption).foregroundStyle(.secondary)
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
                Text("到期日要写成 2027-01-11 这样的格式").font(.caption).foregroundStyle(.red)
            }
            Text(kind == "secret" ? "说明都可以以后再补。填了到期日，会在“提醒事项”里提前 7 天提醒。"
                                  : "配置不是秘密，会直接显示出来。")
                .font(.caption).foregroundStyle(.tertiary)

            if let e = error {
                Text(e).foregroundStyle(.red).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(busy ? "保存中…" : (exists ? "换成新值" : "保存")) { Task { await save() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!nameValid || value.trimmingCharacters(in: .whitespaces).isEmpty || busy || expiryInvalid)
            }
        }
        .padding(24)
        .frame(width: 560)
        .onAppear {
            section = presetSection.flatMap { $0 == "未分类" ? nil : $0 } ?? ""
            group = presetGroup
            kind = presetKind
            if !presetGroup.isEmpty { name = presetGroup.replacingOccurrences(of: "_API_KEY", with: "") + "_" }
        }
    }

    private func save() async {
        busy = true
        defer { busy = false }
        var m = meta
        m["kind"] = kind
        if !group.isEmpty { m["group"] = group }
        error = await store.add(name: name, value: value, section: group.isEmpty && !section.isEmpty ? section : nil, meta: m)
        if error == nil {
            onAdded(name)
            dismiss()
        }
    }
}
