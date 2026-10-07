import AppKit
import Foundation

final class XcodeManager {

    struct XcodeProject: Equatable {
        let id: Int       // workspace document 인덱스 (1-based)
        let name: String
        var isRunning: Bool = false   // last scheme action result 가 running 인지
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
            update(projects: [])
            return
        }

        update(projects: fetchProjects())
    }

    /// 실제로 달라졌을 때만 UI 에 알림
    private func update(projects new: [XcodeProject]) {
        guard new != projects else { return }
        projects = new
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
                set isRun to "0"
                try
                    if (status of last scheme action result of workspace document i) is «constant ****srsr» then set isRun to "1"
                end try
                set out to out & i & ":" & isRun & ":" & name of workspace document i
            end repeat
            return out
        end tell
        """
        var err: NSDictionary?
        guard let raw = NSAppleScript(source: src)?.executeAndReturnError(&err).stringValue,
              err == nil, !raw.isEmpty
        else { return [] }

        // "1:0:MyGame|2:1:Roumit" 파싱 (인덱스:실행중여부:이름)
        let debugged = debuggedAppPaths()
        return raw.split(separator: "|").compactMap { chunk in
            let parts = chunk.split(separator: ":", maxSplits: 2)
            guard parts.count == 3, let idx = Int(parts[0]) else { return nil }
            let name = String(parts[2])
            // AppleScript 로 실행한 경우(status) + Xcode GUI 로 실행한 경우(debugserver 자식 프로세스)
            let running = parts[1] == "1" || isRunningUnderDebugger(projectName: name, paths: debugged)
            return XcodeProject(id: idx, name: name, isRunning: running)
        }
    }

    // MARK: - 프로세스 기반 실행 감지
    // `last scheme action result` 는 스크립트로 실행했을 때만 채워지므로,
    // Xcode GUI(⌘R)로 실행한 앱은 debugserver 의 자식 프로세스로 감지한다.

    /// debugserver 가 부모인 프로세스의 실행 파일 경로들
    private func debuggedAppPaths() -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid=,ppid=,command="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        var commands: [Int: String] = [:]
        var parents: [Int: Int] = [:]
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            let f = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard f.count == 3, let pid = Int(f[0]), let ppid = Int(f[1]) else { continue }
            commands[pid] = String(f[2])
            parents[pid] = ppid
        }
        return parents.compactMap { pid, ppid in
            guard commands[ppid]?.contains("debugserver") == true else { return nil }
            return commands[pid]
        }
    }

    /// DerivedData/<프로젝트명>-해시/ 아래 빌드 산출물이 디버깅 중인지
    private func isRunningUnderDebugger(projectName: String, paths: [String]) -> Bool {
        let base = (projectName as NSString).deletingPathExtension
        let marker = "/DerivedData/\(base)-"
        return paths.contains { $0.contains(marker) }
    }

    // MARK: - AppleScript: Run / Stop

    func run(_ project: XcodeProject) {
        send("run workspace document \(project.id)")
        refreshSoon()
    }

    func stop(_ project: XcodeProject) {
        send("stop workspace document \(project.id)")
        refreshSoon()
    }

    /// 명령 직후 상태를 빠르게 반영 (3초 폴링을 기다리지 않음)
    private func refreshSoon() {
        for delay in [0.5, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refresh()
            }
        }
    }

    private func send(_ command: String) {
        let src = "tell application \"Xcode\"\n\(command)\nend tell"
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        if let err { print("[RunBar] AppleScript error: \(err)") }
    }
}
