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

    public static func present(
        message: String,
        systemImage: String,
        duration: TimeInterval = 2,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        presenter.present(
            ToastItem(
                duration: duration,
                action: action,
                onDismiss: onDismiss,
                message: message,
                systemImage: systemImage
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
    fileprivate let message: String
    fileprivate let systemImage: String
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
                        message: item.message,
                        systemImage: item.systemImage,
                        action: item.action,
                        onDismiss: item.onDismiss
                    )
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
            return -16
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

private struct ToastOverlayView: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Binding var isPresented: Bool
    let duration: TimeInterval
    let presentedOffset: CGFloat
    let message: String
    let systemImage: String
    let action: (() -> Void)?
    let onDismiss: (() -> Void)?

    @State private var yOffset: CGFloat = 0
    @State private var opacityValue: Double = 0
    @State private var dismissWorkItem: DispatchWorkItem?
    @State private var dismissCompletionWorkItem: DispatchWorkItem?
    @State private var isTapped: Bool = false
    @State private var isScheduled: Bool = false

    var body: some View {
        if isPresented {
            toastButton
                .shadow(color: Color.black.opacity(0.35), radius: 12, y: 8)
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
        let height = isiOSAppOnMac ? CGFloat(36) : 44
        let padding = isiOSAppOnMac ? CGFloat(14) : 18
        let buttonSize = isiOSAppOnMac ? CGFloat(24) : 30
        let buttonPadding = isiOSAppOnMac ? CGFloat(5) : 6
        // 모바일은 높이의 절반인 알약, Mac은 반경 10
        let shape = RoundedRectangle(cornerRadius: isiOSAppOnMac ? 10 : height / 2)

        return Button(action: performAction) {
            HStack(spacing: 8) {
                // 인포 토스트는 문구 앞 아이콘, 인터랙션 토스트는 문구 뒤 강조색 원 버튼
                if action == nil {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.accent)
                }

                Text(message)
                    .foregroundStyle(Color.label)

                if action != nil {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.white)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.accent, in: .circle)
                }
            }
            .font(isiOSAppOnMac ? .footnote : .subheadline)
            .fontWeight(.medium)
            .padding(.leading, padding)
            .padding(.trailing, action == nil ? padding : buttonPadding)
            .frame(minHeight: height)
            .background(Color.secondaryBackground, in: shape)
            .overlay {
                shape
                    .strokeBorder(Color.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contentShape(shape)
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
