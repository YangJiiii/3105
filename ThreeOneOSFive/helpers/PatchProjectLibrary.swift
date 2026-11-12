import Foundation

struct PatchLibraryItem: Identifiable {
    let summary: PatchPackageSummary
    var project: PatchProject?
    var contentKey: Data?
    var packageURL: URL
    let isAuthorCopy: Bool
    let origin: PatchPackageOrigin?

    var id: UUID { summary.packageID }
    var isLocked: Bool { project == nil }
    var canInspectContents: Bool {
        guard let project else { return false }
        return PatchProjectAccessPolicy.canInspectContents(
            project: project,
            isAuthorCopy: isAuthorCopy
        )
    }
    var workspaceURL: URL? {
        guard canInspectContents else { return nil }
        return PatchWorkspaceService.workspaceURL(projectID: id)
    }
}

struct PatchPasswordRequest: Identifiable {
    let summary: PatchPackageSummary
    let origin: PatchPackageOrigin?
    var id: UUID { summary.packageID }

    init(summary: PatchPackageSummary, origin: PatchPackageOrigin? = nil) {
        self.summary = summary
        self.origin = origin
    }
}

enum PatchProjectLibrary {
    private static let authorCopiesDirectoryName = ".AuthorCopies"
    private static let originsDirectoryName = ".Origins"

