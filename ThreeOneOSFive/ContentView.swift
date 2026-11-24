
import SwiftUI
import UIKit

// MARK: - KH EXTERNAL THEME

extension Color {
    static let khRed = Color(red: 0.92, green: 0.04, blue: 0.12)
    static let khDark = Color(red: 0.025, green: 0.015, blue: 0.02)
    static let khCard = Color(red: 0.10, green: 0.035, blue: 0.045)
    static let khGreen = Color(red: 0.12, green: 0.88, blue: 0.38)
}

// MARK: - LANGUAGE

enum KHLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case thai = "ไทย"
    case arabic = "العربية"
    case portuguese = "Português (Brasil)"
    case spanish = "Español"
    case vietnamese = "Tiếng Việt"
    case chinese = "简体中文"

    var id: String { rawValue }
}

// MARK: - TRANSLATIONS

func khText(_ key: String, language: KHLanguage) -> String {
    let translations: [String: [KHLanguage: String]] = [
        "settings": [
            .english: "Settings", .thai: "ตั้งค่า"
        ],
        "device": [
            .english: "DEVICE STATUS", .thai: "สถานะอุปกรณ์"
        ],
        "patch": [
            .english: "PATCH OPTIONS", .thai: "ตัวเลือก PATCH"
        ],
        "online": [
            .english: "ONLINE", .thai: "ออนไลน์"
        ],
        "activate": [
            .english: "ACTIVATE PATCH", .thai: "เปิดใช้งาน PATCH"
        ],
        "active": [
            .english: "PATCH ACTIVE", .thai: "เปิดใช้งานแล้ว"
        ],
        "unavailable": [
            .english: "FILE NOT FOUND", .thai: "ไม่พบไฟล์"
        ],
        "game": [
            .english: "OPEN GAME", .thai: "เปิดเกม"
        ],
        "reset": [
            .english: "RESET FUNCTIONS", .thai: "รีเซ็ตฟังก์ชัน"
        ],
        "ready": [
            .english: "KH STORE • READY", .thai: "KH STORE • พร้อมใช้งาน"
        ],
        "language": [
            .english: "LANGUAGE", .thai: "ภาษา"
        ],
        "support": [
            .english: "SUPPORTED", .thai: "รองรับ"
        ],
        "confirmReset": [
            .english: "Reset all functions?", .thai: "ต้องการรีเซ็ตทุกฟังก์ชันหรือไม่?"
        ],
        "cancel": [
            .english: "Cancel", .thai: "ยกเลิก"
        ],
        "confirm": [
            .english: "Reset", .thai: "รีเซ็ต"
        ]
    ]

    return translations[key]?[language] ?? key
}

// MARK: - PATCH MODEL

struct KHPatch: Identifiable {
    let id: String
    let title: String
    let fileName: String
    var isEnabled: Bool = false

    var isAvailable: Bool {
        Bundle.main.url(
            forResource: fileName,
            withExtension: "patch",
            subdirectory: "Patches"
        ) != nil
    }

    static let defaults: [KHPatch] = [
        .init(id: "drag", title: "Aim Drag", fileName: "AimDrag"),
        .init(id: "neck", title: "Aim Neck", fileName: "AimNeck"),
        .init(id: "antenna", title: "Antenna", fileName: "Antenna"),
        .init(id: "fps", title: "144 FPS", fileName: "144FPS"),
        .init(id: "body", title: "Aim Body", fileName: "AimBody"),
        .init(id: "chest", title: "Aim Chest", fileName: "AimChest"),
        .init(id: "magic", title: "Magic", fileName: "Magic")
    ]
}

// MARK: - MAIN VIEW

struct ContentView: View {

    @State private var patches = KHPatch.defaults
    @State private var showSettings = false
    @State private var showResetAlert = false

    @AppStorage("kh.language")
    private var languageCode = KHLanguage.english.rawValue

    private var language: KHLanguage {
        KHLanguage(rawValue: languageCode) ?? .english
    }

    private var activeCount: Int {
        patches.filter { $0.isEnabled }.count
    }

