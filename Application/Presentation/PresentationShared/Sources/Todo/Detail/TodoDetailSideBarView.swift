//
//  TodoDetailSideBarView.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI
import Combine
import ComposableArchitecture
import Domain

// 세부 정보 사이드바와 좁은 창 세부 정보 시트의 Todo 속성 칸
public struct TodoDetailSideBarView: View {
    @State private var store: StoreOf<TodoDetailSideBarFeature>
    private let windowEvent: TodoEditorWindowEvent?
    // 저장한 Todo를 시트를 연 상세 화면에도 반영하는 동작
    private let onUpdate: ((Todo) -> Void)?

    public init(
        todoId: String,
        isEditable: Bool,
        windowEvent: TodoEditorWindowEvent?,
        onUpdate: ((Todo) -> Void)? = nil
    ) {
        self._store = State(initialValue: Store(
            initialState: TodoDetailSideBarFeature.State(todoId: todoId, isEditable: isEditable)
        ) {
            TodoDetailSideBarFeature()
        })
        self.windowEvent = windowEvent
        self.onUpdate = onUpdate
    }

    // 상세 판처럼 바깥 화면이 속성 상태를 함께 쓰는 세부 정보 열
    init(
        store: StoreOf<TodoDetailSideBarFeature>,
        windowEvent: TodoEditorWindowEvent?,
        onUpdate: ((Todo) -> Void)? = nil
    ) {
        self._store = State(initialValue: store)
        self.windowEvent = windowEvent
        self.onUpdate = onUpdate
    }

