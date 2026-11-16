import AppKit
import Foundation
import LocalAuthentication

@MainActor
final class KeyStore: ObservableObject {
    @Published var items: [KeyItem] = []
    @Published var loadError: String?
    @Published var isLoading = false
    /// 底部状态栏里的一句话提示，几秒后自动消失
    @Published var toast: String?
    /// 命令行 key catalog --json 给出的平台目录，添加表单按名字自动补全时用；第一次需要时加载
    @Published private(set) var catalog: KeyCatalog?

    private var toastTask: Task<Void, Never>?
    private var catalogRequested = false

    var sections: [String] {
        var seen: [String] = []
        for i in topLevel where !seen.contains(i.sectionTitle) { seen.append(i.sectionTitle) }
        return seen
    }

    var allTags: [String] {
        var seen: [String] = []
        for i in topLevel { for t in i.tags where !seen.contains(t) { seen.append(t) } }
        return seen
    }

    var expiringCount: Int { topLevel.filter(\.isExpiringSoon).count }

    /// 主列表里显示的：不归属于别的条目的（归属的条目已不存在时也算顶层）
    var topLevel: [KeyItem] {
        let names = Set(items.map(\.name))
        return items.filter { $0.group.isEmpty || !names.contains($0.group) }
    }

    func children(of name: String) -> [KeyItem] { items.filter { $0.group == name } }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        let r = await KeyCLI.run(["ls", "--json"])
        guard r.ok else {
            loadError = r.message
            return
        }
        do {
            items = try JSONDecoder().decode([KeyItem].self, from: Data(r.out.utf8))
            loadError = nil
        } catch {
            loadError = L("读不懂 key 的输出（可能需要更新命令行工具 key）：\(error.localizedDescription)",
                          "Couldn't read the output of key (the command-line tool may need updating): \(error.localizedDescription)")
        }
    }

    /// 加载一次平台目录并缓存。旧版 key 没有这个命令时就不自动补全，不报错
    func loadCatalog() async {
        guard !catalogRequested else { return }
        catalogRequested = true
        let r = await KeyCLI.run(["catalog", "--json"])
        guard r.ok, let c = try? JSONDecoder().decode(KeyCatalog.self, from: Data(r.out.utf8)) else { return }
        catalog = c
    }

    func show(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { toast = nil }
        }
    }

    /// 取出明文，只在“显示”时用，不算作一次“使用”
    func reveal(_ name: String) async -> String? {
        let r = await KeyCLI.run(["get", "--no-log", name])
        if !r.ok { show(r.message); return nil }
        return r.out
    }

    func copy(_ name: String) async {
        let r = await KeyCLI.run(["copy", name])
        show(r.ok ? L("已复制 \(name)，45 秒后自动清空剪贴板", "Copied \(name). The clipboard clears in 45 seconds.") : r.message)
        await reload()
    }

    /// 改说明字段。changes 里值为空表示删掉这个字段
    func saveMeta(_ name: String, changes: [String: String]) async -> Bool {
        guard !changes.isEmpty else { return true }
        let args = ["set", name] + changes.map { "\($0.key)=\($0.value)" }
        let r = await KeyCLI.run(args)
        show(r.ok ? L("已保存 \(name) 的说明", "Saved details for \(name)") : r.message)
        await reload()
        return r.ok
    }

    /// 录入新密钥或给已有的换新值。成功返回 nil，失败返回错误信息
    func add(name: String, value: String, section: String?, meta: [String: String]) async -> String? {
        var args = ["add", name, "--stdin"]
        if let s = section, !s.isEmpty, s != KeyItem.uncategorized { args += ["--section", s] }
        for (k, v) in meta where !v.trimmingCharacters(in: .whitespaces).isEmpty {
            args += ["--meta", "\(k)=\(v)"]
        }
        // 保存前就有这个名字，说明是换新值（不靠命令行输出的文字判断，它可能是任一种语言）
        let existed = items.contains { $0.name == name }
        let r = await KeyCLI.run(args, stdin: value)
        await reload()
        if r.ok {
            // 值如果是从剪贴板粘进来的，存好后把剪贴板清掉
            let pb = NSPasteboard.general
            if pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) == value.trimmingCharacters(in: .whitespacesAndNewlines) {
                pb.clearContents()
            }
            show(existed ? L("\(name) 已换成新值", "Updated \(name) with the new value") : L("\(name) 已存好", "Saved \(name)"))
            return nil
        }
        return Self.dropForceHint(r.message)
    }

    /// 命令行拦下可疑的值时会提示“确认没错就加 --force”，App 里没有这个开关：把含 --force 的那一句换成检查提示
    static func dropForceHint(_ message: String) -> String {
        guard let hit = message.range(of: "--force") else { return message }
        // 句子开头：往前找最近的句末标点（中文句号、分号、换行，或英文句号/分号后跟空格）
        var start = message.startIndex
        for sep in ["。", "；", "\n", ". ", "; ", "! "] {
            if let r = message.range(of: sep, options: .backwards, range: message.startIndex..<hit.lowerBound),
               r.upperBound > start {
                start = r.upperBound
            }
        }
        // 句子结尾：往后找最近的句末标点，找不到就到结尾
        var end = message.endIndex
        for sep in ["。", "；", "\n", ". ", "; "] {
            if let r = message.range(of: sep, range: hit.upperBound..<message.endIndex), r.upperBound < end {
                end = r.upperBound
            }
        }
        var rest = message
        rest.removeSubrange(start..<end)
        rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        let hint = L("请检查是不是复制错了", "Check that you copied the right value.")
        if rest.isEmpty { return hint }
        // 按剩下那句话自己的标点接上，不管它是哪种语言
        switch rest.last {
        case "。", "！", "？": return rest + hint
        case ".", "!", "?": return rest + " " + hint
        default: return rest + (Lang.isChinese ? "。" : ". ") + hint
        }
    }

    func delete(_ name: String) async {
        let r = await KeyCLI.run(["del", name])
        show(r.ok ? L("\(name) 已删除（旧值留在本地快照里）", "Deleted \(name). The old value is kept in a local snapshot.") : r.message)
        await reload()
    }

    func backupNow() async {
        show(L("正在备份到 iCloud……", "Backing up to iCloud…"))
        let r = await KeyCLI.run(["backup"])
        // 备份位置可在 config.json 里改，成功时直接用 key 自己报的那一行（写明了备份到哪里）
        let reported = r.out.split(separator: "\n").last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        show(r.ok ? reported.map { $0.trimmingCharacters(in: .whitespaces) } ?? L("已备份到 iCloud", "Backed up to iCloud") : r.message)
    }

    var keysFilePath: String {
        ProcessInfo.processInfo.environment["KEY_FILE"] ?? NSHomeDirectory() + "/.config/secrets/keys.env"
    }
}

