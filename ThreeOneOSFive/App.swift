import SwiftUI

@main
struct ThreeOneOSFiveApp: App {
    @State private var isUnlocked = false // Controla se o app foi liberado

    var body: some Scene {
        WindowGroup {
            if isUnlocked {
                ContentView() // Abre a tela principal do app
            } else {
                LoginView(isUnlocked: $isUnlocked) // Abre a nossa tela de senha
            }
        }
    }
}