    public var body: some View {
        ZStack(alignment: .top) {
            if let editorStore = store.scope(state: \.editor, action: \.editor) {
                ScrollView {
                    TodoInfoProperties(
                        editorStore: editorStore,
                        isEditable: store.isEditable,
                        isDueDatePickerPresented: $store.isDueDatePickerPresented
                    )
                    // 좁은 창의 세부 정보 시트가 속성 칸 높이만큼 열리도록 알림
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: TodoInfoHeightPreferenceKey.self, value: geometry.size.height)
                        }
                    }
                }
                .onChange(of: editorStore.saveResult) { _, result in
                    // 저장한 Todo를 목록과 상세 칸에도 반영
                    guard case .updated(let todo) = result else { return }
                    windowEvent?.submitUpdate(value: TodoEditorWindowValue(todo: todo), todo: todo)
                    onUpdate?(todo)
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

struct TodoInfoHeightPreferenceKey: PreferenceKey {
    static let defaultValue = CGFloat.zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// 저장한 Todo의 세부 정보, 고친 값은 바로 저장
// 완료와 중요 표시는 표시 아이콘을 눌러 바꾸고, 태그는 보기만 함
private struct TodoInfoProperties: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var editorStore: StoreOf<TodoEditorFeature>
    let isEditable: Bool
    @Binding var isDueDatePickerPresented: Bool

    var body: some View {
        let category = editorStore.category
        let glyphSize = isiOSAppOnMac ? 15 * AdaptiveSize.boardScale : 18

        VStack(spacing: 0) {
            PropertyRow(String(localized: "todo_category", bundle: PresentationResources.bundle)) {
                let label = HStack(spacing: 10 * AdaptiveSize.boardScale) {
                    Text(category.localizedName)
                        .foregroundStyle(Color.secondaryLabel)
                        .lineLimit(1)
                    Image(systemName: category.symbolName)
                        .font(.system(size: isiOSAppOnMac ? 12.5 * AdaptiveSize.boardScale : 14))
                        .foregroundStyle(category.color)
                }
                .contentShape(.rect)

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
                        label
                    }
                } else {
                    label
                }
            }
            Divider().overlay(Color.separator)
            PropertyRow(String(localized: "todo_completed", bundle: PresentationResources.bundle)) {
                Button {
                    editorStore.send(.binding(.set(\.isCompleted, !editorStore.isCompleted)))
                } label: {
                    Image(systemName: editorStore.isCompleted ? "checkmark.circle" : "circle")
                        .resizable()
                        .fontWeight(.medium)
                        .frame(width: glyphSize, height: glyphSize)
                        .foregroundStyle(editorStore.isCompleted ? Color.accent : .secondaryLabel)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
            }
            Divider().overlay(Color.separator)
            PropertyRow(String(localized: "todo_pinned", bundle: PresentationResources.bundle)) {
                Button {
                    editorStore.send(.binding(.set(\.isPinned, !editorStore.isPinned)))
                } label: {
                    Image(systemName: editorStore.isPinned ? "star.fill" : "star")
                        .resizable()
                        .fontWeight(.medium)
                        .frame(width: glyphSize, height: glyphSize)
                        .foregroundStyle(editorStore.isPinned ? Color.accent : .secondaryLabel)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
            }
            Divider().overlay(Color.separator)
            PropertyRow(String(localized: "todo_due_date", bundle: PresentationResources.bundle)) {
                Button {
                    isDueDatePickerPresented = true
                } label: {
                    if let dueDate = editorStore.dueDate {
                        TodoDueDateBadge(dueDate: dueDate)
                    } else {
                        Text(String(localized: "todo_none", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.secondaryLabel)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
                .dueDatePicker(isPresented: $isDueDatePickerPresented, store: editorStore)
            }
            Divider().overlay(Color.separator)
            PropertyRow(String(localized: "todo_tags", bundle: PresentationResources.bundle)) {
                if editorStore.tags.isEmpty {
                    Text(String(localized: "todo_none", bundle: PresentationResources.bundle))
                        .foregroundStyle(Color.secondaryLabel)
                } else {
                    TagList(
                        editorStore.tags,
                        verticalSpacing: 6 * AdaptiveSize.boardScale,
                        horizontalSpacing: 6 * AdaptiveSize.boardScale,
                        alignsTrailing: true
                    )
                    .padding(.vertical, 6 * AdaptiveSize.boardScale)
                }
            }
        }
        .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
    }
}

// Mac은 Mac 화면 크기, iPad는 손가락으로 누르는 크기
// 작성 중인 Todo의 속성, 작성 화면의 저장 버튼으로 함께 저장
struct TodoSideBarProperties: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var editorStore: StoreOf<TodoEditorFeature>
    let isEditable: Bool
    @Binding var isDueDatePickerPresented: Bool

    var body: some View {
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
                            isDueDatePickerPresented = true
                        } label: {
                            dueDateLabel
                        }
                        .buttonStyle(.plain)
                        .dueDatePicker(isPresented: $isDueDatePickerPresented, store: editorStore)
                    } else {
                        dueDateLabel
                    }
                }
            }
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)

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
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.vertical, isiOSAppOnMac ? 4 * AdaptiveSize.boardScale : 8)
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
                Image(systemName: "chevron.right")
                    .font(.system(size: isiOSAppOnMac ? 11 * AdaptiveSize.boardScale : 14, weight: .medium))
                    .foregroundStyle(Color.secondaryLabel)
            }
        }
        .contentShape(.rect)
    }

    @ViewBuilder
    private var dueDateLabel: some View {
        if let dueDate = editorStore.dueDate {
            TodoDueDateBadge(dueDate: dueDate)
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
                .padding(.vertical, isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 10)
            Spacer(minLength: 0)
            value
        }
        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
        .padding(.horizontal, 12 * AdaptiveSize.boardScale)
        .frame(minHeight: isiOSAppOnMac ? 38 * AdaptiveSize.boardScale : 50)
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

private extension View {
    func dueDatePicker(isPresented: Binding<Bool>, store: StoreOf<TodoEditorFeature>) -> some View {
        modifier(DueDatePickerModifier(isPresented: isPresented, store: store))
    }
}

// 넓은 창은 팝오버, 좁은 창은 달력 높이만큼 여는 시트로 마감일 달력 표시
private struct DueDatePickerModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isTabContentActive) private var isTabContentActive
    @State private var height = CGFloat.zero
    @Binding var isPresented: Bool
    let store: StoreOf<TodoEditorFeature>

    func body(content: Content) -> some View {
        let isRegular = horizontalSizeClass == .regular

        content
            .popover(isPresented: isRegular ? $isPresented : .constant(false)) {
                DueDatePopover(store: store)
            }
            .prominentSheet(
                isPresented: (isRegular ? Binding.constant(false) : $isPresented).activePresentation(when: isTabContentActive)
            ) {
                DueDatePopover(store: store)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                    .sheetDetent(height == 0 ? .large : .height(height))
            }
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
