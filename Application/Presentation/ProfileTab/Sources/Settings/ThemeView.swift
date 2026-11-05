//
//  ThemeView.swift
//  ProfileTab
//
//  Created by opfic on 5/6/25.
//

import SwiftUI
import Core
import PresentationShared

struct ThemeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Binding var theme: SystemTheme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 0) {
                    ForEach(Self.themes) { option in
                        themeButton(option)

                        if option != Self.themes.last {
                            Divider()
                                .padding(.leading, 68)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .background(Color.surface, in: .rect(cornerRadius: 16))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.appBackground)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private static let themes: [SystemTheme] = [.automatic, .light, .dark]

    private var topBar: some View {
        ZStack {
            Text(String(localized: "nav_theme", bundle: PresentationResources.bundle))
                .font(.headline)
            HStack {
                NavigationBackButton(action: { dismiss() })
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, windowControlsInset)
        .padding(.bottom, 12)
        .background(Color.appBackground)
        .toolbarBackground(Color.appBackground)
    }

    private func themeButton(_ option: SystemTheme) -> some View {
        HStack(spacing: 12) {
            Image(systemName: option.symbolName)
                .font(.headline)
                .frame(width: 36, height: 36)
                .iconStyle(color: option.iconColor, in: Circle())

            Text(option.localizedName(in: PresentationResources.bundle))
                .foregroundStyle(Color.primary)

            Spacer(minLength: 8)

            Image(systemName: theme == option ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(theme == option ? Color.accent : Color.border)

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture {
            theme = option
        }
    }
}

private extension SystemTheme {
    var symbolName: String {
        switch self {
        case .automatic:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .automatic:
            return .accent
        case .light:
            return .warning
        case .dark:
            return .onControlBackground
        }
    }
}
