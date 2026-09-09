import AppKit
import Foundation

final class XcodeManager {

    struct XcodeProject: Equatable {
        let id: Int       // workspace document 인덱스 (1-based)
        let name: String
    }

    private(set) var projects: [XcodeProject] = []
    private(set) var isXcodeRunning = false

    /// 상태가 바뀔 때마다 호출 (항상 메인 스레드)
    var onUpdate: (() -> Void)?

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - 상태 갱신

    func refresh() {
        isXcodeRunning = NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == "com.apple.dt.Xcode" }

        guard isXcodeRunning else {
            projects = []
            onUpdate?()
            return
        }

        projects = fetchProjects()
        onUpdate?()
    }

    // MARK: - AppleScript: 프로젝트 목록 조회

    private func fetchProjects() -> [XcodeProject] {
        let src = """
        tell application "Xcode"
            set out to ""
            set docCount to count of workspace documents
            repeat with i from 1 to docCount
                if i > 1 then set out to out & "|"
                set out to out & i & ":" & name of workspace document i
            end repeat
            return out
        end tell
        """
        var err: NSDictionary?
        guard let raw = NSAppleScript(source: src)?.executeAndReturnError(&err).stringValue,
              err == nil, !raw.isEmpty
        else { return [] }

        // "1:MyGame|2:Roumit" 파싱
        return raw.split(separator: "|").compactMap { chunk in
            let parts = chunk.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, let idx = Int(parts[0]) else { return nil }
            return XcodeProject(id: idx, name: String(parts[1]))
        }
    }

    // MARK: - AppleScript: Run / Stop

    func run(_ project: XcodeProject) {
        send("run workspace document \(project.id)")
    }

    func stop(_ project: XcodeProject) {
        send("stop workspace document \(project.id)")
    }

    private func send(_ command: String) {
        let src = "tell application \"Xcode\"\n\(command)\nend tell"
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        if let err { print("[RunBar] AppleScript error: \(err)") }
    }
}
