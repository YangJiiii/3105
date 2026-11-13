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
    @State private var showCreate = false
    @State private var showImporter = false
    @State private var showWallpaperImporter = false
    @State private var showCleaner = false
    @State private var searchText = ""
    @State private var wallpaperPackages: [WallpaperStagedPackage] = []
    @State private var wallpaperImportFeedback: WallpaperImportFeedback?
    @State private var wallpaperPendingDeletion: WallpaperStagedPackage?
    @State private var isImportingWallpapers = false
    @State private var showSimulatedWallpaperDetail = false
    @State private var simulatedWallpaperDetailGate = OneShotPresentationGate()
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    private var filteredItems: [PatchLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            if item.packageURL.lastPathComponent.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard let project = item.project else { return false }
            if project.name.localizedCaseInsensitiveContains(query)
                || project.author.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard item.canInspectContents else { return false }
            return project.allBundleIdentifiers.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
                || project.directories.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                }
                || project.rules.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                        || $0.replacementFilename.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var filteredWallpaperPackages: [WallpaperStagedPackage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return wallpaperPackages }
        return wallpaperPackages.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    private var hasLocalContent: Bool {
        !store.items.isEmpty || !wallpaperPackages.isEmpty
    }

    private var hasSearchResults: Bool {
        !filteredItems.isEmpty || !filteredWallpaperPackages.isEmpty
    }

    init(
        onOpenSettings: @escaping () -> Void = {},
        onOpenLogs: @escaping () -> Void = {}
    ) {
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
#if targetEnvironment(simulator)
        _showCreate = State(
            initialValue: ProcessInfo.processInfo.arguments.contains("--simulate-patch-editor")
        )
#endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0a0c").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // MARK: - HEADER GAMER GH777
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "zap.fill")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.purple)
                                Text("SYSTEM ACTIVE")
                                    .font(.system(size: 10, weight: .black))
                                    .tracking(2)
                                    .foregroundStyle(Color.purple)
                            }
                            
                            Text("EXTERNAL")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .italic()
                                .foregroundStyle(.white)
                            
                            Text("GH777")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .italic()
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .indigo],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // MARK: - SEARCH BAR
                        AppSearchField(
                            text: $searchText,
                            prompt: language.text("installed.search"),
                            clearLabel: language.text("common.clear")
                        )
                        .padding(.horizontal)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)

                        // MARK: - CONTENT
                        VStack(alignment: .leading, spacing: 15) {
                            if !hasLocalContent && (store.isBusy || isImportingWallpapers) {
                                loadingState
                            } else if !hasLocalContent {
                                emptyState
                            } else if !hasSearchResults && !store.isBusy {
                                searchEmptyState
                            } else {
                                // Patches Section
                                if !filteredItems.isEmpty {
                                    sectionHeader(title: language.text("patch.title"))
                                    
                                    ForEach(filteredItems) { item in
                                        itemRow(item)
                                    }
                                }
                                
                                // Wallpapers Section
                                if !filteredWallpaperPackages.isEmpty {
                                    sectionHeader(title: language.text("tab.wallpapers"))
                                    
                                    ForEach(filteredWallpaperPackages) { package in
                                        NavigationLink {
                                            InstalledWallpaperPackageDetailView(
                                                package: package,
                                                onApplied: reloadWallpaperPackages
                                            )
                                        } label: {
                                            wallpaperRow(package)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            if cleanerEnabled {
                                sectionHeader(title: language.text("repository.utilities"))
                                cleanerRow
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        Menu {
                            Button { showCreate = true } label: {
                                Label(language.text("patch.new"), systemImage: "doc.badge.plus")
                            }
                            Button { showImporter = true } label: {
                                Label(language.text("patch.import"), systemImage: "square.and.arrow.down")
                            }
                            Button { showWallpaperImporter = true } label: {
                                Label(language.text("wallpaper.import"), systemImage: "photo.badge.plus")
                            }
                        } label: {
                            if store.isBusy || isImportingWallpapers {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        AppUtilityToolbar(
                            language: language,
                            onOpenSettings: onOpenSettings,
                            onOpenLogs: onOpenLogs
                        )
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
                    onCancel: {
                        showImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCreate) {
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false
                ) { project, password in
                    store.create(project: project, password: password)
                }
            }
            .sheet(isPresented: $showCleaner) {
                CleanerView()
            }
            .sheet(item: $draftCoordinator.request) { request in
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false,
                    initialDraft: request.draft
                ) { project, password in
                    store.create(project: project, password: password)
                    draftCoordinator.clear()
                }
            }
            .sheet(isPresented: $showWallpaperImporter) {
                FileDocumentPicker(
                    allowedContentTypes: WallpaperPackagePickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: true,
                    allowsMultipleSelection: true,
                    onSelection: { result in
                        showWallpaperImporter = false
                        if case .success(let urls) = result, !urls.isEmpty {
                            importWallpaperPackages(urls)
                        }
                    },
                    onCancel: {
                        showWallpaperImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .alert(item: $wallpaperImportFeedback) { feedback in
                Alert(
                    title: Text(language.text(feedback.titleKey)),
                    message: Text(feedback.message),
                    dismissButton: .default(Text(language.text("common.ok")))
                )
            }
            .alert(item: $wallpaperPendingDeletion) { package in
                Alert(
                    title: Text(language.text("wallpaper.delete_title")),
                    message: Text(language.text(
                        "wallpaper.delete_message",
                        package.displayName
                    )),
                    primaryButton: .destructive(
                        Text(language.text("common.delete"))
                    ) {
                        deleteWallpaperPackage(package)
                    },
                    secondaryButton: .cancel(Text(language.text("common.cancel")))
                )
            }
            .onAppear {
                reloadWallpaperPackages()
                consumeExternalImport()
#if targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains(
                    "--simulate-wallpaper-detail"
                ), !wallpaperPackages.isEmpty,
                   simulatedWallpaperDetailGate.claim() {
                    DispatchQueue.main.async {
                        showSimulatedWallpaperDetail = true
                    }
                }
#endif
            }
            .navigationDestination(isPresented: $showSimulatedWallpaperDetail) {
                if let package = wallpaperPackages.first {
                    InstalledWallpaperPackageDetailView(
                        package: package,
                        onApplied: reloadWallpaperPackages
                    )
                }
            }
            .onChange(of: draftCoordinator.importRequest?.id) { _ in
                consumeExternalImport()
            }
        }
    }

    private func consumeExternalImport() {
        guard let request = draftCoordinator.importRequest else { return }
        draftCoordinator.clearImport()
        store.importPackage(from: request.source)
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black))
                .tracking(1.5)
                .foregroundStyle(.gray)
            Spacer()
            Rectangle()
                .fill(LinearGradient(colors: [.purple, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .padding(.top, 10)
    }

    private func wallpaperRow(_ package: WallpaperStagedPackage) -> some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 44, height: 44)
                Image(systemName: wallpaperSymbol)
                    .foregroundStyle(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(package.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    InstalledContentKindBadge(kind: .wallpaper, language: language)
                    Text(language.text(
                        "wallpaper.package_summary",
                        Int64(package.payload.descriptors.count),
                        ByteCountFormatter.string(
                            fromByteCount: package.payload.totalBytes,
                            countStyle: .file
                        )
                    ))
                    .font(.caption2)
                    .foregroundStyle(.gray)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.03)))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func cleanerRow: some View {
        Button {
            showCleaner = true
        } label: {
            HStack(spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.text("tab.cleaner"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(language.text("repository.cleaner_subtitle"))
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.gray)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.03)))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var wallpaperSymbol: String {
        if #available(iOS 18.0, *) {
            return "photo.on.rectangle.angled.fill"
        }
        return "photo.fill.on.rectangle.fill"
    }

    private func reloadWallpaperPackages() {
        wallpaperPackages = WallpaperPackageStore.packages()
    }

    private func deleteWallpaperPackage(_ package: WallpaperStagedPackage) {
        do {
            try WallpaperPackageStore.delete(package)
            reloadWallpaperPackages()
        } catch {
            wallpaperImportFeedback = WallpaperImportFeedback(
                titleKey: "wallpaper.operation_failed",
                message: wallpaperErrorMessage(error)
            )
        }
    }

    private func importWallpaperPackages(_ urls: [URL]) {
        guard !isImportingWallpapers else { return }
        isImportingWallpapers = true
        DispatchQueue.global(qos: .userInitiated).async {
            var imported = 0
            var failures: [String] = []
            for url in urls {
                do {
                    _ = try WallpaperPackageStore.importPackage(from: url)
                    imported += 1
                    log("wallpaper: staged \(url.lastPathComponent)")
                } catch {
                    failures.append(
                        "\(url.lastPathComponent): \(wallpaperErrorMessage(error))"
                    )
                    log("wallpaper: import rejected \(url.lastPathComponent)")
                }
            }
            DispatchQueue.main.async {
                isImportingWallpapers = false
                reloadWallpaperPackages()
                wallpaperImportFeedback = WallpaperImportFeedback(
                    titleKey: failures.isEmpty
                        ? "wallpaper.import_done_title"
                        : "wallpaper.import_result_title",
                    message: failures.isEmpty
                        ? language.text(
                            "wallpaper.import_done_message",
                            Int64(imported)
                        )
                        : failures.joined(separator: "\n")
                )
            }
        }
    }

    private func wallpaperErrorMessage(_ error: Error) -> String {
        if let wallpaperError = error as? WallpaperLabError {
            return language.text(wallpaperError.localizationKey)
        }
        return language.text("wallpaper.error.unknown")
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem) -> some View {
        let row = PatchProjectRow(item: item, language: language)
        
        if item.isLocked {
            Button { store.requestUnlock(for: item) } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                PatchProjectDetailView(store: store, projectID: item.id)
            } label: {
                row
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(Color.purple)
            Text(language.text("installed.empty_title"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(language.text("installed.empty_message"))
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Button(language.text("patch.new")) { showCreate = true }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.purple)
            Text(language.text("installed.loading"))
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.gray)
            Text(language.text("patch.search_empty"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(language.text("patch.search_empty_message"))
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private struct WallpaperImportFeedback: Identifiable {
    let id = UUID()
    let titleKey: String
    let message: String
}

private struct PatchProjectRow: View {
    let item: PatchLibraryItem
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 44, height: 44)
                Image(systemName: item.isLocked ? "lock.doc.fill" : "shippingbox.fill")
                    .foregroundStyle(item.isLocked ? .gray : .purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.project?.name ?? language.text("patch.locked_project"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    InstalledContentKindBadge(kind: .patch, language: language)
                    if let author = item.project?.author, !author.isEmpty {
                        Text(language.text("patch.by_author", author))
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
                
                Text(rowDetail)
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            Spacer()
            
            HStack(spacing: 8) {
                if item.summary.isPasswordProtected {
                    Image(systemName: "key.fill")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                if item.project?.isPrivate == true {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.purple)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.03)))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var rowDetail: String {
        if item.isLocked {
            return language.text("patch.tap_to_unlock")
        }
        if item.project?.isPrivate == true, !item.isAuthorCopy {
            return language.text("patch.private_received")
        }
        return language.text(
            item.summary.schemaVersion >= 2
                ? "patch.workspace_items_count"
                : "patch.rules_count",
            Int64((item.project?.rules.count ?? 0) + (item.project?.directories.count ?? 0))
        )
    }
}

private enum InstalledContentKind {
    case patch
    case wallpaper

    var localizationKey: String {
        switch self {
        case .patch: return "installed.kind.patch"
        case .wallpaper: return "installed.kind.wallpaper"
        }
    }

    var systemImage: String {
        switch self {
        case .patch: return "shippingbox.fill"
        case .wallpaper: return "photo.fill"
        }
    }
}

private struct InstalledContentKindBadge: View {
    let kind: InstalledContentKind
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.systemImage)
                .accessibilityHidden(true)
            Text(language.text(kind.localizationKey))
        }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 18)
            .background(Color.purple.opacity(0.3), in: Capsule())
            .overlay(
                Capsule().stroke(Color.purple.opacity(0.5), lineWidth: 1)
            )
            .fixedSize()
            .accessibilityElement(children: .combine)
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
            ZStack {
                Color(hex: "#0a0a0c").ignoresSafeArea()
                
                VStack(spacing: 25) {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.purple)
                        
                        Text(language.text("patch.unlock"))
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 40)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(language.text("patch.password"))
                            .font(.caption.bold())
                            .foregroundStyle(.gray)
                            .padding(.leading, 4)
                        
                        SecureField("", text: $password)
                            .textContentType(.password)
                            .submitLabel(.done)
                            .onSubmit(unlock)
                            .onChange(of: password) { _ in
                                store.clearUnlockError()
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.05)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .foregroundStyle(.white)
                        
                        if let errorKey = store.unlockErrorKey {
                            Text(language.text(errorKey))
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        if let origin = request.origin {
                            Text(language.text(
                                "patch.password_repo_contact",
                                origin.repositoryName
                            ))
                        } else {
                            Text(language.text("patch.password_once_message"))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: unlock) {
                        Text(language.text("patch.unlock"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(15)
                    }
                    .disabled(password.isEmpty || store.isBusy)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
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

private struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID
    @State private var showEditor = false
    @State private var editingRule: PatchRule?
    @State private var showApplyConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var showChangedRestoreConfirmation = false
    @State private var showResetConfirmation = false
    @State private var restoreChangedPaths: [String] = []
    @State private var isWorking = false
    @State private var actionAlert: PatchStoreAlert?
    @State private var shareRequest: PatchShareRequest?

    private var item: PatchLibraryItem? {
        store.items.first(where: { $0.id == projectID })
    }

    private var receipt: PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: projectID)
    }

    private var isWorkspaceProject: Bool {
        (item?.summary.schemaVersion ?? 1) >= 2
    }

    var body: some View {
        List {
            if let item, let project = item.project {
                Section(language.text("patch.information")) {
                    if !project.author.isEmpty {
                        patchInfoRow(
                            label: language.text("patch.author"),
                            value: project.author
                        )
                    }
                    patchInfoRow(label: language.text("patch.privacy")) {
                        Label(
                            language.text(project.isPrivate
                                ? "patch.private"
                                : "patch.public"),
                            systemImage: project.isPrivate
                                ? "eye.slash.fill"
                                : "eye"
                        )
                        .foregroundStyle(project.isPrivate ? AppTheme.accent : Color.secondary)
                    }
                    if let origin = item.origin {
                        patchInfoRow(
                            label: language.text("repository.source"),
                            value: origin.repositoryName
                        )
                    }
                }

                if project.isPrivate && !item.canInspectContents {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(AppTheme.accent)
                            Text(language.text("patch.private_hidden_title"))
                                .font(.headline)
                            Text(language.text("patch.private_hidden_message"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else if isWorkspaceProject {
                    Section {
                        ForEach(project.allBundleIdentifiers, id: \.self) { bundleID in
                            Label {
                                Text(bundleID)
                                    .font(.subheadline.monospaced())
                            } icon: {
                                Image(systemName: "app.dashed")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        LabeledContent(language.text("patch.files")) {
                            Text("\(project.rules.count)")
                        }
                        LabeledContent(language.text("patch.folders")) {
                            Text("\(project.directories.count)")
                        }
                        if let workspaceURL = item.workspaceURL {
                            NavigationLink {
                                FileBrowserView(
                                    containerPath: workspaceURL.path,
                                    title: project.name,
                                    bundleID: nil
                                )
                            } label: {
                                Label(
                                    language.text("patch.open_workspace"),
                                    systemImage: "folder"
                                )
                            }
                        }
                    } header: {
                        Text(language.text("patch.workspace"))
                    } footer: {
                        Text(language.text("patch.workspace_detail_footer"))
                    }
                } else {
                    Section {
                        ForEach(project.rules) { rule in
                            Button {
                                editingRule = rule
                            } label: {
                                HStack(spacing: 10) {
                                    ruleSummary(rule)
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(language.text("patch.edit_rule_hint"))
                        }
                    } header: {
                        Text(language.text("patch.rules"))
                    } footer: {
                        Text(language.text("patch.legacy_footer"))
                    }
                }

                Section(language.text("patch.password")) {
                    HStack(spacing: 12) {
                        Image(systemName: item.summary.isPasswordProtected ? "lock.fill" : "lock.open")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Text(language.text(item.summary.isPasswordProtected
                            ? "patch.password_locked"
                            : "patch.no_password"))
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        showApplyConfirmation = true
                    } label: {
                        actionLabel("patch.apply", systemImage: "checkmark.shield.fill")
                    }
                    .disabled(isWorking || receipt != nil)

                    if receipt != nil {
                        Button {
                            showResetConfirmation = true
                        } label: {
                            actionLabel("patch.reset", systemImage: "arrow.counterclockwise.circle")
                        }
                        .disabled(isWorking)

                        Button(role: .destructive) {
                            showRestoreConfirmation = true
                        } label: {
                            actionLabel("patch.restore", systemImage: "arrow.uturn.backward.circle")
                        }
                        .disabled(isWorking)
                    }

                    Button(action: prepareExport) {
                        actionLabel("patch.export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isWorking)
                } footer: {
                    Text(language.text("patch.apply_footer"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item?.project?.name ?? language.text("patch.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isWorking {
                    ProgressView()
                } else if !isWorkspaceProject, item?.canInspectContents == true {
                    Button(language.text("patch.edit```swift
.disabled(item?.project == nil)
}
}
}
.sheet(isPresented: $showEditor) {
if let item, let project = item.project {
PatchProjectEditorView(
existingProject: project,
passwordIsProtected: item.summary.isPasswordProtected
) { updatedProject, _ in
store.update(project: updatedProject)
}
}
}
.sheet(item: $editingRule) { rule in
PatchRuleEditorView(rule: rule) { updatedRule in
updateRule(updatedRule)
}
}
.confirmationDialog(
language.text("patch.apply_confirm_title"),
isPresented: $showApplyConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.apply")) { apply() }
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(language.text("patch.apply_confirm_message"))
}
.confirmationDialog(
language.text("patch.restore_confirm_title"),
isPresented: $showRestoreConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.restore"), role:.destructive) { prepareRestore() }
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(language.text("patch.restore_confirm_message"))
}
.confirmationDialog(
language.text("patch.restore_changed_title"),
isPresented: $showChangedRestoreConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.restore_changed_action"), role:.destructive) {
restore(allowChangedTargets: true)
}
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(changedRestoreMessage)
}
.confirmationDialog(
language.text("patch.reset_confirm_title"),
isPresented: $showResetConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.reset"), role:.destructive) { resetToAppliedState() }
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(language.text("patch.reset_confirm_message"))
}
.alert(item: $actionAlert) { alert in
Alert(
title: Text(language.text(alert.titleKey)),
message: Text(alert.message(language: language)),
dismissButton:.default(Text(language.text("common.ok")))
)
}
.sheet(item: $shareRequest) { request in
PatchActivityView(items: [request.url])
.ignoresSafeArea()
}
}

private func actionLabel(_ key: String, systemImage: String) -> some View {
Label(language.text(key), systemImage: systemImage)
.frame(maxWidth:.infinity, alignment:.leading)
}

private func patchInfoRow(
label: String,
value: String
) -> some View {
patchInfoRow(label: label) {
Text(value)
.foregroundStyle(.primary)
}
}

private func patchInfoRow<Content: View>(
label: String,
@ViewBuilder value: () -> Content
) -> some View {
HStack(alignment:.firstTextBaseline, spacing: 12) {
Text(label)
.foregroundStyle(.secondary)
Spacer(minLength: 16)
value()
.multilineTextAlignment(.trailing)
.fixedSize(horizontal: false, vertical: true)
}
.font(.subheadline)
.padding(.vertical, 5)
}

private func ruleSummary(_ rule: PatchRule) -> some View {
VStack(alignment:.leading, spacing: 5) {
Text(rule.bundleID)
.font(.subheadline.weight(.semibold))
.foregroundStyle(.primary)
Text(rule.relativePath)
.font(.caption.monospaced())
.foregroundStyle(.secondary)
.lineLimit(2)
Label(rule.replacementFilename, systemImage: "arrow.triangle.2.circlepath")
.font(.caption)
.foregroundStyle(AppTheme.accent)
}
.padding(.vertical, 3)
}

private func updateRule(_ updatedRule: PatchRule) {
guard var project = item?.project,
let index = project.rules.firstIndex(where: { $0.id == updatedRule.id }) else {
return
}
project.rules[index] = updatedRule
project.updatedAt = Date()
do {
try PatchPackageCodec.validate(project)
store.update(project: project)
} catch let error as PatchPackageError {
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: error.localizationKey,
messageArgument: error.localizationArgument
)
} catch {
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: "patch.error.invalid_project"
)
}
}

private func apply() {
guard let item, let baseProject = item.project else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
let project = item.summary.schemaVersion >= 2 && item.canInspectContents
? try PatchProjectLibrary.synchronizeWorkspace(item: item)
: baseProject
_ = try DevicePatchService.apply(project: project)
await MainActor.run {
store.reload()
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.apply")
}
}
}
}

private func prepareExport() {
guard let item else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
if item.summary.schemaVersion >= 2, item.canInspectContents {
_ = try PatchProjectLibrary.synchronizeWorkspace(item: item)
}
await MainActor.run {
store.reload()
isWorking = false
shareRequest = PatchShareRequest(url: item.packageURL)
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: "patch.error.invalid_project"
)
}
}
}
}

private var changedRestoreMessage: String {
guard item?.project?.isPrivate!= true || item?.isAuthorCopy == true else {
return language.text(
"patch.restore_changed_private_message",
Int64(restoreChangedPaths.count)
)
}
var visiblePaths = restoreChangedPaths.prefix(5).joined(separator: "\n")
if restoreChangedPaths.count > 5 {
visiblePaths += "\n…"
}
return language.text(
"patch.restore_changed_message",
Int64(restoreChangedPaths.count),
visiblePaths
)
}

private func prepareRestore() {
guard let receipt else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
let inspection = try DevicePatchService.inspectRestore(receipt: receipt)
if inspection.changedTargets.isEmpty {
try DevicePatchService.restore(receipt: receipt)
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.done",
messageKey: "patch.restored_message"
)
}
} else {
await MainActor.run {
isWorking = false
restoreChangedPaths = inspection.changedTargets.map(\.displayPath)
showChangedRestoreConfirmation = true
}
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: "patch.error.restore"
)
}
}
}
}

private func restore(allowChangedTargets: Bool) {
guard let receipt else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
try DevicePatchService.restore(
receipt: receipt,
allowChangedTargets: allowChangedTargets
)
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message")
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.restore")
}
}
}
}

private func resetToAppliedState() {
guard let receipt, let project = item?.project else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
try DevicePatchService.resetToAppliedState(
receipt: receipt,
project: project
)
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.done",
messageKey: "patch.reset_message"
)
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.reset")
}
}
}
}

private func privateErrorKey(for error: PatchPackageError) -> String {
guard item?.project?.isPrivate == true,
item?.isAuthorCopy == false else {
return error.localizationKey
}
return "patch.error.private_operation"
}

private func privateErrorArgument(for error: PatchPackageError) -> String? {
guard item?.project?.isPrivate == true,
item?.isAuthorCopy == false else {
return error.localizationArgument
}
return nil
}
}

private struct PatchShareRequest: Identifiable {
let id = UUID()
let url: URL
}

private struct PatchActivityView: UIViewControllerRepresentable {
let items:

func makeUIViewController(context: Context) -> UIActivityViewController {
UIActivityViewController(activityItems: items, applicationActivities: nil)
}

func updateUIViewController(
_ uiViewController: UIActivityViewController,
context: Context
) {}
}
``````swift
Button(language.text("patch.edit")) { showEditor = true }
.disabled(item?.project == nil)
}
}
}
.sheet(isPresented: $showEditor) {
if let item, let project = item.project {
PatchProjectEditorView(
existingProject: project,
passwordIsProtected: item.summary.isPasswordProtected
) { updatedProject, _ in
store.update(project: updatedProject)
}
}
}
.sheet(item: $editingRule) { rule in
PatchRuleEditorView(rule: rule) { updatedRule in
updateRule(updatedRule)
}
}
.confirmationDialog(
language.text("patch.apply_confirm_title"),
isPresented: $showApplyConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.apply")) { apply() }
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(language.text("patch.apply_confirm_message"))
}
.confirmationDialog(
language.text("patch.restore_confirm_title"),
isPresented: $showRestoreConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.restore"), role:.destructive) { prepareRestore() }
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(language.text("patch.restore_confirm_message"))
}
.confirmationDialog(
language.text("patch.restore_changed_title"),
isPresented: $showChangedRestoreConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.restore_changed_action"), role:.destructive) {
restore(allowChangedTargets: true)
}
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(changedRestoreMessage)
}
.confirmationDialog(
language.text("patch.reset_confirm_title"),
isPresented: $showResetConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.reset"), role:.destructive) { resetToAppliedState() }
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(language.text("patch.reset_confirm_message"))
}
.alert(item: $actionAlert) { alert in
Alert(
title: Text(language.text(alert.titleKey)),
message: Text(alert.message(language: language)),
dismissButton:.default(Text(language.text("common.ok")))
)
}
.sheet(item: $shareRequest) { request in
PatchActivityView(items: [request.url])
.ignoresSafeArea()
}
}

