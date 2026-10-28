//
//  TodoEditorView.swift
//  PresentationShared
//
//  Created by opfic on 5/31/25.
//

import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct TodoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isTabContentActive) private var isTabContentActive
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @State var store: StoreOf<TodoEditorFeature>
    @FocusState private var field: Field?
    private let calendar = Calendar.current
    var onCreateSuccess: (() -> Void)?
    var onUpdateSuccess: ((Todo) -> Void)?
    var onClose: (() -> Void)?

    public init(
        store: StoreOf<TodoEditorFeature>,
        onCreateSuccess: (() -> Void)? = nil,
        onUpdateSuccess: ((Todo) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.store = store
        self.onCreateSuccess = onCreateSuccess
        self.onUpdateSuccess = onUpdateSuccess
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 8) {
                    ToolBar(
                        store: store,
                        isWideLayout: isWideLayout,
                        onClose: close,
                        onSubmit: submit
                    )
                    GeometryReader { geometry in
                        ScrollView {
                            VStack(spacing: 16) {
                                VStack(alignment: .trailing, spacing: 16) {
                                    TitleField(store: store, field: _field)
                                    ModePicker(store: store, field: _field)
                                }
                                .onGeometryChange(for: CGFloat.self) { proxy in
                                    proxy.size.height
                                } action: { height in
                                    store.send(.binding(.set(\.editorHeaderHeight, height)))
                                }
                                ContentView(
                                    store: store,
                                    field: _field,
                                    height: geometry.size.height
                                )
                                .onTapGesture {
                                    field = .content
                                }
                            }
                            .padding(.horizontal)
                        }
                        .contentMargins(.vertical, 16, for: .scrollContent)
                    }
                }
            }
            .onAppear { store.send(.onAppear) }
            .onChange(of: store.saveResult) { _, result in
                handleSaveResult(result)
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .prominentAlert(store, state: \.alert, action: \.alert)
            .inspector(isPresented: $store.isInspectorPresented) {
                EditorInspector(store: store, isWideLayout: isWideLayout)
                    .inspectorColumnWidth(min: 320, ideal: 420, max: 520)
                    .presentationDetents([.large])
            }
        }
    }

    private var isWideLayout: Bool {
        isiOSAppOnMac || horizontalSizeClass == .regular
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func submit() {
        store.send(.upsertTodo)
    }

    private func handleSaveResult(_ result: TodoEditorFeature.SaveResult?) {
        switch result {
        case .created:
            onCreateSuccess?()
        case .updated(let todo):
            onUpdateSuccess?(todo)
        case .none:
            break
        }
    }
}

private struct ToolBar: View {
    @ScaledMetric(relativeTo: .title) private var iconSize = UIFont.preferredFont(
        forTextStyle: .title1,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
    ).lineHeight
    let store: StoreOf<TodoEditorFeature>
    let isWideLayout: Bool
    let onClose: () -> Void
    let onSubmit: () -> Void

    private var showsActions: Bool {
        !(store.isInspectorPresented && isWideLayout)
    }

    var body: some View {
        HStack {
            if #available(iOS 26.0, *) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .topBarButtonStyle(tint: showsActions ? nil : Color.accent)
            } else {
                Button {
                    onClose()
                } label: {
                    Text(String(localized: "common_close", bundle: PresentationResources.bundle))
                }
                .topBarButtonStyle(tint: showsActions ? nil : Color.accent)
            }
            Spacer()
            Text(store.navigationTitle)
                .font(.title3.bold())
            Spacer()
            if showsActions {
                EditorToolbarActions(store: store, onSubmit: onSubmit)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
}

struct EditorToolbarActions: View {
    @ScaledMetric(relativeTo: .title) private var iconSize = UIFont.preferredFont(
        forTextStyle: .title1,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
    ).lineHeight
    let store: StoreOf<TodoEditorFeature>
    let onSubmit: () -> Void

    var body: some View {
        HStack {
            if #available(iOS 26.0, *) {
                Button {
                    store.send(.showInspector(.options))
                } label: {
                    Image(systemName: "info.circle")
                }
                .topBarButtonStyle()
            } else {
                Button {
                    store.send(.showInspector(.options))
                } label: {
                    Image(systemName: "info.circle")
                        .frame(width: iconSize, height: iconSize)
                        .foregroundStyle(Color.primary)
                }
                .font(.title)
                .adaptiveButtonStyle(shape: .circle, color: Color.surface, glassEffect: .enabled)
            }
            if store.isLoading {
                if #available(iOS 26.0, *) {
                    ProgressView()
                        .topBarProgressStyle()
                } else {
                    ProgressView()
                        .frame(width: iconSize, height: iconSize)
                        .adaptiveButtonStyle(shape: .circle, color: Color.surface, glassEffect: .enabled)
                }
            } else {
                if #available(iOS 26.0, *) {
                    Button {
                        onSubmit()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .topBarButtonStyle(
                        tint: store.isReadyToSubmit ? Color.accent : nil
                    )
                    .disabled(!store.isReadyToSubmit)
                    .opacity(store.isReadyToSubmit ? 1 : 0.4)
                } else {
                    Button {
                        onSubmit()
                    } label: {
                        Text(String(localized: "todo_manage_save", bundle: PresentationResources.bundle))
                    }
                    .topBarButtonStyle(
                        tint: store.isReadyToSubmit ? Color.accent : nil
                    )
                    .disabled(!store.isReadyToSubmit)
                    .opacity(store.isReadyToSubmit ? 1 : 0.4)
                }
            }
        }
    }
}

