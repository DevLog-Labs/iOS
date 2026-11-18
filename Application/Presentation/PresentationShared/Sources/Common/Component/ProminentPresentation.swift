//
//  ProminentPresentation.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI
import UIComposable

// 탭 바·사이드바까지 화면 전체를 덮는 표시 자리
struct ProminentPresentation<Item: Identifiable, Overlay: View>: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @State private var isCovered = false
    @State private var isShown = false
    @State private var presented: Item?
    let item: Binding<Item?>
    @ViewBuilder let overlay: (Item, Bool, @escaping () -> Void) -> Overlay

    func body(content: Content) -> some View {
        // 넓은 iPad·Mac 화면은 커지거나 올라오는 효과 없이 내용만 바꿈
        // 사이드바 구조 밖에서 띄우는 표시는 가운데 대화상자와 같은 기준으로 판단
        let isAnimated = !usesDesktopLayout
            && !(horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad)

        content
            .onChange(of: item.wrappedValue?.id, initial: true) { _, id in
                if id == nil {
                    hide(isAnimated: isAnimated)
                } else {
                    show()
                }
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { isCovered },
                    set: { isPresented in
                        // 내용 안에서 dismiss를 부르면 표시 상태도 함께 닫음, 표시 상태가 먼저 닫혀 내리는 중이면 그대로 둠
                        if !isPresented && isCovered {
                            item.wrappedValue = nil
                        }
                    }
                ),
                onDismiss: {
                    if item.wrappedValue == nil {
                        presented = nil
                    }
                }
            ) {
                ZStack {
                    if let shown = item.wrappedValue ?? presented {
                        overlay(shown, isShown) {
                            item.wrappedValue = nil
                        }
                    }
                }
                .presentationBackground(.clear)
                // 내용 안에서 dismiss로 닫을 때도 시스템 덮개가 내려가는 효과 없이 닫힘
                .background {
                    CoverDismissTransition.composable { controller in
                        controller.isAnimated = isAnimated
                    }
                }
                .onAppear {
                    withAnimation(isAnimated ? .easeOut(duration: 0.2) : nil) {
                        isShown = true
                    }
                }
            }
    }

    private func show() {
        presented = item.wrappedValue
        guard !isCovered else { return }
        // 시스템 전체 화면 표시 애니메이션 없이 덮고, 나타나는 모양은 직접 그림
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isCovered = true
        }
    }

    // 다음 표시가 시스템 표시 순서를 기다리도록 닫힘은 바로 시작
    private func hide(isAnimated: Bool) {
        guard isCovered else { return }
        withAnimation(isAnimated ? .easeIn(duration: 0.2) : nil) {
            isShown = false
        }
        guard !isAnimated else {
            isCovered = false
            return
        }
        // 효과 없이 닫으면 비어 있는 덮개도 바로 걷어 뒤 화면을 바로 누를 수 있게 함
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isCovered = false
        }
    }
}

// 덮개를 띄운 컨트롤러에 닫힘 전환 효과를 정함
private final class CoverDismissTransition: UIViewController, UIComposable, UIViewControllerTransitioningDelegate {
    var isAnimated = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        // 덮개로 띄운 화면은 이 컨트롤러의 가장 바깥 부모
        let cover = sequence(first: self, next: \.parent).reduce(self) { $1 }
        guard cover !== self, cover.presentingViewController != nil else { return }
        cover.transitioningDelegate = self
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        isAnimated ? nil : ImmediateDismissTransition()
    }
}

private final class ImmediateDismissTransition: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using context: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0
    }

    func animateTransition(using context: any UIViewControllerContextTransitioning) {
        // 덮개 아래에서 빠져 있던 화면이 있으면 제자리에 되돌림
        if let toController = context.viewController(forKey: .to),
           let toView = context.view(forKey: .to) {
            toView.frame = context.finalFrame(for: toController)
            context.containerView.insertSubview(toView, at: 0)
        }
        context.view(forKey: .from)?.removeFromSuperview()
        context.completeTransition(!context.transitionWasCancelled)
    }
}