private func actionLabel(_ key: String, systemImage: String) -> some View {
Label(language.text(key), systemImage: systemImage)
.frame(maxWidth:.infinity, alignment:.leading)
}

private func patchInfoRow(
label: String,
value: String
) -> some View {
patchInfoRow(label: label) {
Text(value)
.foregroundStyle(.primary)
}
}

private func patchInfoRow<Content: View>(
label: String,
@ViewBuilder value: () -> Content
) -> some View {
HStack(alignment:.firstTextBaseline, spacing: 12) {
Text(label)
.foregroundStyle(.secondary)
Spacer(minLength: 16)
value()
.multilineTextAlignment(.trailing)
.fixedSize(horizontal: false, vertical: true)
}
.font(.subheadline)
.padding(.vertical, 5)
}

private func ruleSummary(_ rule: PatchRule) -> some View {
VStack(alignment:.leading, spacing: 5) {
Text(rule.bundleID)
.font(.subheadline.weight(.semibold))
.foregroundStyle(.primary)
Text(rule.relativePath)
.font(.caption.monospaced())
.foregroundStyle(.secondary)
.lineLimit(2)
Label(rule.replacementFilename, systemImage: "arrow.triangle.2.circlepath")
.font(.caption)
.foregroundStyle(AppTheme.accent)
}
.padding(.vertical, 3)
}

