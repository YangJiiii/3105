import SwiftUI
import UIKit
import WebKit
import Security

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-sources-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-installed-tab")
                    || arguments.contains("--simulate-patch-tab")
                    || arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        PortalRootView()
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            RepositoryHomeView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .new:
            RepositoryNewView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .sources:
            RepositorySourcesView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .installed:
            PatchProjectsView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .search:
            RepositorySearchView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .home
    }

    private func openSettings() {
        showSettings = true
    }

    private func openLogs() {
        showLogs = true
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .new: return "tab.new"
        case .sources: return "tab.sources"
        case .installed: return "tab.installed"
        case .files: return "tab.files"
        case .search: return "tab.search"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .new: return "clock.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "tray.full.fill"
        case .files: return "folder.fill"
        case .search: return "magnifyingglass"
        }
    }
}

// MARK: - Key-gated web portal

private enum PortalAPI {
    // Set this to the deployed API URL before building the app.
    static let baseURL = URL(string: "https://YOUR-API-HOST")!
    static let tokenKey = "portal.session.token"

    static func savedToken() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "3105.portal", kSecAttrAccount as String: tokenKey, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveToken(_ token: String?) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "3105.portal", kSecAttrAccount as String: tokenKey]
        SecItemDelete(query as CFDictionary)
        guard let token, let data = token.data(using: .utf8) else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func request<T: Decodable>(_ path: String, token: String? = nil, body: Data? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PortalError.connection }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(PortalMessage.self, from: data).message)
            throw PortalError.server(message ?? "Yêu cầu không thành công (\(http.statusCode)).")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct PortalMessage: Decodable { let message: String }
private struct ActivationRequest: Encodable { let key: String; let deviceID: String; let deviceName: String }
private struct ActivationResponse: Decodable { let token: String; let expiresAt: String }
private struct PortalCatalog: Decodable { let features: [PortalFeature]; let notices: [PortalNotice]; let expiresAt: String }
private struct PortalFeature: Decodable, Identifiable {
    let id: String; let category: String; let title: String; let description: String; let icon: String; let url: String
}
private struct PortalNotice: Decodable, Identifiable { let id: String; let title: String; let body: String }

private enum PortalError: LocalizedError {
    case connection
    case server(String)
    var errorDescription: String? {
        switch self { case .connection: return "Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại."; case .server(let value): return value }
    }
}

