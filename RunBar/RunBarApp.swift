import SwiftUI

@main
struct RunBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 모든 UI는 AppDelegate의 NSStatusBar로 관리
        Settings { EmptyView() }
    }
}
