import SwiftUI

struct ContentView: View {
    @StateObject private var patchStore = PatchProjectStore()

    var body: some View {
        TabView {
            // Aba de Início (Dashboard)
            PatchProjectsView(store: patchStore)
                .tabItem {
                    Label("Início", systemImage: "house.fill")
                }
            
            // Aba de Arquivos (Installed)
            // Aqui você coloca a view que gerencia os arquivos instalados
            Text("Tela de Arquivos") 
                .tabItem {
                    Label("Arquivos", systemImage: "folder.fill")
                }
        }
        .accentColor(.purple) // Cor roxa para combinar com o estilo gamer
    }
}
