import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: KeyStore
    @EnvironmentObject var lock: AppLock
    @State private var filter: SidebarFilter? = .all
    @State private var selection: KeyItem.ID?
    @State private var search = ""
    @State private var showAdd = false
    @State private var sortOrder: [KeyPathComparator<KeyItem>] = []

    private var visible: [KeyItem] {
        var list = store.topLevel
        switch filter ?? .all {
        case .all: break
        case .expiring: list = list.filter(\.isExpiringSoon)
        case .section(let s): list = list.filter { $0.sectionTitle == s }
        case .tag(let t): list = list.filter { $0.tags.contains(t) }
        }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            let words = q.split(separator: " ").map(String.init)
            // 搜到附属条目（如接口地址）时，显示它所属的主密钥
            list = list.filter { item in
                let text = ([item] + store.children(of: item.name)).map(\.searchText).joined(separator: " ")
                return words.allSatisfy { text.contains($0) }
            }
        }
        if !sortOrder.isEmpty { list.sort(using: sortOrder) }
        return list
    }

    private var selectedItem: KeyItem? {
        store.items.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 260)
        } content: {
            table
                .safeAreaInset(edge: .bottom, spacing: 0) { statusBar }
                .navigationSplitViewColumnWidth(min: 460, ideal: 620)
        } detail: {
            if let item = selectedItem {
                DetailView(item: item)
                    .id(item.id)
            } else {
                ContentUnavailableView(L("选一个密钥", "No Key Selected"), systemImage: "key.horizontal",
                                       description: Text(L("左边筛选，上面搜索；⌘N 添加新密钥",
                                                           "Filter on the left, search above, or press ⌘N to add a key.")))
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: L("搜索名字、平台、账号、用途……", "Search names, platforms, accounts, purposes…"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showAdd = true } label: { Label(L("添加", "Add"), systemImage: "plus") }
                    .help(L("添加密钥（⌘N）", "Add Key (⌘N)"))
                Button { Task { await store.reload() } } label: { Label(L("刷新", "Refresh"), systemImage: "arrow.clockwise") }
                    .help(L("刷新（⌘R）", "Refresh (⌘R)"))
                Button { lock.lock() } label: { Label(L("锁定", "Lock"), systemImage: "lock") }
                    .help(L("锁定（⌘L）", "Lock (⌘L)"))
            }
        }
        .sheet(isPresented: $showAdd) {
            AddKeyView(presetSection: currentSection) { name in selection = name }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addKey)) { _ in showAdd = true }
        .onReceive(NotificationCenter.default.publisher(for: SelfCheck.selectKey)) { selection = $0.object as? String }
        .onReceive(NotificationCenter.default.publisher(for: .selectKey)) { selection = $0.object as? String }
        .onReceive(NotificationCenter.default.publisher(for: SelfCheck.setSearch)) { search = $0.object as? String ?? "" }
        .onReceive(NotificationCenter.default.publisher(for: SelfCheck.setFilter)) {
            filter = ($0.object as? String) == "expiring" ? .expiring : .all
        }
    }

    private var currentSection: String? {
        if case .section(let s) = filter ?? .all { return s }
        return nil
    }

    // MARK: 左侧栏

    private var sidebar: some View {
        List(selection: $filter) {
            Section {
                Label(L("全部", "All Keys"), systemImage: "tray.full")
                    .badge(store.topLevel.count)
                    .tag(SidebarFilter.all)
                Label(L("快到期", "Expiring Soon"), systemImage: "clock.badge.exclamationmark")
                    .badge(store.expiringCount)
                    .foregroundStyle(store.expiringCount > 0 ? .orange : .primary)
                    .tag(SidebarFilter.expiring)
            }
            Section(L("分类", "Categories")) {
                ForEach(store.sections, id: \.self) { s in
                    Label(s, systemImage: icon(for: s))
                        .badge(store.topLevel.filter { $0.sectionTitle == s }.count)
                        .tag(SidebarFilter.section(s))
                }
            }
            if !store.allTags.isEmpty {
                Section(L("标签", "Tags")) {
                    ForEach(store.allTags, id: \.self) { t in
                        Label(t, systemImage: "tag").tag(SidebarFilter.tag(t))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    /// 按分类名挑图标，中英文都认。分类名来自用户的文件，认不出的用文件夹。
    /// 顺序有讲究：“数据库”要排在“数据”前，“云服务与开发”要排在“服务”前。
    private func icon(for section: String) -> String {
        let lower = section.lowercased()
        // 英文按单词比，避免 “ai” 误中 “email”、“db” 误中别的词
        let words = Set(lower.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        func has(_ zh: [String], words en: [String] = [], prefixes: [String] = []) -> Bool {
            zh.contains { section.contains($0) } || en.contains { words.contains($0) }
                || prefixes.contains { p in words.contains { $0.hasPrefix(p) } }
        }
        if has(["数据库", "存储"], words: ["db", "sql"], prefixes: ["database", "storage", "postgres", "redis", "mongo"]) {
            return "cylinder.split.1x2"
        }
        if has(["搜索", "检索", "爬"], prefixes: ["search", "crawl", "scrap"]) { return "magnifyingglass" }
        if has(["模型", "智能", "人工智能"], words: ["ai", "llm", "llms", "gpt"], prefixes: ["model", "intelligence"]) {
            return "brain"
        }
        if has(["数据", "金融", "行情", "财经", "投研"], prefixes: ["data", "financ", "market", "stock", "quant"]) {
            return "chart.line.uptrend.xyaxis"
        }
        if has(["云", "开发", "部署", "代码"], words: ["dev", "devops", "ci"], prefixes: ["cloud", "develop", "deploy", "hosting", "infra", "code"]) {
            return "cloud"
        }
        if has(["邮件", "邮箱"], prefixes: ["mail", "email"]) { return "envelope" }
        if has(["消息", "通知", "聊天", "通讯", "短信"], words: ["sms", "im"], prefixes: ["messag", "notif", "chat", "communication", "alert"]) {
            return "bubble.left.and.bubble.right"
        }
        if has(["支付", "付款", "收款", "账单", "财务"], prefixes: ["pay", "billing", "checkout"]) { return "creditcard" }
        if has(["地图", "位置"], prefixes: ["map", "geo", "location"]) { return "map" }
        if has(["社交", "社区"], prefixes: ["social"]) { return "person.2" }
        if has(["工具", "服务", "其他", "其它"], prefixes: ["tool", "service", "util", "other", "misc"]) {
            return "wrench.and.screwdriver"
        }
        return "folder"
    }

    // MARK: 中间表格

    private var table: some View {
        Table(visible, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(L("名称", "Name"), value: \.name) { item in
                HStack(spacing: 6) {
                    Text(item.name).font(.system(.body, design: .monospaced))
                    let n = store.children(of: item.name).count
                    if n > 0 {
                        Text("+\(n)").font(.caption2).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                            .help(L("还有 \(n) 条相关配置，在右边详情里",
                                    "\(plural(n, "more related item")) in the details on the right"))
                    }
                }
            }
            .width(min: 160, ideal: 210)
            TableColumn(L("平台", "Platform"), value: \.sortPlatform) { item in
                Text(item.m("platform")).foregroundStyle(item.m("platform").isEmpty ? .tertiary : .primary)
            }
            .width(min: 60, ideal: 90)
            TableColumn(L("账号", "Account"), value: \.sortAccount) { item in
                Text(item.m("account")).lineLimit(1)
            }
            .width(min: 60, ideal: 110)
            TableColumn(L("到期", "Expires"), value: \.sortExpiry) { item in
                ExpiryText(item: item)
            }
            .width(min: 80, ideal: 100)
            TableColumn(L("上次使用", "Last Used"), value: \.sortLastUsed) { item in
                Text(DateFormats.relativeText(item.lastUsedDate)).foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 90)
        }
        .overlay {
            if let e = store.loadError {
                ContentUnavailableView(L("读不到密钥", "Can't Load Keys"), systemImage: "exclamationmark.triangle", description: Text(e))
            } else if visible.isEmpty && !store.isLoading {
                ContentUnavailableView.search(text: search)
            }
        }
        .contextMenu(forSelectionType: KeyItem.ID.self) { ids in
            if let id = ids.first {
                Button(L("复制值", "Copy Value")) { Task { await store.copy(id) } }
                Button(L("复制名字", "Copy Name")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(id, forType: .string)
                }
            }
        }
    }

    // MARK: 底部状态栏

    private var statusBar: some View {
        HStack(spacing: 10) {
            if let t = store.toast {
                Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                Text(t)
            } else {
                Text(L("\(visible.count) 个密钥", plural(visible.count, "key")))
                if store.items.count > store.topLevel.count {
                    let n = store.items.count - store.topLevel.count
                    Text(L("· 另有 \(n) 条配置挂在各自的密钥下", "· \(plural(n, "more item")) grouped under their keys"))
                        .foregroundStyle(.secondary)
                }
                if store.expiringCount > 0 {
                    Text(L("· \(store.expiringCount) 个 30 天内到期", "· \(store.expiringCount) expiring within 30 days"))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
        .animation(.default, value: store.toast)
    }
}

struct ExpiryText: View {
    let item: KeyItem
    var body: some View {
        if let d = item.daysLeft {
            if d < 0 {
                Text(L("已过期", "Expired")).foregroundStyle(.red).fontWeight(.medium)
            } else if d <= 30 {
                Text(item.m("expires")).foregroundStyle(.orange).help(L("还剩 \(d) 天", "\(plural(d, "day")) left"))
            } else {
                Text(item.m("expires"))
            }
        } else if !item.m("expires").isEmpty {
            Text(item.m("expires")).foregroundStyle(.red).help(L("日期格式应为 2027-01-11", "Use the format 2027-01-11"))
        } else {
            Text("—").foregroundStyle(.tertiary)
        }
    }
}
