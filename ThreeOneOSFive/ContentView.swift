import SwiftUI

struct ContentView: View {
    @EnvironmentObject var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject var patchProjectStore: PatchProjectStore
    @EnvironmentObject var packageRepositoryStore: PackageRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                // Imagem de fundo: sem frame infinito para NÃO esticar
                Image("background_gh")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .clipped()

                VStack(spacing: 0) {
                    // Título Manual: Como o sistema está forçando "Installed", 
                    // criamos nosso próprio título para garantir que apareça GH777 EXTERNAL
                    Text("GH777 EXTERNAL")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 50) // Ajuste para não ficar embaixo do notch
                        .padding(.bottom, 10)
                        .zIndex(1)

                    // Lista de Patches
                    PatchProjectsView(section: .search)
                }
            }
            // Deixamos o título do sistema vazio para ele não escrever "Installed"
            .navigationTitle("") 
            .navigationBarHidden(true) 
        }
        .onAppear {
            setupAppearance()
        }
    }

    private func setupAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Remove o fundo da lista para a imagem aparecer
        UITableView.appearance().backgroundColor = .clear
    }
}
