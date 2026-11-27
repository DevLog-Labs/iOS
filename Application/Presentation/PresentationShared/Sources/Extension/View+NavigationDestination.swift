//
//  View+NavigationDestination.swift
//  PresentationShared
//
//  Created by opfic on 9/25/26.
//

import SwiftUI
import SwiftUINavigation
import UIComposable

public extension View {
    func navigationDestination<Item, Destination: View>(
        item: Binding<Item?>,
        interactivePop: Bool,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        modifier(ItemNavigationDestination(item: item, interactivePop: interactivePop, destination: destination))
    }

    func navigationDestination<Destination: View>(
        isPresented: Binding<Bool>,
        interactivePop: Bool,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        navigationDestination(isPresented: isPresented) {
            destination()
                .modifier(
                    NavigationPopGesture(isEnabled: interactivePop) {
                        guard isPresented.wrappedValue else { return }
                        isPresented.wrappedValue = false
                    }
                )
        }
    }

    func navigationDestination<Item: Hashable, Destination: View>(
        for type: Item.Type,
        interactivePop: @escaping (Item) -> Bool,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        navigationDestination(for: type) { value in
            destination(value)
                .modifier(NavigationPopGesture(isEnabled: interactivePop(value)))
        }
    }

    // 사이드바가 있는 창에서 쌓는 화면을 밀리는 효과 없이 내용만 바꿈
    // NavigationStack에 두어 경로를 바꾸는 곳과 상관없이 적용
    func desktopNavigationTransition() -> some View {
        modifier(DesktopNavigationTransition())
    }
}

// 상태로 여는 화면은 NavigationStack에 건 설정이 닿지 않아 바인딩에 전환 설정을 실음
private struct ItemNavigationDestination<Item, Destination: View>: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let item: Binding<Item?>
    let interactivePop: Bool
    @ViewBuilder let destination: (Item) -> Destination

    func body(content: Content) -> some View {
        let transaction = {
            var transaction = Transaction()
            transaction.disablesAnimations = usesDesktopLayout
            return transaction
        }()

        content
            .navigationDestination(item: item.transaction(transaction)) { value in
                destination(value)
                    .modifier(
                        NavigationPopGesture(isEnabled: interactivePop) {
                            guard item.wrappedValue != nil else { return }
                            item.wrappedValue = nil
                        }
                    )
            }
    }
}

private struct DesktopNavigationTransition: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout

    func body(content: Content) -> some View {
        content
            .transaction { transaction in
                if usesDesktopLayout {
                    transaction.disablesAnimations = true
                }
            }
    }
}

private struct NavigationPopGesture: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let isEnabled: Bool
    var onCompleted: () -> Void = { }

    func body(content: Content) -> some View {
        content
            .background {
                if isEnabled {
                    NavigationPopGestureController
                        .composable { controller in
                            controller.onInteractivePopCompleted = onCompleted
                            controller.popsImmediately = usesDesktopLayout
                        }
                }
            }
    }
}

@MainActor
private final class NavigationPopGestureController: UIViewController, UICoordinatedComposable {
    var onInteractivePopCompleted: () -> Void = { }
    // 사이드바가 있는 창은 밀어서 따라오는 화면 없이 바로 이전 화면으로 돌아감
    var popsImmediately = false
    private weak var coordinator: Coordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        coordinator?.configure(navigationController)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        coordinator?.configure(navigationController)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: onInteractivePopCompleted)
    }

    func connect(coordinator: Coordinator) {
        self.coordinator = coordinator
        coordinator.owner = self
    }

    func update(coordinator: Coordinator) {
        coordinator.completion = onInteractivePopCompleted
        coordinator.popsImmediately = popsImmediately
        coordinator.configure(navigationController)
    }

    func disconnect(coordinator: Coordinator) {
        self.coordinator = nil
        coordinator.restore()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var recognizer: UIGestureRecognizer?
        // 화면 가장자리가 아닌 곳에서 밀어도 이전 화면으로 돌아가는 제스처
        private weak var contentRecognizer: UIGestureRecognizer?
        private weak var controller: UINavigationController?
        private weak var delegate: (any UIGestureRecognizerDelegate)?
        private weak var contentDelegate: (any UIGestureRecognizerDelegate)?
        private var isObserving = false
        weak var owner: UIViewController?
        var completion: () -> Void
        var popsImmediately = false

        init(completion: @escaping () -> Void) {
            self.completion = completion
        }

        func configure(_ controller: UINavigationController?) {
            guard let controller,
                  let gesture = controller.interactivePopGestureRecognizer else { return }

            // 시스템 막대를 숨긴 화면은 시스템이 이 제스처도 막아 가장자리 제스처와 함께 넘겨받음
            var content: UIGestureRecognizer?
            if #available(iOS 26.0, *) {
                content = controller.interactiveContentPopGestureRecognizer
            }

            if recognizer !== gesture || contentRecognizer !== content {
                restore()
                recognizer = gesture
                delegate = gesture.delegate
                gesture.addTarget(self, action: #selector(handlePopGesture(_:)))
                contentRecognizer = content
                contentDelegate = content?.delegate
                content?.addTarget(self, action: #selector(handlePopGesture(_:)))
            }

            self.controller = controller
            gesture.delegate = self
            gesture.isEnabled = 1 < controller.viewControllers.count
            content?.delegate = self
        }

        func restore() {
            if let recognizer {
                recognizer.removeTarget(self, action: #selector(handlePopGesture(_:)))
                if recognizer.delegate === self {
                    recognizer.delegate = delegate
                }
            }
            if let contentRecognizer {
                contentRecognizer.removeTarget(self, action: #selector(handlePopGesture(_:)))
                if contentRecognizer.delegate === self {
                    contentRecognizer.delegate = contentDelegate
                }
            }
            recognizer = nil
            contentRecognizer = nil
            controller = nil
            delegate = nil
            contentDelegate = nil
            isObserving = false
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let controller,
                  1 < controller.viewControllers.count,
                  controller.transitionCoordinator == nil else { return false }
            guard !popsImmediately else {
                // 사이드바가 있는 창은 화면 가장자리에서 밀 때만 바로 돌아감
                guard recognizer !== contentRecognizer else { return false }
                controller.popViewController(animated: false)
                completion()
                return false
            }
            return true
        }

        @objc
        private func handlePopGesture(_ recognizer: UIGestureRecognizer) {
            // 같은 내비게이션에 쌓인 아래 화면도 이 제스처를 받으므로 닫히는 화면의 처리기만 반응
            guard recognizer.state == .changed,
                  !isObserving,
                  let owner,
                  let transition = controller?.transitionCoordinator,
                  let from = transition.viewController(forKey: .from),
                  owner.viewIfLoaded?.isDescendant(of: from.view) == true else {
                return
            }

            isObserving = true
            transition.notifyWhenInteractionChanges { context in
                self.isObserving = false
                guard !context.isCancelled else { return }
                self.completion()
            }
        }
    }
}
