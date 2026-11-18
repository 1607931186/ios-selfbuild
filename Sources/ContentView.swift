import SwiftUI

struct ContentView: View {
    @State private var logText = ""
    @State private var isSharing = false

    var body: some View {
        NavigationStack {
            List {
                Section("运行信息") {
                    InfoRow("版本", Bundle.main.shortVersion)
                    InfoRow("Build", Bundle.main.buildNumber)
                    InfoRow("Bundle ID", Bundle.main.bundleIdentifier ?? "-")
                    InfoRow("系统", ProcessInfo.processInfo.operatingSystemVersionString)
                }

                Section("调试日志") {
                    Button("刷新日志") { logText = DebugLog.read() }
                    Button("写一条测试日志") {
                        DebugLog.write("hello from 测试按钮")
                        logText = DebugLog.read()
                    }
                    Button("导出 app.log") { isSharing = true }
                    Button("清空日志", role: .destructive) {
                        DebugLog.clear()
                        logText = ""
                    }
                }

                Section("日志内容") {
                    Text(logText.isEmpty ? "(空)" : logText)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("自用工具")
            .onAppear {
                DebugLog.write("ContentView appeared")
                logText = DebugLog.read()
            }
            .sheet(isPresented: $isSharing) {
                ShareSheet(items: [DebugLog.fileURL])
            }
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }
}
