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
                DesktopSettingsSection {
                    ForEach(Self.themes) { option in
                        Button {
                            theme = option
                        } label: {
                            DesktopSettingsRow(
                                symbolName: option.symbolName,
                                title: Text(option.localizedName(in: PresentationResources.bundle))
                            ) {
                                SettingsCheck(isSelected: theme == option)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            // Mac 설정 화면은 묶음마다 보드의 위아래 8, 좌우 14 여백
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 24)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // 위쪽 줄 구분선과 첫 항목 사이 여백
        .contentMargins(
            .top,
            isiOSAppOnMac ? 20 * AdaptiveSize.boardScale : showsPaneTitleBar ? 24 : 12,
            for: .scrollContent
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsTopBar {
                topBar
            }
        }
        .background(Color.background)
        .duoToolbarVisibility(showsBackButton: true)
    }

    private static let themes: [SystemTheme] = [.automatic, .light, .dark]

    @ViewBuilder
    private var topBar: some View {
        let title = Text(String(localized: "nav_theme", bundle: PresentationResources.bundle))

        if showsPaneTitleBar {
            // 일반 화면에서 밀어 넣은 화면이 칸 화면으로 바뀌어도 뒤로 갈 수 있게 뒤로 버튼 표시
            PaneTitleBar(title, onBack: isPaneDetail ? nil : { dismiss() }, showsBackOnDesktop: true)
        } else {
            // OS와 상관없이 같은 모양인 가운데 제목과 아래 구분선
            ZStack {
                title
                    .font(.adaptive(.callout).bold())
                HStack {
                    // Duo는 세로 막대의 뒤로 버튼 사용
                    if deviceType != .duo {
                        NavigationBackButton(action: { dismiss() })
                    }
                    Spacer()
                }
            }
            .frame(height: 48)
            .padding(.horizontal, 8)
            .overlay(alignment: .bottom) {
                Divider().overlay(Color.secondarySeparator)
            }
            .padding(.top, windowControlsInset)
            .background(Color.background, ignoresSafeAreaEdges: .top)
        }
    }
}

private extension SystemTheme {
    // 아이콘 사각형 안 기호
    var symbolName: String {
        switch self {
        case .automatic:
            return "desktopcomputer"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}