private struct EditorInspector: View {
    let store: StoreOf<TodoEditorFeature>
    let isWideLayout: Bool

    var body: some View {
        Group {
            switch store.inspectorContent {
            case .options:
                TodoPropertiesView(
                    store: store,
                    showsEditorActions: store.isInspectorPresented && isWideLayout,
                    onSubmit: { store.send(.upsertTodo) }
                ) {
                    store.send(.binding(.set(\.isInspectorPresented, false)))
                }
            case .todo(let item):
                NavigationStack {
                    TodoDetailView(
                        store: Store(
                            initialState: TodoDetailFeature.State(todoId: item.id, showEditButton: false)
                        ) {
                            TodoDetailFeature()
                        },
                        onBack: { store.send(.showInspector(.options)) }
                    )
                    .id(item.id)
                }
            }
        }
    }
}

private struct TitleField: View {
    @Bindable var store: StoreOf<TodoEditorFeature>
    @FocusState var field: Field?

    var body: some View {
        TextField(
            "",
            text: $store.title,
            prompt: Text(
                String(
                    localized: "todo_editor_title_required",
                    bundle: PresentationResources.bundle
                )
            )
            .foregroundStyle(Color.secondary),
        )
        .font(.body)
        .focused($field, equals: .title)
        .padding()
        .background(Color.surface, in: .rect(cornerRadius: 16))
    }
}

private struct ModePicker: View {
    @Bindable var store: StoreOf<TodoEditorFeature>
    @FocusState var field: Field?

    var body: some View {
        HStack(spacing: 0) {
            modeButton(
                String(localized: "todo_write", bundle: PresentationResources.bundle),
                tab: .editor
            )
            modeButton(
                String(localized: "todo_preview", bundle: PresentationResources.bundle),
                tab: .preview
            )
        }
        .padding(2)
        .background(Color.border, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func modeButton(_ title: String, tab: TodoEditorFeature.EditorTab) -> some View {
        let isSelected = store.tabViewTag == tab

        Button {
            if tab == .editor {
                store.send(.binding(.set(\.tabViewTag, .editor)))
                field = .content
            } else {
                field = nil
                DispatchQueue.main.async {
                    store.send(.binding(.set(\.tabViewTag, .preview)))
                }
            }
        } label: {
            Text(title)
                .font(.body)
                .foregroundStyle(isSelected ? Color.accent : Color.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.surface)
                            .shadow(color: Color.textSecondary.opacity(0.08), radius: 2, y: 2)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct ContentView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Bindable var store: StoreOf<TodoEditorFeature>
    @FocusState var field: Field?
    let height: CGFloat

    private var minimumHeight: CGFloat {
        max(0, height - store.editorHeaderHeight - 16 - safeAreaInsets.bottom)
    }

    var body: some View {
        let isContentFocused = field == .content
        Group {
            if store.tabViewTag == .editor {
                TextEditorContentLayout(minimumHeight: minimumHeight) {
                    markdownHint
                    UIKitTextEditor
                        .composable(
                            update: { textEditor in
                                textEditor.updateInput(
                                    text: $store.content,
                                    isFocused: isContentFocused,
                                    onFocusChange: { isFocused in
                                        if isFocused {
                                            field = .content
                                        } else if field == .content {
                                            field = nil
                                        }
                                    },
                                    placeholder: String(
                                        localized: "todo_editor_description_optional",
                                        bundle: PresentationResources.bundle
                                    )
                                )
                            },
                            sizeThatFits: { UIKitTextEditor.fittingSize(proposal: $0, textEditor: $1) }
                        )
                        // SwiftUI 포커싱 시스템에 등록하기 위해 사용
                        .focused($field, equals: .content)
                        .padding(12)
                        .background(Color.surface, in: .rect(cornerRadius: 16))
                }
            } else {
                if store.content.isEmpty {
                    previewPlaceholder
                } else {
                    TodoMarkdownContentView(
                        content: store.content,
                        referenceItems: store.referenceItems,
                        isScrollEnabled: false,
                        onOpenTodoID: { store.send(.showInspector(.todo(TodoIdItem(id: $0)))) }
                    )
                    // MarkdownRenderer 내부의 좌우 여백을 상쇄해 입력 본문과 정렬
                    .padding(.horizontal, -16)
                    .padding(12)
                    .frame(minHeight: minimumHeight, alignment: .topLeading)
                    .background(Color.surface, in: .rect(cornerRadius: 16))
                }
            }
        }
        .frame(minHeight: minimumHeight, alignment: .topLeading)
        .contentShape(.rect)
    }

    private var markdownHint: some View {
        Text(String(localized: "todo_editor_markdown_hint", bundle: PresentationResources.bundle))
            .font(.caption)
            .foregroundStyle(Color.textTertiary)
    }

    private var previewPlaceholder: some View {
        VStack(spacing: 8) {
            Text(String(localized: "todo_editor_markdown_preview_title", bundle: PresentationResources.bundle))
                .font(.headline)
            Text(String(localized: "todo_editor_markdown_preview_message", bundle: PresentationResources.bundle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .center)
        .background(Color.surface, in: .rect(cornerRadius: 16))
    }
}

private enum Field: Hashable {
    case title, content
}