    var body: some View {
        ZStack {
            Color.khDark.ignoresSafeArea()

            // Background grid
            KHGridBackground()

            // Falling snow
            SnowfallView()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    header

                    deviceStatus

                    patchSection

                    patchFooter

                    gameSection

                    resetButton

                    systemStatus

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 35)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            KHSettingsView(languageCode: $languageCode)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            khText("confirmReset", language: language),
            isPresented: $showResetAlert
        ) {
            Button(khText("cancel", language: language), role: .cancel) {}

            Button(khText("confirm", language: language), role: .destructive) {
                resetFunctions()
            }
        }
    }

    // MARK: HEADER

    private var header: some View {
        HStack(spacing: 15) {

            Image("KHAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 82, height: 82)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(Color.khRed, lineWidth: 3)
                }
                .shadow(color: .khRed.opacity(0.6), radius: 12)

            VStack(alignment: .leading, spacing: 5) {
                Text("KH EXTERNAL")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("PATCH CONTROL CENTER")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(.khRed)
            }

            Spacer(minLength: 0)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.khRed)
                    .frame(width: 54, height: 54)
                    .background(Color.khCard)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.khRed.opacity(0.7), lineWidth: 1)
                    }
                    .shadow(color: .khRed.opacity(0.35), radius: 10)
            }
        }
    }

    // MARK: DEVICE STATUS

    private var deviceStatus: some View {
        VStack(spacing: 18) {

            sectionTitle(
                "shield.lefthalf.filled",
                khText("device", language: language)
            )

            statusRow(
                icon: "apple.logo",
                title: "iOS",
                value: UIDevice.current.systemVersion,
                color: .khRed
            )

            statusRow(
                icon: "iphone",
                title: "Device",
                value: UIDevice.current.model,
                color: .khRed
            )

            statusRow(
                icon: "checkmark.seal.fill",
                title: "Support",
                value: khText("support", language: language),
                color: .khGreen
            )
        }
        .padding(20)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .overlay {
            RoundedRectangle(cornerRadius: 25)
                .stroke(.khRed.opacity(0.55), lineWidth: 1)
        }
    }

    private func statusRow(
        icon: String,
        title: String,
        value: String,
        color: Color
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 30)

            Text(title)
                .foregroundStyle(.gray)
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            Text(value)
                .foregroundStyle(.white)
                .font(.system(size: 16, weight: .bold))
        }
    }

    // MARK: PATCH SECTION

    private var patchSection: some View {
        VStack(spacing: 16) {

            HStack {
                sectionTitle(
                    "bolt.fill",
                    khText("patch", language: language)
                )

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(.khGreen)
                        .frame(width: 7, height: 7)

                    Text(khText("online", language: language))
                        .font(.system(size: 11, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.khGreen)
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 14
            ) {
                ForEach($patches) { $patch in
                    PatchCardView(
                        patch: $patch,
                        language: language
                    )
                }
            }
        }
    }

    // MARK: PATCH FOOTER

    private var patchFooter: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(activeCount > 0 ? .khGreen : .khRed)
                .frame(width: 10, height: 10)

            Text(
                activeCount > 0
                ? "\(activeCount) PATCH ACTIVE"
                : "PATCHED DÉSACTIVÉ"
            )
            .font(.system(size: 12, weight: .black))
            .tracking(1)
            .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
        .padding(.horizontal, 10)
    }

    // MARK: GAME SECTION

    private var gameSection: some View {
        VStack(spacing: 15) {

            HStack {
                sectionTitle("arrow.up.right.square", khText("game", language: language))
                Spacer()
            }

            HStack(spacing: 12) {

                Button {
                    openGame()
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.title2)
                            .foregroundStyle(.khRed)

                        Text("FF NORMAL")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)

                        Text("Free Fire Normal")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.khCard)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.khRed.opacity(0.55), lineWidth: 1)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)

                    Text("FF MAX")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.gray)

                    Text("Locked • Coming Soon")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.red.opacity(0.25), lineWidth: 1)
                }
            }
        }
    }

    // MARK: RESET

    private var resetButton: some View {
        Button {
            showResetAlert = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise")
                Text(khText("reset", language: language))
                    .tracking(1)
            }
            .font(.system(size: 16, weight: .black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.khCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.khRed, lineWidth: 1.5)
            }
            .shadow(color: .khRed.opacity(0.3), radius: 12)
        }
    }

    // MARK: SYSTEM STATUS

    private var systemStatus: some View {
        HStack {
            Circle()
                .fill(.khGreen)
                .frame(width: 12, height: 12)
                .shadow(color: .khGreen, radius: 7)

            Text("BY KH EXTERNAL")
                .font(.system(size: 12, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)

            Spacer()

            Text(khText("ready", language: language))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.khRed)
        }
        .padding(17)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(.khRed.opacity(0.5), lineWidth: 1)
        }
    }

    // MARK: FOOTER

    private var footer: some View {
        VStack(spacing: 10) {
            Text("KH EXTERNAL")
                .font(.system(size: 18, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)

            Text("PLAY A BETTER TOMORROW")
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundStyle(.khRed)
        }
        .padding(.top, 12)
    }

    // MARK: HELPERS

    private func sectionTitle(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(.khRed)

            Text(title)
                .font(.system(size: 14, weight: .black))
                .tracking(2)
                .foregroundStyle(.khRed)
        }
    }

    private func resetFunctions() {
        for index in patches.indices {
            patches[index].isEnabled = false
        }
    }

    private func openGame() {
        guard let url = URL(string: "freefire://") else { return }

        UIApplication.shared.open(url)
    }
}

// MARK: - PATCH CARD

struct PatchCardView: View {

    @Binding var patch: KHPatch
    let language: KHLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {

            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(.khRed)

                Spacer()

                Text(patch.isEnabled ? "ON" : "OFF")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(
                        patch.isEnabled ? .khGreen : .gray
                    )
            }

