import SwiftUI
import UniformTypeIdentifiers

enum AppTab: String, CaseIterable {
case dashboard
case search
case installed

var localizationKey: String {
switch self {
case.dashboard: return "inicio"
case.search: return "search"
case.installed: return "arquivos"
}
}
}

struct PatchProjectsView: View {
@Environment(\.appLanguage) private var language
@ObservedObject var store: PatchProjectStore

@State private var searchText = ""
@State private var selectedTab: AppTab =.dashboard
@State private var showCreate = false
@State private var showCleaner = false
@State private var isImportingWallpapers = false
@State private var wallpaperImportFeedback: WallpaperImportFeedback?
@State private var wallpaperPackages: = []

var body: some View {
ZStack {
Color(hex: "#0a0a0c").ignoresSafeArea()

VStack(spacing: 0) {
headerView
tabSelector
contentArea
}
}
.navigationTitle("EXTERNAL GH777")
.navigationBarTitleDisplayMode(.inline)
.toolbar {
ToolbarItem(placement:.navigationBarTrailing) {
Button {
showCreate = true
} label: {
Image(systemName: "plus.circle.fill")
.foregroundStyle(.purple)
.font(.title3)
}
}
}
.sheet(isPresented: $showCreate) {
Text("Create Patch").foregroundStyle(.white)
}
.sheet(isPresented: $showCleaner) {
Text("System Cleaner").foregroundStyle(.white)
}
.alert(item: $wallpaperImportFeedback) { feedback in
Alert(title: Text(language.text(feedback.titleKey)), message: Text(feedback.message))
}
.onAppear {
reloadWallpaperPackages()
}
}

private var headerView: some View {
VStack(spacing: 8) {
HStack {
VStack(alignment:.leading, spacing: 4) {
Text("EXTERNAL GH777")
.font(.system(size: 24, weight:.black))
.foregroundStyle(
LinearGradient(colors: [.white,.purple], startPoint:.top, endPoint:.bottom)
)

HStack(spacing: 6) {
Circle()
.fill(.green)
.frame(width: 8, height: 8)
Text("SYSTEM ACTIVE")
.font(.system(size: 10, weight:.bold))
.foregroundStyle(.gray)
}
}
Spacer()
Image(systemName: "cpu")
.font(.title)
.foregroundStyle(.purple)
.shadow(color:.purple.opacity(0.5), radius: 10)
}
.padding(.horizontal)
.padding(.top, 20)

Divider()
.background(Color.white.opacity(0.1))
.padding(.horizontal)
}
.padding(.bottom, 20)
}

private var tabSelector: some View {
ScrollView(.horizontal, showsIndicators: false) {
HStack(spacing: 12) {
ForEach(AppTab.allCases, id: \.self) { tab in
Button {
selectedTab = tab
} label: {
Text(language.text(tab.localizationKey))
.font(.system(size: 13, weight:.bold))
.padding(.horizontal, 16)
.padding(.vertical, 8)
.background(selectedTab == tab? Color.purple: Color.white.opacity(0.05))
.foregroundStyle(selectedTab == tab?.white:.gray)
.cornerRadius(20)
.overlay(
RoundedRectangle(cornerRadius: 20)
.stroke(selectedTab == tab? Color.purple: Color.white.opacity(0.1), lineWidth: 1)
)
}
}
}
.padding(.horizontal)
}
.padding(.bottom, 20)
}

@ViewBuilder
private var contentArea: some View {
ScrollView {
VStack(spacing: 20) {
if selectedTab ==.dashboard {
dashboardContent
} else if selectedTab ==.search {
searchContent
} else if selectedTab ==.installed {
installedContent
}
}
.padding(.horizontal)
.padding(.bottom, 30)
}
}

private var dashboardContent: some View {
VStack(spacing: 20) {
sectionHeader(title: "Quick Access")
VStack(spacing: 12) {
cleanerRow()
if!wallpaperPackages.isEmpty {
ForEach(wallpaperPackages, id: \.id) { package in
wallpaperRow(package)
}
}
}
}
}

private var installedContent: some View {
VStack(spacing: 20) {
sectionHeader(title: "Installed Patches")
if store.isBusy {
loadingState
} else if store.items.isEmpty {
emptyState
} else {
VStack(spacing: 12) {
ForEach(store.items) { item in
itemRow(item)
}
}
}
}
}

private var searchContent: some View {
VStack(spacing: 20) {
TextField(language.text("patch.search_placeholder"), text: $searchText)
.padding()
.background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.05)))
.foregroundStyle(.white)
.overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))

if searchText.isEmpty {
searchEmptyState
} else {
VStack(spacing: 12) {
let filtered = store.items.filter {
$0.project?.name.localizedCaseInsensitiveContains(searchText)?? false
}
if filtered.isEmpty {
searchEmptyState
} else {
ForEach(filtered) { item in
itemRow(item)
}
}
}
}
}
}

private func sectionHeader(title: String) -> some View {
HStack {
Text(title.uppercased())
.font(.system(size: 12, weight:.black))
.tracking(1.5)
.foregroundStyle(.gray)
Spacer()
Rectangle()
.fill(LinearGradient(colors: [.purple,.clear], startPoint:.leading, endPoint:.trailing))
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
VStack(alignment:.leading, spacing: 4) {
Text(package.displayName)
.font(.body.weight(.semibold))
.foregroundStyle(.white)
.lineLimit(1)
HStack(spacing: 8) {
InstalledContentKindBadge(kind:.wallpaper,language: language)
Text(language.text("wallpaper.package_summary", Int64(package.payload.descriptors.count), ByteCountFormatter.string(fromByteCount: package.payload.totalBytes, countStyle:.file)))
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
.overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
}

private func cleanerRow() -> some View {
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
VStack(alignment:.leading, spacing: 4) {
Text(language.text("tab.cleaner"))
.font(.body.weight(.semibold))
.foregroundStyle(.white)
Text(language.text("repository.cleaner_subtitle"))
.font(.caption2)
.foregroundStyle(.gray)
}
Spacer()
Image(systemName: "
