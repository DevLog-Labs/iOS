//
//  PreviewModifier.swift
//  PresentationShared
//
//  Created by opfic on 8/11/26.
//

import SwiftUI
import ComposableArchitecture
import Domain

public extension View {
    func todoDetailPreview(todoId: String) -> some View {
        modifier(PreviewModifier(todoId: todoId))
    }
}

private struct PreviewModifier: ViewModifier {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let todoId: String

    @ViewBuilder
    func body(content: Content) -> some View {
        // Mac 우클릭 메뉴는 미리보기를 표시하지 않아 행의 우클릭 메뉴를 가리지 않도록 제외
        if isiOSAppOnMac {
            content
        } else {
            content.overlay {
                PreviewInteractionView(
                    todoId: todoId,
                    makePreview: makePreviewViewController
                )
            }
        }
    }

    private func makePreviewViewController() -> UIViewController {
        let store = Store(
            initialState: TodoDetailFeature.State(
                todoId: todoId,
                showEditButton: false
            )
        ) {
            TodoDetailFeature()
        }
        return UIHostingController(rootView: PreviewView(store: store))
    }
}

private struct PreviewInteractionView: UIViewRepresentable {
    let todoId: String
    let makePreview: () -> UIViewController

    func makeCoordinator() -> PreviewInteractionCoordinator {
        PreviewInteractionCoordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        context.coordinator.update(todoId: todoId, makePreview: makePreview)
        context.coordinator.install(on: view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.update(todoId: todoId, makePreview: makePreview)
    }
}

private final class PreviewInteractionCoordinator: NSObject {
    private weak var view: UIView?
    private var contextMenuInteraction: UIContextMenuInteraction?
    private var todoId = ""
    private var makePreview: (() -> UIViewController)?

    func update(
        todoId: String,
        makePreview: @escaping () -> UIViewController
    ) {
        self.todoId = todoId
        self.makePreview = makePreview
    }

    func install(on view: UIView) {
        guard self.view !== view else { return }

        if let contextMenuInteraction {
            self.view?.removeInteraction(contextMenuInteraction)
        }

        let contextMenuInteraction = UIContextMenuInteraction(delegate: self)
        view.addInteraction(contextMenuInteraction)
        self.view = view
        self.contextMenuInteraction = contextMenuInteraction
    }
}

extension PreviewInteractionCoordinator: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let makePreview else { return nil }

        let preferredContentSize = preferredContentSize(for: interaction.view)
        return UIContextMenuConfiguration(
            identifier: todoId as NSString,
            previewProvider: {
                let viewController = makePreview()
                viewController.preferredContentSize = preferredContentSize
                return viewController
            },
            actionProvider: nil
        )
    }

    // 미리보기가 표시될 때 원본 행에 기본 배경색이 적용되는 현상 방지
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configuration: UIContextMenuConfiguration,
        highlightPreviewForItemWithIdentifier identifier: any NSCopying
    ) -> UITargetedPreview? {
        targetedPreview()
    }

    // 미리보기가 닫힐 때 원본 행에 기본 배경색이 적용되는 현상 방지
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configuration: UIContextMenuConfiguration,
        dismissalPreviewForItemWithIdentifier identifier: any NSCopying
    ) -> UITargetedPreview? {
        targetedPreview()
    }

    // iOS 18 이하에서 투명한 원본 뷰의 기본 전환 배경이 흰색으로 표시되는 현상 방지
    private func targetedPreview() -> UITargetedPreview? {
        guard let view else { return nil }

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.shadowPath = UIBezierPath()

        return UITargetedPreview(
            view: view,
            parameters: parameters
        )
    }

    private func preferredContentSize(for view: UIView?) -> CGSize {
        let bounds = view?.window?.bounds ?? view?.bounds ?? .zero
        let width = min(420, max(280, bounds.width - 32))
        let height = min(640, max(320, bounds.height * 0.7))
        return CGSize(width: width, height: height)
    }
}
