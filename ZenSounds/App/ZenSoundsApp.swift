import SwiftUI

@main
struct ZenSoundsApp: App {
    var body: some Scene {
        WindowGroup {
            ZenSoundsTheme {
                RootView()
            }
            .onOpenURL { url in
                DeepLinkHandler.handle(url)
            }
        }
    }
}
