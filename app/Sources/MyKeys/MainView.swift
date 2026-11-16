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
                ContentUnavailableView("选一个密钥", systemImage: "key.horizontal",
                                       description: Text("左边筛选，上面搜索；⌘N 添加新密钥"))
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "搜索名字、平台、账号、用途……")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showAdd = true } label: { Label("添加", systemImage: "plus") }
                    .help("添加密钥（⌘N）")
                Button { Task { await store.reload() } } label: { Label("刷新", systemImage: "arrow.clockwise") }
                    .help("刷新（⌘R）")
                Button { lock.lock() } label: { Label("锁定", systemImage: "lock") }
                    .help("锁定（⌘L）")
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
                Label("全部", systemImage: "tray.full")
                    .badge(store.topLevel.count)
                    .tag(SidebarFilter.all)
                Label("快到期", systemImage: "clock.badge.exclamationmark")
                    .badge(store.expiringCount)
                    .foregroundStyle(store.expiringCount > 0 ? .orange : .primary)
                    .tag(SidebarFilter.expiring)
            }
            Section("分类") {
                ForEach(store.sections, id: \.self) { s in
                    Label(s, systemImage: icon(for: s))
                        .badge(store.topLevel.filter { $0.sectionTitle == s }.count)
                        .tag(SidebarFilter.section(s))
                }
            }
            if !store.allTags.isEmpty {
                Section("标签") {
                    ForEach(store.allTags, id: \.self) { t in
                        Label(t, systemImage: "tag").tag(SidebarFilter.tag(t))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func icon(for section: String) -> String {
        if section.contains("模型") { return "brain" }
        if section.contains("金融") || section.contains("数据") { return "chart.line.uptrend.xyaxis" }
        if section.contains("搜索") { return "magnifyingglass" }
        if section.contains("工具") || section.contains("服务") { return "wrench.and.screwdriver" }
        return "folder"
    }

    // MARK: 中间表格

    private var table: some View {
        Table(visible, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("名称", value: \.name) { item in
                HStack(spacing: 6) {
                    Text(item.name).font(.system(.body, design: .monospaced))
                    let n = store.children(of: item.name).count
                    if n > 0 {
                        Text("+\(n)").font(.caption2).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                            .help("还有 \(n) 条相关配置，在右边详情里")
                    }
                }
            }
            .width(min: 160, ideal: 210)
            TableColumn("平台", value: \.sortPlatform) { item in
                Text(item.m("platform")).foregroundStyle(item.m("platform").isEmpty ? .tertiary : .primary)
            }
            .width(min: 60, ideal: 90)
            TableColumn("账号", value: \.sortAccount) { item in
                Text(item.m("account")).lineLimit(1)
            }
            .width(min: 60, ideal: 110)
            TableColumn("到期", value: \.sortExpiry) { item in
                ExpiryText(item: item)
            }
            .width(min: 80, ideal: 100)
            TableColumn("上次使用", value: \.sortLastUsed) { item in
                Text(DateFormats.relativeText(item.lastUsedDate)).foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 90)
        }
        .overlay {
            if let e = store.loadError {
                ContentUnavailableView("读不到密钥", systemImage: "exclamationmark.triangle", description: Text(e))
            } else if visible.isEmpty && !store.isLoading {
                ContentUnavailableView.search(text: search)
            }
        }
        .contextMenu(forSelectionType: KeyItem.ID.self) { ids in
            if let id = ids.first {
                Button("复制值") { Task { await store.copy(id) } }
                Button("复制名字") {
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
                Text("\(visible.count) 个密钥")
                if store.items.count > store.topLevel.count {
                    Text("· 另有 \(store.items.count - store.topLevel.count) 条配置挂在各自的密钥下").foregroundStyle(.secondary)
                }
                if store.expiringCount > 0 {
                    Text("· \(store.expiringCount) 个 30 天内到期").foregroundStyle(.orange)
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
                Text("已过期").foregroundStyle(.red).fontWeight(.medium)
            } else if d <= 30 {
                Text(item.m("expires")).foregroundStyle(.orange).help("还剩 \(d) 天")
            } else {
                Text(item.m("expires"))
            }
        } else if !item.m("expires").isEmpty {
            Text(item.m("expires")).foregroundStyle(.red).help("日期格式应为 2027-01-11")
        } else {
            Text("—").foregroundStyle(.tertiary)
        }
    }
}
