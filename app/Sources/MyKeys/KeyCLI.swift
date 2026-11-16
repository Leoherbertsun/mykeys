import Foundation

/// 所有读写都交给命令行小工具 key 去做，App 自己不碰 keys.env，保证只有一套逻辑。
enum KeyCLI {
    static var binary: String {
        if let p = ProcessInfo.processInfo.environment["MYKEYS_KEY_BIN"] { return p }
        let installed = NSHomeDirectory() + "/.local/bin/key"
        if FileManager.default.isExecutableFile(atPath: installed) { return installed }
        // 只下载了 App、还没装命令行工具时，用 App 里自带的那一份
        return Bundle.main.path(forResource: "key", ofType: nil) ?? installed
    }

    struct Result {
        let code: Int32
        let out: String
        let err: String
        var ok: Bool { code == 0 }
        /// 给人看的错误信息：去掉 “key：” / “key: ” 前缀
        var message: String {
            let text = (err.isEmpty ? out : err).trimmingCharacters(in: .whitespacesAndNewlines)
            for prefix in ["key：", "key: "] where text.hasPrefix(prefix) {
                return String(text.dropFirst(prefix.count))
            }
            return text
        }
    }

    static func run(_ args: [String], stdin: String? = nil) async -> Result {
        await Task.detached(priority: .userInitiated) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: binary)
            p.arguments = args
            // 让 key 的提示和界面用同一种语言（已经设了 MYKEYS_LANG 就沿用）
            var env = ProcessInfo.processInfo.environment
            if env["MYKEYS_LANG"] == nil { env["MYKEYS_LANG"] = Lang.code }
            p.environment = env
            let outPipe = Pipe(), errPipe = Pipe(), inPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            p.standardInput = inPipe
            do {
                try p.run()
            } catch {
                return Result(code: -1, out: "", err: L("找不到小工具 key（\(binary)）：\(error.localizedDescription)",
                                                      "Can't find the key command-line tool (\(binary)): \(error.localizedDescription)"))
            }
            if let s = stdin { inPipe.fileHandleForWriting.write(Data(s.utf8)) }
            try? inPipe.fileHandleForWriting.close()
            let out = outPipe.fileHandleForReading.readDataToEndOfFile()
            let err = errPipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return Result(code: p.terminationStatus,
                          out: String(decoding: out, as: UTF8.self),
                          err: String(decoding: err, as: UTF8.self))
        }.value
    }
}
