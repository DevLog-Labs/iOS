//
//  TodoDetailSideBarView.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI
import Combine
import ComposableArchitecture

// 세부 정보 사이드바의 Todo 속성 칸
public struct TodoDetailSideBarView: View {
    @State private var store: StoreOf<TodoDetailSideBarFeature>
    private let windowEvent: TodoEditorWindowEvent?

    public init(
        todoId: String,
        isEditable: Bool,
        windowEvent: TodoEditorWindowEvent?
    ) {
        self._store = State(initialValue: Store(
            initialState: TodoDetailSideBarFeature.State(todoId: todoId, isEditable: isEditable)
        ) {
            TodoDetailSideBarFeature()
        })
        self.windowEvent = windowEvent
    }

    public var body: some View {
        ZStack(alignment: .top) {
            if let editorStore = store.scope(state: \.editor, action: \.editor) {
                ScrollView {
                    TodoSideBarProperties(store: store, editorStore: editorStore)
                }
                .onChange(of: editorStore.saveResult) { _, result in
                    // 저장한 Todo를 목록과 상세 칸에도 반영
                    guard case .updated(let todo) = result else { return }
                    windowEvent?.submitUpdate(value: TodoEditorWindowValue(todo: todo), todo: todo)
                }
                .prominentAlert(editorStore, state: \.alert, action: \.alert)
            } else if store.isFetchFailed {
                DetailSideBarPlaceholder()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { store.send(.onAppear) }
        .onReceive(windowSubmits) { submit in
            // 이 사이드바가 저장해 보낸 Todo는 입력 중인 값을 덮지 않도록 다시 받지 않음
            guard case .update(let value, let todo) = submit,
                  value.matchesEdit(todoId: store.todoId),
                  store.editor?.saveResult != .updated(todo) else { return }
            store.send(.setTodo(todo))
        }
    }

    private var windowSubmits: AnyPublisher<TodoEditorWindowSubmit, Never> {
        windowEvent?.submits ?? Empty().eraseToAnyPublisher()
    }
}

// Mac은 Mac 화면 크기, iPad는 손가락으로 누르는 크기
private struct TodoSideBarProperties: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: StoreOf<TodoDetailSideBarFeature>
    @Bindable var editorStore: StoreOf<TodoEditorFeature>

    var body: some View {
        let isEditable = store.isEditable

        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                PropertyRow(String(localized: "todo_category", bundle: PresentationResources.bundle)) {
                    if isEditable {
                        DropdownMenu(
                            alignment: .trailing,
                            sections: [
                                DropdownMenuSection(items: editorStore.categories.map { category in
                                    DropdownMenuItem(
                                        category.localizedName,
                                        systemImage: category.symbolName,
                                        imageColor: category.color,
                                        isChecked: editorStore.selectedCategoryID == category.id
                                    ) {
                                        editorStore.send(.binding(.set(\.selectedCategoryID, category.id)))
                                    }
                                })
                            ]
                        ) {
                            categoryLabel(showsChevron: true)
                        }
                    } else {
                        categoryLabel(showsChevron: false)
                    }
                }
                Divider().overlay(Color.separator)
                PropertyRow(String(localized: "todo_completed", bundle: PresentationResources.bundle)) {
                    if isEditable {
                        Toggle(isOn: $editorStore.isCompleted) { EmptyView() }
                            .toggleStyle(.pill)
                            .labelsHidden()
                    } else {
                        Image(systemName: editorStore.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(editorStore.isCompleted ? Color.accent : .secondaryLabel)
                    }
                }
                Divider().overlay(Color.separator)
                PropertyRow(String(localized: "todo_pinned", bundle: PresentationResources.bundle)) {
                    if isEditable {
                        Toggle(isOn: $editorStore.isPinned) { EmptyView() }
                            .toggleStyle(.pill)
                            .labelsHidden()
                    } else {
                        Image(systemName: editorStore.isPinned ? "star.fill" : "star")
                            .foregroundStyle(Color.accent)
                    }
                }
                Divider().overlay(Color.separator)
                PropertyRow(String(localized: "todo_due_date", bundle: PresentationResources.bundle)) {
                    if isEditable {
                        Button {
                            store.send(.binding(.set(\.isDueDatePickerPresented, true)))
                        } label: {
                            dueDateLabel
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $store.isDueDatePickerPresented) {
                            DueDatePopover(store: editorStore)
                        }
                    } else {
                        dueDateLabel
                    }
                }
            }
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
            .padding(.horizontal, 14 * AdaptiveSize.boardScale)
            .padding(.vertical, 8 * AdaptiveSize.boardScale)

            VStack(alignment: .leading, spacing: 6 * AdaptiveSize.boardScale) {
                Text(String(localized: "todo_tags", bundle: PresentationResources.bundle))
                    .font(.adaptive(isiOSAppOnMac ? .subheadline : .footnote))
                    .foregroundStyle(Color.secondaryLabel)
                if isEditable {
                    TagField(store: editorStore)
                    if !editorStore.tags.isEmpty {
                        TagList(
                            editorStore.tags,
                            isEditing: true,
                            verticalSpacing: 6 * AdaptiveSize.boardScale,
                            horizontalSpacing: 6 * AdaptiveSize.boardScale,
                            action: { editorStore.send(.removeTag($0)) }
                        )
                        .padding(.top, 4 * AdaptiveSize.boardScale)
                    }
                } else if editorStore.tags.isEmpty {
                    Text(String(localized: "todo_no_tags", bundle: PresentationResources.bundle))
                        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                        .foregroundStyle(Color.secondaryLabel)
                } else {
                    TagList(
                        editorStore.tags,
                        verticalSpacing: 6 * AdaptiveSize.boardScale,
                        horizontalSpacing: 6 * AdaptiveSize.boardScale
                    )
                }
            }
            .padding(.horizontal, 14 * AdaptiveSize.boardScale)
            .padding(.vertical, 4 * AdaptiveSize.boardScale)
        }
    }

