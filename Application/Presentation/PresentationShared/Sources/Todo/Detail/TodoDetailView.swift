//
//  TodoDetailView.swift
//  PresentationShared
//
//  Created by opfic on 6/12/25.
//

import SwiftUI
import Combine
import ComposableArchitecture
import Core
import Domain

public struct TodoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isTabContentActive) private var isTabContentActive
    @Environment(\.openWindow) private var openWindow
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.deviceType) private var deviceType
    @State var store: StoreOf<TodoDetailFeature>
    private let windowEvent: TodoEditorWindowEvent?
    private let onBack: (() -> Void)?

    public init(
        store: StoreOf<TodoDetailFeature>,
        windowEvent: TodoEditorWindowEvent? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.store = store
        self.windowEvent = windowEvent
        self.onBack = onBack
    }

    public var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if let todo = store.todo {
                TodoDetailContentView(
                    title: todo.title,
                    content: todo.content,
                    referenceItems: store.referenceItems,
                    number: todo.number,
                    showsTitle: !showsPaneTitleBar,
                    onOpenTodoID: { store.send(.setSheet(.todo(TodoIdItem(id: $0)))) }
                )
            } else if store.isLoading {
                LoadingView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if deviceType != .duo {
                topBar
            }
        }
        .duoToolbarVisibility()
        .toolbar {
            if deviceType == .duo {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // 접힌 뒤 펼칠 때 레일 아이콘이 사라지는 현상 방지
                    Group {
                        Button {
                            store.send(.setSheet(.info))
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        if store.showEditButton {
                            Button {
                                openTodoEditor()
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    .id(windowControlsInset)
                }
            }
        }
        .onAppear { store.send(.onAppear) }
        .onReceive(windowSubmits) { submit in
            guard case .update(let value, let todo) = submit,
                  value.matchesEdit(todoId: store.todoId) else { return }
            store.send(.setTodo(todo))
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .sheet(
            item: $store.scope(state: \.sheet, action: \.sheet)
                .activePresentation(when: isTabContentActive)
        ) { store in
            sheetContent(store)
        }
        .fullScreenCover(
            item: $store.scope(state: \.fullScreenCover, action: \.fullScreenCover)
                .activePresentation(when: isTabContentActive)
        ) { store in
            fullScreenCoverContent(store)
        }
    }

    private var windowSubmits: AnyPublisher<TodoEditorWindowSubmit, Never> {
        windowEvent?.submits ?? Empty().eraseToAnyPublisher()
    }

    @ViewBuilder
    private var topBar: some View {
        if showsPaneTitleBar {
            PaneTitleBar {
                if let todo = store.todo {
                    HStack(spacing: 8) {
                        Text(todo.title)
                        Text(verbatim: "#\(todo.number)")
                            .foregroundStyle(Color.tertiaryLabel)
                    }
                }
            } actions: {
                infoButton
                if store.showEditButton {
                    editButton
                }
            }
        } else {
            HStack(spacing: 12) {
                NavigationBackButton {
                    if let onBack {
                        onBack()
                    } else {
                        dismiss()
                    }
                }
                Spacer()
                infoButton
                if store.showEditButton {
                    editButton
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.top, windowControlsInset)
            .background(Color.background, ignoresSafeAreaEdges: .top)
        }
    }

    @ViewBuilder
    private var infoButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                store.send(.setSheet(.info))
            } label: {
                Image(systemName: "info.circle")
            }
            .topBarButtonStyle()
        } else {
            Button {
                store.send(.setSheet(.info))
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .adaptiveButtonStyle(shape: .circle, color: .secondaryBackground, glassEffect: .enabled)
        }
    }

    @ViewBuilder
    private var editButton: some View {
        Button {
            openTodoEditor()
        } label: {
            if #available(iOS 26.0, *) {
                Image(systemName: "pencil")
            } else {
                Text(String(localized: "todo_edit", bundle: PresentationResources.bundle))
                    .foregroundStyle(Color.accent)
            }
        }
        .topBarButtonStyle()
    }

    private func openTodoEditor() {
        if isiOSAppOnMac {
            guard let todo = store.todo else { return }
            openWindow(
                id: TodoEditorWindowValue.sceneId,
                value: TodoEditorWindowValue(todo: todo)
            )
        } else {
            store.send(.setFullScreenCover(.editor))
        }
    }

    @ViewBuilder
    private func fullScreenCoverContent(
        _ coverStore: Store<TodoDetailFeature.FullScreenCoverState, TodoDetailFeature.Action.FullScreenCover>
    ) -> some View {
        switch coverStore.destination {
        case .editor:
            if let todoEditorStore = coverStore.scope(state: \.todoEditor, action: \.todoEditor) {
                TodoEditorView(store: todoEditorStore)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(
        _ sheetStore: Store<TodoDetailFeature.SheetState, TodoDetailFeature.Action.Sheet>
    ) -> some View {
        switch sheetStore.state {
        case .info:
            if let todo = store.todo {
                InfoSheetView(todo: todo) {
                    sheetStore.send(.tapCloseButton)
                }
            }
        case .todo:
            NavigationStack {
                if let todoStore = sheetStore.scope(state: \.todoDetail, action: \.todo) {
                    TodoDetailView(store: todoStore)
                }
            }
            .environment(\.windowControlsInset, 0)
            .environment(\.deviceType, .bar)
            .environment(\.showsPaneTitleBar, false)
            .background(Color.background)
            .presentationDragIndicator(.visible)
        }
    }
}

private struct InfoSheetView: View {
    let todo: Todo
    let onClose: () -> Void
    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 0) {
                    optionRow(
                        systemImage: "tag.fill",
                        color: Color.accent,
                        title: String(localized: "todo_category", bundle: PresentationResources.bundle)
                    ) {
                        Text(TodoCategoryItem(from: todo.category).localizedName)
                            .foregroundStyle(Color.accent)
                            .lineLimit(1)
                    }

                    Divider().overlay(Color.separator)

                    optionRow(
                        systemImage: "circle",
                        color: Color.secondaryLabel,
                        title: String(localized: "todo_completed", bundle: PresentationResources.bundle)
                    ) {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(todo.isCompleted ? Color.accent : Color.tertiaryLabel)
                    }

                    Divider().overlay(Color.separator)

                    optionRow(
                        systemImage: "star.fill",
                        color: Color.orange,
                        title: String(localized: "todo_pinned", bundle: PresentationResources.bundle)
                    ) {
                        Image(systemName: todo.isPinned ? "star.fill" : "star")
                            .foregroundStyle(todo.isPinned ? Color.orange : Color.tertiaryLabel)
                    }

                    Divider().overlay(Color.separator)

                    optionRow(
                        systemImage: "calendar",
                        color: Color.secondaryLabel,
                        title: String(localized: "todo_due_date", bundle: PresentationResources.bundle)
                    ) {
                        if let dueDate = todo.dueDate {
                            Tag(dueDateText(for: dueDate), isEditing: false)
                        } else {
                            Text(String(localized: "todo_none", bundle: PresentationResources.bundle))
                                .foregroundStyle(Color.secondaryLabel)
                        }
                    }
                }
                .background(Color.secondaryBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.group))

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "todo_tags", bundle: PresentationResources.bundle))
                        .font(.headline)
                        .padding(.horizontal, 16)

                    Group {
                        if todo.tags.isEmpty {
                            Text(String(localized: "todo_no_tags", bundle: PresentationResources.bundle))
                                .foregroundStyle(Color.secondaryLabel)
                        } else {
                            TagList(todo.tags, verticalSpacing: 4, horizontalSpacing: 4)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondaryBackground)
                    .clipShape(.rect(cornerRadius: CornerRadius.group))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    private var topBar: some View {
        ZStack {
            Text(String(localized: "todo_details", bundle: PresentationResources.bundle))
                .font(.headline)
            HStack {
                Button {
                    onClose()
                } label: {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "xmark")
                    } else {
                        Text(String(localized: "common_close", bundle: PresentationResources.bundle))
                    }
                }
                .topBarButtonStyle()
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    private func optionRow<Trailing: View>(
        systemImage: String,
        color: Color,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.headline)
                .layoutPriority(1)

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func dueDateText(for dueDate: Date) -> String {
        let currentYear = calendar.component(.year, from: Date())
        let dueDateYear = calendar.component(.year, from: dueDate)

        if currentYear == dueDateYear {
            return dueDate.formatted(
                .dateTime.month(.defaultDigits).day(.defaultDigits)
            )
        }

        return dueDate.formatted(
            .dateTime.year(.twoDigits).month(.defaultDigits).day(.defaultDigits)
        )
    }
}