private func updateRule(_ updatedRule: PatchRule) {
guard var project = item?.project,
let index = project.rules.firstIndex(where: { $0.id == updatedRule.id }) else {
return
}
project.rules[index] = updatedRule
project.updatedAt = Date()
do {
try PatchPackageCodec.validate(project)
store.update(project: project)
} catch let error as PatchPackageError {
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: error.localizationKey,
messageArgument: error.localizationArgument
)
} catch {
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: "patch.error.invalid_project"
)
}
}

private func apply() {
guard let item, let baseProject = item.project else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
let project = item.summary.schemaVersion >= 2 && item.canInspectContents
? try PatchProjectLibrary.synchronizeWorkspace(item: item)
: baseProject
_ = try DevicePatchService.apply(project: project)
await MainActor.run {
store.reload()
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.apply")
}
}
}
}

private func prepareExport() {
guard let item else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
if item.summary.schemaVersion >= 2, item.canInspectContents {
_ = try PatchProjectLibrary.synchronizeWorkspace(item: item)
}
await MainActor.run {
store.reload()
isWorking = false
shareRequest = PatchShareRequest(url: item.packageURL)
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: "patch.error.invalid_project"
)
}
}
}
}

private var changedRestoreMessage: String {
guard item?.project?.isPrivate!= true || item?.isAuthorCopy == true else {
return language.text(
"patch.restore_changed_private_message",
Int64(restoreChangedPaths.count)
)
}
var visiblePaths = restoreChangedPaths.prefix(5).joined(separator: "\n")
if restoreChangedPaths.count > 5 {
visiblePaths += "\n…"
}
return language.text(
"patch.restore_changed_message",
Int64(restoreChangedPaths.count),
visiblePaths
)
}

