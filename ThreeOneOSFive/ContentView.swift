import SwiftUI

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    @State private var showSettings = false
    @State private var showLogs = false

    var body: some View {
        ZStack {
            // Imagem de fundo com travas para não esticar a tela
            Image("background_gh") 
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .clipped()

            NavigationStack {
                // Voltando para a seção .installed (Aba de arquivos importados)
                PatchProjectsView(
                    section: .installed, 
                    onOpenSettings: openSettings, 
                    onOpenLogs: openLogs
                )
                .navigationTitle("external gh777")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            openSettings()
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden) 
        }
        .tint(AppTheme.accent)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private func openSettings() { showSettings = true }
    private func openLogs() { showLogs = true }
}