/// Touch ID / 开机密码解锁；离开超过 5 分钟或电脑睡眠后自动上锁
@MainActor
final class AppLock: ObservableObject {
    @Published var isUnlocked: Bool
    @Published var lastError: String?
    private var resignedAt: Date?
    private let idleLimit: TimeInterval = 5 * 60

    init() {
        isUnlocked = ProcessInfo.processInfo.environment["MYKEYS_NO_LOCK"] == "1"
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resignedAt = Date() }
        }
        nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, let t = self.resignedAt else { return }
                if Date().timeIntervalSince(t) > self.idleLimit { self.lock() }
            }
        }
        let wnc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            wnc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.lock() }
            }
        }
    }

    func lock() {
        guard ProcessInfo.processInfo.environment["MYKEYS_NO_LOCK"] != "1" else { return }
        isUnlocked = false
    }

    func unlock() {
        let ctx = LAContext()
        ctx.localizedCancelTitle = L("取消", "Cancel")
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            lastError = L("这台 Mac 没法验证身份：\(err?.localizedDescription ?? "")",
                          "This Mac can't verify your identity: \(err?.localizedDescription ?? "")")
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L("查看你的 API 密钥", "view your API keys")) { ok, error in
            Task { @MainActor in
                if ok {
                    self.isUnlocked = true
                    self.lastError = nil
                } else if let e = error as? LAError, e.code != .userCancel, e.code != .appCancel, e.code != .systemCancel {
                    self.lastError = e.localizedDescription
                }
            }
        }
    }
}