private func prepareRestore() {
guard let receipt else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
let inspection = try DevicePatchService.inspectRestore(receipt: receipt)
if inspection.changedTargets.isEmpty {
try DevicePatchService.restore(receipt: receipt)
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.done",
messageKey: "patch.restored_message"
)
}
} else {
await MainActor.run {
isWorking = false
restoreChangedPaths = inspection.changedTargets.map(\.displayPath)
showChangedRestoreConfirmation = true
}
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: "patch.error.restore"
)
}
}
}
}

private func restore(allowChangedTargets: Bool) {
guard let receipt else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
try DevicePatchService.restore(
receipt: receipt,
allowChangedTargets: allowChangedTargets
)
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message")
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.restore")
}
}
}
}

private func resetToAppliedState() {
guard let receipt, let project = item?.project else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
try DevicePatchService.resetToAppliedState(
receipt: receipt,
project: project
)
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.done",
messageKey: "patch.reset_message"
)
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.reset")
}
}
}
}

private func privateErrorKey(for error: PatchPackageError) -> String {
guard item?.project?.isPrivate == true,
item?.isAuthorCopy == false else {
return error.localizationKey
}
return "patch.error.private_operation"
}

private func privateErrorArgument(for error: PatchPackageError) -> String? {
guard item?.project?.isPrivate == true,
item?.isAuthorCopy == false else {
return error.localizationArgument
}
return nil
}
}

