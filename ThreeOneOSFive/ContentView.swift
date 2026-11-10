import SwiftUI

struct ContentView: View {
    @EnvironmentObject var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject var patchProjectStore: PatchProjectStore
    @EnvironmentObject var packageRepositoryStore: PackageRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                // Imagem de fundo configurada para preencher a tela sem esticar
                Image("background_gh")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                    .clipped()

                // Conteúdo principal
                VStack {
                    // Chamada da View de Patches apontando para .search
                    // Isso faz com que os arquivos apareçam, mas o título continua "external gh777"
                    PatchProjectsView(section: .search)
                }
            }
            .navigationTitle("external gh777")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            setupAppearance()
        }
    }

    // Função para remover fundos sólidos e deixar a interface transparente
    private func setupAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Remove o fundo branco da lista de patches
        UITableView.appearance().backgroundColor = .clear
    }
}