    private func categoryLabel(showsChevron: Bool) -> some View {
        let category = editorStore.category

        return HStack(spacing: 6 * AdaptiveSize.boardScale) {
            Text(category.localizedName)
                .foregroundStyle(Color.secondaryLabel)
                .lineLimit(1)
            Image(systemName: category.symbolName)
                .foregroundStyle(category.color)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.adaptive(.caption).weight(.semibold))
                    .foregroundStyle(Color.secondaryLabel)
            }
        }
        .contentShape(.rect)
    }

    @ViewBuilder
    private var dueDateLabel: some View {
        if let dueDate = editorStore.dueDate {
            let calendar = Calendar.autoupdatingCurrent
            // 마감일이 지난 Todo는 위험 색으로 표시
            let color = calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: Date())
                ? Color.danger : .secondaryLabel

            Text(dueDate.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated)))
                .font(.adaptive(isiOSAppOnMac ? .caption2 : .caption).weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 6 * AdaptiveSize.boardScale)
                .frame(height: isiOSAppOnMac ? 18.5 * AdaptiveSize.boardScale : 20)
                .background(color.opacity(0.13), in: .rect(cornerRadius: CornerRadius.badge))
        } else {
            Text(String(localized: "todo_none", bundle: PresentationResources.bundle))
                .foregroundStyle(Color.secondaryLabel)
        }
    }
}

// 카드 안 속성 한 줄
private struct PropertyRow<Value: View>: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    private let title: String
    private let value: Value

    init(_ title: String, @ViewBuilder value: () -> Value) {
        self.title = title
        self.value = value()
    }

    var body: some View {
        HStack(spacing: 10 * AdaptiveSize.boardScale) {
            Text(title)
                .lineLimit(1)
                .padding(.vertical, 6 * AdaptiveSize.boardScale)
            Spacer(minLength: 0)
            value
        }
        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
        .padding(.horizontal, 12 * AdaptiveSize.boardScale)
        .frame(minHeight: isiOSAppOnMac ? 38 * AdaptiveSize.boardScale : 44)
    }
}

private struct TagField: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: StoreOf<TodoEditorFeature>
    @FocusState private var isFocused: Bool

    var body: some View {
        let tag = store.tagText.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSubmit = !tag.isEmpty && !store.tags.contains(tag)

        HStack(spacing: 8 * AdaptiveSize.boardScale) {
            TextField(
                String(localized: "todo_tag_add", bundle: PresentationResources.bundle),
                text: $store.tagText
            )
            .textInputAutocapitalization(.never)
            .focused($isFocused)
            .onSubmit { submit(tag, canSubmit: canSubmit) }
            Button {
                submit(tag, canSubmit: canSubmit)
            } label: {
                Image(systemName: "plus")
                    .font(.adaptive(.title3))
                    .foregroundStyle(canSubmit ? Color.accent : .secondaryLabel)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
        .tint(Color.accent)
        .padding(.horizontal, 12 * AdaptiveSize.boardScale)
        .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : 44)
        .inputBackground(isFocused: isFocused)
    }

    private func submit(_ tag: String, canSubmit: Bool) {
        guard canSubmit else { return }
        store.send(.addTag(tag))
        store.send(.binding(.set(\.tagText, "")))
    }
}

private struct DueDatePopover: View {
    @Bindable var store: StoreOf<TodoEditorFeature>

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            DatePicker(
                "",
                selection: $store.selectedDueDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.graphical)
            .tint(Color.accent)
            if store.dueDate != nil {
                Button {
                    store.send(.binding(.set(\.dueDate, nil)))
                } label: {
                    Text(String(localized: "todo_none", bundle: PresentationResources.bundle))
                }
                .foregroundStyle(Color.danger)
            }
        }
        .padding(12)
    }
}
