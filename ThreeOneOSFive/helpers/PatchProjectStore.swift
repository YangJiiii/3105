import Foundation
import SwiftUI

@MainActor
class PatchProjectStore: ObservableObject {
    @Published var allItems: [PatchLibraryItem] = []
    @Published var items: [PatchLibraryItem] = []
    @Published var isLoading = false
    @Published var alert: PatchStoreAlert?

    struct PatchStoreAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    init() {
        // O init pode ficar vazio ou carregar dados iniciais se necessário
    }

    func filterProjects(for section: AppSection) {
        switch section {
        case .home:
            // Filtra projetos que tenham "HS" no nome do projeto
            items = allItems.filter { $0.project.name.localizedCaseInsensitiveContains("HS") }
        case .new:
            // Filtra projetos que tenham "PAINEL" no nome do projeto
            items = allItems.filter { $0.project.name.localizedCaseInsensitiveContains("PAINEL") }
        case .sources:
            // Filtra projetos que tenham "HOLOGRAMAS" no nome do projeto
            items = allItems.filter { $0.project.name.localizedCaseInsensitiveContains("HOLOGRAMAS") }
        case .installed:
            // Pega tudo que NÃO seja HS, PAINEL ou HOLOGRAMAS (vai para TEXTURAS)
            items = allItems.filter { item in
                let name = item.project.name
                return !name.localizedCaseInsensitiveContains("HS") && 
                       !name.localizedCaseInsensitiveContains("PAINEL") && 
                       !name.localizedCaseInsensitiveContains("HOLOGRAMAS")
            }
        default:
            items = allItems
        }
    }
    
    // Adicione aqui outras funções de carregamento (fetch) que existiam no seu arquivo original
}
