//
//  TodoPropertiesView.swift
//  PresentationShared
//
//  Created by opfic on 9/13/26.
//

import SwiftUI
import ComposableArchitecture
import Core

public struct TodoPropertiesView: View {
    @Bindable var store: StoreOf<TodoEditorFeature>
    var showsEditorActions = false
    var showsCloseButton = false
    var onSubmit: () -> Void = {}
    let onClose: () -> Void

    public init(
        store: StoreOf<TodoEditorFeature>,
        showsEditorActions: Bool = false,
        showsCloseButton: Bool = false,
        onSubmit: @escaping () -> Void = {},
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.showsEditorActions = showsEditorActions
        self.showsCloseButton = showsCloseButton
        self.onSubmit = onSubmit
        self.onClose = onClose
    }

    public var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) { toolBar }
            .background(Color.background.ignoresSafeArea())
    }

    private var toolBar: some View {
        ZStack {
            if !showsEditorActions {
                Text(String(localized: "todo_details", bundle: PresentationResources.bundle))
                    .font(.adaptive(.headline))
            }
            HStack {
                if !showsEditorActions || showsCloseButton {
                    if #available(iOS 26.0, *) {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .topBarButtonStyle()
                    } else {
                        Button {
                            onClose()
                        } label: {
                            // 저장 버튼과 함께 둘 때는 저장 없이 닫는 버튼
                            Text(
                                String(
                                    localized: showsEditorActions ? "common_close" : "common_done",
                                    bundle: PresentationResources.bundle
                                )
                            )
                        }
                        .topBarButtonStyle(tint: showsEditorActions ? nil : Color.accent)
                    }
                }
                Spacer()
                if showsEditorActions {
                    EditorToolbarActions(store: store, onSubmit: onSubmit)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    private var content: some View {
        ScrollView {
            TodoSideBarProperties(
                editorStore: store,
                isDueDatePickerPresented: $store.isDueDatePickerPresented
            )
        }
    }
}
