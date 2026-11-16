import AppKit
import SwiftUI

@main
struct MyKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = KeyStore()
    @StateObject private var lock = AppLock()

    var body: some Scene {
        Window("My Keys", id: "main") {
            RootView()
                .environmentObject(store)
                .environmentObject(lock)
                .frame(minWidth: 980, minHeight: 560)
        }
        .defaultSize(width: 1240, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加密钥…") { NotificationCenter.default.post(name: .addKey, object: nil) }
                    .keyboardShortcut("n")
            }
            CommandMenu("密钥") {
                Button("刷新") { Task { await store.reload() } }
                    .keyboardShortcut("r")
                Button("立即备份到 iCloud") { Task { await store.backupNow() } }
                Button("在访达中显示密钥文件") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: store.keysFilePath)])
                }
                Divider()
                Button("锁定") { lock.lock() }
                    .keyboardShortcut("l")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let addKey = Notification.Name("MyKeys.addKey")
}

struct RootView: View {
    @EnvironmentObject var store: KeyStore
    @EnvironmentObject var lock: AppLock

    var body: some View {
        Group {
            if lock.isUnlocked {
                MainView()
                    .task {
                        await store.reload()
                        SelfCheck.runIfNeeded(store)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                        Task { await store.reload() }
                    }
            } else {
                LockView()
            }
        }
    }
}

struct LockView: View {
    @EnvironmentObject var lock: AppLock

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.tint)
            Text("My Keys").font(.largeTitle.weight(.semibold))
            Text("你的 API 密钥都在这里。用 Touch ID 或开机密码解锁。")
                .foregroundStyle(.secondary)
            Button {
                lock.unlock()
            } label: {
                Label("解锁", systemImage: "touchid").frame(minWidth: 120)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            if let e = lock.lastError {
                Text(e).font(.callout).foregroundStyle(.red)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { lock.unlock() }
    }
}
