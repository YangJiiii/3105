import SwiftUI

struct RepositoryHomeView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var store: PackageRepositoryStore

    @State private var selectedTab = 0
    @State private var toggles: [Bool] = [
        true, true, true, true, true, true, true
    ]

    private let items = [
        "Hs Alto 100%",
        "HS 100% BAYPSS",
        "HS CABEÇA",
        "HS ALTO + PESCOÇO",
        "HS PEITO LITE",
        "HS PEITO BRUTO",
        "Unlock FPS 144"
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.08, green: 0.04, blue: 0.05),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("12:35")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: 12) {
                        Image(systemName: "wifi")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)

                        Image(systemName: "battery.75")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                statusCard

                tabSelector

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Funções")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()

                        Text("7 itens")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                }

                VStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        rowItem(title: item, enabled: $toggles[index])
                    }
                }
                .padding(.top, 8)

                Spacer()

                bottomNav
            }
            .frame(maxWidth: 430)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 26, height: 26)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.red)
                }

                Text("Log de atividade")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }

            HStack {
                Text("Sessão atual")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.system(size: 18))

                Spacer()

                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
            }
            .padding(.top, 2)

            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Sistema pronto — aguardando patches")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()
            }

            Text("12:35 AM")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.red.opacity(0.65), lineWidth: 1.0)
                )
        )
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("Hs", index: 0)
            tabButton("Hs + Antena", index: 1)
            tabButton("Hologramas", index: 2)
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.14, green: 0.13, blue: 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.7), lineWidth: 1)
        )
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.65))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    selectedTab == index
                        ? Color.red.opacity(0.85)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func rowItem(title: String, enabled: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text("Substituição autorizada")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Toggle("", isOn: enabled)
                .labelsHidden()
                .tint(.gray)
                .frame(width: 52, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.14, green: 0.14, blue: 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.red.opacity(0.7), lineWidth: 1.2)
                )
        )
    }

    private var bottomNav: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red)
                    .frame(width: 42, height: 42)

                Image(systemName: "house.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Home")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.red)
        }
    }
}