private struct PortalRootView: View {
    @State private var hasStarted = false
    @State private var token = PortalAPI.savedToken()
    @State private var catalog: PortalCatalog?
    @State private var activeTab = 0
    @State private var selectedFeature: PortalFeature?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !hasStarted {
                welcome
            } else if token == nil {
                KeyEntryView(isLoading: $isLoading, errorMessage: $errorMessage, onActivate: activate)
            } else {
                portal
            }
        }
        .tint(Color(red: 0.93, green: 0.36, blue: 0.24))
        .task { if token != nil { await refreshCatalog() } }
        .alert("Thông báo", isPresented: Binding(get: { errorMessage != nil && token != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Đóng", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .sheet(item: $selectedFeature) { feature in
            NavigationStack {
                PortalWebView(url: URL(string: feature.url)!)
                    .navigationTitle(feature.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Đóng") { selectedFeature = nil } } }
            }
        }
    }

    private var welcome: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.26), Color(red: 0.28, green: 0.20, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "sparkles.rectangle.stack.fill").font(.system(size: 46)).foregroundStyle(.orange)
                Text("Không gian tiện ích của bạn").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Một nơi để mở các tiện ích, tài liệu và nội dung được cấp cho tài khoản của bạn.").font(.title3).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button { hasStarted = true } label: {
                    HStack { Text("Bắt đầu"); Spacer(); Image(systemName: "arrow.right") }
                        .font(.headline).padding().foregroundStyle(.black).background(.white, in: RoundedRectangle(cornerRadius: 18))
                }
            }.padding(28)
        }
    }

    private var portal: some View {
        TabView(selection: $activeTab) {
            NavigationStack { dashboard }
                .tabItem { Label("Tổng quan", systemImage: "square.grid.2x2.fill") }.tag(0)
            NavigationStack { featureList }
                .tabItem { Label("Tiện ích", systemImage: "sparkles") }.tag(1)
            NavigationStack { account }
                .tabItem { Label("Tài khoản", systemImage: "person.crop.circle") }.tag(2)
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Xin chào").font(.title2.weight(.semibold))
                    Text("Các tiện ích đã được cấp sẽ xuất hiện ở đây.").foregroundStyle(.white.opacity(0.85))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(22).foregroundStyle(.white)
                    .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
                if let catalog, !catalog.notices.isEmpty {
                    Text("Thông báo").font(.title3.bold())
                    ForEach(catalog.notices) { notice in
                        VStack(alignment: .leading, spacing: 6) { Text(notice.title).font(.headline); Text(notice.body).foregroundStyle(.secondary) }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                HStack {
                    Label("Key đang hoạt động", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    Spacer()
                    Button { activeTab = 1 } label: { Text("Mở tiện ích").fontWeight(.semibold) }
                }.padding(16).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            }.padding()
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Tổng quan")
            .refreshable { await refreshCatalog() }
    }

    private var featureList: some View {
        Group {
            if isLoading && catalog == nil { ProgressView("Đang tải tiện ích…") }
            else if let catalog, !catalog.features.isEmpty {
                List {
                    ForEach(Dictionary(grouping: catalog.features, by: \.category).keys.sorted(), id: \.self) { category in
                        Section(category) {
                            ForEach(catalog.features.filter { $0.category == category }) { feature in
                                Button { selectedFeature = feature } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: feature.icon).font(.title3).foregroundStyle(.tint).frame(width: 42, height: 42).background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                        VStack(alignment: .leading, spacing: 4) { Text(feature.title).font(.headline).foregroundStyle(.primary); Text(feature.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                                        Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(.tertiary)
                                    }.padding(.vertical, 5)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.listStyle(.insetGrouped)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Chưa có tiện ích").font(.headline)
                    Text("Quản trị viên sẽ thêm các mục hiển thị tại đây.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            }
        }.navigationTitle("Tiện ích").toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { Task { await refreshCatalog() } } label: { Image(systemName: "arrow.clockwise") } } }
    }

    private var account: some View {
        Form {
            Section("Trạng thái key") {
                LabeledContent("Trạng thái", value: token == nil ? "Chưa kích hoạt" : "Đang hoạt động")
                LabeledContent("Hết hạn", value: catalog?.expiresAt ?? "Đang tải…")
            }
            Section("Thiết bị") { LabeledContent("Thiết bị hiện tại", value: UIDevice.current.name) }
            Section { Button("Đăng xuất key", role: .destructive) { PortalAPI.saveToken(nil); token = nil; catalog = nil } }
        }.navigationTitle("Tài khoản")
    }

    private func activate(_ key: String) async {
        isLoading = true; defer { isLoading = false }
        do {
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UIDevice.current.name
            let payload = try JSONEncoder().encode(ActivationRequest(key: key, deviceID: deviceID, deviceName: UIDevice.current.name))
            let result: ActivationResponse = try await PortalAPI.request("api/activate", body: payload)
            PortalAPI.saveToken(result.token); token = result.token
            await refreshCatalog()
        } catch { errorMessage = error.localizedDescription }
    }

    private func refreshCatalog() async {
        guard let token else { return }
        isLoading = true; defer { isLoading = false }
        do { catalog = try await PortalAPI.request("api/catalog", token: token) }
        catch {
            errorMessage = error.localizedDescription
            if (error as? PortalError)?.localizedDescription.contains("key") == true {
                PortalAPI.saveToken(nil); self.token = nil
            }
        }
    }
}

private struct KeyEntryView: View {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onActivate: (String) async -> Void
    @State private var key = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "key.horizontal.fill").font(.system(size: 42)).foregroundStyle(.tint)
                Text("Nhập key truy cập").font(.largeTitle.bold())
                Text("Key sẽ được kiểm tra với máy chủ và gắn với thiết bị này theo giới hạn được cấp.").foregroundStyle(.secondary)
                TextField("XXXX-XXXX-XXXX-XXXX", text: $key).textInputAutocapitalization(.characters).autocorrectionDisabled().padding(16).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
                Button { Task { errorMessage = nil; await onActivate(key.trimmingCharacters(in: .whitespacesAndNewlines)) } } label: {
                    HStack { if isLoading { ProgressView().tint(.white) }; Text(isLoading ? "Đang xác thực…" : "Kích hoạt key"); Spacer(); Image(systemName: "arrow.right") }
                        .font(.headline).padding(16).foregroundStyle(.white).background(.tint, in: RoundedRectangle(cornerRadius: 15))
                }.disabled(isLoading || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }.padding(24).navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PortalWebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ view: WKWebView, context: Context) { if view.url != url { view.load(URLRequest(url: url)) } }
}

