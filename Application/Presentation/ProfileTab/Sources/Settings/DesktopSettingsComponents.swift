//
//  DesktopSettingsComponents.swift
//  ProfileTab
//
//  Created by opfic on 11/16/26.
//

import SwiftUI
import PresentationShared

// 설정 화면 묶음
// 위쪽 작은 제목, 바탕·테두리 없이 행 사이 구분선으로 나눈 행, 아래쪽 안내 순서로 같은 왼쪽 선에 배치
// 사이드바가 있는 창은 행 전체 폭, 좁은 화면은 이름 시작부터 행 끝까지 구분선 표시
struct DesktopSettingsSection<Content: View>: View {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    // 행이 알려 주는 아이콘 자리 폭
    @State private var separatorInset = CGFloat.zero
    var header: Text?
    var footer: Text?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                header
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
                    .padding(.bottom, 6 * AdaptiveSize.boardScale)
            }

            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(subviews) { subview in
                        subview

                        if subview.id != subviews.last?.id {
                            Rectangle()
                                .fill(usesDesktopLayout ? Color.secondarySeparator : .separator)
                                .frame(height: 1)
                                .padding(.leading, usesDesktopLayout ? 0 : separatorInset)
                        }
                    }
                }
            }
            .onPreferenceChange(SettingsSeparatorInsetKey.self) { separatorInset = $0 }

            if let footer {
                footer
                    .font(.adaptive(.caption))
                    .foregroundStyle(Color.secondaryLabel)
                    .lineSpacing(5.5 * AdaptiveSize.boardScale)
                    .padding(.top, 6 * AdaptiveSize.boardScale)
            }
        }
    }
}

// 설정 화면 행
// 왼쪽 테두리 있는 아이콘 사각형이나 로고, 이름과 설명, 오른쪽 선택 원이나 버튼 배치
// Mac은 Mac 화면 크기, iPhone·Duo·iPad는 손가락으로 누르는 크기
struct DesktopSettingsRow<Trailing: View>: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    private let symbolName: String?
    private let symbolColor: Color
    private let logo: Image?
    private let title: Text
    private let subtitle: Text?
    private let trailing: Trailing

    init(
        symbolName: String? = nil,
        symbolColor: Color = .secondaryLabel,
        logo: Image? = nil,
        title: Text,
        subtitle: Text? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.symbolName = symbolName
        self.symbolColor = symbolColor
        self.logo = logo
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        let iconSize = isiOSAppOnMac ? 25 * AdaptiveSize.boardScale : 28
        let minHeight = isiOSAppOnMac ? 38 * AdaptiveSize.boardScale : 50

        HStack(spacing: 10 * AdaptiveSize.boardScale) {
            // 좁은 화면 아이콘 사각형은 화면 바탕색, 사이드바가 있는 창은 한 단계 밝은 바탕색
            if let symbolName {
                Image(systemName: symbolName)
                    .foregroundStyle(symbolColor)
                    .frame(width: iconSize, height: iconSize)
                    .background(
                        usesDesktopLayout ? Color.tertiaryBackground : .background,
                        in: .rect(cornerRadius: CornerRadius.control)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.control)
                            .strokeBorder(Color.secondarySeparator)
                    }
            }

            // Orca 공급자 설정처럼 로고는 사각형 없이 원래 색으로 이름 앞에 표시
            // 아이콘 사각형 행과 이름 시작 위치를 맞추도록 사각형 폭 가운데에 배치
            if let logo {
                let logoSize = isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 18

                logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize, height: logoSize)
                    .frame(width: iconSize)
            }

            VStack(alignment: .leading, spacing: 2 * AdaptiveSize.boardScale) {
                title
                if let subtitle {
                    subtitle
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
            .padding(.vertical, isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
        .foregroundStyle(Color.label)
        .frame(minHeight: minHeight)
        .contentShape(.rect)
        // 좁은 화면 묶음 구분선이 이름 시작에서 시작하도록 아이콘 자리 폭 전달
        .preference(
            key: SettingsSeparatorInsetKey.self,
            value: symbolName != nil || logo != nil ? iconSize + 10 * AdaptiveSize.boardScale : 0
        )
    }
}

extension DesktopSettingsRow where Trailing == EmptyView {
    init(
        symbolName: String? = nil,
        symbolColor: Color = .secondaryLabel,
        logo: Image? = nil,
        title: Text,
        subtitle: Text? = nil
    ) {
        self.init(symbolName: symbolName, symbolColor: symbolColor, logo: logo, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

// 설정 화면 테마, 알림 시간 행 오른쪽 선택 원
struct SettingsCheck: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle" : "circle")
            .font(.adaptive(isiOSAppOnMac ? .title2 : .title3))
            .foregroundStyle(isSelected ? Color.label : .secondaryLabel)
    }
}

// 설정 화면 행 오른쪽 작은 버튼
// Orca 설정처럼 행 자체는 누르지 않고 이 버튼으로 동작 실행
struct DesktopSettingsButton: View {
    enum Role {
        case normal
        case prominent
        case destructive
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let title: String
    var role = Role.normal
    var showsProgress = false
    let action: () -> Void

    var body: some View {
        let color: Color = switch role {
        case .normal: .secondaryLabel
        case .prominent: .background
        case .destructive: .danger
        }
        let border: Color = switch role {
        case .normal: .separator
        case .prominent: .label
        case .destructive: .danger
        }

        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(showsProgress ? 0 : 1)

                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(color)
                }
            }
            .font(.adaptive(.footnote).weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12 * AdaptiveSize.boardScale)
            .frame(minHeight: isiOSAppOnMac ? 22 * AdaptiveSize.boardScale : 34)
            .background(role == .prominent ? Color.label : .clear, in: .rect(cornerRadius: CornerRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.control)
                    .strokeBorder(border)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled || showsProgress ? 1 : 0.5)
    }
}

private struct SettingsSeparatorInsetKey: PreferenceKey {
    static let defaultValue = CGFloat.zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
