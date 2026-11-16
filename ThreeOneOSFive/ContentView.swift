import SwiftUI

struct ContentView: View {
    @StateObject private var patchStore = PatchProjectStore()

    var body: some View {
        TabView {
            // Apenas a view, sem VStack em volta
            PatchProjectsView(store: patchStore)
                .tabItem {
                    Label("Início", systemImage: "house.fill")
                }
            
            Text("Tela de Arquivos") 
                .tabItem {
                    Label("Arquivos", systemImage: "folder.fill")
                }
        }
        .accentColor(.purple)
    }
}
