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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Environment(\.deviceType) private var deviceType
    @Environment(\.isInDetailPanel) private var isInDetailPanel
    @State var store: StoreOf<TodoDetailFeature>
    private let windowEvent: TodoEditorWindowEvent?
    private let onBack: (() -> Void)?
    // 목록 옆 칸에 넣은 상세는 뒤로 갈 곳이 없어 칸 제목 줄의 뒤로 버튼 생략
    private let isPaneDetail: Bool
    // 사이드바에서 고를 수 없는 화면에서 연 상세는 사이드바가 있는 창에서도 뒤로 버튼 표시
    private let showsBackOnDesktop: Bool
    // Mac 목록 옆 칸에 붙인 상세를 닫는 동작
    private let onClose: (() -> Void)?

    public init(
        store: StoreOf<TodoDetailFeature>,
        windowEvent: TodoEditorWindowEvent? = nil,
        onBack: (() -> Void)? = nil,
        isPaneDetail: Bool = false,
        showsBackOnDesktop: Bool = false,
        onClose: (() -> Void)? = nil
    ) {
        self.store = store
        self.windowEvent = windowEvent
        self.onBack = onBack
        self.isPaneDetail = isPaneDetail
        self.showsBackOnDesktop = showsBackOnDesktop
        self.onClose = onClose
    }

    public var body: some View {
        // 칸으로 나눈 화면은 편집 화면을 덮는 화면 대신 상세 칸 자리에 표시
        let editsInPane = usesPaneLayout && showsPaneTitleBar

        detailContent(editsInPane: editsInPane)
            .onAppear { store.send(.onAppear) }
            // 좁은 창으로 바뀌어도 편집 화면이 닫히지 않도록 상세 칸을 남겨 두게 알림
            .preference(key: PaneDetailPresentingPreferenceKey.self, value: store.fullScreenCover != nil)
            // 편집 화면에서 저장하면 창 폭과 상관없이 Mac 편집 창과 같은 경로로 옆 목록에도 전달
            // 편집 화면이 닫히며 놓치지 않도록 상세 상태에 남긴 저장 결과로 전달
            .onChange(of: store.savedTodo) { _, todo in
                guard let todo else { return }
                windowEvent?.submitUpdate(value: TodoEditorWindowValue(todo: todo), todo: todo)
            }
            .onReceive(windowSubmits) { submit in
                guard case .update(let value, let todo) = submit,
                      value.matchesEdit(todoId: store.todoId) else { return }
                store.send(.setTodo(todo))
            }
            .prominentAlert(store, state: \.alert, action: \.alert)
            .prominentSheet(
                item: $store.scope(state: \.sheet, action: \.sheet)
                    .activePresentation(when: isTabContentActive)
            ) { store in
                sheetContent(store)
            }
            .fullScreenCover(
                item: $store.scope(state: \.fullScreenCover, action: \.fullScreenCover)
                    .activePresentation(when: isTabContentActive)
                    .hiddenInPane(editsInPane)
            ) { store in
                fullScreenCoverContent(store)
            }
    }

    private func detailContent(editsInPane: Bool) -> some View {
        ZStack {
            Color.background.ignoresSafeArea()
            if let todo = store.todo {
                TodoDetailContentView(
                    todo: todo,
                    referenceItems: store.referenceItems,
                    // 사이드바가 있는 iPad 창의 칸 제목 줄은 Todo 제목을 표시하므로 본문 제목 생략
                    showsTitle: !(showsPaneTitleBar && !isiOSAppOnMac),
                    onOpenTodoID: { store.send(.setSheet(.todo(TodoIdItem(id: $0)))) }
                )
            } else if store.isLoading {
                LoadingView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // 상세 판은 판 위쪽 막대를 쓰므로 상세 위쪽 줄 생략
            if !isInDetailPanel && deviceType != .duo {
                topBar
            }
        }
        .overlay {
            if editsInPane,
               let editorStore = store.scope(
                state: \.fullScreenCover?.todoEditor,
                action: \.fullScreenCover.presented.todoEditor
               ) {
                TodoEditorView(store: editorStore, onClose: { store.send(.fullScreenCover(.dismiss)) })
            }
        }
        .duoToolbarVisibility(showsBackButton: true)
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
                                store.send(.setFullScreenCover(.editor))
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    .id(windowControlsInset)
                }
                .sharedBackgroundHidden()
            }
        }
    }

    private var windowSubmits: AnyPublisher<TodoEditorWindowSubmit, Never> {
        windowEvent?.submits ?? Empty().eraseToAnyPublisher()
    }

    @ViewBuilder
    private var topBar: some View {
        if showsPaneTitleBar {
            // Mac 칸 제목 줄은 디자인대로 Todo 제목 대신 "Todo" 표시
            let showsTodoTitle = !isiOSAppOnMac

            // 일반 화면에서 밀어 넣은 상세가 칸 화면으로 바뀌어도 뒤로 갈 수 있게 뒤로 버튼 표시
            PaneTitleBar(onBack: isPaneDetail ? nil : back, showsBackOnDesktop: showsBackOnDesktop) {
                if showsTodoTitle, let todo = store.todo {
                    HStack(spacing: 8) {
                        Text(todo.title)
                        Text(verbatim: "#\(todo.number)")
                            .foregroundStyle(Color.tertiaryLabel)
                    }
                } else if !showsTodoTitle {
                    Text(verbatim: "Todo")
                }
            } actions: {
                // Mac은 창 오른쪽 세부 정보 사이드바에 속성을 표시하므로 정보 버튼 생략
                if !isiOSAppOnMac {
                    infoButton
                }
                if store.showEditButton {
                    editButton
                }
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .topBarButtonStyle()
                }
            }
        } else {
            // 검색 위쪽 줄과 같은 높이 48, 가로 여백 8, 붙은 아이콘 버튼과 아래 구분선
            ZStack {
                Text(verbatim: "Todo")
                    .font(.adaptive(.callout).bold())
                HStack(spacing: 0) {
                    NavigationBackButton(action: back)
                    Spacer()
                    infoButton
                    if store.showEditButton {
                        editButton
                    }
                }
            }
            .frame(height: 48)
            .padding(.horizontal, 8)
            .overlay(alignment: .bottom) {
                Divider().overlay(Color.secondarySeparator)
            }
            .padding(.top, windowControlsInset)
            .background(Color.background, ignoresSafeAreaEdges: .top)
        }
    }

    private func back() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    private var infoButton: some View {
        Button {
            store.send(.setSheet(.info))
        } label: {
            Image(systemName: "info.circle")
        }
        .topBarButtonStyle()
    }

    private var editButton: some View {
        Button {
            store.send(.setFullScreenCover(.editor))
        } label: {
            Image(systemName: "pencil")
        }
        .topBarButtonStyle()
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
            // 넓은 창의 세부 정보 사이드바와 같은 속성 칸, 고친 값은 바로 저장
            InfoSheetView(
                store: store.scope(state: \.info, action: \.info),
                onClose: { sheetStore.send(.tapCloseButton) }
            )
        case .todo:
            NavigationStack {
                if let todoStore = sheetStore.scope(state: \.todoDetail, action: \.todo) {
                    TodoDetailView(store: todoStore)
                }
            }
            .environment(\.windowControlsInset, 0)
            .environment(\.deviceType, .bar)
            .environment(\.showsPaneTitleBar, false)
            // 상세 판에서 연 참조 Todo도 자기 위쪽 줄 표시
            .environment(\.isInDetailPanel, false)
            .background(Color.background)
        }
    }
}

