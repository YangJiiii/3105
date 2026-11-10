import SwiftUI

struct ContentView: View {
    @EnvironmentObject var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject var patchProjectStore: PatchProjectStore
    @EnvironmentObject var packageRepositoryStore: PackageRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                // Imagem de fundo sem esticar
                Image("background_gh")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .clipped()

                VStack(spacing: 0) {
                    // Forçamos a seção .search para os patches aparecerem
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

    private func setupAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Isso remove o fundo branco/cinza da lista para mostrar sua imagem
        UITableView.appearance().backgroundColor = .clear
    }
}
