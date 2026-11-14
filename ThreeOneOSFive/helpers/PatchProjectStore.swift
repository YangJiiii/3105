import Foundation
import SwiftUI
import Combine

// MARK: - Tipos de Suporte
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

struct PatchUnlockRequest: Identifiable {
    let id: UUID
    let item: PatchLibraryItem
}

// MARK: - Store Principal
@MainActor
final class PatchProjectStore: ObservableObject {
    @Published private(set) var items: [PatchLibraryItem] = []
    @Published private(set) var isBusy = false
    @Published var passwordRequest: PatchPasswordRequest?
    @Published var alert: PatchStoreAlert?
    @Published var unlockErrorKey: String?
    @Published var customPasswordRequest: PatchUnlockRequest?

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
            // Carrega o que já está salvo no iPhone
            let loadedItems = PatchProjectLibrary.load()
            
            // Procura os novos arquivos .3105 do GitHub
            self?.loadBundledPatches()
            
            await self?.finishInitialLoad(loadedItems)
        }
    }

    @MainActor
    private func finishInitialLoad(_ items: [PatchLibraryItem]) {
        self.items = items
        self.isBusy = false
    }

    func loadBundledPatches() {
        let appPath = Bundle.main.bundlePath
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: appPath)
            let patches = files.filter { $0.hasSuffix(".3105") }
            print("EXTERNAL GH777: Encontrados \(patches.count) patches no bundle.")
            
            for patchFile in patches {
                self.importPatch(fileName: patchFile)
            }
        } catch {
            print("Erro ao ler patches do bundle: \(error)")
        }
    }

    private func importPatch(fileName: String) {
        print("Importando patch: \(fileName)")
        // Aqui o app processa o arquivo .3105
    }
}


    func reload() {
        items = PatchProjectLibrary.load()
    }

    private func finishInitialLoad(_ loadedItems: [PatchLibraryItem]) {
        items = loadedItems
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
            customPasswordRequest = PatchUnlockRequest(id: UUID(), item: item)
        } catch let error as PatchPackageError {
            present(error)
        } catch {
            present(.unsupportedFormat)
        }
    }

    func verifyUnlock(request: PatchUnlockRequest, password: String) {
        unlock(password: password)
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
        customPasswordRequest = nil
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
}
