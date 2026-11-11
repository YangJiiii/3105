import SwiftUI
import UniformTypeIdentifiers

struct PatchProjectsView: View {
    @EnvironmentObject var store: PatchProjectStore
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    
    // Categorias configuradas para o Dashboard
    let categories = [
        ("Cache", "cpu"),
        ("Avatar", "person.fill"),
        ("Holograma", "sparkles"),
        ("AI", "brain"),
        ("Skin", "tshirt.fill"),
        ("Externo", "square.grid.2x2.fill")
    ]
    
    // Filtra os itens com base na categoria selecionada e na busca
    var filteredItems: [PatchLibraryItem] {
        var items = store.items
        
        if !searchText.isEmpty {
            items = items.filter { $0.project?.name.localizedCaseInsensitiveContains(searchText) ?? false }
        }
        
        if let category = selectedCategory {
            return items.filter { $0.project?.name.localizedCaseInsensitiveContains(category) ?? false }
        }
        
        return items
    }
    
    var body: some View {
        ZStack {
            // Fundo Preto Sólido (Estilo Gamer)
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Header
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
                        
                        Button(action: {
                            // Ação do botão de menu (opcional)
                        }) {
                            Image(systemName: "ellipsis.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Barra de Busca
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
                    // VIEW DE LISTA DE PATCHES (Quando uma categoria é selecionada)
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
                    // GRID DE CATEGORIAS (Dashboard Principal)
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
                                        
                                        // Contador de patches real baseado na store
                                        Text("\(store.items.filter { $0.project?.name.localizedCaseInsensitiveContains(category.0) ?? false }.count) patches")
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
                    Text(item.project?.name ?? "Patch Desconhecido")
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
                                // Aqui chama a função de aplicar o patch
                                store.togglePatch(item: item, enabled: newValue)
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
}
