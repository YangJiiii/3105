import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PatchProjectStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fundo preto sólido para o estilo gamer
                Color.black.ignoresSafeArea()
                
                // A PatchProjectsView é a tela principal que contém o Dashboard e a lista de patches
               PatchProjectsView()
            }
            .navigationTitle("GH777 EXTERNAL") // Título exatamente como na sua foto
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Se quiser adicionar algum botão extra no topo, coloque aqui
            }
        }
    }
}

// Preview para facilitar o teste no Xcode
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PatchProjectStore())
    }
}