private struct PatchShareRequest: Identifiable {
let id = UUID()
let url: URL
}

private struct PatchActivityView: UIViewControllerRepresentable {
let items:

func makeUIViewController(context: Context) -> UIActivityViewController {
UIActivityViewController(activityItems: items, applicationActivities: nil)
}

func updateUIViewController(
_ uiViewController: UIActivityViewController,
context: Context
) {}
}
``````swift
Button(language.text("patch.edit")) { showEditor = true }
.disabled(item?.project == nil)
}
}
}
.sheet(isPresented: $showEditor) {
if let item, let project = item.project {
PatchProjectEditorView(
existingProject: project,
passwordIsProtected: item.summary.isPasswordProtected
) { updatedProject, _ in
store.update(project: updatedProject)
}
}
}
.sheet(item: $editingRule) { rule in
PatchRuleEditorView(rule: rule) { updatedRule in
updateRule(updatedRule)
}
}
.confirmationDialog(
language.text("patch.apply_confirm_title"),
isPresented: $showApplyConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.apply")) { apply() }
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(language.text("patch.apply_confirm_message"))
}
.confirmationDialog(
language.text("patch.restore_confirm_title"),
isPresented: $showRestoreConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.restore"), role:.destructive) { prepareRestore() }
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(language.text("patch.restore_confirm_message"))
}
.confirmationDialog(
language.text("patch.restore_changed_title"),
isPresented: $showChangedRestoreConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.restore_changed_action"), role:.destructive) {
restore(allowChangedTargets: true)
}
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(changedRestoreMessage)
}
.confirmationDialog(
language.text("patch.reset_confirm_title"),
isPresented: $showResetConfirmation,
titleVisibility:.visible
) {
Button(language.text("patch.reset"), role:.destructive) { resetToAppliedState() }
Button(language.text("common.cancel"), role:.cancel) {}
} message: {
Text(language.text("patch.reset_confirm_message"))
}
.alert(item: $actionAlert) { alert in
Alert(
title: Text(language.text(alert.titleKey)),
message: Text(alert.message(language: language)),
dismissButton:.default(Text(language.text("common.ok")))
)
}
.sheet(item: $shareRequest) { request in
PatchActivityView(items: [request.url])
.ignoresSafeArea()
}
}

