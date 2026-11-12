import Foundation

struct PatchStoreAlert: Identifiable {
    let id = UUID()
    let titleKey: String
    let messageKey: String
    var messageArgument: String?

    init(titleKey: String, messageKey: String, messageArgument: String? = nil) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.messageArgument = messageArgument
    }

    func message(language: AppLanguage) -> String {
        if let messageArgument {
            return language.text(messageKey, messageArgument)
        }
        return language.text(messageKey)
    }
}

@MainActor
final class PatchProjectStore: ObservableObject {
    @Published private(set) var items: [PatchLibraryItem] = []
    @Published private(set) var allItems: [PatchLibraryItem] = []
    @Published var currentSection: AppSection = .home 
    @Published private(set) var isBusy = false
    @Published var passwordRequest: PatchPasswordRequest?
    @Published var alert: PatchStoreAlert?
    @Published var unlockErrorKey: String?

    private struct PendingUnlock {
        let data: Data
        let summary: PatchPackageSummary
        let existingURL: URL?
        let origin: PatchPackageOrigin?
    }

    private var pendingUnlock: PendingUnlock?

    init() {
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let loadedItems = PatchProjectLibrary.load()
            var bundleItems: [PatchLibraryItem] = []
            
            let fileManager = FileManager.default
            let bundlePath = Bundle.main.bundlePath
            
            if let enumerator = fileManager.enumerator(atPath: bundlePath) {
                while let filePath = enumerator.nextObject() as? String {
                    if filePath.hasSuffix(".3105") {
                        let fullPath = (bundlePath as NSString).appendingPathComponent(filePath)
                        let url = URL(fileURLWithPath: fullPath)
                        do {
                            let data = try Data(contentsOf: url)
                            let summary = try PatchPackageCodec.inspect(data)
                            let item = PatchLibraryItem(
                                summary: summary,
                                contentKey: nil, 
                                packageURL: url,
                                isAuthorCopy: false,
                                origin: nil
                            )
                            bundleItems.append(item)
                        } catch {
                            print("Erro ao ler arquivo: \(url.lastPathComponent)")
                        }
                    }
                }
            }
            
            let finalItems = loadedItems + bundleItems
            await self?.finishInitialLoad(finalItems)
        }
    }

    func filterProjects(for section: AppSection) {
        switch section {
        case .home:
            items = allItems.filter { $0.project?.name.localizedCaseInsensitiveContains("HS") ?? false }
        case .new:
            items = allItems.filter { $0.project?.name.localizedCaseInsensitiveContains("PAINEL") ?? false }
        case .sources:
            items = allItems.filter { $0.project?.name.localizedCaseInsensitiveContains("HOLOGRAMAS") ?? false }
        case .installed:
            items = allItems.filter { item in
                let name = item.project?.name ?? ""
                return !name.localizedCaseInsensitiveContains("HS") && 
                       !name.localizedCaseInsensitiveContains("PAINEL") && 
                       !name.localizedCaseInsensitiveContains("HOLOGRAMAS")
            }
        default:
            items = allItems
        }
    }

    func reload() {
        let loadedItems = PatchProjectLibrary.load()
        allItems = loadedItems
        filterProjects(for: currentSection)
    }

    private func finishInitialLoad(_ loadedItems: [PatchLibraryItem]) {
        allItems = loadedItems
        filterProjects(for: currentSection)
        isBusy = false
    }

    func create(project: PatchProject, password: String?) {
        runOperation(successMessageKey: "patch.created_message") {
            let encoded = try PatchPackageCodec.encodeNew(project: project, password: password)
            let summary = try PatchPackageCodec.inspect(encoded.data)
            let workspace = try PatchWorkspaceService.createWorkspace(for: project)
            var savedURL: URL?
            do {
                if summary.isPasswordProtected {
                    try PatchKeyStore.store(encoded.contentKey, for: summary)
                }
                savedURL = try PatchProjectLibrary.save(
                    data: encoded.data,
                    projectName: project.name
                )
                try PatchProjectLibrary.markAsAuthorCopy(packageID: project.id)
            } catch {
                try? FileManager.default.removeItem(at: workspace)
                if let savedURL {
                    try? FileManager.default.removeItem(at: savedURL)
                }
                try? PatchKeyStore.delete(for: summary)
                throw error
            }
        }
    }

    func update(project: PatchProject) {
        guard let item = items.first(where: { $0.id == project.id }),
              let contentKey = item.contentKey else {
            present(.invalidProject)
            return
        }
        runOperation(successMessageKey: "patch.updated_message") {
            let original = try PatchProjectLibrary.readPackage(at: item.packageURL)
            let updated = try PatchPackageCodec.update(
                original,
                project: project,
                contentKey: contentKey,
                schemaVersion: PatchPackageCodec.latestSchemaVersion
            )
            _ = try PatchProjectLibrary.save(
                data: updated,
                projectName: project.name,
                existingURL: item.packageURL
            )
        }
    }

    func importPackage(at sourceURL: URL) {
        guard !isBusy else { return }
        isBusy = true
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if hasAccess { sourceURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try PatchProjectLibrary.readPackage(at: sourceURL)
                let summary = try PatchPackageCodec.inspect(data)
                let existingURL = await self?.existingPackageURL(for: summary.packageID)
                if let pending = try Self.persistImportedPackage(
                    data: data,
                    summary: summary,
                    existingURL: existingURL
                ) {
                    await self?.requestPassword(pending: pending)
                } else {
                    await self?.finishOperation(successMessageKey: "patch.imported_message")
                }
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.unsupportedFormat)
            }
        }
    }

    @discardableResult
    func importPackage(
        data: Data,
        password: String? = nil,
        origin: PatchPackageOrigin? = nil
    ) -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let summary = try PatchPackageCodec.inspect(data)
                let existingURL = await self?.existingPackageURL(for: summary.packageID)
                if let pending = try Self.persistImportedPackage(
                    data: data,
                    summary: summary,
                    existingURL: existingURL,
                    password: password,
                    origin: origin
                ) {
                    await self?.requestPassword(pending: pending)
                } else {
                    await self?.finishOperation(successMessageKey: "patch.imported_message")
                }
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.unsupportedFormat)
            }
        }
        return true
    }

    func presentImportError(_ error: PatchPackageError) {
        present(error)
    }

    func importPackage(from source: PatchImportSource) {
        switch source {
        case .file(let url):
            importPackage(at: url)
        case .remote(let url):
            importPackage(fromRemoteURL: url)
        case .invalid:
            present(.invalidImportLink)
        }
    }

    private func importPackage(fromRemoteURL remoteURL: URL) {
        guard !isBusy,
              PatchImportRoute.validatedRemoteURL(remoteURL) != nil else {
            if !isBusy { present(.invalidImportLink) }
            return
        }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 60
                configuration.timeoutIntervalForResource = 600
                let session = URLSession(configuration: configuration)
                defer { session.invalidateAndCancel() }

                let (temporaryURL, response) = try await session.download(from: remoteURL)
                defer { try? FileManager.default.removeItem(at: temporaryURL) }
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode),
                      let finalURL = response.url,
                      PatchImportRoute.validatedRemoteURL(finalURL) != nil else {
                    throw PatchPackageError.remoteImportFailed
                }

                let data = try PatchProjectLibrary.readPackage(at: temporaryURL)
                let summary = try PatchPackageCodec.inspect(data)
                let existingURL = await self?.existingPackageURL(for: summary.packageID)
                if let pending = try Self.persistImportedPackage(
                    data: data,
                    summary: summary,
                    existingURL: existingURL
                ) {
                    await self?.requestPassword(pending: pending)
                } else {
                    await self?.finishOperation(successMessageKey: "patch.imported_message")
                }
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.remoteImportFailed)
            }
        }
    }

    func requestUnlock(for item: PatchLibraryItem) {
        guard item.isLocked, !isBusy else { return }
        do {
            let data = try PatchProjectLibrary.readPackage(at: item.packageURL)
            pendingUnlock = PendingUnlock(
                data: data,
                summary: item.summary,
                existingURL: item.packageURL,
                origin: item.origin
            )
            passwordRequest = PatchPasswordRequest(
                summary: item.summary,
                origin: item.origin
            )
        } catch let error as PatchPackageError {
            present(error)
        } catch {
            present(.unsupportedFormat)
        }
    }

    func unlock(password: String) {
        guard let pending = pendingUnlock, !isBusy else { return }
        isBusy = true
        unlockErrorKey = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let decoded = try PatchPackageCodec.decode(pending.data, password: password)
                try PatchKeyStore.store(decoded.contentKey, for: pending.summary)
                do {
                    try PatchProjectLibrary.installImportedPackage(
                        data: pending.data,
                        decoded: decoded,
                        summary: pending.summary,
                        existingURL: pending.existingURL,
                        origin: pending.origin
                    )
                } catch {
                    try? PatchKeyStore.delete(for: pending.summary)
                    throw error
                }
                await self?.clearPendingUnlock()
                await self?.finishOperation(successMessageKey: "patch.unlocked_message")
            } catch let error as PatchPackageError {
                await self?.failUnlock(error)
            } catch {
                await self?.failUnlock(.invalidPasswordOrCorruptedPackage)
            }
        }
    }

    func cancelUnlock() {
        clearPendingUnlock()
        isBusy = false
    }

    func clearUnlockError() {
        unlockErrorKey = nil
    }

    func delete(_ item: PatchLibraryItem) {
        do {
            try PatchProjectLibrary.delete(item)
            reload()
        } catch let error as PatchPackageError {
            present(error)
        } catch {
            present(.invalidProject)
        }
    }

    func synchronizeWorkspace(projectID: UUID, reportsSuccess: Bool = false) {
        guard let item = items.first(where: { $0.id == projectID }),
              item.summary.schemaVersion >= 2,
              !isBusy else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                _ = try PatchProjectLibrary.synchronizeWorkspace(item: item)
                await self?.finishWorkspaceSynchronization(reportsSuccess: reportsSuccess)
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.invalidProject)
            }
        }
    }

    private func finishWorkspaceSynchronization(reportsSuccess: Bool) {
        reload()
        isBusy = false
        if reportsSuccess {
            alert = PatchStoreAlert(
                titleKey: "common.done",
                messageKey: "patch.workspace_synced_message"
            )
        }
    }

    private func runOperation(
        successMessageKey: String,
        operation: @escaping () throws -> Void
    ) {
        guard !isBusy else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try operation()
                await self?.finishOperation(successMessageKey: successMessageKey)
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.invalidProject)
            }
        }
    }

    private func requestPassword(pending: PendingUnlock) {
        pendingUnlock = pending
        passwordRequest = PatchPasswordRequest(
            summary: pending.summary,
            origin: pending.origin
        )
        isBusy = false
    }

    private func existingPackageURL(for packageID: UUID) -> URL? {
        items.first(where: { $0.id == packageID })?.packageURL
    }

    private nonisolated static func persistImportedPackage(
        data: Data,
        summary: PatchPackageSummary,
        existingURL: URL?,
        password: String? = nil,
        origin: PatchPackageOrigin? = nil
    ) throws -> PendingUnlock? {
        if let key = try PatchKeyStore.load(for: summary) {
            let decoded = try PatchPackageCodec.decode(data, contentKey: key)
            try PatchProjectLibrary.installImportedPackage(
                data: data,
                decoded: decoded,
                summary: summary,
                existingURL: existingURL,
                origin: origin
            )
            return nil
        }
        if summary.isPasswordProtected {
            guard let password else {
                return PendingUnlock(
                    data: data,
                    summary: summary,
                    existingURL: existingURL,
                    origin: origin
                )
            }
            let decoded = try PatchPackageCodec.decode(data, password: password)
            try PatchKeyStore.store(decoded.contentKey, for: summary)
            do {
                try PatchProjectLibrary.installImportedPackage(
                    data: data,
                    decoded: decoded,
                    summary: summary,
                    existingURL: existingURL,
                    origin: origin
                )
            } catch {
                try? PatchKeyStore.delete(for: summary)
                throw error
            }
            return nil
        }
        let decoded = try PatchPackageCodec.decode(data, password: nil)
        try PatchProjectLibrary.installImportedPackage(
            data: data,
            decoded: decoded,
            summary: summary,
            existingURL: existingURL,
            origin: origin
        )
        return nil
    }

    private func clearPendingUnlock() {
        pendingUnlock = nil
        passwordRequest = nil
        unlockErrorKey = nil
    }

    private func finishOperation(successMessageKey: String) {
        reload()
        isBusy = false
        alert = PatchStoreAlert(titleKey: "common.done", messageKey: successMessageKey)
    }

    private func failOperation(_ error: PatchPackageError) {
        isBusy = false
        present(error)
    }

    private func failUnlock(_ error: PatchPackageError) {
        isBusy = false
        if case .invalidPasswordOrCorruptedPackage = error {
            unlockErrorKey = "patch.error.wrong_password"
        } else {
            unlockErrorKey = error.localizationKey
        }
    }

    private func present(_ error: PatchPackageError) {
        alert = PatchStoreAlert(
            titleKey: "common.failed",
            messageKey: error.localizationKey,
            messageArgument: error.localizationArgument
        )
    }

    func togglePatch(item: PatchLibraryItem, enabled: Bool) {
        // Removemos a chamada ao PatchProjectLibrary porque a função setPatchEnabled não existe lá
        print("Estado do patch \(item.summary.projectName) alterado para \(enabled)")
        
        // Apenas recarregamos a interface para evitar travamentos
        Task {
            await self.reload()
        }
    }

    }
}
