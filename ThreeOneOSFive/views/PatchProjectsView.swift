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
    @EnvironmentObject var store: PatchProjectStore
    @State private var activeTab: AppTab = .dashboard
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    
    let categories = [
        ("Avatar", "person.fill", "AVT_"),
        ("Cache", "cpu", "CCH_"),
        ("Holograma", "sparkles", "HOL_"),
        ("AI", "brain", "AI_"),
        ("Skin", "tshirt.fill", "TEX_"),
        ("Externo", "square.grid.2x2.fill", "EXT_")
    ]
    
    func filterItems(for categoryPrefix: String, currentItems: [PatchLibraryItem]) -> [PatchLibraryItem] {
        return currentItems.filter { item in
            let name = item.project?.name ?? ""
            return name.uppercased().contains(categoryPrefix.uppercased())
        }
    }
    
    var filteredItems: [PatchLibraryItem] {
        var items = store.allItems 
        if !searchText.isEmpty {
            items = items.filter { $0.project?.name.localizedCaseInsensitiveContains(searchText) ?? false }
        }
        if let categoryName = selectedCategory {
            if let categoryData = categories.first(where: { $0.0 == categoryName }) {
                return filterItems(for: categoryData.2, currentItems: items)
            }
        }
        return items
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // CONTEÚDO DINÂMICO BASEADO NA ABA
                    switch activeTab {
                        case .dashboard:
                            dashboardContent
                        case .installed:
                            genericTabContent(title: "INSTALLED", icon: "checkmark.circle.fill", description: "Patches instalados e ativos no sistema.")
                        case .search:
                            dashboardContent
                        case .settings:
                            genericTabContent(title: "SETTINGS", icon: "gearshape.fill", description: "Configurações avançadas do injetor.")
                        }
                    
                .frame(maxHeight: .infinity)
                
                // TAB BAR CUSTOMIZADA (ESTÉTICA GAMER)
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
