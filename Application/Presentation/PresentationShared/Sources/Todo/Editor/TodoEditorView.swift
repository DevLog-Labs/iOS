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
    @Environment(\.usesPaneLayout) private var usesPaneLayout
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
        // 목록 옆 칸에서 작성하는 넓은 창은 칸 제목 줄에 저장 버튼 표시
        if usesPaneLayout {
            paneContent
        } else {
            coverContent
        }
    }

    private var paneContent: some View {
        EditorForm(store: store, field: _field)
            .safeAreaInset(edge: .top, spacing: 0) {
                PaneTitleBar(Text(store.navigationTitle), onClose: close) {
                    PaneEditorActions(store: store, onSubmit: submit)
                }
            }
            .background(Color.background.ignoresSafeArea())
            .preference(key: PaneDetailEditingPreferenceKey.self, value: true)
            .onAppear { store.send(.onAppear) }
            .onChange(of: store.saveResult) { _, result in
                handleSaveResult(result)
            }
            .prominentAlert(store, state: \.alert, action: \.alert)
            // 사이드바가 있는 창은 작성 중인 속성을 세부 정보 사이드바에 표시
            .detailSideBar {
                ScrollView {
                    TodoSideBarProperties(
                        editorStore: store,
                        isEditable: true,
                        isDueDatePickerPresented: $store.isDueDatePickerPresented
                    )
                }
            }
            // 본문에서 연 Todo는 가운데 대화상자로 표시
            .prominentSheet(
                isPresented: $store.isInspectorPresented.hiddenInPane(store.inspectorContent == .options)
            ) {
                EditorInspector(store: store, isWideLayout: false)
                    .environment(\.windowControlsInset, 0)
            }
    }

    private var coverContent: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                VStack(spacing: 8) {
                    ToolBar(
                        store: store,
                        isWideLayout: isWideLayout,
                        onClose: close,
                        onSubmit: submit
                    )
                    EditorForm(store: store, field: _field)
                }
            }
            .onAppear { store.send(.onAppear) }
            .onChange(of: store.saveResult) { _, result in
                handleSaveResult(result)
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .prominentAlert(store, state: \.alert, action: \.alert)
            .inspector(isPresented: isWideLayout ? $store.isInspectorPresented : .constant(false)) {
                EditorInspector(store: store, isWideLayout: isWideLayout)
                    .environment(\.windowControlsInset, 0)
                    .inspectorColumnWidth(min: 320, ideal: 420, max: 520)
            }
            // 좁은 화면의 세부 정보는 시스템 시트 대신 직접 그린 시트로 표시
            .prominentSheet(isPresented: isWideLayout ? .constant(false) : $store.isInspectorPresented) {
                EditorInspector(store: store, isWideLayout: isWideLayout)
                    .environment(\.windowControlsInset, 0)
            }
        }
        .environment(\.windowControlsInset, store.windowControlsInset)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.windowControlsInset
        } action: { inset in
            store.send(.binding(.set(\.windowControlsInset, inset)))
        }
    }

    private var isWideLayout: Bool {
        // Duo는 펼쳐도 좁은 화면처럼 세부 정보를 시트로 표시
        isiOSAppOnMac || horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
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

// 제목, 작성·미리보기 전환, 본문 입력
private struct EditorForm: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.readableContentWidth) private var readableContentWidth
    let store: StoreOf<TodoEditorFeature>
    @FocusState var field: Field?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                // Mac은 Orca 데스크톱 작성 칸처럼 간격을 좁히고 칸 좌우 여백 14로 표시
                VStack(spacing: isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 8) {
                    // Mac은 글자 폭만큼 작은 작성·미리보기 버튼을 제목 아래 왼쪽에 표시
                    VStack(alignment: .leading, spacing: isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12) {
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
                .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                .frame(maxWidth: readableContentWidth)
                .frame(maxWidth: .infinity)
            }
            .contentMargins(.vertical, isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 16, for: .scrollContent)
        }
    }
}

// 칸 제목 줄의 저장 버튼
private struct PaneEditorActions: View {
    let store: StoreOf<TodoEditorFeature>
    let onSubmit: () -> Void

    var body: some View {
        if store.isLoading {
            ProgressView()
        } else {
            Button(action: onSubmit) {
                Text(String(localized: "todo_manage_save", bundle: PresentationResources.bundle))
                    .font(.adaptive(.body).weight(.semibold))
                    .foregroundStyle(Color.accent)
            }
            .buttonStyle(.plain)
            .disabled(!store.isReadyToSubmit)
            .opacity(store.isReadyToSubmit ? 1 : 0.4)
        }
    }
}

