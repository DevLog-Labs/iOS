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
            modifier(LegacyTopBarButtonStyleModifier(tint: tint ?? .textPrimary))
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
        content
            .toolbarTitleDisplayMode(deviceType == .duo ? .inline : .automatic)
            .toolbarBackgroundVisibility(deviceType == .duo ? .hidden : .automatic, for: .navigationBar)
            .toolbarVisibility(deviceType == .duo ? .visible : .hidden, for: .navigationBar)
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
                    .fill(Color.surface)
            }
    }
}

@available(iOS 26.0, *)
private struct TopBarButtonStyleModifier: ViewModifier {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @ScaledMetric(relativeTo: .title) private var iconSize = UIFont.preferredFont(
        forTextStyle: .title2,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
    ).lineHeight
    @ScaledMetric(relativeTo: .body) private var macIconSize = UIFont.preferredFont(
        forTextStyle: .body,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
    ).lineHeight
    let tint: Color?
    let isInteractive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isiOSAppOnMac {
            // Mac에서는 리퀴드 글래스 없이 제목 줄에 맞는 작은 아이콘만 표시
            content
                .font(.body.weight(.medium))
                .foregroundStyle(tint ?? Color.textPrimary)
                .frame(width: macIconSize, height: macIconSize)
                .padding(6)
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
                .foregroundStyle(Color.textPrimary)
                .frame(width: iconSize, height: iconSize)
                .padding(9)
                .glassEffect(.regular.interactive(isInteractive), in: .circle)
        }
    }
}
