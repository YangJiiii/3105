import SwiftUI
import Combine

class PatchProjectStore: ObservableObject {
    @Published var projects: [PatchProject] = []
    private var allProjects: [PatchProject] = []
    
    // Função para filtrar patches por aba
    func filterProjects(for section: AppSection) {
        // Se a aba for 'installed' (TEXTURAS), mostra tudo ou filtra por categoria
        // Para as outras abas, filtramos os patches que pertencem àquela seção
        self.projects = allProjects.filter { project in
            // Aqui definimos que o patch deve ter a categoria igual à aba
            // Se o patch não tiver categoria, ele só aparece na aba TEXTURAS
            if section == .installed {
                return project.category == nil || project.category == "installed"
            }
            return project.category == section.rawValue
        }
    }

    func loadProjects() {
        // Lógica original de carregamento de patches
        // ... (mantendo a lógica de carregamento do seu app)
        // Após carregar, salvamos em allProjects
        self.allProjects = self.projects 
    }
    
    // Adicione as demais funções originais de deletar, aplicar e importar aqui...
}
