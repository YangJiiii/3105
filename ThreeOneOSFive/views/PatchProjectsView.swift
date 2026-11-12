import SwiftUI

// 1. DEFINIÇÃO DAS ABAS
enum AppTab {
    case dashboard, installed, search, settings
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    
    @State private var activeTab: AppTab = .dashboard
    @State private var searchText = ""

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
                        dashboardContent
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxHeight: .infinity)
                
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
        .patchStorePresentation(store)
    }

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search patches...", text: $searchText).foregroundColor(.white)
            }
            .padding().background(Color.white.opacity(0.1)).cornerRadius(12).padding()

            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(filteredItems) { item in
                        if item.isLocked {
                            Button { store.requestUnlock(for: item) } label: {
                                PatchCard(item: item, store: store)
                            }.buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                PatchProjectDetailView(store: store, projectID: item.id)
                            } label: {
                                PatchCard(item: item, store: store)
                            }
                        }
                    }
                }.padding()
            }
        }
    }

    private var installedContent: some View {
        VStack {
            Text("INSTALLED").font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(.gray).padding(.top)
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(store.allItems.filter { $0.project?.isEnabled == true }) { item in
                        PatchCard(item: item, store: store)
                    }
                }.padding()
            }
        }
    }

    private func tabButton(tab: AppTab, icon: String, label: String) -> some View {
        Button { activeTab = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).foregroundColor(activeTab == tab ? .purple : .gray)
                Text(label).font(.caption2).foregroundColor(activeTab == tab ? .purple : .gray)
            }.frame(maxWidth: .infinity)
        }
    }
}

struct PatchCard: View {
    let item: PatchLibraryItem
    let store: PatchProjectStore

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.project?.name ?? "Unknown Patch")
                    .foregroundColor(.white)
                    .font(.headline)
                Text(item.project?.author ?? "Unknown Author")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
            Spacer()
            if item.project?.isEnabled == true {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.purple)
            } else {
                Image(systemName: "circle").foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID
    @State private var isWorking = false
    @State private var showApplyConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var showResetConfirmation = false

    private var item: PatchLibraryItem? {
        store.items.first(where: { $0.id == projectID })
    }

    var body: some View {
        List {
            if let item, let project = item.project {
                Section(language.text("patch.information")) {
                    Text("Author: \(project.author)").foregroundColor(.primary)
                }
                
                Section {
                    Button { showApplyConfirmation = true } label: {
                        Label("Apply Patch", systemImage: "checkmark.shield.fill")
                    }
                    .disabled(isWorking)

                    if DevicePatchService.latestReceipt(projectID: projectID) != nil {
                        Button { showResetConfirmation = true } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise.circle")
                        }
                        Button(role: .destructive) { showRestoreConfirmation = true } label: {
                            Label("Restore Originals", systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item?.project?.name ?? "Details")
        .confirmationDialog("Confirm", isPresented: $showApplyConfirmation) {
            Button("Apply") { /* Logica apply */ }
        }
        .confirmationDialog("Restore", isPresented: $showRestoreConfirmation) {
            Button("Restore", role: .destructive) { /* Logica restore */ }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Reset", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) { /* Logica reset */ }
            Button("Cancel", role: .cancel) {}
        }
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
