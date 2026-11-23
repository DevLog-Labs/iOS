//
//  RecordPresentation.swift
//  Development
//
//  Created by opfic on 9/13/26.
//

import SwiftUI
import Domain
import PresentationShared

enum RecordPresentation {
    static func text(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: PresentationResources.bundle)
    }

    static func versionLabel(_ number: Int) -> String {
        "v\(number)"
    }
}

// 좁은 창 화면 맨 위의 높이 48 줄
// 양쪽 칸은 둘 중 넓은 버튼 폭으로 맞추고 가운데 제목이 남은 폭을 모두 쓰며 아래 구분선 표시
struct RecordTopBar<Leading: View, Trailing: View>: View {
    @Environment(\.windowControlsInset) private var windowControlsInset
    private let title: String
    private let background: Color
    private let leading: Leading
    private let trailing: Trailing

    init(
        _ title: String,
        background: Color = .background,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.background = background
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            // 반대쪽 버튼을 숨겨 겹쳐 두어 양쪽 칸 폭을 같게 맞춤
            ZStack(alignment: .leading) {
                HStack(spacing: 0) { trailing }.hidden()
                HStack(spacing: 0) { leading }
            }
            Text(title)
                .font(.adaptive(.callout).bold())
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            ZStack(alignment: .trailing) {
                HStack(spacing: 0) { leading }.hidden()
                HStack(spacing: 0) { trailing }
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)
        }
        .padding(.top, windowControlsInset)
        .background(background, ignoresSafeAreaEdges: .top)
    }
}

// 위쪽 줄의 글자 닫기·저장 버튼
struct RecordTopBarTextButton: View {
    @Environment(\.isEnabled) private var isEnabled
    private let title: String
    private let isProminent: Bool
    private let action: () -> Void

    init(_ title: String, isProminent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isProminent = isProminent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.adaptive(.callout).weight(isProminent ? .bold : .medium))
                .foregroundStyle(Color.label)
                .opacity(isEnabled ? 1 : 0.4)
                .padding(.horizontal, 4)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// 반경 6의 높이 44 버튼, Mac은 높이 32
// 강조 버튼은 흑백 채움 바탕, 보조 버튼은 회색 바탕과 테두리
struct RecordButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    var isProminent = true
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.control)

        configuration.label
            .font(.adaptive(isiOSAppOnMac ? .body : .subheadline).weight(.semibold))
            .foregroundStyle(isProminent ? Color.background : .label)
            .lineLimit(1)
            .padding(.horizontal, 16 * AdaptiveSize.boardScale)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : 44)
            .background(isProminent ? Color.label : .tertiaryBackground, in: shape)
            .overlay { shape.strokeBorder(isProminent ? Color.label : .secondarySeparator) }
            .opacity(isEnabled ? configuration.isPressed ? 0.7 : 1 : 0.4)
            .contentShape(shape)
    }
}

// 아이콘과 글자를 붙인 버튼 내용
struct RecordButtonLabel: View {
    let title: String
    let systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
    }
}

extension View {
    // 사이드바가 있는 창은 공용 입력칸 모양, 좁은 창은 라이트에서도 보이도록 옅은 회색 바탕과 테두리
    func recordInputBackground(isMultiline: Bool = false, isFocused: Bool = false) -> some View {
        modifier(RecordInputBackground(isMultiline: isMultiline, isFocused: isFocused))
    }
}

private struct RecordInputBackground: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let isMultiline: Bool
    let isFocused: Bool

    func body(content: Content) -> some View {
        if usesDesktopLayout {
            content.inputBackground(isMultiline: isMultiline, isFocused: isFocused)
        } else {
            let shape = RoundedRectangle(cornerRadius: CornerRadius.control)

            content
                .background(Color.tertiaryBackground, in: shape)
                .overlay { shape.strokeBorder(isFocused ? Color.secondaryLabel : .secondarySeparator) }
        }
    }
}

// 작성·미리보기 분할 버튼
// 좁은 창은 칸 폭을 채우고, 사이드바가 있는 창은 글자 폭만큼 작게 표시
struct RecordModePicker: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let isWriting: Bool
    let onWrite: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            segment(RecordPresentation.text("development_record_write"), isSelected: isWriting, action: onWrite)
            segment(RecordPresentation.text("development_record_preview"), isSelected: !isWriting, action: onPreview)
        }
        .padding(2)
        .background(Color.tertiaryBackground, in: RoundedRectangle(cornerRadius: CornerRadius.control))
    }

    private func segment(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // 고른 조각은 강조색 대신 글자색과 옅은 테두리로 표시
            Text(title)
                .font(.adaptive(isiOSAppOnMac ? .subheadline : .footnote).weight(.semibold))
                .foregroundStyle(isSelected ? Color.label : .secondaryLabel)
                .padding(.horizontal, usesDesktopLayout ? (isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 14) : 0)
                .padding(.vertical, isiOSAppOnMac ? 3 * AdaptiveSize.boardScale : 5)
                .frame(maxWidth: usesDesktopLayout ? nil : .infinity)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.segment)
                            .fill(Color.secondaryBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: CornerRadius.segment)
                                    .strokeBorder(Color.label.opacity(0.12))
                            }
                            .shadow(color: Color.secondaryLabel.opacity(0.08), radius: 2, y: 2)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// 버전이 만들어진 방식 배지
struct RecordVersionKindBadge: View {
    let kind: DevelopmentRecord.Version.Kind

    var body: some View {
        switch kind {
        case .initial:
            TodoBadge(RecordPresentation.text("development_record_version_initial"), color: .tintLabel)
        case .correction:
            TodoBadge(RecordPresentation.text("development_record_version_correction"), color: .warning)
        case .rollback:
            TodoBadge(RecordPresentation.text("development_record_version_rollback"), color: .secondaryLabel)
        }
    }
}

// 왼쪽을 페이지 여백만큼 들이고 아래 구분선으로 나눈 목록 행
struct RecordListRow<Content: View>: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    private let isSelected: Bool
    private let content: Content

    init(isSelected: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.adaptive(.footnote).weight(.semibold))
                    .foregroundStyle(Color.secondaryLabel)
            }
            .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
            .padding(.trailing, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)
        }
        .padding(.leading, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        // 상세 판으로 연 행은 회색 바탕
        .background(isSelected ? Color.fill : .clear)
        .contentShape(.rect)
    }
}
