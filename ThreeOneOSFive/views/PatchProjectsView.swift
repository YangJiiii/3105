import SwiftUI
import UniformTypeIdentifiers

struct PatchProjectsView: View {
    @EnvironmentObject var store: PatchProjectStore
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    
    // Categorias configuradas com seus respectivos prefixos de arquivo
    let categories = [
        ("Avatar", "person.fill", "AVT_"),
        ("Cache", "cpu", "CCH_"),
        ("Holograma", "sparkles", "HOL_"),
        ("AI", "brain", "AI_"),
        ("Skin", "tshirt.fill", "TEX_"),
        ("Externo", "square.grid.2x2.fill", "EXT_")
    ]
    
    // Função auxiliar para filtrar por prefixo ou nome
    func filterItems(for categoryPrefix: String, currentItems: [PatchLibraryItem]) -> [PatchLibraryItem] {
        return currentItems.filter { item in
            let name = item.project?.name ?? ""
            return name.uppercased().hasPrefix(categoryPrefix.uppercased())
        }
    }
    
    var filteredItems: [PatchLibraryItem] {
        var items = store.items
        
        if !searchText.isEmpty {
            items = items.filter { $0.project?.name.localizedCaseInsensitiveContains(searchText) ?? false }
        }
        
        if let categoryName = selectedCategory {
            // Busca o prefixo correspondente ao nome da categoria selecionada
            if let categoryData = categories.first(where: { $0.0 == categoryName }) {
                return filterItems(for: categoryData.2, currentItems: items)
            }
        }
        
        return items
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 25) {
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
                            
                            Text("Toque em uma opção para abrir os patches.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "ellipsis.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
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
                            Button(action: { selectedCategory = nil }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            Text(category)
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        if filteredItems.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("Nenhum patch encontrado nesta categoria")
                                    .foregroundColor(.gray)
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
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: category.1)
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(category.0)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        // Contador atualizado para contar por prefixo
                                        Text("\(filterItems(for: category.2, currentItems: store.items).count) patches")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding()
                    .transition(.move(edge: .leading))
                }
                Spacer()
            }
        }
        .animation(.spring(), value: selectedCategory)
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.purple, lineWidth: 1)
                        )
                    
                    Image(systemName: "skull")
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Remove o prefixo do nome para ficar bonito na tela
                    Text(cleanName(item.project?.name))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(item.project?.author ?? "Autor Desconhecido")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            
            if isExpanded {
                VStack(spacing: 15) {
                    Divider().background(Color.gray)
                    
                    HStack {
                        Text("Ativar Patch")
                            .foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { item.project?.isEnabled ?? false },
                            set: { newValue in
                                store.togglePatch(item: item,enabled: newValue)
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                }
                .padding(.top, 5)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // Função para remover o prefixo (AVT_, CCH_, etc) da exibição do nome
    func cleanName(_ name: String?) -> String {
        guard let name = name else { return "Patch Desconhecido" }
        if let underscoreIndex = name.firstIndex(of: "_") {
            return String(name[name.index(after: underscoreIndex)...])
        }
        return name
    }
}
