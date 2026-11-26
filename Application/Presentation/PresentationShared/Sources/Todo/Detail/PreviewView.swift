//
//  PreviewView.swift
//  PresentationShared
//
//  Created by opfic on 8/11/26.
//

import SwiftUI
import ComposableArchitecture

struct PreviewView: View {
    @State var store: StoreOf<TodoDetailFeature>

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if let todo = store.todo {
                TodoDetailContentView(
                    todo: todo,
                    referenceItems: store.referenceItems,
                    onOpenTodoID: nil
                )
            } else if store.alert != nil {
                EmptyStateView(
                    String(localized: "common_error_title", bundle: PresentationResources.bundle),
                    systemImage: "exclamationmark.triangle",
                    message: String(localized: "common_error_message", bundle: PresentationResources.bundle)
                )
            } else {
                LoadingView()
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}
