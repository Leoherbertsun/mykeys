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

    private var toastTask: Task<Void, Never>?

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
            loadError = "读不懂 key 的输出（可能需要更新命令行工具 key）：\(error.localizedDescription)"
        }
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
        show(r.ok ? "已复制 \(name)，45 秒后自动清空剪贴板" : r.message)
        await reload()
    }

    /// 改说明字段。changes 里值为空表示删掉这个字段
    func saveMeta(_ name: String, changes: [String: String]) async -> Bool {
        guard !changes.isEmpty else { return true }
        let args = ["set", name] + changes.map { "\($0.key)=\($0.value)" }
        let r = await KeyCLI.run(args)
        show(r.ok ? "已保存 \(name) 的说明" : r.message)
        await reload()
        return r.ok
    }

    /// 录入新密钥或给已有的换新值。成功返回 nil，失败返回错误信息
    func add(name: String, value: String, section: String?, meta: [String: String]) async -> String? {
        var args = ["add", name, "--stdin"]
        if let s = section, !s.isEmpty, s != "未分类" { args += ["--section", s] }
        for (k, v) in meta where !v.trimmingCharacters(in: .whitespaces).isEmpty {
            args += ["--meta", "\(k)=\(v)"]
        }
        let r = await KeyCLI.run(args, stdin: value)
        await reload()
        if r.ok {
            // 值如果是从剪贴板粘进来的，存好后把剪贴板清掉
            let pb = NSPasteboard.general
            if pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) == value.trimmingCharacters(in: .whitespacesAndNewlines) {
                pb.clearContents()
            }
            show(r.out.contains("换成新值") ? "\(name) 已换成新值" : "\(name) 已存好")
            return nil
        }
        return r.message.replacingOccurrences(of: "确认没错就加 --force", with: "请检查是不是复制错了")
    }

    func delete(_ name: String) async {
        let r = await KeyCLI.run(["del", name])
        show(r.ok ? "\(name) 已删除（旧值留在本地快照里）" : r.message)
        await reload()
    }

    func backupNow() async {
        show("正在备份到 iCloud……")
        let r = await KeyCLI.run(["backup"])
        show(r.ok ? "已备份到 iCloud 云盘「个人/密钥备份」" : r.message)
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
        ctx.localizedCancelTitle = "取消"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            lastError = "这台 Mac 没法验证身份：\(err?.localizedDescription ?? "")"
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "查看你的 API 密钥") { ok, error in
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