private func actionLabel(_ key: String, systemImage: String) -> some View {
Label(language.text(key), systemImage: systemImage)
.frame(maxWidth:.infinity, alignment:.leading)
}

private func patchInfoRow(
label: String,
value: String
) -> some View {
patchInfoRow(label: label) {
Text(value)
.foregroundStyle(.primary)
}
}

private func patchInfoRow<Content: View>(
label: String,
@ViewBuilder value: () -> Content
) -> some View {
HStack(alignment:.firstTextBaseline, spacing: 12) {
Text(label)
.foregroundStyle(.secondary)
Spacer(minLength: 16)
value()
.multilineTextAlignment(.trailing)
.fixedSize(horizontal: false, vertical: true)
}
.font(.subheadline)
.padding(.vertical, 5)
}

private func ruleSummary(_ rule: PatchRule) -> some View {
VStack(alignment:.leading, spacing: 5) {
Text(rule.bundleID)
.font(.subheadline.weight(.semibold))
.foregroundStyle(.primary)
Text(rule.relativePath)
.font(.caption.monospaced())
.foregroundStyle(.secondary)
.lineLimit(2)
Label(rule.replacementFilename, systemImage: "arrow.triangle.2.circlepath")
.font(.caption)
.foregroundStyle(AppTheme.accent)
}
.padding(.vertical, 3)
}