    static func packageRootURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("PatchProjects", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func backupRootURL(fileManager: FileManager = .default) throws -> URL {
        let root = try packageRootURL(fileManager: fileManager)
            .appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func load(fileManager: FileManager = .default) -> [PatchLibraryItem] {
        guard let root = try? packageRootURL(fileManager: fileManager),
              let urls = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
              ) else { return [] }

        var byID: [UUID: PatchLibraryItem] = [:]
        for url in urls where url.pathExtension.lowercased() == "3105" {
            do {
                let data = try readPackage(at: url)
                let summary = try PatchPackageCodec.inspect(data)
                let decoded: DecodedPatchPackage?
                if let contentKey = try PatchKeyStore.load(for: summary) {
                    decoded = try PatchPackageCodec.decode(data, contentKey: contentKey)
                } else if summary.isPasswordProtected {
                    decoded = nil
                } else {
                    decoded = try PatchPackageCodec.decode(data, password: nil)
                }
                let isAuthorCopy = isAuthorCopy(
                    packageID: summary.packageID,
                    fileManager: fileManager
                )
                let item = PatchLibraryItem(
                    summary: summary,
                    project: decoded?.project,
                    contentKey: decoded?.contentKey,
                    packageURL: url,
                    isAuthorCopy: isAuthorCopy,
                    origin: loadOrigin(
                        packageID: summary.packageID,
                        fileManager: fileManager
                    )
                )
                if summary.schemaVersion >= 2, let project = decoded?.project {
                    if PatchProjectAccessPolicy.shouldMaterializeWorkspace(
                        project: project,
                        isAuthorCopy: isAuthorCopy
                    ) {
                        do {
                            _ = try PatchWorkspaceService.ensureWorkspace(for: project)
                        } catch {
                            log("patch: workspace unavailable for \(project.id.uuidString)")
                        }
                    } else {
                        try? PatchWorkspaceService.deleteWorkspace(
                            projectID: project.id,
                            fileManager: fileManager
                        )
                    }
                }
                byID[summary.packageID] = item
            } catch {
                log("patch: skipped invalid local package \(url.lastPathComponent)")
            }
        }
        return byID.values.sorted {
            ($0.project?.updatedAt ?? .distantPast) > ($1.project?.updatedAt ?? .distantPast)
        }
    }

    static func readPackage(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isDirectory != true,
              values.isSymbolicLink != true,
              values.isRegularFile == true else {
            throw PatchPackageError.invalidProject
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    static func save(
        data: Data,
        projectName: String,
        existingURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let destination: URL
        if let existingURL {
            destination = existingURL
        } else {
            let root = try packageRootURL(fileManager: fileManager)
            let baseName = sanitizedFilename(projectName)
            var candidate = root.appendingPathComponent(baseName).appendingPathExtension("3105")
            var suffix = 2
            while fileManager.fileExists(atPath: candidate.path) {
                candidate = root.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("3105")
                suffix += 1
            }
            destination = candidate
        }
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }

    static func markAsAuthorCopy(
        packageID: UUID,
        fileManager: FileManager = .default
    ) throws {
        let root = try authorCopiesRootURL(fileManager: fileManager)
        try Data().write(
            to: root.appendingPathComponent(packageID.uuidString),
            options: [.atomic, .completeFileProtection]
        )
    }

    static func isAuthorCopy(
        packageID: UUID,
        fileManager: FileManager = .default
    ) -> Bool {
        guard let root = try? authorCopiesRootURL(fileManager: fileManager) else {
            return false
        }
        return fileManager.fileExists(
            atPath: root.appendingPathComponent(packageID.uuidString).path
        )
    }

    static func overlappingTargetPath(
        in project: PatchProject,
        excludingPackageID: UUID,
        fileManager: FileManager = .default
    ) -> String? {
        var occupied = Set<String>()
        for item in load(fileManager: fileManager) where item.id != excludingPackageID {
            guard let other = item.project else { continue }
            for rule in other.rules {
                occupied.insert(rule.bundleID + "\0" + rule.relativePath)
            }
        }
        for rule in project.rules {
            let key = rule.bundleID + "\0" + rule.relativePath
            if occupied.contains(key) {
                return rule.bundleID + "/" + rule.relativePath
            }
        }
        return nil
    }

    static func installImportedPackage(
        data: Data,
        decoded: DecodedPatchPackage,
        summary: PatchPackageSummary,
        existingURL: URL?,
        origin: PatchPackageOrigin? = nil,
        fileManager: FileManager = .default
    ) throws {
        let authorCopy = isAuthorCopy(
            packageID: summary.packageID,
            fileManager: fileManager
        )
        if let occupiedPath = overlappingTargetPath```swift
in decoded.project,
excludingPackageID: summary.packageID,
fileManager: fileManager
) {
if decoded.project.isPrivate,!authorCopy {
throw PatchPackageError.privateOperationFailed
}
throw PatchPackageError.targetOccupied(occupiedPath)
}
let previousData = try existingURL.map { try readPackage(at: $0) }
let originURL = try originFileURL(
packageID: summary.packageID,
fileManager: fileManager
)
let previousOriginData = try? Data(contentsOf: originURL)
var savedURL: URL?
do {
if let origin {
try saveOrigin(origin, to: originURL)
}
savedURL = try save(
data: data,
projectName: decoded.project.name,
existingURL: existingURL,
fileManager: fileManager
)
if summary.schemaVersion >= 2 {
if PatchProjectAccessPolicy.shouldMaterializeWorkspace(
project: decoded.project,
isAuthorCopy: authorCopy
) {
_ = try PatchWorkspaceService.replaceWorkspace(
with: decoded.project,
fileManager: fileManager
)
} else {
try PatchWorkspaceService.deleteWorkspace(
projectID: decoded.project.id,
fileManager: fileManager
)
}
} else {
try? PatchWorkspaceService.deleteWorkspace(
projectID: decoded.project.id,
fileManager: fileManager
)
}
} catch {
if let previousData, let existingURL {
try? previousData.write(
to: existingURL,
options: [.atomic,.completeFileProtection]
)
} else if let savedURL, fileManager.fileExists(atPath: savedURL.path) {
try? fileManager.removeItem(at: savedURL)
}
if let previousOriginData {
try? previousOriginData.write(
to: originURL,
options: [.atomic,.completeFileProtection]
)
} else if origin!= nil, fileManager.fileExists(atPath: originURL.path) {
try? fileManager.removeItem(at: originURL)
}
throw error
}
}

static func delete(_ item: PatchLibraryItem, fileManager: FileManager =.default) throws {
let backupRoot = try backupRootURL(fileManager: fileManager)
guard PatchTransaction.latestReceipt(
projectID: item.id,
backupRoot: backupRoot,
fileManager: fileManager
) == nil else {
throw PatchPackageError.activePatchCannotBeDeleted
}
if fileManager.fileExists(atPath: item.packageURL.path) {
try fileManager.removeItem(at: item.packageURL)
}
try? PatchWorkspaceService.deleteWorkspace(projectID: item.id, fileManager: fileManager)
try? PatchKeyStore.delete(for: item.summary)
if let originURL = try? originFileURL(
packageID: item.id,
fileManager: fileManager
), fileManager.fileExists(atPath: originURL.path) {
try? fileManager.removeItem(at: originURL)
}
if let marker = try? authorCopyMarkerURL(
packageID: item.id,
fileManager: fileManager
), fileManager.fileExists(atPath: marker.path) {
try? fileManager.removeItem(at: marker)
}
}

static func synchronizeWorkspace(
item: PatchLibraryItem,
fileManager: FileManager =.default
) throws -> PatchProject {
guard item.summary.schemaVersion >= 2,
item.canInspectContents,
let baseProject = item.project,
let contentKey = item.contentKey else {
throw PatchPackageError.invalidProject
}
let workspace = try PatchWorkspaceService.ensureWorkspace(
for: baseProject,
fileManager: fileManager
)
let project = try PatchWorkspaceService.snapshot(
baseProject: baseProject,
workspaceURL: workspace,
fileManager: fileManager
)
let original = try readPackage(at: item.packageURL)
let updated = try PatchPackageCodec.update(
original,
project: project,
contentKey: contentKey,
schemaVersion: PatchPackageCodec.latestSchemaVersion
)
_ = try save(
data: updated,
projectName: project.name,
existingURL: item.packageURL,
fileManager: fileManager
)
return project
}

private static func sanitizedFilename(_ rawName: String) -> String {
let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
let scalars = rawName.unicodeScalars.map { allowed.contains($0)? Character(String($0)): "-" }
let result = String(scalars)
.trimmingCharacters(in:.whitespacesAndNewlines)
.prefix(80)
return result.isEmpty? "Patch": String(result)
}

private static func authorCopiesRootURL(
fileManager: FileManager
) throws -> URL {
let root = try packageRootURL(fileManager: fileManager)
.appendingPathComponent(authorCopiesDirectoryName, isDirectory: true)
try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
return root
}

private static func authorCopyMarkerURL(
packageID: UUID,
fileManager: FileManager
) throws -> URL {
try authorCopiesRootURL(fileManager: fileManager)
.appendingPathComponent(packageID.uuidString)
}

private static func originsRootURL(fileManager: FileManager) throws -> URL {
let root = try packageRootURL(fileManager: fileManager)
.appendingPathComponent(originsDirectoryName, isDirectory: true)
try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
return root
}

private static func originFileURL(
packageID: UUID,
fileManager: FileManager
) throws -> URL {
try originsRootURL(fileManager: fileManager)
.appendingPathComponent(packageID.uuidString)
.appendingPathExtension("plist")
}

private static func loadOrigin(
packageID: UUID,
fileManager: FileManager
) -> PatchPackageOrigin? {
guard let url = try? originFileURL(
packageID: packageID,
fileManager: fileManager
), let data = try? Data(contentsOf: url) else {
return nil
}
return try? PropertyListDecoder().decode(PatchPackageOrigin.self, from: data)
}

private static func saveOrigin(
_ origin: PatchPackageOrigin,
to url: URL
) throws {
let encoder = PropertyListEncoder()
encoder.outputFormat =.binary
try encoder.encode(origin).write(
to: url,
options: [.atomic,.completeFileProtection]
)
}

static func setPatchEnabled(_ packageID: UUID, enabled: Bool) throws {
let defaults = UserDefaults.standard
defaults.set(enabled, forKey: "patch_enabled_\(packageID.uuidString)")
}

static func isPatchEnabled(_ packageID: UUID) -> Bool {
return UserDefaults.standard.bool(forKey: "patch_enabled_\(packageID.uuidString)")
}
}
``````swift
static func setPatchEnabled(_ packageID: UUID, enabled: Bool) throws {
let defaults = UserDefaults.standard
defaults.set(enabled, forKey: "patch_enabled_\(packageID.uuidString)")
}

static func isPatchEnabled(_ packageID: UUID) -> Bool {
return UserDefaults.standard.bool(forKey: "patch_enabled_\(packageID.uuidString)")
}
}
``````swift
static func setPatchEnabled(_ packageID: UUID, enabled: Bool) throws {
let defaults = UserDefaults.standard
defaults.set(enabled, forKey: "patch_enabled_\(packageID.uuidString)")
}

static func isPatchEnabled(_ packageID: UUID) -> Bool {
return UserDefaults.standard.bool(forKey: "patch_enabled_\(packageID.uuidString)")
}
}
