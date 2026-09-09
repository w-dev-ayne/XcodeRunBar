import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let manager = XcodeManager()

    // 메뉴바 아이콘 3개 (왼쪽 → 오른쪽: 🔨 앱정보 | ▶ Run | ■ Stop)
    private var infoItem: NSStatusItem?
    private var runItem:  NSStatusItem?
    private var stopItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItems()
        manager.onUpdate = { [weak self] in self?.refreshRunStop() }
    }

    // MARK: - 아이콘 초기 세팅
    // macOS는 나중에 추가된 아이콘이 왼쪽에 배치되므로 역순으로 생성

    private func setupStatusItems() {
        // 생성 순서 = 오른쪽 → 왼쪽 (나중에 만들수록 왼쪽에 배치)
        runItem  = makeItem(symbol: "play.fill",  description: "Run",    length: 20) // 오른쪽
        stopItem = makeItem(symbol: "stop.fill",  description: "Stop",   length: 20) // Stop이 왼쪽
        infoItem = makeItem(symbol: "hammer",     description: "XcodeRunBar"       ) // 맨 왼쪽

        // 앱 정보 아이콘은 항상 고정 드롭다운
        infoItem?.menu = buildInfoMenu()

        refreshRunStop()
    }

    private func makeItem(symbol: String, description: String, length: CGFloat = NSStatusItem.squareLength) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: length)
        let config = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .medium)
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: description)?
            .withSymbolConfiguration(config)
        img?.isTemplate = true   // 라이트/다크 모드 자동 대응
        item.button?.image = img
        return item
    }

    // MARK: - Run / Stop 동작 전환

    private func refreshRunStop() {
        let projects = manager.projects

        switch projects.count {
        case 0:
            // Xcode 없음 — 아이콘 dim 처리
            setDimmed(runItem,  dimmed: true)
            setDimmed(stopItem, dimmed: true)
            bind(runItem,  menu: nil, action: nil)
            bind(stopItem, menu: nil, action: nil)

        case 1:
            // 프로젝트 하나 — 클릭 즉시 실행/정지
            setDimmed(runItem,  dimmed: false)
            setDimmed(stopItem, dimmed: false)
            bind(runItem,  menu: nil, action: #selector(runSingle))
            bind(stopItem, menu: nil, action: #selector(stopSingle))

        default:
            // 프로젝트 여러 개 — 선택 드롭다운
            setDimmed(runItem,  dimmed: false)
            setDimmed(stopItem, dimmed: false)
            bind(runItem,  menu: buildMenu(projects, mode: .run),  action: nil)
            bind(stopItem, menu: buildMenu(projects, mode: .stop), action: nil)
        }
    }

    private func bind(_ item: NSStatusItem?, menu: NSMenu?, action: Selector?) {
        item?.menu = menu
        item?.button?.action = action
        item?.button?.target = self
    }

    /// Xcode 없을 때 아이콘을 흐리게
    private func setDimmed(_ item: NSStatusItem?, dimmed: Bool) {
        item?.button?.alphaValue = dimmed ? 0.35 : 1.0
    }

    // MARK: - 앱 정보 드롭다운

    private let githubRepo = "w-dev-ayne/XcodeRunBar"

    private func buildInfoMenu() -> NSMenu {
        let menu = NSMenu()

        // 앱 이름 + 버전 (비활성 헤더)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let header = NSMenuItem(title: "XcodeRunBar \(version)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        menu.addItem(infoMenuItem(
            title:  "Contact",
            symbol: "envelope",
            action: #selector(openContact)
        ))
        menu.addItem(infoMenuItem(
            title:  "Check for Updates...",
            symbol: "arrow.clockwise",
            action: #selector(checkForUpdates)
        ))

        menu.addItem(.separator())

        menu.addItem(infoMenuItem(
            title:  "Quit XcodeRunBar",
            symbol: "power",
            action: #selector(quitApp),
            key:    "q"
        ))

        return menu
    }

    private func infoMenuItem(title: String, symbol: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        return item
    }

    // MARK: - 앱 정보 액션

    @objc private func openContact() {
        if let url = URL(string: "mailto:w.dev.ayne@gmail.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func checkForUpdates() {
        guard let apiURL = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest") else { return }

        URLSession.shared.dataTask(with: apiURL) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }

                // 네트워크 오류 또는 응답 없음
                guard error == nil,
                      let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let releaseURL = json["html_url"] as? String
                else {
                    self.showAlert(title: "Update Check Failed", message: "Could not connect to GitHub.\nPlease try again later.")
                    return
                }

                let latest  = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"

                if latest.compare(current, options: .numeric) == .orderedDescending {
                    let alert = NSAlert()
                    alert.messageText = "New Version Available!"
                    alert.informativeText = "XcodeRunBar \(latest) is now available.\n(Current version: \(current))"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")
                    if alert.runModal() == .alertFirstButtonReturn,
                       let url = URL(string: releaseURL) {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    self.showAlert(title: "XcodeRunBar", message: "You're up to date. ✓\n(Current version: \(current))")
                }
            }
        }.resume()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Run / Stop 프로젝트 메뉴 빌더

    private enum Mode { case run, stop }

    private func buildMenu(_ projects: [XcodeManager.XcodeProject], mode: Mode) -> NSMenu {
        let menu = NSMenu()
        let (prefix, action) = mode == .run
            ? ("▶", #selector(runProject(_:)))
            : ("■", #selector(stopProject(_:)))

        for project in projects {
            let item = NSMenuItem(title: "\(prefix)  \(project.name)", action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = project
            menu.addItem(item)
        }
        return menu
    }

    // MARK: - Run / Stop 액션

    @objc private func runSingle() {
        guard let p = manager.projects.first else { return }
        manager.run(p)
    }

    @objc private func stopSingle() {
        guard let p = manager.projects.first else { return }
        manager.stop(p)
    }

    @objc private func runProject(_ sender: NSMenuItem) {
        guard let p = sender.representedObject as? XcodeManager.XcodeProject else { return }
        manager.run(p)
    }

    @objc private func stopProject(_ sender: NSMenuItem) {
        guard let p = sender.representedObject as? XcodeManager.XcodeProject else { return }
        manager.stop(p)
    }
}