private func updateRule(_ updatedRule: PatchRule) {
guard var project = item?.project,
let index = project.rules.firstIndex(where: { $0.id == updatedRule.id }) else {
return
}
project.rules[index] = updatedRule
project.updatedAt = Date()
do {
try PatchPackageCodec.validate(project)
store.update(project: project)
} catch let error as PatchPackageError {
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: error.localizationKey,
messageArgument: error.localizationArgument
)
} catch {
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: "patch.error.invalid_project"
)
}
}

private func apply() {
guard let item, let baseProject = item.project else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
let project = item.summary.schemaVersion >= 2 && item.canInspectContents
? try PatchProjectLibrary.synchronizeWorkspace(item: item)
: baseProject
_ = try DevicePatchService.apply(project: project)
await MainActor.run {
store.reload()
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.apply")
}
}
}
}

private func prepareExport() {
guard let item else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
if item.summary.schemaVersion >= 2, item.canInspectContents {
_ = try PatchProjectLibrary.synchronizeWorkspace(item: item)
}
await MainActor.run {
store.reload()
isWorking = false
shareRequest = PatchShareRequest(url: item.packageURL)
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: "patch.error.invalid_project"
)
}
}
}
}

private var changedRestoreMessage: String {
guard item?.project?.isPrivate!= true || item?.isAuthorCopy == true else {
return language.text(
"patch.restore_changed_private_message",
Int64(restoreChangedPaths.count)
)
}
var visiblePaths = restoreChangedPaths.prefix(5).joined(separator: "\n")
if restoreChangedPaths.count > 5 {
visiblePaths += "\n…"
}
return language.text(
"patch.restore_changed_message",
Int64(restoreChangedPaths.count),
visiblePaths
)
}