// 좁은 창의 세부 정보 시트, 상세 화면과 오늘 탭이 함께 사용
public struct InfoSheetView: View {
    let store: StoreOf<TodoDetailSideBarFeature>
    let onClose: () -> Void

    public init(store: StoreOf<TodoDetailSideBarFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        // 저장 결과는 시트를 연 화면의 상태가 받아 목록에 전달
        TodoDetailSideBarView(store: store, windowEvent: nil)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    store.send(.binding(.set(\.sheetBarHeight, $0)))
                }
        }
        .background(Color.secondaryBackground.ignoresSafeArea())
        .onPreferenceChange(TodoInfoHeightPreferenceKey.self) { height in
            store.send(.binding(.set(\.sheetContentHeight, height)))
        }
        // 속성을 불러오기 전에는 시트 높이를 바꾸지 않음
        .sheetDetent(
            store.sheetContentHeight == 0 ? .large : .height(store.sheetBarHeight + store.sheetContentHeight)
        )
    }

    // OS와 상관없이 같은 모양인 글자 닫기 버튼과 가운데 제목, 아래 구분선
    private var topBar: some View {
        ZStack {
            Text(String(localized: "todo_details", bundle: PresentationResources.bundle))
                .font(.adaptive(.callout).bold())
            HStack {
                Button {
                    onClose()
                } label: {
                    Text(String(localized: "common_close", bundle: PresentationResources.bundle))
                        .font(.adaptive(.callout).weight(.medium))
                        .foregroundStyle(Color.label)
                        .padding(.horizontal, 4)
                        .frame(maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.secondarySeparator)
        }
        // 손잡이 아래부터 위쪽 줄을 둠
        .padding(.top, 11)
        .background(Color.secondaryBackground, ignoresSafeAreaEdges: .top)
    }
}
