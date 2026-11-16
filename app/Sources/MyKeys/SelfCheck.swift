import AppKit
import SwiftUI

/// 开发自查：设置环境变量 MYKEYS_SELFCHECK_DIR 时，App 按固定步骤操作一遍并把每一步的窗口画面存成 PNG，然后退出。
/// 平时不设这个变量，这段代码不会运行。
enum SelfCheck {
    static var dir: String? { ProcessInfo.processInfo.environment["MYKEYS_SELFCHECK_DIR"] }

    static let selectKey = Notification.Name("MyKeys.selfcheck.select")
    static let setFilter = Notification.Name("MyKeys.selfcheck.filter")
    static let setSearch = Notification.Name("MyKeys.selfcheck.search")
    static let reveal = Notification.Name("MyKeys.selfcheck.reveal")

    @MainActor
    static func runIfNeeded(_ store: KeyStore) {
        guard let dir else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        Task { @MainActor in
            func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
            func post(_ n: Notification.Name, _ obj: Any? = nil) { NotificationCenter.default.post(name: n, object: obj) }
            await wait(2)
            snap("1-列表")
            post(selectKey, "DEEPSEEK_API_KEY")
            await wait(1)
            snap("2-详情")
            post(reveal)
            await wait(1.5)
            snap("3-显示值")
            post(setFilter, "expiring")
            post(selectKey, "OLD_TOKEN")
            await wait(1)
            snap("4-快到期")
            post(setFilter, "all")
            post(setSearch, "tavily")
            await wait(1)
            snap("5-搜索")
            post(setSearch, "")
            post(.addKey)
            await wait(1.5)
            snap("6-添加")
            // 通过 App 自己的读写通道走一遍：录入 → 改说明 → 挂配置 → 换新值 → 拦坏值 → 删除
            var log: [String] = []
            @MainActor func item(_ n: String) -> KeyItem? { store.items.first { $0.name == n } }
            let e1 = await store.add(name: "SELFCHECK_KEY", value: "sk-selfcheck-111111", section: "搜索",
                                     meta: ["platform": "测试平台", "account": "me@example.com", "note": "带 空格 的备注"])
            log.append("录入：\(e1 ?? "成功")；分类：\(item("SELFCHECK_KEY")?.section ?? "无")")
            let ok = await store.saveMeta("SELFCHECK_KEY", changes: ["purpose": "自查用", "account": ""])
            let it = item("SELFCHECK_KEY")
            log.append("改说明：\(ok)；平台=\(it?.m("platform") ?? "")；账号=\(it?.m("account") ?? "")（应为空）；用途=\(it?.m("purpose") ?? "")；备注=\(it?.m("note") ?? "")")
            let e4 = await store.add(name: "SELFCHECK_BASE_URL", value: "https://api.example.com/v1", section: nil,
                                     meta: ["kind": "config", "group": "SELFCHECK_KEY"])
            log.append("挂配置：\(e4 ?? "成功")；类型=\(item("SELFCHECK_BASE_URL")?.kind ?? "")；归属=\(item("SELFCHECK_BASE_URL")?.group ?? "")；明文值=\(item("SELFCHECK_BASE_URL")?.value ?? "无")；主列表里不单列：\(!store.topLevel.contains { $0.name == "SELFCHECK_BASE_URL" })；子项数=\(store.children(of: "SELFCHECK_KEY").count)")
            post(selectKey, "SELFCHECK_KEY")
            await wait(1)
            snap("7-相关配置")
            let e2 = await store.add(name: "SELFCHECK_KEY", value: "sk-selfcheck-222222", section: nil, meta: [:])
            let v = await store.reveal("SELFCHECK_KEY")
            log.append("换新值：\(e2 ?? "成功")；新值正确：\(v == "sk-selfcheck-222222")；轮换日=\(item("SELFCHECK_KEY")?.m("rotated") ?? "")；平台还在：\(item("SELFCHECK_KEY")?.m("platform") ?? "")")
            let e3 = await store.add(name: "BAD", value: "has space", section: nil, meta: [:])
            log.append("坏值被拒：\(e3 ?? "没被拒！")")
            await store.delete("SELFCHECK_BASE_URL")
            await store.delete("SELFCHECK_KEY")
            log.append("删除后还在：\(item("SELFCHECK_KEY") != nil || item("SELFCHECK_BASE_URL") != nil)")
            try? log.joined(separator: "\n").write(toFile: "\(dir)/8-读写.txt", atomically: true, encoding: .utf8)
            exit(0)
        }
    }

    /// 把窗口里的表格和侧栏有几行、各行写了什么记下来，截图看不清时用来核对
    @MainActor
    static func dumpTables(_ name: String) {
        guard let dir else { return }
        var lines: [String] = []
        func allText(_ v: NSView) -> [String] {
            var out: [String] = []
            if let tf = v as? NSTextField { out.append(tf.stringValue) }
            for s in v.subviews { out += allText(s) }
            return out
        }
        func walk(_ v: NSView) {
            if let t = v as? NSTableView {
                lines.append("\(type(of: t)) 行数=\(t.numberOfRows)")
                for r in 0..<t.numberOfRows {
                    var row: [String] = []
                    for c in 0..<t.numberOfColumns {
                        if let cell = t.view(atColumn: c, row: r, makeIfNecessary: true) {
                            row.append(allText(cell).joined(separator: " "))
                        }
                    }
                    lines.append("  " + row.joined(separator: " | "))
                }
            }
            v.subviews.forEach(walk)
        }
        for w in NSApp.windows where w.isVisible { if let c = w.contentView { walk(c) } }
        try? lines.joined(separator: "\n").write(toFile: "\(dir)/\(name).txt", atomically: true, encoding: .utf8)
    }

    @MainActor
    static func snap(_ name: String) {
        guard let dir else { return }
        dumpTables(name)
        for (i, w) in NSApp.windows.enumerated() where w.isVisible && w.frame.width > 200 {
            guard let view = w.contentView?.superview ?? w.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            let suffix = i == 0 ? "" : "-窗口\(i)"
            try? rep.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: "\(dir)/\(name)\(suffix).png"))
        }
    }
}