            Text(patch.title)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("FREE FIRE • NORMAL")
                .font(.system(size: 10, weight: .black))
                .tracking(1.5)
                .foregroundStyle(.khRed)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button {
                guard patch.isAvailable else { return }
                withAnimation(.spring(response: 0.3)) {
                    patch.isEnabled.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(
                            !patch.isAvailable ? .gray :
                            patch.isEnabled ? .khGreen : .gray
                        )
                        .frame(width: 9, height: 9)

                    Text(buttonTitle)
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .disabled(!patch.isAvailable)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 175, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.19, green: 0.055, blue: 0.075),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 23))
        .overlay {
            RoundedRectangle(cornerRadius: 23)
                .stroke(
                    patch.isEnabled ? .khRed : .khRed.opacity(0.45),
                    lineWidth: patch.isEnabled ? 2 : 1
                )
        }
        .shadow(
            color: patch.isEnabled ? .khRed.opacity(0.35) : .clear,
            radius: 12
        )
    }

    private var buttonTitle: String {
        if !patch.isAvailable {
            return khText("unavailable", language: language)
        }

        return patch.isEnabled
            ? khText("active", language: language)
            : khText("activate", language: language)
    }
}

// MARK: - SETTINGS

struct KHSettingsView: View {

    @Binding var languageCode: String
    @Environment(\.dismiss) private var dismiss

    private var language: KHLanguage {
        KHLanguage(rawValue: languageCode) ?? .english
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 27) {

                        // App information
                        HStack(spacing: 18) {
                            Image("KHAvatar")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 85, height: 85)
                                .clipShape(Circle())
                                .overlay {
                                    Circle().stroke(.khRed, lineWidth: 3)
                                }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("KH EXTERNAL")
                                    .font(.system(size: 23, weight: .bold))
                                    .foregroundStyle(.white)

                                Text("Version 1.0.0")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                        // Language
                        VStack(alignment: .leading, spacing: 12) {
                            Text(khText("language", language: language))
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)

                            Menu {
                                ForEach(KHLanguage.allCases) { item in
                                    Button {
                                        languageCode = item.rawValue
                                    } label: {
                                        HStack {
                                            Text(item.rawValue)
                                            if languageCode == item.rawValue {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(languageCode)
                                        .foregroundStyle(.khRed)

                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundStyle(.khRed)

                                    Spacer()
                                }
                                .padding(22)
                                .background(Color(white: 0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                            }
                        }

                        // Device
                        settingsGroup(title: "DEVICE") {
                            settingsRow(
                                "Hardware model",
                                value: UIDevice.current.model
                            )

                            Divider()

                            settingsRow(
                                "iOS Version",
                                value: UIDevice.current.systemVersion
                            )
                        }

                        // Supported versions
                        settingsGroup(title: "VERIFIED VERSIONS") {
                            settingsRow(
                                "Current version",
                                value: "Supported",
                                color: .khGreen
                            )

                            Divider()

                            settingsRow("iOS 17", value: "17.0–17.7.x")
                            Divider()
                            settingsRow("iOS 18", value: "18.0–18.7.1")
                            Divider()
                            settingsRow("iOS 26", value: "26.0–26.6.1")
                        }

                        Text("KH EXTERNAL • PLAY A BETTER TOMORROW")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.khRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(khText("settings", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .padding(.leading, 8)

            VStack(spacing: 15) {
                content()
            }
            .padding(20)
            .background(Color(white: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func settingsRow(
        _ title: String,
        value: String,
        color: Color = .gray
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .foregroundStyle(color)
        }
        .font(.system(size: 15))
    }
}

// MARK: - BACKGROUND GRID

struct KHGridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 55

                stride(
                    from: CGFloat(0),
                    through: geometry.size.width,
                    by: spacing
                ).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(
                        to: CGPoint(x: x, y: geometry.size.height)
                    )
                }

                stride(
                    from: CGFloat(0),
                    through: geometry.size.height,
                    by: spacing
                ).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(
                        to: CGPoint(x: geometry.size.width, y: y)
                    )
                }
            }
            .stroke(.khRed.opacity(0.10), lineWidth: 0.6)
        }
        .ignoresSafeArea()
    }
}

// MARK: - SNOWFALL EFFECT

struct SnowfallView: View {

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in

            Canvas { context, size in

                let time = timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<65 {

                    let seed = Double(index)

                    let speed = 20 + (seed.truncatingRemainder(dividingBy: 5) * 8)

                    let startX = (seed * 47.3)
                        .truncatingRemainder(dividingBy: Double(size.width))

                    let startY = (seed * 83.7)
                        .truncatingRemainder(dividingBy: Double(size.height))

                    let x = startX + sin(time * 0.7 + seed) * 18

                    let y = (startY + time * speed)
                        .truncatingRemainder(
                            dividingBy: Double(size.height)
                        )

                    let diameter = 2 + (seed.truncatingRemainder(dividingBy: 3))

                    let rect = CGRect(
                        x: x,
                        y: y,
                        width: diameter,
                        height: diameter
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(0.45))
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}
