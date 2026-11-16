//
//  TodoEditorWindowView.swift
//  Entry
//
//  Created by opfic on 5/31/26.
//

import SwiftUI
import Domain
import PresentationShared

public struct TodoEditorWindowView: View {
    @State private var windowScene: UIWindowScene?
    @State private var readableContentWidth = CGFloat.infinity
    private let value: TodoEditorWindowValue
    private let windowEvent: TodoEditorWindowEvent

    public init(
        value: TodoEditorWindowValue,
        windowEvent: TodoEditorWindowEvent
    ) {
        self.value = value
        self.windowEvent = windowEvent
    }

    public var body: some View {
        Group {
            switch value {
            case .create(let windowCategory, _):
                TodoEditorView(
                    store: Store(initialState: TodoEditorFeature.State(category: windowCategory.todoCategory)) {
                        TodoEditorFeature()
                    },
                    onCreateSuccess: create,
                    onClose: closeWindow
                )
            case .edit(let windowTodo):
                TodoEditorView(
                    store: Store(initialState: TodoEditorFeature.State(todo: windowTodo.todo)) {
                        TodoEditorFeature()
                    },
                    onUpdateSuccess: update,
                    onClose: closeWindow
                )
            }
        }
        .environment(\.readableContentWidth, readableContentWidth)
        // 작성 창은 칸이 아니라 창 하나를 채우는 화면이라 속성을 창 안의 정보 버튼으로 표시
        .environment(\.usesPaneLayout, false)
        .background {
            WindowSceneReader { windowScene = $0 }
            ReadableContentWidthReader { readableContentWidth = $0 }
        }
        // 글자 크기를 정하지 않은 글자도 Mac 크기로 표시
        .font(AdaptiveSize.macFontSize(.body).map { .system(size: $0) })
    }

    private func create() {
        windowEvent.submitCreate(value: value)
        closeWindow()
    }

    private func update(_ todo: Todo) {
        windowEvent.submitUpdate(value: value, todo: todo)
        closeWindow()
    }

    private func closeWindow() {
        guard let windowScene else { return }
        UIApplication.shared.requestSceneSessionDestruction(
            windowScene.session,
            options: nil,
            errorHandler: nil
        )
    }
}

private struct WindowSceneReader: UIViewRepresentable {
    let onResolve: (UIWindowScene?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        resolve(from: view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        resolve(from: view)
    }

    private func resolve(from view: UIView) {
        DispatchQueue.main.async {
            onResolve(view.window?.windowScene)
        }
    }
}
