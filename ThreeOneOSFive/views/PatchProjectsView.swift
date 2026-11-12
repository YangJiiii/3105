import SwiftUI
import UniformTypeIdentifiers

// Enum para controlar qual aba está ativa
enum AppTab {
    case dashboard
    case installed
    case search
    case settings
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    
    @State private var activeTab: AppTab = .dashboard
    @State private var selectedCategory: String = "Todos"
    @State private var searchText = "" // A busca agora usa a lógica original

    // --- LÓGICA ORIGINAL DE FILTRAGEM ---
    private var filteredItems: [PatchLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            if item.packageURL.lastPathComponent.localizedCaseInsensitiveContains(query) { return true }
            guard let project = item.project else { return false }
            if project.name.localizedCaseInsensitiveContains(query) || project.author.localizedCaseInsensitiveContains(query) { return true }
            guard item.canInspectContents else { return false }
            return project.allBundleIdentifiers.contains { $0.localizedCaseInsensitiveContains(query) }
                || project.directories.contains { $0.relativePath.localizedCaseInsensitiveContains(query) }
                || project.rules.contains { $0.relativePath.localizedCaseInsensitiveContains(query) || $0.replacementFilename.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Group {
                    switch activeTab {
                    case .dashboard:
                        dashboardContent
                    case .installed:
                        installedContent
                    case .search:
                        dashboardContent // A dashboard já processa o filteredItems
                    case .settings:
                        SettingsView() // Chama a View original de configurações
                    }
                }
                .frame(maxHeight: .infinity)
                
                // TAB BAR
                HStack(spacing: 0) {
                    tabButton(tab: .dashboard, icon: "house.fill", label: "Home")
                    tabButton(tab: .installed, icon: "checkmark.circle.fill", label: "Installed")
                    tabButton(tab: .search, icon: "magnifyingglass", label: "Search")
                    tabButton(tab: .settings, icon: "gearshape.fill", label: "Settings")
                }
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.1)), alignment: .top)
            }
        }
        .animation(.spring(), value: activeTab)
    }

    // --- ABA INSTALLED (Lógica Original) ---
    private var installedContent: some View {
        VStack {
            Text("INSTALLED")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.top)
            
            ScrollView {
                LazyVStack(spacing: 15) {
                    // Mostra apenas o que está habilitado (Lógica de patches instalados)
                    ForEach(store.allItems.filter { $0.project?.isEnabled == true }) { item in
                        PatchCard(item: item, store: store)
                    }
                }
                .padding()
            }
        }
    }

    // --- DASHBOARD COM A FILTRAGEM ORIGINAL ---
    private var dashboardContent: some View {
        VStack(spacing: 0) {
            // Barra de busca integrada com a variável searchText
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search patches, authors, bundles...", text: $searchText)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .padding()

            // Aqui usamos o filteredItems da lógica original para renderizar os cards
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(filteredItems) { item in
                        PatchCard(item: item, store: store)
                    }
                }
                .padding()
            }
        }
    }

    // Função auxiliar para a Tab Bar
    private func tabButton(tab: AppTab, icon: String, label: String) -> some View {
        Button { activeTab = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(activeTab == tab ? .purple : .gray)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(activeTab == tab ? .purple : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

                
                // TAB BAR CUSTOMIZADA
                HStack(spacing: 0) {
                    tabButton(tab: .dashboard, icon: "house.fill", label: "Home")
                    tabButton(tab: .installed, icon: "checkmark.circle.fill", label: "Installed")
                    tabButton(tab: .search, icon: "magnifyingglass", label: "Search")
                    tabButton(tab: .settings, icon: "gearshape.fill", label: "Settings")
                }
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.1)),
                    alignment: .top
                )
            }
        }
        .animation(.spring(), value: activeTab)
        .animation(.spring(), value: selectedCategory)
    }

    
    // MARK: - Componentes de Tela
    
    var dashboardContent: some View {
        VStack(spacing: 25) {
            if selectedCategory == nil {
                VStack(spacing: 8) {
                    Text("DASHBOARD")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ESCOLHA UMA CATEGORIA")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.purple)
                            Text("Patches disponíveis para FF")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Image(systemName: "ellipsis.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Buscar patch...", text: $searchText)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)
            
            if let category = selectedCategory {
                VStack {
                    HStack {
                        Button(action: { selectedCategory = nil; searchText = "" }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .padding()
                        }
                        Text("SEARCH: \(category)")
                            .font(.title2).bold().foregroundColor(.white)
                        Spacer()
                    }
                    
                    if filteredItems.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass.circle").font(.system(size: 50)).foregroundColor(.gray)
                            Text("Nenhum resultado encontrado").foregroundColor(.gray)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(filteredItems) { item in
                                    PatchCard(item: item, store: store)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .transition(.move(edge: .trailing))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(categories, id: \.0) { category in
                        Button(action: { selectedCategory = category.0 }) {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
                                    Image(systemName: category.1).foregroundColor(.white)
                                }
                                VStack(alignment: .leading) {
                                    Text(category.0).font(.headline).foregroundColor(.white)
                                    Text("\(filterItems(for: category.2, currentItems: store.allItems).count) patches").font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                            }
                            .padding().background(Color.white.opacity(0.05)).cornerRadius(15)
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                }
                .padding()
                .transition(.move(edge: .leading))
            }
            Spacer()
        }
    }
    
    func genericTabContent(title: String, icon: String, description: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.purple)
            Text(title)
                .font(.title).bold().foregroundColor(.white)
            Text(description)
                .font(.subheadline).foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    func tabButton(tab: AppTab, icon: String, label: String) -> some View {
        Button(action: { 
            activeTab = tab 
            selectedCategory = nil // Reseta a categoria ao mudar de aba
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(activeTab == tab ? .purple : .gray)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(activeTab == tab ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct PatchCard: View {
    let item: PatchLibraryItem
    let store: PatchProjectStore
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.black).frame(width: 50, height: 50)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 1))
                    Image(systemName: "skull").foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(cleanName(item.project?.name)).font(.headline).foregroundColor(.white)
                    Text(item.project?.author ?? "Autor Desconhecido").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundColor(.gray)
                }
            }
            if isExpanded {
                VStack(spacing: 15) {
                    Divider().background(Color.gray)
                    HStack {
                        Text("Ativar Patch").foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { item.project?.isEnabled ?? false },
                            set: { store.togglePatch(item: item, enabled: $0) }
                        )).toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                }
                .padding(.top, 5)
            }
        }
        .padding().background(Color.white.opacity(0.05)).cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    func cleanName(_ name: String?) -> String {
        guard let name = name else { return "Patch Desconhecido" }
        if let underscoreIndex = name.firstIndex(of: "_") {
            return String(name[name.index(after: underscoreIndex)...])
        }
        return name
    }
}
