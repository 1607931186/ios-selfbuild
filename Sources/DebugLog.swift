import Foundation

/// 把日志写进 App 沙盒的 Documents/app.log。
/// 没有 Mac 就没法用 Xcode Console / 崩溃日志符号化，
/// 所以界面上留一个「导出日志」按钮，出问题直接把 txt 发出来。
enum DebugLog {
    static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("app.log")
    }()

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func write(_ message: String, file: String = #fileID, line: Int = #line) {
        let line = "[\(formatter.string(from: Date()))] \(file):\(line) \(message)"
        print(line)
        append(line + "\n")
    }

    static func read() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    static func clear() {
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func append(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
