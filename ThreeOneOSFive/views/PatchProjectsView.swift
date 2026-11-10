import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum PatchPackagePickerPolicy {
    static let packageType = UTType(filenameExtension: "3105") ?? .data
    static let allowedContentTypes: [UTType] = [packageType, .data]
    static let copiesSelectedDocument = true
}

private enum WallpaperPackagePickerPolicy {
    static let packageType = UTType(filenameExtension: "tendies") ?? .data
    static let allowedContentTypes: [UTType] = [packageType, .data]
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var showImporter = false
    @State private var showCreate = false
    
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    let categories = [
        CategoryItem(name: "Cache", icon: "cpu", color: .blue),
        CategoryItem(name: "Avatar", icon: "person.fill", color: .purple),
        CategoryItem(name: "Holograma", icon: "sparkles", color: .cyan),
        CategoryItem(name: "AI", icon: "brain", color: .orange),
        CategoryItem(name: "Skin", icon: "tshirt.fill", color: .pink),
        CategoryItem(name: "Externo", icon: "square.grid.2x2.fill", color: .green)
    ]

    private var filteredItems: [PatchLibraryItem] {
        let items = store.items
        if let category = selectedCategory {
            return items.filter { $0.project?.name.localizedCaseInsensitiveContains(category) ?? false }
        }
        if !searchText.isEmpty {
            return items.filter { $0.project?.name.localizedCaseInsensitiveContains(searchText) ?? false }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if selectedCategory == nil {
                    dashboardView
                } else {
                    patchesListView
                }
            }
            .navigationTitle(selectedCategory == nil ? "DASHBOARD" : selectedCategory!.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedCategory != nil {
                        Button { selectedCategory = nil } label: {
                            Image(systemName: "chevron.left").foregroundStyle(.white)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showImporter = true } label: {
                            Label("Importar", systemImage: "square.and.arrow.down")
                        }
                        Button { showCreate = true } label: {
                            Label("Novo", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill").foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showImporter) {
                FileDocumentPicker(
                    allowedContentTypes: PatchPackagePickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: PatchPackagePickerPolicy.copiesSelectedDocument,
                    allowsMultipleSelection: false,
                    onSelection: { result in
                        showImporter = false
                        if case .success(let urls) = result, let url = urls.first {
                            store.importPackage(at: url)
                        }
                    },
                    onCancel: { showImporter = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCreate) {
                PatchProjectEditorView(existingProject: nil, passwordIsProtected: false) { project, password in
                    store.create(project: project, password: password)
                }
            }
        }
    }

    private var dashboardView: some View {
        ScrollView {
            VStack(spacing: 25) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ESCOLHA UMA CATEGORIA")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                    Text("Patches disponíveis para FF")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Toque em uma opção para abrir os patches.")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(categories, id: \.name) { cat in
                        CategoryCard(category: cat, count: countForCategory(cat.name)) {
                            selectedCategory = cat.name
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var patchesListView: some View {
        VStack {
            AppSearchField(text: $searchText, prompt: "Buscar patch...", clearLabel: "Limpar")
                .padding()
            ScrollView {
                VStack(spacing: 12) {
                    if filteredItems.isEmpty {
                        Text("Nenhum patch encontrado nesta categoria")
                            .foregroundStyle(.gray)
                            .padding(.vertical, 50)
                    } else {
                        ForEach(filteredItems) { item in
                            PatchCard(item: item, store: store)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func countForCategory(_ name: String) -> Int {
        store.items.filter { $0.project?.name.localizedCaseInsensitiveContains(name) ?? false }.count
    }
}

// MARK: - UI Components

struct CategoryCard: View {
    let category: CategoryItem
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(category.color)
                    .frame(width: 40, height: 40)
                    .background(category.color.opacity(0.2))
                    .cornerRadius(8)
                VStack(alignment: .leading) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(count) patches")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding()
            .background(Color(white: 0.1))
            .cornerRadius(15)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(category.color.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PatchCard: View {
    let item: PatchLibraryItem
    let store: PatchProjectStore
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .frame(width: 50, height: 50)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 1))
                    Image(systemName: "skull")
                        .foregroundStyle(.white)
                        .font(.title2)
                }
                VStack(alignment: .leading, spacing: 2.foregroundStyle(.white)
                    Text("Turn on to apply")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.purple)
            }
            .padding()
            .background(Color(white: 0.05))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.3), lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { isExpanded.toggle() } }

            if isExpanded {
                VStack(spacing: 15) {
                    HStack {
                        Text("PATCH INACTIVE")
                            .font(.caption.bold())
                            .foregroundStyle(.gray)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { false },
                            set: { _ in 
                                applyPatch()
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                    .padding(.top)
                }
                .padding()
                .background(Color(white: 0.08))
                .cornerRadius(12)
            }
        }
    }

    private func applyPatch() {
        Task {
            do {
                if let project = item.project {
                    _ = try DevicePatchService.apply(project: project)
                }
            } catch {
                print("Erro ao aplicar: \(error)")
            }
        }
    }
}

struct CategoryItem {
    let name: String
    let icon: String
    let color: Color
}

private struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID
    @State private var isWorking = false

    private var item: PatchLibraryItem? {
        store.items.first(where: { $0.id == projectID })
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text(item?.project?.name ?? "Patch")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("EXTERNAL SYSTEM")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
                .padding(.top, 50)

                Button(action: apply) {
                    HStack {
                        Image(systemName: isWorking ? "arrow.clockwise" : "checkmark.shield.fill")
                            .rotating(isWorking)
                        Text(isWorking ? "APPLYING..." : "APPLY PATCH")
                            .fontWeight(.bold)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(15)
                    .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .disabled(isWorking)
                .padding(.horizontal, 40)
                Spacer()
            }
            .padding()
        }
    }

    private func apply() {
        guard let item, let project = item.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run { isWorking = false }
            } catch {
                await MainActor.run { isWorking = false }
            }
        }
    }
}

extension View {
    func rotating(_ animating: Bool) -> some View {
        animation(.linear(duration: 1).repeatForever(autoreverses: false), value: animating)
    }
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { request in
                PatchUnlockView(store: store, request: request)
            }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}

struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    let request: PatchPasswordRequest
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(language.text("patch.password"), text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in
                            store.clearUnlockError()
                        }
                    if let errorKey = store.unlockErrorKey {
                        Text(language.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    if let origin = request.origin {
                        Text(language.text("patch.password_repo_contact", origin.repositoryName))
                    } else {
                        Text(language.text("patch.password_once_message"))
                    }
                }
            }
            .navigationTitle(language.text("patch.unlock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("patch.unlock"), action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}
