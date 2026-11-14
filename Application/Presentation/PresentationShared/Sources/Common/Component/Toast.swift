//
//  Toast.swift
//  PresentationShared
//
//  Created by 최윤진 on 2/10/26.
//

import SwiftUI

@MainActor
@Observable
public final class ToastPresenter {
    fileprivate static let presenter = ToastPresenter()

    public private(set) var item: ToastItem?

    private init() { }

    public static var item: ToastItem? {
        presenter.item
    }

    public static func present<Label: View>(
        duration: TimeInterval = 2,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        presenter.present(
            ToastItem(
                duration: duration,
                action: action,
                onDismiss: onDismiss,
                label: {
                    AnyView(label())
                }
            )
        )
    }

    public static func reset() {
        presenter.item = nil
    }

    private func present(_ item: ToastItem) {
        dismissImmediately()
        self.item = item
    }

    fileprivate func dismiss(itemId: UUID) {
        guard let item,
              item.id == itemId else { return }
        self.item = nil
    }

    private func dismissImmediately() {
        guard let item else { return }
        self.item = nil
        item.onDismiss?()
    }
}

public struct ToastItem: Identifiable {
    public let id = UUID()
    public let duration: TimeInterval
    public let action: (() -> Void)?
    public let onDismiss: (() -> Void)?
    fileprivate let label: () -> AnyView
}

public extension View {
    func toastHost() -> some View {
        modifier(ToastHostModifier())
    }
}

private struct ToastHostModifier: ViewModifier {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @State private var tabBarHeight = CGFloat.zero
    private let toastPresenter = ToastPresenter.presenter
    private let placement = ToastPresentationPlacement.current

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                updateTabBarHeight()
            }
            .onChange(of: toastPresenter.item?.id) { _, _ in
                updateTabBarHeight()
            }
            .overlay(alignment: placement.alignment) {
                if let item = toastPresenter.item {
                    ToastOverlayView(
                        isPresented: Binding(
                            get: { toastPresenter.item?.id == item.id },
                            set: { isPresented in
                                if !isPresented {
                                    toastPresenter.dismiss(itemId: item.id)
                                }
                            }
                        ),
                        duration: item.duration,
                        presentedOffset: placement.presentedOffset,
                        action: item.action,
                        onDismiss: item.onDismiss
                    ) {
                        item.label()
                    }
                    .id(item.id)
                    .padding(.horizontal, 12)
                    .padding(.bottom, placement.bottomPadding(toastBottomInset))
                }
            }
    }

    private var toastBottomInset: CGFloat {
        max(0, tabBarHeight - safeAreaInsets.bottom)
    }

    @MainActor
    private func updateTabBarHeight() {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        guard let window else {
            tabBarHeight = .zero
            return
        }
        tabBarHeight = window.rootViewController?.visibleTabBarHeight ?? .zero
    }
}

private enum ToastPresentationPlacement {
    case top
    case bottom

    static var current: ToastPresentationPlacement {
        ProcessInfo.processInfo.isiOSAppOnMac ? .top : .bottom
    }

    var alignment: Alignment {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    var presentedOffset: CGFloat {
        switch self {
        case .top:
            return 50
        case .bottom:
            return -50
        }
    }

    func bottomPadding(_ inset: CGFloat) -> CGFloat {
        switch self {
        case .top:
            return 0
        case .bottom:
            return inset
        }
    }
}

private struct ToastOverlayView<Label: View>: View {
    @Binding var isPresented: Bool
    let duration: TimeInterval
    let presentedOffset: CGFloat
    let action: (() -> Void)?
    let onDismiss: (() -> Void)?
    @ViewBuilder let label: () -> Label

    @State private var yOffset: CGFloat = 0
    @State private var opacityValue: Double = 0
    @State private var dismissWorkItem: DispatchWorkItem?
    @State private var dismissCompletionWorkItem: DispatchWorkItem?
    @State private var isTapped: Bool = false
    @State private var isScheduled: Bool = false

    var body: some View {
        if isPresented {
            Group {
                if #available(iOS 26.0, *) {
                    toastButton
                        .glassEffect(.regular.tint(Color.secondaryBackground.opacity(0.65)), in: .capsule)
                } else {
                    toastButton
                        .background(Color.secondaryBackground.opacity(0.45), in: .capsule)
                        .background(.regularMaterial, in: .capsule)
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.14), Color.primary.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.16), radius: 16, y: 8)
            .offset(y: yOffset)
            .opacity(opacityValue)
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    resetForNewPresentation()
                    presentAnimated()
                    scheduleDismissIfNeeded()
                } else {
                    cleanupPresentation()
                }
            }
            .onAppear {
                presentAnimated()
                scheduleDismissIfNeeded()
            }
            .onDisappear {
                cleanupPresentation()
            }
            .transition(.identity)
        }
    }

    private var toastButton: some View {
        Button(action: performAction) {
            label()
                .labelStyle(TrailingIconLabelStyle())
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .contentShape(.capsule)
    }

    private func presentAnimated() {
        guard opacityValue == 0 else { return }

        withAnimation(.spring(response: 0.5, dampingFraction: 1, blendDuration: 0.0)) {
            yOffset = presentedOffset
            opacityValue = 1
        }
    }

    private func resetForNewPresentation() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        dismissCompletionWorkItem?.cancel()
        dismissCompletionWorkItem = nil
        isScheduled = false
        isTapped = false
        yOffset = 0
        opacityValue = 0
    }

    private func cleanupPresentation() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        dismissCompletionWorkItem?.cancel()
        dismissCompletionWorkItem = nil
        isScheduled = false
        isTapped = false
        yOffset = 0
        opacityValue = 0
    }

    private func scheduleDismissIfNeeded() {
        guard !isScheduled else { return }
        isScheduled = true

        let workItem = DispatchWorkItem {
            dismissAnimated()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func dismissAnimated() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        dismissCompletionWorkItem?.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            yOffset = 0
            opacityValue = 0
        }

        let workItem = DispatchWorkItem {
            isPresented = false
            isScheduled = false

            if !isTapped {
                onDismiss?()
            }
            isTapped = false
        }
        dismissCompletionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func performAction() {
        isTapped = true
        dismissAnimated()
        action?()
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}
