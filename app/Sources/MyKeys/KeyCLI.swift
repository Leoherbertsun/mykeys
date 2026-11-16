import Foundation

/// 所有读写都交给命令行小工具 key 去做，App 自己不碰 keys.env，保证只有一套逻辑。
enum KeyCLI {
    static var binary: String {
        ProcessInfo.processInfo.environment["MYKEYS_KEY_BIN"] ?? NSHomeDirectory() + "/.local/bin/key"
    }

    struct Result {
        let code: Int32
        let out: String
        let err: String
        var ok: Bool { code == 0 }
        /// 给人看的错误信息：去掉 “key：” 前缀
        var message: String {
            let text = (err.isEmpty ? out : err).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.hasPrefix("key：") ? String(text.dropFirst(4)) : text
        }
    }

    static func run(_ args: [String], stdin: String? = nil) async -> Result {
        await Task.detached(priority: .userInitiated) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: binary)
            p.arguments = args
            let outPipe = Pipe(), errPipe = Pipe(), inPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            p.standardInput = inPipe
            do {
                try p.run()
            } catch {
                return Result(code: -1, out: "", err: "找不到小工具 key（\(binary)）：\(error.localizedDescription)")
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
