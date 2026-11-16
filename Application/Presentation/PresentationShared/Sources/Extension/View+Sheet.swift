//
//  View+Sheet.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

public enum SheetDetent: Equatable {
    case large
    case height(CGFloat)
    case fraction(CGFloat)
}

public extension View {
    // OS와 기기에 상관없이 같은 모양으로 직접 그리는 시트
    func prominentSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(
            ProminentPresentation(item: item) { item, isShown, dismiss in
                ProminentSheet(isShown: isShown, dismiss: dismiss) {
                    content(item)
                }
            }
        )
    }

    func prominentSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        prominentSheet(
            item: Binding(
                get: { isPresented.wrappedValue ? SheetPresence() : nil },
                set: { isPresented.wrappedValue = $0 != nil }
            )
        ) { _ in
            content()
        }
    }

    func sheetDetent(_ detent: SheetDetent) -> some View {
        preference(key: SheetDetentKey.self, value: detent)
    }

    func sheetDismissDisabled(_ isDisabled: Bool = true) -> some View {
        preference(key: SheetDismissDisabledKey.self, value: isDisabled)
    }

    // 손잡이 모양만 숨기고 끌어서 닫기는 유지
    func sheetGrabberHidden(_ isHidden: Bool = true) -> some View {
        preference(key: SheetGrabberHiddenKey.self, value: isHidden)
    }
}

private struct SheetPresence: Identifiable {
    var id: Bool { true }
}

private struct SheetDetentKey: PreferenceKey {
    static let defaultValue = SheetDetent.large

    static func reduce(value: inout SheetDetent, nextValue: () -> SheetDetent) {
        if value == .large {
            value = nextValue()
        }
    }
}

private struct SheetDismissDisabledKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct SheetGrabberHiddenKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct ProminentSheet<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var detent = SheetDetent.large
    @State private var isDismissDisabled = false
    @State private var isGrabberHidden = false
    @State private var dragOffset = CGFloat.zero
    // 창 기준 옆 안전 영역, 시트 안 옆 안전 영역을 지운 뒤에도 Duo 세로 막대 여부를 알기 위해 보관
    @State private var verticalBarWidth = CGFloat.zero
    let isShown: Bool
    let dismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        // 넓은 화면은 가운데 대화상자, 좁은 화면은 아래에서 올라오는 시트
        let isDialog = horizontalSizeClass == .regular

        GeometryReader { proxy in
            ZStack(alignment: isDialog ? .center : .bottom) {
                if isShown {
                    Color.dimming
                        .ignoresSafeArea()
                        .overlay { dismissArea }
                        .transition(.opacity)

                    if isDialog {
                        dialog(in: proxy)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                    } else {
                        bottomSheet(in: proxy)
                            .transition(.move(edge: .bottom))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            SheetSideSafeArea(isIgnored: !isDialog) { width in
                verticalBarWidth = width
            }
        }
        .onPreferenceChange(SheetDetentKey.self) { detent = $0 }
        .onPreferenceChange(SheetDismissDisabledKey.self) { isDismissDisabled = $0 }
        .onPreferenceChange(SheetGrabberHiddenKey.self) { isGrabberHidden = $0 }
    }

    private func dialog(in proxy: GeometryProxy) -> some View {
        let margin = CGFloat(16)
        let maxHeight = min(proxy.size.height - margin * 2, 600)

        return content
            // 시스템 시트처럼 내용은 좁은 화면 배치로 그림
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.usesPaneLayout, false)
            .frame(width: min(520, proxy.size.width - margin * 2), height: height(of: detent, in: maxHeight))
            .background(Color.secondaryBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.dialog))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.dialog)
                    .strokeBorder(Color.separator)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.12), radius: 30, y: 24)
    }

    private func bottomSheet(in proxy: GeometryProxy) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: CornerRadius.sheet, topTrailingRadius: CornerRadius.sheet)
        let insets = proxy.safeAreaInsets
        // 시트 내용의 deviceType 재정의와 상관없이 세로 막대 위쪽의 시각·카메라 표시 아래까지만 올림
        // 옆 안전 영역을 지우기 전 첫 화면에서도 세로 막대를 알도록 지금 안전 영역도 함께 확인
        let topMargin = 0 < max(verticalBarWidth, insets.leading, insets.trailing) ? CGFloat(160) : 10

        return content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 아래 안전 영역까지 시트 바탕을 깔고, 내용은 안전 영역 위에 둠
            .safeAreaPadding(.bottom, insets.bottom)
            .overlay(alignment: .top) {
                grabber
            }
            .frame(height: height(of: detent, in: proxy.size.height - topMargin) + insets.bottom)
            .background(Color.secondaryBackground)
            .clipShape(shape)
            .overlay {
                // 위쪽 테두리만 보이도록 양옆과 아래 선은 화면 밖으로 밀어냄
                shape
                    .strokeBorder(Color.separator)
                    .padding([.horizontal, .bottom], -1)
            }
            .gesture(
                SheetDragGesture(isEnabled: !isDismissDisabled) { translation in
                    guard !isDismissDisabled else { return }
                    dragOffset = max(translation, 0)
                } onEnded: { translation, predictedTranslation in
                    // 끄는 도중 닫기가 막히면 닫지 않고 제자리로 돌림
                    if !isDismissDisabled, 80 < max(translation, predictedTranslation) {
                        dismiss()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                        }
                    }
                }
            )
            .offset(y: dragOffset)
            .ignoresSafeArea(edges: .bottom)
    }

    private var dismissArea: some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture {
                if !isDismissDisabled {
                    dismiss()
                }
            }
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.sheetGrabber)
            .frame(width: 36, height: 5)
            .opacity(isGrabberHidden ? 0 : 1)
            .padding(.top, 6)
            .frame(width: 120, height: 20, alignment: .top)
    }

    private func height(of detent: SheetDetent, in maxHeight: CGFloat) -> CGFloat {
        switch detent {
        case .large:
            maxHeight
        case .height(let height):
            min(height, maxHeight)
        case .fraction(let fraction):
            maxHeight * fraction
        }
    }
}

