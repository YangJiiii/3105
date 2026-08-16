import SwiftUI

struct CleanerView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var records: [CleanerAppRecord] = []
    @State private var selectedBundleIDs = Set<String>()
    @State private var searchText = ""
    @State private var sortOrder: CleanerSortOrder = .largestFirst
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var scannedAppCount = 0
    @State private var hasLoaded = false
    @State private var scanID = UUID()
    @State private var activeAlert: CleanerAlert?
    @State private var selectedCategory: CleanerAppCategory = .thirdParty

    private var categoryRecords: [CleanerAppRecord] {
        records.filter { record in
            switch selectedCategory {
            case .thirdParty:
                return !Self.isSystemApp(record.app.bundleID)
            case .system:
                return Self.isSystemApp(record.app.bundleID)
            }
        }
    }

    private var filteredRecords: [CleanerAppRecord] {
        let matchingRecords: [CleanerAppRecord]
        if searchText.isEmpty {
            matchingRecords = categoryRecords
        } else {
            let query = searchText.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: language.locale
            )
            matchingRecords = categoryRecords.filter {
                $0.app.displayName.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: language.locale
                ).contains(query) || $0.app.bundleID.lowercased().contains(query.lowercased())
            }
        }

        return CleanerCatalog.sorted(
            matchingRecords,
            order: sortOrder,
            size: { $0.usage.totalBytes },
            displayName: { $0.app.displayName },
            stableID: { $0.id }
        )
    }

    private static func isSystemApp(_ bundleID: String) -> Bool {
        bundleID.hasPrefix("com.apple.")
    }

    private var visibleBundleIDs: [String] {
        filteredRecords.map(\.id)
    }

    private var areAllVisibleRecordsSelected: Bool {
        !visibleBundleIDs.isEmpty && visibleBundleIDs.allSatisfy(selectedBundleIDs.contains)
    }

    private var totalAvailableBytes: Int64 {
        categoryRecords.reduce(0) { $0 + $1.usage.totalBytes }
    }

    private var selectedBytes: Int64 {
        categoryRecords.reduce(0) { result, record in
            result + (selectedBundleIDs.contains(record.id) ? record.usage.totalBytes : 0)
        }
    }

    private var isBusy: Bool {
        isScanning || isCleaning
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedCategory) {
                    Text(language.text("browser.category_third_party")).tag(CleanerAppCategory.thirdParty)
                    Text(language.text("browser.category_system")).tag(CleanerAppCategory.system)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                AppSearchField(
                    text: $searchText,
                    prompt: language.text("cleaner.search"),
                    clearLabel: language.text("common.clear")
                )
                Divider()
                cleanerList
                    .listStyle(.insetGrouped)
            }
            .navigationTitle(language.text("cleaner.title"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar { toolbarContent }
            .alert(item: $activeAlert, content: alert(for:))
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                reload()
            }
        }
    }

    @ViewBuilder
    private var cleanerList: some View {
        if records.isEmpty {
            List { emptySection }
        } else {
            List {
                summarySection
                applicationsSection
            }
        }
    }

    private var summarySection: some View {
        Section {
            LabeledContent(language.text("cleaner.available")) {
                Text(sizeText(totalAvailableBytes))
                    .monospacedDigit()
            }
            LabeledContent(language.text("cleaner.selected")) {
                Text(language.text("cleaner.selected_summary", Int64(selectedBundleIDs.count), sizeText(selectedBytes)))
                    .monospacedDigit()
            }
            cleanAction
        } header: {
            Label(language.text("cleaner.limited_mode"), systemImage: "checkmark.shield")
        } footer: {
            Text(language.text("cleaner.scope_footer"))
        }
    }

    private var applicationsSection: some View {
        Section {
            if filteredRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(language.text("browser.search_empty"))
                        .font(.headline)
                    Text(language.text("cleaner.search_empty_message"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(filteredRecords) { record in
                    Button {
                        toggleSelection(record.id)
                    } label: {
                        applicationRow(record)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCleaning)
                }
            }
        } header: {
            HStack(spacing: 8) {
                Text(language.text("cleaner.apps_with_cache", Int64(filteredRecords.count)))
                Spacer()
                if isScanning {
                    ProgressView()
                        .controlSize(.mini)
                    Text(language.text("cleaner.scanned_count", Int64(scannedAppCount)))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(nil)
        } footer: {
            if !records.isEmpty {
                Text(language.text("cleaner.apps_footer"))
            }
        }
    }

    private func applicationRow(_ record: CleanerAppRecord) -> some View {
        HStack(spacing: 10) {
            BrowserAppIcon(app: record.app)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.app.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Text(record.app.bundleID)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(sizeText(record.usage.totalBytes))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Image(systemName: selectedBundleIDs.contains(record.id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: AppTheme.selectionIconSize, weight: .medium))
                .foregroundStyle(selectedBundleIDs.contains(record.id) ? AppTheme.accent : Color.secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            selectedBundleIDs.contains(record.id)
                ? language.text("cleaner.accessibility_selected")
                : language.text("cleaner.accessibility_not_selected")
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !records.isEmpty {
            ToolbarItem(placement: .navigationBarLeading) {
                selectionMenu
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                sortMenu
                refreshButton
            }
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                refreshButton
            }
        }
    }

    private var selectionMenu: some View {
        Menu {
            Button {
                selectedBundleIDs = CleanerCatalog.selectingAllVisible(
                    visibleBundleIDs,
                    preserving: selectedBundleIDs
                )
            } label: {
                Label(
                    searchText.isEmpty
                        ? language.text("patch.select_all")
                        : language.text("cleaner.select_all_results"),
                    systemImage: "checkmark.circle"
                )
            }
            .disabled(areAllVisibleRecordsSelected)

            Button {
                selectedBundleIDs.removeAll()
            } label: {
                Label(language.text("patch.deselect_all"), systemImage: "circle")
            }
            .disabled(selectedBundleIDs.isEmpty)
        } label: {
            Image(systemName: "checklist")
        }
        .disabled(isBusy)
        .accessibilityLabel(language.text("cleaner.selection_actions"))
    }

    private var sortMenu: some View {
        Menu {
            Picker(language.text("cleaner.sort"), selection: $sortOrder) {
                Label(
                    language.text("cleaner.sort_largest_first"),
                    systemImage: "arrow.down"
                )
                .tag(CleanerSortOrder.largestFirst)

                Label(
                    language.text("cleaner.sort_smallest_first"),
                    systemImage: "arrow.up"
                )
                .tag(CleanerSortOrder.smallestFirst)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .disabled(isBusy)
        .accessibilityLabel(language.text("cleaner.sort"))
    }

    private var refreshButton: some View {
        Button { reload() } label: {
            if isScanning {
                ProgressView()
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(isBusy)
        .accessibilityLabel(language.text("cleaner.scan_again"))
    }

    private var cleanAction: some View {
        Button {
            activeAlert = .confirmation
        } label: {
            HStack(spacing: 8) {
                if isCleaning {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "trash")
                }
                Text(
                    isCleaning
                        ? language.text("cleaner.cleaning")
                        : language.text("cleaner.clean_button", sizeText(selectedBytes))
                )
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedBundleIDs.isEmpty || isBusy)
        .padding(.vertical, 4)
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 12) {
                if isScanning {
                    ProgressView()
                    Text(language.text("cleaner.scanning"))
                        .font(.headline)
                    Text(language.text("cleaner.scanned_count", Int64(scannedAppCount)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(language.text("cleaner.empty_title"))
                        .font(.headline)
                    Text(language.text("cleaner.empty_message"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(language.text("cleaner.scan_again")) { reload() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    private func alert(for alert: CleanerAlert) -> Alert {
        switch alert {
        case .confirmation:
            return Alert(
                title: Text(language.text("cleaner.confirm_title")),
                message: Text(
                    language.text(
                        "cleaner.confirm_message",
                        Int64(selectedBundleIDs.count),
                        sizeText(selectedBytes)
                    )
                ),
                primaryButton: .destructive(Text(language.text("cleaner.confirm_action"))) {
                    cleanSelectedApps()
                },
                secondaryButton: .cancel(Text(language.text("common.cancel")))
            )
        case .result(let message):
            return Alert(
                title: Text(language.text("cleaner.result_title")),
                message: Text(message),
                dismissButton: .default(Text(language.text("common.done")))
            )
        }
    }

    private func toggleSelection(_ bundleID: String) {
        if selectedBundleIDs.contains(bundleID) {
            selectedBundleIDs.remove(bundleID)
        } else {
            selectedBundleIDs.insert(bundleID)
        }
    }

    private func reload() {
        guard !isBusy else { return }
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-cleaner-empty") {
            records = []
            selectedBundleIDs = []
            scannedAppCount = 388
            isScanning = false
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--simulate-cleaner-data") {
            let samples = [
                CleanerAppRecord(
                    app: InstalledApp(
                        bundleID: "com.lemon.lvoverseas",
                        name: "CapCut",
                        containerPath: "/tmp/CapCut",
                        version: "",
                        icon: nil
                    ),
                    usage: LimitedCleanerUsage(
                        cacheBytes: 184_549_376,
                        temporaryBytes: 12_582_912,
                        removableItemCount: 284
                    )
                ),
                CleanerAppRecord(
                    app: InstalledApp(
                        bundleID: "com.apple.Maps",
                        name: "Maps",
                        containerPath: "/tmp/Maps",
                        version: "",
                        icon: nil
                    ),
                    usage: LimitedCleanerUsage(
                        cacheBytes: 61_865_984,
                        temporaryBytes: 3_145_728,
                        removableItemCount: 92
                    )
                ),
                CleanerAppRecord(
                    app: InstalledApp(
                        bundleID: "com.apple.mobilesafari",
                        name: "Safari",
                        containerPath: "/tmp/Safari",
                        version: "",
                        icon: nil
                    ),
                    usage: LimitedCleanerUsage(
                        cacheBytes: 27_262_976,
                        temporaryBytes: 1_048_576,
                        removableItemCount: 48
                    )
                )
            ]
            records = samples
            selectedBundleIDs = Set(samples.prefix(2).map(\.id))
            scannedAppCount = 388
            isScanning = false
            if ProcessInfo.processInfo.arguments.contains("--simulate-cleaner-warning") {
                activeAlert = .confirmation
            }
            return
        }
#endif
        let requestID = UUID()
        scanID = requestID
        isScanning = true
        scannedAppCount = 0
        selectedBundleIDs.removeAll()
        records.removeAll()

        DispatchQueue.global(qos: .userInitiated).async {
            var scannedBundleIDs = Set<String>()
            var discoveredRecords: [CleanerAppRecord] = []
            var processedCount = 0

            func publish(force: Bool = false) {
                guard force || processedCount.isMultiple(of: 8) else { return }
                let snapshot = discoveredRecords.sorted {
                    $0.app.displayName.localizedCaseInsensitiveCompare($1.app.displayName) == .orderedAscending
                }
                let count = processedCount
                DispatchQueue.main.async {
                    guard scanID == requestID else { return }
                    records = snapshot
                    scannedAppCount = count
                }
            }

            func scanNewApps(_ applications: [InstalledApp]) {
                let metadata = Dictionary(
                    applications.map {
                        ($0.bundleID, $0)
                    },
                    uniquingKeysWith: { first, _ in first }
                )
                let catalogApplications = applications.map {
                    CleanerResolvedApplication(
                        bundleID: $0.bundleID,
                        name: $0.name,
                        containerPath: $0.containerPath,
                        version: $0.version
                    )
                }
                let newRecords = CleanerCatalog.scanNewApplications(
                    catalogApplications,
                    scannedBundleIDs: &scannedBundleIDs,
                    shouldIncludeBundleID: {
                        ContainerPresentationPolicy.shouldShow(bundleID: $0)
                    },
                    activateContainer: { application in
                    var activationError: NSString?
                        return MCMActivateContainerPath(
                        2,
                            application.bundleID,
                        false,
                        &activationError
                        )
                    },
                    isValidContainerPath: ContainerStore.isApplicationContainerPath,
                    usageForContainer: { containerPath in
                        try? LimitedCleanerService.scan(
                            containerURL: URL(fileURLWithPath: containerPath, isDirectory: true),
                            rootValidator: { ContainerStore.isApplicationContainerPath($0.path) }
                        )
                    }
                )
                processedCount = scannedBundleIDs.count
                for record in newRecords {
                    let original = metadata[record.bundleID]
                    let resolvedApp = InstalledApp(
                        bundleID: record.bundleID,
                        name: record.application.name,
                        containerPath: record.containerPath,
                        version: record.application.version,
                        icon: original?.icon
                    )
                    discoveredRecords.append(
                        CleanerAppRecord(app: resolvedApp, usage: record.usage)
                    )
                }
                publish()
            }

            let apiApps = ContainerStore.installedAppsFromAPI()
            let dynamicIdentifiers = ContainerStore.dynamicAppIdentifiers()
            let mcmApps = ContainerStore.installedAppsFromMCM(identifiers: dynamicIdentifiers)
            scanNewApps(apiApps + mcmApps)

            let launchServicesIdentifiers = ContainerStore.launchServicesStoreIdentifiers()
            let candidates = MHAIdentifierCatalog.identifiers(
                dynamic: dynamicIdentifiers,
                installed: apiApps.map(\.bundleID),
                research: ContainerStore.researchAppIdentifiers,
                custom: [],
                launchServices: launchServicesIdentifiers
            )
            log("cleaner: resolving \(candidates.count) MHA-C2 bundle candidates")
            let mhaApps = ContainerStore.installedAppsFromMHACandidates(
                identifiers: candidates
            ) { progressiveApps in
                scanNewApps(progressiveApps)
            }
            scanNewApps(mhaApps)
            publish(force: true)

            DispatchQueue.main.async {
                guard scanID == requestID else { return }
                isScanning = false
                log(
                    "cleaner: scan complete bundles=\(processedCount) " +
                        "reclaimableApps=\(discoveredRecords.count)"
                )
            }
        }
    }

    private func cleanSelectedApps() {
        guard !isBusy else { return }
        let selectedRecords = records.filter { selectedBundleIDs.contains($0.id) }
        guard !selectedRecords.isEmpty else { return }
        isCleaning = true

        DispatchQueue.global(qos: .userInitiated).async {
            var updatedUsage: [String: LimitedCleanerUsage] = [:]
            var freedBytes: Int64 = 0
            var removedItems = 0
            var failedItems = 0
            var unavailableApps = 0

            for record in selectedRecords {
                guard let containerPath = ContainerStore.resolveAppContainerPath(
                    bundleID: record.app.bundleID
                ) else {
                    unavailableApps += 1
                    log("cleaner: bundle unavailable \(record.app.bundleID)")
                    continue
                }

                do {
                    let result = try LimitedCleanerService.clean(
                        containerURL: URL(fileURLWithPath: containerPath, isDirectory: true),
                        rootValidator: { ContainerStore.isApplicationContainerPath($0.path) }
                    )
                    updatedUsage[record.id] = result.after
                    freedBytes += result.freedBytes
                    removedItems += result.removedItemCount
                    failedItems += result.failedItemCount
                    log(
                        "cleaner: cleaned \(record.app.bundleID) " +
                            "freed=\(result.freedBytes) removed=\(result.removedItemCount) " +
                            "failed=\(result.failedItemCount)"
                    )
                } catch {
                    unavailableApps += 1
                    log("cleaner: failed \(record.app.bundleID) error=\(error)")
                }
            }

            let resultMessage = language.text(
                "cleaner.result_message",
                sizeText(freedBytes),
                Int64(removedItems),
                Int64(failedItems + unavailableApps)
            )
            DispatchQueue.main.async {
                records = records.compactMap { record in
                    guard let usage = updatedUsage[record.id] else { return record }
                    guard usage.totalBytes > 0 else { return nil }
                    return CleanerAppRecord(app: record.app, usage: usage)
                }
                selectedBundleIDs.removeAll()
                isCleaning = false
                activeAlert = .result(message: resultMessage)
            }
        }
    }

    private func sizeText(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

private enum CleanerAppCategory: String, CaseIterable, Identifiable {
    case thirdParty
    case system

    var id: String { rawValue }
}

private struct CleanerAppRecord: Identifiable {
    let app: InstalledApp
    let usage: LimitedCleanerUsage

    var id: String { app.bundleID }
}

private enum CleanerAlert: Identifiable {
    case confirmation
    case result(message: String)

    var id: String {
        switch self {
        case .confirmation: return "confirmation"
        case .result(let message): return "result-\(message)"
        }
    }
}
