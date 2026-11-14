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
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.deviceType) private var deviceType
    @Binding var theme: SystemTheme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 0) {
                    ForEach(Self.themes) { option in
                        themeButton(option)

                        if option != Self.themes.last {
                            Divider().overlay(Color.border)
                                .padding(.leading, 68)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .groupBackground(in: .rect(cornerRadius: 16))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // Mac 제목 줄 구분선과 첫 항목 사이 여백
        .contentMargins(.top, showsPaneTitleBar ? 12 : 0, for: .scrollContent)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.appBackground)
        .duoToolbarVisibility()
    }

    private static let themes: [SystemTheme] = [.automatic, .light, .dark]

    @ViewBuilder
    private var topBar: some View {
        let title = Text(String(localized: "nav_theme", bundle: PresentationResources.bundle))

        if showsPaneTitleBar {
            PaneTitleBar(title)
        } else {
            ZStack {
                title
                    .font(.headline)

                if deviceType != .duo {
                    HStack {
                        NavigationBackButton(action: { dismiss() })
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: readableContentWidth)
            .padding(.top, windowControlsInset)
            .padding(.bottom, 12)
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground)
        }
    }

    private func themeButton(_ option: SystemTheme) -> some View {
        HStack(spacing: 12) {
            Image(systemName: option.symbolName)
                .font(.headline)
                .frame(width: 36, height: 36)
                .iconStyle(color: option.iconColor, in: Circle())

            Text(option.localizedName(in: PresentationResources.bundle))
                .foregroundStyle(Color.textPrimary)

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
