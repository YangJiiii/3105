import SwiftUI

@main
struct ThreeOneOSFiveApp: App {
    @State private var isUnlocked = false

    var body: some Scene {
        WindowGroup {
            if isUnlocked {
                ContentView()
            } else {
                LoginView(isUnlocked: $isUnlocked)
            }
        }
    }
}