// 옆 안전 영역은 Duo 세로 막대 자리
// 아래 시트는 세로 막대 위쪽 표시 아래에서 시작하므로 시트 안 UIKit 화면까지 옆 안전 영역 없이 꽉 채움
private struct SheetSideSafeArea: UIViewControllerRepresentable {
    let isIgnored: Bool
    let onVerticalBarWidthChange: (CGFloat) -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.isIgnored = isIgnored
        controller.onVerticalBarWidthChange = onVerticalBarWidthChange
        controller.apply()
    }

    final class Controller: UIViewController {
        var isIgnored = false
        var onVerticalBarWidthChange: ((CGFloat) -> Void)?
        private var verticalBarWidth: CGFloat?
        private var isOverridden = false
        private var displayLink: CADisplayLink?
        private var isVisible = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            isVisible = true
            apply()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            isVisible = false
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc func apply() {
            // 시트를 띄운 표시 컨트롤러는 이 컨트롤러의 가장 바깥 부모
            guard let window = view.window,
                  let host = sequence(first: self, next: \.parent).reduce(nil, { $1 }),
                  host !== self else { return }
            let insets = window.safeAreaInsets
            let width = max(insets.left, insets.right)
            if width != verticalBarWidth {
                verticalBarWidth = width
                // 레이아웃 중 상태 변경 방지
                DispatchQueue.main.async { [onVerticalBarWidthChange] in
                    onVerticalBarWidthChange?(width)
                }
            }
            // 옆 안전 영역이 없고 지운 적도 없으면 확인할 것이 없어 화면마다 하던 확인도 멈춤
            guard isOverridden || 0 < width else {
                displayLink?.invalidate()
                displayLink = nil
                return
            }
            // 시트 안에서 새로 밀어 넣은 화면도 반영하도록 옆 안전 영역이 있는 동안 화면을 그릴 때마다 확인
            if isVisible && displayLink == nil {
                displayLink = CADisplayLink(target: self, selector: #selector(apply))
                displayLink?.add(to: .main, forMode: .common)
            }
            // 시트 안 화면은 부모와 따로 창 기준 옆 안전 영역을 받으므로 컨트롤러마다 남은 만큼 지움
            var controllers = [host]
            while let controller = controllers.popLast() {
                controllers += controller.children
                guard let controllerView = controller.viewIfLoaded else { continue }
                let safeArea = controllerView.safeAreaInsets
                let additional = controller.additionalSafeAreaInsets
                let left = isIgnored ? additional.left - safeArea.left : 0
                let right = isIgnored ? additional.right - safeArea.right : 0
                if additional.left != left || additional.right != right {
                    controller.additionalSafeAreaInsets.left = left
                    controller.additionalSafeAreaInsets.right = right
                }
            }
            isOverridden = isIgnored
        }
    }
}

// 시스템 시트처럼 손잡이뿐 아니라 내용을 아래로 끌어도 시트를 내림
// 스크롤 내용은 맨 위에 있을 때만 시트를 끌고, 그 밖의 끌기는 내용에 맡김
private struct SheetDragGesture: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: nil).y

        switch recognizer.state {
        case .began, .changed:
            // 시트를 끄는 동안 스크롤 내용이 같이 당겨지지 않게 맨 위에 고정
            if 0 < translation, let scrollView = context.coordinator.scrollView {
                scrollView.contentOffset.y = -scrollView.adjustedContentInset.top
            }
            onChanged(translation)
        case .ended:
            // 손을 뗀 뒤 스크롤처럼 감속해 멈출 위치까지 더함
            let rate = UIScrollView.DecelerationRate.normal.rawValue
            let velocity = recognizer.velocity(in: nil).y
            onEnded(translation, translation + velocity / 1000 * rate / (1 - rate))
        case .cancelled, .failed:
            // 시스템이 끌기를 취소하면 닫지 않고 제자리로 돌림
            onEnded(0, 0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = true
        weak var scrollView: UIScrollView?

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled,
                  let recognizer = recognizer as? UIPanGestureRecognizer,
                  let view = recognizer.view
            else { return false }

            let translation = recognizer.translation(in: view)
            guard abs(translation.x) < translation.y else { return false }

            // 끌기를 시작한 자리 아래의 스크롤 내용을 찾음
            let location = recognizer.location(in: view)
            let startLocation = CGPoint(x: location.x - translation.x, y: location.y - translation.y)
            // 목록 순서 바꾸기 손잡이처럼 직접 끄는 컨트롤은 시트를 끌지 않음
            guard let hitView = view.hitTest(startLocation, with: nil), !(hitView is UIControl) else { return false }

            scrollView = sequence(first: hitView, next: \.superview)
                .lazy
                .compactMap { $0 as? UIScrollView }
                .first { $0.alwaysBounceVertical || $0.bounds.height < $0.contentSize.height }
            guard let scrollView else { return true }
            return scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top
        }

        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // 스크롤 끌기와는 함께 받고, 목록 순서 바꾸기 같은 다른 끌기와는 겹치지 않음
            !(other is UIPanGestureRecognizer) || other === (other.view as? UIScrollView)?.panGestureRecognizer
        }
    }
}
