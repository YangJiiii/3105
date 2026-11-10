import SwiftUI

struct ContentView: View {
    @EnvironmentObject var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject var patchProjectStore: PatchProjectStore
    @EnvironmentObject var packageRepositoryStore: PackageRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                // MUDANÇA AQUI: Usando .fit e removendo qualquer comando de expansão forçada
                Image("background_gh")
                    .resizable()
                    .aspectRatio(contentMode: .fit) 
                    .ignoresSafeArea()
                    .clipped()

                VStack(spacing: 0) {
                    Text("GH777 EXTERNAL")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 50)
                        .padding(.bottom, 10)
                        .zIndex(1)

                    PatchProjectsView(section: .search)
                }
            }
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
        
        UITableView.appearance().backgroundColor = .clear
    }
}
