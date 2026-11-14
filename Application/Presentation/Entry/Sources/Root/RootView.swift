//
//  RootView.swift
//  Entry
//
//  Created by opfic on 5/2/25.
//

import SwiftUI
import Combine
import PresentationShared

public struct RootView: View {
    @State private var store: StoreOf<Feature>
    private let widgetURLRoute: (URL) -> WidgetRoute?
    private let windowEvent: TodoEditorWindowEvent
    private let pushNotificationTodoIdPublisher: AnyPublisher<String, Never>
    private let clearPushNotificationRoute: () -> Void

    public init(
        widgetURLRoute: @escaping (URL) -> WidgetRoute?,
        windowEvent: TodoEditorWindowEvent,
        pushNotificationTodoIdPublisher: AnyPublisher<String, Never>,
        clearPushNotificationRoute: @escaping () -> Void
    ) {
        self._store = State(initialValue: Store(initialState: Feature.State()) {
            Feature()
        })
        self.widgetURLRoute = widgetURLRoute
        self.windowEvent = windowEvent
        self.pushNotificationTodoIdPublisher = pushNotificationTodoIdPublisher
        self.clearPushNotificationRoute = clearPushNotificationRoute
    }

    public var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if let signIn = store.signIn {
                if signIn {
                    MainView(
                        windowEvent: windowEvent,
                        selectedTab: $store.selectedMainTab
                    )
                } else {
                    LoginView()
                }
            }
        }
        .preferredColorScheme(store.theme.colorScheme)
        .onAppear { store.send(.onAppear) }
        .onOpenURL { url in
            guard let route = widgetURLRoute(url) else { return }
            store.send(.openWidgetRoute(route))
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .prominentSheet(item: $store.scope(state: \.sheet, action: \.sheet)) { sheetStore in
            sheetContent(todoId: sheetStore.todoId)
        }
        .onReceive(pushNotificationTodoIdPublisher) { todoId in
            store.send(.presentTodoDetail(todoId))
            clearPushNotificationRoute()
        }
    }

    private func sheetContent(todoId: String) -> some View {
        NavigationStack {
            TodoDetailView(store: Store(
                initialState: TodoDetailFeature.State(todoId: todoId, showEditButton: false)
            ) {
                TodoDetailFeature()
            })
        }
        .environment(\.deviceType, .bar)
        .background(Color.background)
    }
}
