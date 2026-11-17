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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Binding var theme: SystemTheme
    // 설정 옆 칸에 넣은 화면은 뒤로 갈 곳이 없어 칸 제목 줄의 뒤로 버튼 생략
    var isPaneDetail = false
    // 앱 화면과 분리한 Mac 설정 화면은 위쪽 줄을 직접 그려 화면 제목 줄 생략
    var showsTopBar = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if isiOSAppOnMac {
                    DesktopSettingsSection {
                        ForEach(Self.themes) { option in
                            Button {
                                theme = option
                            } label: {
                                DesktopSettingsRow(
                                    symbolName: option.desktopSymbolName,
                                    title: Text(option.localizedName(in: PresentationResources.bundle))
                                ) {
                                    SettingsCheck(isSelected: theme == option)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Self.themes) { option in
                            themeButton(option)

                            if option != Self.themes.last {
                                Divider().overlay(Color.separator)
                                    .padding(.leading, 68)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
                }
            }
            // Mac 설정 화면은 묶음마다 보드의 위아래 8, 좌우 14 여백
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 24)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // Mac 제목 줄 구분선과 첫 항목 사이 여백
        .contentMargins(
            .top,
            isiOSAppOnMac ? 20 * AdaptiveSize.boardScale : showsPaneTitleBar ? 12 : 0,
            for: .scrollContent
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsTopBar {
                topBar
            }
        }
        .background(Color.background)
        .duoToolbarVisibility()
    }

    private static let themes: [SystemTheme] = [.automatic, .light, .dark]

    @ViewBuilder
    private var topBar: some View {
        let title = Text(String(localized: "nav_theme", bundle: PresentationResources.bundle))

        if showsPaneTitleBar {
            // 일반 화면에서 밀어 넣은 화면이 칸 화면으로 바뀌어도 뒤로 갈 수 있게 뒤로 버튼 표시
            PaneTitleBar(title, onBack: isPaneDetail ? nil : { dismiss() })
        } else {
            ZStack {
                title
                    .font(.adaptive(.headline))

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
            .background(Color.background)
            .toolbarBackground(Color.background)
        }
    }

    private func themeButton(_ option: SystemTheme) -> some View {
        HStack(spacing: 12) {
            Image(systemName: option.symbolName)
                .font(.adaptive(.headline))
                .frame(width: 36, height: 36)
                .iconStyle(color: option.iconColor, in: Circle())

            Text(option.localizedName(in: PresentationResources.bundle))
                .foregroundStyle(Color.label)

            Spacer(minLength: 8)

            Image(systemName: theme == option ? "checkmark.circle.fill" : "circle")
                .font(.adaptive(.title2))
                .foregroundStyle(theme == option ? Color.accent : Color.separator)

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

    // Mac 설정 화면 아이콘 사각형 안 기호
    var desktopSymbolName: String {
        switch self {
        case .automatic:
            return "desktopcomputer"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }

    var iconColor: Color {
        switch self {
        case .automatic:
            return .accent
        case .light:
            return .warning
        case .dark:
            return .fillLabel
        }
    }
}
