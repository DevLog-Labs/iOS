//
//  View+.swift
//  PresentationShared
//
//  Created by 최윤진 on 11/22/25.
//

import SwiftUI

public enum AdaptiveButtonGlassEffect {
    case enabled
    case disabled
}

public extension View {
    @ViewBuilder
    func topBarButtonStyle(tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            modifier(TopBarButtonStyleModifier(tint: tint, isInteractive: true))
        } else {
            modifier(LegacyTopBarButtonStyleModifier(tint: tint ?? .label))
        }
    }

    @available(iOS 26.0, *)
    func topBarProgressStyle() -> some View {
        modifier(TopBarButtonStyleModifier(tint: nil, isInteractive: false))
    }

    func duoToolbarVisibility() -> some View {
        modifier(DuoToolbarVisibilityModifier())
    }

    func toolbarBackground(_ color: Color) -> some View {
        background(alignment: .top) {
            GeometryReader { proxy in
                let top = max(proxy.frame(in: .global).minY, 0)
                color
                    .frame(height: top)
                    .offset(y: -top)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    func onScrollOffsetChange(action: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 18, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, newOffset in
                action(newOffset)
            }
        } else {
            self.background(ScrollViewOffsetTracker(onChange: action))
        }
    }
}

private struct ScrollViewOffsetTracker: UIViewRepresentable {
    var onChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            guard let scrollView = Self.findScrollView(from: view) else { return }
            context.coordinator.observe(scrollView)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private static func findScrollView(from view: UIView) -> UIScrollView? {
        var current = view.superview
        while let superview = current {
            if let scrollView = superview as? UIScrollView {
                return scrollView
            }
            for sibling in superview.subviews where sibling !== view {
                if let scrollView = findScrollViewInSubviews(of: sibling) {
                    return scrollView
                }
            }
            current = superview.superview
        }
        return nil
    }

    private static func findScrollViewInSubviews(of view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = findScrollViewInSubviews(of: subview) {
                return scrollView
            }
        }
        return nil
    }

    class Coordinator: NSObject {
        private var onChange: (CGFloat) -> Void
        private var observation: NSKeyValueObservation?

        init(onChange: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
        }

        func observe(_ scrollView: UIScrollView) {
            observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
                self?.onChange(offset)
            }
        }

        deinit {
            observation?.invalidate()
        }
    }
}

public extension View {
    @ViewBuilder
    func adaptiveButtonStyle<S: InsettableShape>(
        shape: S = Capsule(),
        color: Color = .clear,
        glassEffect: AdaptiveButtonGlassEffect = .disabled
    ) -> some View {
        if #available(iOS 26.0, *) {
            switch glassEffect {
            case .enabled:
                if ProcessInfo.processInfo.isiOSAppOnMac {
                    // Mac에서는 리퀴드 글래스 대신 같은 색의 불투명 배경 표시
                    self.foregroundStyle(Color(.label))
                        .padding(8)
                        .background(color, in: shape)
                } else {
                    self.foregroundStyle(Color(.label))
                        .padding(8)
                        .glassEffect(.regular.tint(color), in: shape)
                        .clipShape(shape)
                }
            case .disabled:
                opaqueButtonStyle(shape: shape, color: color)
            }
        } else {
            opaqueButtonStyle(shape: shape, color: color)
        }
    }

    private func opaqueButtonStyle<S: InsettableShape>(
        shape: S,
        color: Color
    ) -> some View {
        self.foregroundStyle(Color(.label))
            .padding(8)
            .background {
                shape
                    .fill(color == .clear ? Color(.systemGray5) : color)
            }
            .overlay {
                if color == .clear {
                    shape
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                }
            }
    }
}

private struct DuoToolbarVisibilityModifier: ViewModifier {
    @Environment(\.deviceType) private var deviceType

    func body(content: Content) -> some View {
        // 세로 막대가 있는 Duo는 시스템 막대 버튼을 세로 막대에 표시하고, 그 밖은 직접 그린 위쪽 막대 사용
        let showsNavigationBar = deviceType == .duo

        content
            .toolbarTitleDisplayMode(showsNavigationBar ? .inline : .automatic)
            .toolbarBackgroundVisibility(showsNavigationBar ? .hidden : .automatic, for: .navigationBar)
            .toolbarVisibility(showsNavigationBar ? .visible : .hidden, for: .navigationBar)
    }
}

private struct LegacyTopBarButtonStyleModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(tint)
            .padding(8)
            .background {
                Capsule()
                    .fill(Color.secondaryBackground)
            }
    }
}

@available(iOS 26.0, *)
private struct TopBarButtonStyleModifier: ViewModifier {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.isInPaneTitleBar) private var isInPaneTitleBar
    @ScaledMetric(relativeTo: .title) private var iconSize = UIFont.preferredFont(
        forTextStyle: .title2,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
    ).lineHeight
    @ScaledMetric(relativeTo: .body) private var macIconSize = UIFont.preferredFont(
        forTextStyle: .body,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
    ).lineHeight
    @ScaledMetric(relativeTo: .title3) private var padIconSize = UIFont.preferredFont(
        forTextStyle: .title3,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
    ).lineHeight
    let tint: Color?
    let isInteractive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if usesDesktopLayout {
            // 사이드바가 있으면 리퀴드 글래스 없이 제목 줄에 맞는 아이콘만 표시
            // Mac은 Mac 화면 크기, iPad는 손가락으로 누르는 크기
            // 아이콘 둘레 여백까지 버튼이 채워 마우스 반응 채움 전체를 누를 수 있게 함
            let size = isiOSAppOnMac ? macIconSize + 12 : padIconSize + 16

            content
                .font(isiOSAppOnMac ? .body.weight(.medium) : .title3.weight(.medium))
                .foregroundStyle(tint ?? Color.label)
                .buttonStyle(FillButtonStyle())
                .frame(width: size, height: size)
                .hoverHighlight(in: RoundedRectangle(cornerRadius: CornerRadius.control), isEnabled: isInteractive)
                .contentShape(.rect)
        } else if isInPaneTitleBar && tint == nil {
            // 칸 제목 줄에서는 리퀴드 글래스 없이 손가락으로 누르는 크기의 아이콘만 표시
            content
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.label)
                .buttonStyle(FillButtonStyle())
                .frame(width: iconSize + 12, height: iconSize + 12)
                .contentShape(.rect)
        } else if let tint {
            content
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(width: iconSize, height: iconSize)
                .padding(9)
                .glassEffect(
                    .regular.tint(tint).interactive(isInteractive),
                    in: .circle
                )
        } else {
            content
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.label)
                .frame(width: iconSize, height: iconSize)
                .padding(9)
                .glassEffect(.regular.interactive(isInteractive), in: .circle)
        }
    }
}

// 버튼의 누르는 영역을 바깥에서 정한 크기 전체로 넓힘
private struct FillButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: configuration.trigger) {
            configuration.label
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
