import SwiftUI

struct ContentView: View {
    // Alterado para StateObject para que a ContentView seja a dona da Store
    @StateObject private var patchStore = PatchProjectStore() 
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fundo preto sólido para o estilo gamer
                Color.black.ignoresSafeArea()
                
                // CORREÇÃO: Agora passamos a store para a view
                PatchProjectsView(store: patchStore) 
            }
            .navigationTitle("GH777 EXTERNAL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Espaço para botões extras no topo
            }
        }
    }
}

// Preview corrigido para funcionar com a nova estrutura
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