private func prepareRestore() {
guard let receipt else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
let inspection = try DevicePatchService.inspectRestore(receipt: receipt)
if inspection.changedTargets.isEmpty {
try DevicePatchService.restore(receipt: receipt)
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.done",
messageKey: "patch.restored_message"
)
}
} else {
await MainActor.run {
isWorking = false
restoreChangedPaths = inspection.changedTargets.map(\.displayPath)
showChangedRestoreConfirmation = true
}
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: "patch.error.restore"
)
}
}
}
}

private func restore(allowChangedTargets: Bool) {
guard let receipt else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
try DevicePatchService.restore(
receipt: receipt,
allowChangedTargets: allowChangedTargets
)
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message")
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.restore")
}
}
}
}

private func resetToAppliedState() {
guard let receipt, let project = item?.project else { return }
isWorking = true
Task.detached(priority:.userInitiated) {
do {
try DevicePatchService.resetToAppliedState(
receipt: receipt,
project: project
)
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.done",
messageKey: "patch.reset_message"
)
}
} catch let error as PatchPackageError {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(
titleKey: "common.failed",
messageKey: privateErrorKey(for: error),
messageArgument: privateErrorArgument(for: error)
)
}
} catch {
await MainActor.run {
isWorking = false
actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.reset")
}
}
}
}

private func privateErrorKey(for error: PatchPackageError) -> String {
guard item?.project?.isPrivate == true,
item?.isAuthorCopy == false else {
return error.localizationKey
}
return "patch.error.private_operation"
}

private func privateErrorArgument(for error: PatchPackageError) -> String? {
guard item?.project?.isPrivate == true,
item?.isAuthorCopy == false else {
return error.localizationArgument
}
return nil
}
}

private struct PatchShareRequest: Identifiable {
let id = UUID()
let url: URL
}

private struct PatchActivityView: UIViewControllerRepresentable {
let items:

func makeUIViewController(context: Context) -> UIActivityViewController {
UIActivityViewController(activityItems: items, applicationActivities: nil)
}

func updateUIViewController(
_ uiViewController: UIActivityViewController,
context: Context
) {}
}
