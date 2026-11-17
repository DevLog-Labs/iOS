//
//  DesktopSettingsComponents.swift
//  ProfileTab
//
//  Created by opfic on 11/16/26.
//

import SwiftUI
import PresentationShared

// Mac 설정 화면 묶음
// 위쪽 작은 제목, 행 사이 구분선이 있는 테두리 상자, 아래쪽 안내 순서로 배치
struct DesktopSettingsSection<Content: View>: View {
    var header: Text?
    var footer: Text?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                header
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
                    .padding(.horizontal, 4 * AdaptiveSize.boardScale)
                    .padding(.bottom, 6 * AdaptiveSize.boardScale)
            }

            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(subviews) { subview in
                        subview

                        if subview.id != subviews.last?.id {
                            Rectangle()
                                .fill(Color.secondarySeparator)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))

            if let footer {
                footer
                    .font(.adaptive(.caption))
                    .foregroundStyle(Color.secondaryLabel)
                    .lineSpacing(5.5 * AdaptiveSize.boardScale)
                    .padding(.horizontal, 4 * AdaptiveSize.boardScale)
                    .padding(.top, 6 * AdaptiveSize.boardScale)
            }
        }
    }
}

// Mac 설정 화면 행
// 왼쪽 테두리 있는 아이콘 사각형이나 로고, 이름과 설명, 오른쪽 선택 원이나 버튼 배치
struct DesktopSettingsRow<Trailing: View>: View {
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
        HStack(spacing: 10 * AdaptiveSize.boardScale) {
            if let symbolName {
                Image(systemName: symbolName)
                    .foregroundStyle(symbolColor)
                    .frame(width: 25 * AdaptiveSize.boardScale, height: 25 * AdaptiveSize.boardScale)
                    .background(Color.tertiaryBackground, in: .rect(cornerRadius: CornerRadius.segment))
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.segment)
                            .strokeBorder(Color.secondarySeparator)
                    }
            }

            // Orca 공급자 설정처럼 로고는 사각형 없이 원래 색으로 이름 앞에 표시
            // 아이콘 사각형 행과 이름 시작 위치를 맞추도록 사각형 폭 가운데에 배치
            if let logo {
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16 * AdaptiveSize.boardScale, height: 16 * AdaptiveSize.boardScale)
                    .frame(width: 25 * AdaptiveSize.boardScale)
            }

            VStack(alignment: .leading, spacing: 2 * AdaptiveSize.boardScale) {
                title
                if let subtitle {
                    subtitle
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
            .padding(.vertical, 6 * AdaptiveSize.boardScale)
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .font(.adaptive(.body))
        .foregroundStyle(Color.label)
        .padding(.horizontal, 12 * AdaptiveSize.boardScale)
        .frame(minHeight: 38 * AdaptiveSize.boardScale)
        .contentShape(.rect)
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

// Mac 설정 화면 테마, 알림 시간 행 오른쪽 선택 원
struct SettingsCheck: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle" : "circle")
            .font(.adaptive(.title2))
            .foregroundStyle(isSelected ? Color.accent : .secondaryLabel)
    }
}

// Mac 설정 화면 행 오른쪽 작은 버튼
// Orca 설정처럼 행 자체는 누르지 않고 이 버튼으로 동작 실행
struct DesktopSettingsButton: View {
    enum Role {
        case normal
        case prominent
        case destructive
    }

    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var role = Role.normal
    var showsProgress = false
    let action: () -> Void

    var body: some View {
        let color: Color = switch role {
        case .normal: .secondaryLabel
        case .prominent: .white
        case .destructive: .danger
        }
        let border: Color = switch role {
        case .normal: .separator
        case .prominent: .accent
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
            .frame(minHeight: 22 * AdaptiveSize.boardScale)
            .background(role == .prominent ? Color.accent : .clear, in: .rect(cornerRadius: CornerRadius.control))
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