private struct ToolBar: View {
    @ScaledMetric(relativeTo: .title) private var iconSize = UIFont.preferredFont(
        forTextStyle: .title1,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
    ).lineHeight
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
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
                .font(.adaptive(.title3).bold())
            Spacer()
            if showsActions {
                EditorToolbarActions(store: store, onSubmit: onSubmit)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: readableContentWidth)
        .padding(.top, 12 + windowControlsInset)
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
                        .foregroundStyle(Color.label)
                }
                .font(.adaptive(.title))
                .adaptiveButtonStyle(shape: .circle, color: Color.secondaryBackground, glassEffect: .enabled)
            }
            if store.isLoading {
                if #available(iOS 26.0, *) {
                    ProgressView()
                        .topBarProgressStyle()
                } else {
                    ProgressView()
                        .frame(width: iconSize, height: iconSize)
                        .adaptiveButtonStyle(shape: .circle, color: Color.secondaryBackground, glassEffect: .enabled)
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
                .environment(\.deviceType, .bar)
            }
        }
    }
}

private struct TitleField: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
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
            .foregroundStyle(Color.secondaryLabel),
        )
        // 입력칸 바탕 없이 큰 굵은 제목으로 표시
        .font(.system(size: isiOSAppOnMac ? 17 * AdaptiveSize.boardScale : 24, weight: .heavy))
        .focused($field, equals: .title)
    }
}

private struct ModePicker: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesPaneLayout) private var usesPaneLayout
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
        .background(Color.tertiaryBackground, in: RoundedRectangle(cornerRadius: CornerRadius.control))
    }

    @ViewBuilder
    private func modeButton(_ title: String, tab: TodoEditorFeature.EditorTab) -> some View {
        let isSelected = store.tabViewTag == tab
        // 넓은 창은 칸 폭을 채우지 않고 글자 폭만큼 작게 표시
        let isWide = isiOSAppOnMac || usesPaneLayout

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
            // 고른 조각은 강조색 대신 글자색으로 표시하고 넓은 창은 옅은 테두리도 표시
            Text(title)
                .font(.adaptive(isiOSAppOnMac ? .subheadline : .footnote).weight(.semibold))
                .foregroundStyle(isSelected ? Color.label : .secondaryLabel)
                .padding(.horizontal, isWide ? (isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 14) : 0)
                .padding(.vertical, isiOSAppOnMac ? 3 * AdaptiveSize.boardScale : 5)
                .frame(maxWidth: isWide ? nil : .infinity)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.segment)
                            .fill(Color.secondaryBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: CornerRadius.segment)
                                    .strokeBorder(isWide ? Color.label.opacity(0.12) : .clear)
                            }
                            .shadow(color: Color.secondaryLabel.opacity(0.08), radius: 2, y: 2)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct ContentView: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
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
                // 안내 문구를 본문 바로 아래에 표시하고 빈 영역은 바깥 최소 높이로 누를 수 있게 둠
                TextEditorContentLayout(minimumHeight: 0, placesHintBelow: true) {
                    markdownHint
                    UIKitTextEditor
                        .composable(
                            update: { textEditor in
                                // Markdown 본문은 고정폭 글꼴로 표시
                                // 같은 글꼴을 다시 넣어 긴 본문을 갱신마다 다시 배치하지 않도록 다를 때만 지정
                                let font = UIFont.monospacedSystemFont(
                                    ofSize: isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 13.5,
                                    weight: .regular
                                )
                                if textEditor.font != font {
                                    textEditor.font = font
                                }
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
                    .frame(minHeight: minimumHeight, alignment: .topLeading)
                }
            }
        }
        .frame(minHeight: minimumHeight, alignment: .topLeading)
        // 카드 바탕 대신 칸 폭 전체를 가로지르는 구분선 아래에 본문 표시
        .padding(.top, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
        .overlay(alignment: .top) {
            // 본문 폭이 읽기 폭으로 줄어도 가운데 정렬된 본문 위에서 스크롤 칸 폭만큼 표시
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)
                .containerRelativeFrame(.horizontal)
        }
        .contentShape(.rect)
    }

    private var markdownHint: some View {
        Text(String(localized: "todo_editor_markdown_hint", bundle: PresentationResources.bundle))
            .font(.adaptive(.caption))
            .foregroundStyle(Color.secondaryLabel)
    }

    private var previewPlaceholder: some View {
        VStack(spacing: 8) {
            Text(String(localized: "todo_editor_markdown_preview_title", bundle: PresentationResources.bundle))
                .font(.adaptive(.headline))
            Text(String(localized: "todo_editor_markdown_preview_message", bundle: PresentationResources.bundle))
                .font(.adaptive(.subheadline))
                .foregroundStyle(Color.secondaryLabel)
        }
        .multilineTextAlignment(.center)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .center)
    }
}

private enum Field: Hashable {
    case title, content
}
