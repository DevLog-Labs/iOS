//
//  HomeView.swift
//  HomeTab
//
//  Created by opfic on 5/7/25.
//

import SwiftUI
import Combine
import Domain
import PresentationShared

public struct HomeView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.deviceType) private var deviceType
    @Environment(\.sideBarRequest) private var sideBarRequest
    @State private var router = NavigationRouter<HomeRoute>()
    @State private var searchStore: StoreOf<SearchFeature>
    @State private var store: StoreOf<HomeFeature>
    private let isSelected: Bool
    private let windowEvent: TodoEditorWindowEvent

    public init(
        isSelected: Bool,
        windowEvent: TodoEditorWindowEvent
    ) {
        @Dependency(\.homeFetchRecentSearchQueriesUseCase) var fetchRecentSearchQueriesUseCase
        self._store = State(initialValue: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        })
        self._searchStore = State(initialValue: Store(
            initialState: SearchFeature.State(
                recentQueries: fetchRecentSearchQueriesUseCase.execute()
            )
        ) {
            SearchFeature()
        })
        self.isSelected = isSelected
        self.windowEvent = windowEvent
    }

    public var body: some View {
        let sideBarLocation: SideBarLocation = if case .goalDetail(let goalID)? = store.sheet {
            .developmentGoal(goalID)
        } else if case .category(let item)? = router.root {
            .todoCategory(item.id)
        } else {
            .home
        }
        // Mac은 카테고리 관리와 새 개발 목표를 시트 대신 칸으로 표시
        let showsSheetAsPane = isiOSAppOnMac
            && (store.sheet?.categoryManageState != nil || store.sheet?.goalCreateState != nil)
        let sheetBinding = $store.scope(state: \.sheet, action: \.sheet)
            .activePresentation(when: isSelected)

        NavigationStack(path: $router.path) {
            Group {
                if isiOSAppOnMac,
                   let manageStore = store.scope(state: \.sheet?.categoryManageState, action: \.sheet.presented.categoryManage) {
                    CategoryManageView(store: manageStore)
                } else if isiOSAppOnMac,
                          let goalStore = store.scope(state: \.sheet?.goalCreateState, action: \.sheet.presented.goalCreate) {
                    // 홈 오른쪽 칸에서 쓰고 연결된 Todo는 세부 정보 사이드바에 표시
                    PaneSplitView {
                        homeContent
                    } detail: {
                        GoalCreateView(store: goalStore) {
                            store.send(.sheet(.dismiss))
                        }
                    }
                    .detailSideBar {
                        GoalCreateSideBarContent(store: goalStore)
                    }
                } else {
                    homeContent
                }
            }
            .navigationDestination(
                for: HomeRoute.self,
                interactivePop: {
                    switch $0 {
                    case .category: true
                    case .todo: true
                    }
                },
                destination: { destinationView($0).environment(\.showsPaneTitleBar, usesDesktopLayout) }
            )
        }
        // 사이드바 구조로 바뀌면 쌓아 연 Todo 상세는 내리고 카테고리 목록 옆 칸에 표시
        .closesPushedDetail {
            router.path.removeAll {
                if case .todo = $0 { return true }
                return false
            }
        }
        .preference(key: SideBarLocationPreferenceKey.self, value: sideBarLocation)
        .preference(
            key: SideBarContentPreferenceKey.self,
            value: SideBarContent(
                todoCategories: store.preferences.filter(\.isVisible),
                developmentGoals: store.developmentGoalItems.map { SideBarGoal(id: $0.id, title: $0.goal.title) }
            )
        )
        // 사이드바 요청으로 처음 여는 탭도 그 요청을 반영
        .onChange(of: sideBarRequest, initial: true) { _, request in
            handleSideBarRequest(request, showsSheetAsPane: showsSheetAsPane)
        }
        // 작성 중인 새 개발 목표를 버린 뒤 미뤄 둔 사이드바 요청 처리
        .onChange(of: store.sideBarRequestAfterGoalDiscard) { _, request in
            handleSideBarRequest(request, showsSheetAsPane: showsSheetAsPane)
        }
        .onAppear {
            store.send(.view(.startObserving))
            // 사이드바가 있으면 홈이 아닌 탭으로 켜져도 사이드바 하위 항목을 채우도록 한 번 불러옴
            if usesDesktopLayout && !isSelected {
                store.send(.view(.fetchData))
            }
        }
        .onChange(of: isSelected, initial: true) { _, isSelected in
            if isSelected {
                store.send(.view(.fetchData))
            }
        }
        .onReceive(windowEvent.submits) { submit in
            guard case .create(let value) = submit,
                  value.matchesCreate(source: .home) else { return }
            store.send(.view(.todoEditorCreated))
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .prominentSheet(
            item: Binding(
                get: { showsSheetAsPane ? nil : sheetBinding.wrappedValue },
                // 앞 시트가 늦게 닫히며 보내는 닫힘이 칸으로 연 화면을 지우지 않도록 지금 상태로 판단
                set: { sheet in
                    guard !isiOSAppOnMac
                        || store.sheet?.categoryManageState == nil && store.sheet?.goalCreateState == nil
                    else { return }
                    sheetBinding.wrappedValue = sheet
                }
            ),
            content: sheetContent
        )
        .fullScreenCover(
            item: $store.scope(state: \.fullScreenCover, action: \.fullScreenCover)
                .activePresentation(when: isSelected),
            content: coverContent
        )
    }

    private func handleSideBarRequest(_ request: SideBarRequest?, showsSheetAsPane: Bool) {
        // 작성 중인 새 개발 목표가 있으면 칸을 닫기 전에 버릴지 물음
        if let request,
           request.action != .createTodo,
           store.sheet?.goalCreateState?.hasDraft == true {
            store.send(.view(.closeGoalCreateForSideBarRequest(request)))
            return
        }
        // 사이드바로 다른 곳을 열면 칸으로 표시하던 화면은 닫음
        if showsSheetAsPane, case .open = request?.action {
            store.send(.store(.setSheet(nil)))
        }
        switch request?.action {
        case .open(.home):
            router.path = []
        case .open(.todoCategory(let id)):
            guard let item = store.preferences.first(where: { $0.id == id }) else { break }
            router.replace(with: .category(item))
        case .open(.developmentGoal(let goalID)):
            store.send(.view(.tapDevelopmentGoal(goalID)))
        case .createTodo:
            // 카테고리 목록이 보이면 그 목록이 자기 작성 버튼과 같은 방식으로 작성
            // 홈 작성 버튼처럼 연결이 끊기면 열지 않음
            guard router.root == nil, store.isNetworkConnected else { break }
            store.send(.store(.setPresentation(.contentPicker, true)))
        case .manageTodoCategory:
            // 카테고리를 불러오기 전 빈 목록으로 저장하지 않도록 무시
            guard !store.preferences.isEmpty else { break }
            // Mac은 카테고리 관리 칸을 홈 루트에 그려 위에 쌓인 목록을 비움
            if isiOSAppOnMac {
                router.path = []
            }
            store.send(.view(.tapManageTodoCategory))
        case .open, nil:
            break
        }
    }

    private var homeContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HomeDevelopmentSummary(store: store)
                HomeTodoSection(store: store)
                HomeDevelopmentGoals(store: store)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // 칸 제목 줄 구분선과 첫 카드 사이 여백
        .contentMargins(.top, usesDesktopLayout ? 12 : 0, for: .scrollContent)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background)
        .duoToolbarVisibility()
        .toolbar {
            if deviceType == .duo {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // 접힌 뒤 펼칠 때 레일 아이콘이 사라지는 현상 방지
                    Group {
                        Button {
                            store.send(.store(.setPresentation(.searchView, true)))
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        Button {
                            store.send(.store(.setPresentation(.contentPicker, true)))
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(!store.isNetworkConnected)
                    }
                    .id(windowControlsInset)
                }
            }
        }
    }

    @ViewBuilder
    private var topBar: some View {
        if usesDesktopLayout {
            PaneTitleBar(Text("nav_home", bundle: PresentationResources.bundle)) {
                searchButton
                HomeCreateButton(store: store)
            }
        } else {
            HStack(spacing: 12) {
                Text("DevLog")
                    .font(.adaptive(.largeTitle).weight(.bold))
                Spacer()
                if deviceType != .duo {
                    searchButton
                    HomeCreateButton(store: store)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: readableContentWidth)
            .padding(.top, windowControlsInset)
            .padding(.bottom, 8)
            .background(Color.background)
            .toolbarBackground(Color.background)
        }
    }

    @ViewBuilder
    private var searchButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                store.send(.store(.setPresentation(.searchView, true)))
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .topBarButtonStyle()
        } else {
            Button {
                store.send(.store(.setPresentation(.searchView, true)))
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.adaptive(.title3).weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .adaptiveButtonStyle(
                shape: .circle,
                color: .secondaryBackground,
                glassEffect: .enabled
            )
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheetStore: Store<HomeFeature.SheetState, HomeFeature.Sheet>) -> some View {
        switch sheetStore.state {
        case .contentPicker:
            HomeContentPicker(store: store, onSelect: openTodoEditor)
        case .reorderTodo:
            if let store = sheetStore.scope(state: \.categoryManageState, action: \.categoryManage) {
                CategoryManageView(store: store)
            }
        case .goalCreate:
            if let goalStore = sheetStore.scope(state: \.goalCreateState, action: \.goalCreate) {
                GoalCreateView(store: goalStore) {
                    store.send(.sheet(.dismiss))
                }
            }
        case .goalDetail(let goalID):
            GoalDetailView(goalId: goalID)
                .environment(\.windowControlsInset, 0)
        }
    }

    @ViewBuilder
    private func coverContent(
        _ coverStore: Store<HomeFeature.FullScreenCoverState, HomeFeature.FullScreenCover>
    ) -> some View {
        switch coverStore.destination {
        case .todoEditor:
            if let todoEditorStore = coverStore.scope(state: \.todoEditor, action: \.todoEditor) {
                TodoEditorView(store: todoEditorStore)
            }
        case .search:
            SearchView(store: searchStore)
                .environment(\.windowControlsInset, store.searchInset)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.windowControlsInset
                } action: { inset in
                    store.send(.binding(.set(\.searchInset, inset)))
                }
        }
    }

    @ViewBuilder
    private func destinationView(_ route: HomeRoute) -> some View {
        switch route {
        case .category(let item):
            TodoListView(
                store: Store(initialState: TodoListFeature.State(category: item.todoCategory)) {
                    TodoListFeature()
                },
                windowEvent: windowEvent,
                onSelectTodo: { router.push(.todo(TodoIdItem(id: $0))) }
            )
            .id(item.id)
        case .todo(let item):
            TodoDetailView(
                store: Store(
                    initialState: TodoDetailFeature.State(todoId: item.id, showEditButton: true)
                ) {
                    TodoDetailFeature()
                },
                windowEvent: windowEvent
            )
            .id(item.id)
        }
    }

    private func openTodoEditor(for todoCategory: TodoCategory) {
        if isiOSAppOnMac {
            store.send(.store(.setPresentation(.contentPicker, false)))
            openWindow(
                id: TodoEditorWindowValue.sceneId,
                value: TodoEditorWindowValue(todoCategory: todoCategory, source: .home)
            )
        } else {
            store.send(.view(.tapTodoCategory(todoCategory)))
        }
    }
}

public enum HomeRoute: Hashable {
    case category(TodoCategoryItem)
    case todo(TodoIdItem)
}

private struct HomeCreateButton: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        if #available(iOS 26.0, *) {
            Button {
                store.send(.store(.setPresentation(.contentPicker, true)))
            } label: {
                Image(systemName: "plus")
            }
            .topBarButtonStyle()
            .disabled(!store.isNetworkConnected)
        } else {
            Button {
                store.send(.store(.setPresentation(.contentPicker, true)))
            } label: {
                Image(systemName: "plus")
                    .font(.adaptive(.title3).weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .adaptiveButtonStyle(
                shape: .circle,
                color: .secondaryBackground,
                glassEffect: .enabled
            )
            .disabled(!store.isNetworkConnected)
        }
    }
}

private struct HomeDevelopmentSummary: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        DevelopmentSummaryCard(
            items: store.developmentGoalItems,
            isLoading: store.isDevelopmentGoalsLoading,
            hasLoaded: store.hasDevelopmentGoalsLoaded,
            hasLoadFailure: store.hasDevelopmentGoalsLoadFailure
        )
    }
}

private struct HomeDevelopmentGoals: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        DevelopmentGoalSection(
            items: store.developmentGoalItems,
            isLoading: store.isDevelopmentGoalsLoading,
            hasLoaded: store.hasDevelopmentGoalsLoaded,
            hasLoadFailure: store.hasDevelopmentGoalsLoadFailure,
            onSelect: { store.send(.view(.tapDevelopmentGoal($0.id))) },
            onRetry: { store.send(.view(.fetchData)) }
        )
    }
}

private struct HomeTodoSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var iconSize = CGFloat(64)
    let store: StoreOf<HomeFeature>

    var body: some View {
        let items = store.preferences.filter(\.isVisible)
        let collapsedCount = min(items.count, 8)
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        let showsExpansionButton = 8 < items.count
            || 0 < collapsedCount && collapsedCount.isMultiple(of: columnCount)

        VStack(alignment: .leading, spacing: 0) {
            if store.isPreferencesLoading {
                LoadingView()
                    .frame(maxWidth: .infinity)
            } else {
                let visibleItems = store.isTodoCategoryExpanded
                    ? items
                    : Array(items.prefix(8))
                let hasAvailableSlot = visibleItems.isEmpty
                    || !visibleItems.count.isMultiple(of: columnCount)

                TodoCategoryGridLayout(
                    columnCount: columnCount,
                    itemWidth: iconSize,
                    maximumRowSpacing: dynamicTypeSize.isAccessibilitySize ? .infinity : iconSize / 2
                ) {
                    ForEach(visibleItems) { item in
                        HomeTodoCategoryLink(item: item, iconSize: iconSize)
                    }
                    if store.isTodoCategoryExpanded || hasAvailableSlot {
                        Button {
                            store.send(.view(.tapManageTodoCategory))
                        } label: {
                            VStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: CornerRadius.control)
                                    .strokeBorder(
                                        Color.tertiaryLabel,
                                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                                    )
                                    .frame(width: iconSize, height: iconSize)
                                    .overlay {
                                        Image(systemName: "square.grid.2x2")
                                            .font(.adaptive(.title2).bold())
                                            .foregroundStyle(Color.tertiaryLabel)
                                    }
                                Text("todo_edit", bundle: PresentationResources.bundle)
                                    .font(.adaptive(.subheadline))
                                    .foregroundStyle(Color.tertiaryLabel)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if !store.isPreferencesLoading, showsExpansionButton {
                HStack {
                    Spacer()
                    Button {
                        store.send(
                            .view(.tapTodoCategoryExpansionButton),
                            animation: .easeInOut(duration: 0.2)
                        )
                    } label: {
                        Image(systemName: store.isTodoCategoryExpanded ? "chevron.up" : "chevron.down")
                            .font(.adaptive(.title3).weight(.semibold))
                            .foregroundStyle(Color.tertiaryLabel)
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                }
            }
        }
        .padding(.bottom, 12)
        .background(Color.secondaryBackground, in: Rectangle())
    }
}

private struct HomeTodoCategoryLink: View {
    let item: TodoCategoryItem
    let iconSize: CGFloat

    var body: some View {
        NavigationLink(value: HomeRoute.category(item)) {
            VStack(spacing: 10) {
                Image(systemName: item.symbolName)
                    .font(.adaptive(.title2).bold())
                    .frame(width: iconSize, height: iconSize)
                    .iconStyle(
                        color: item.color,
                        in: RoundedRectangle(cornerRadius: CornerRadius.control)
                    )
                Text(item.localizedName)
                    .font(.adaptive(.subheadline))
                    .foregroundStyle(Color.secondaryLabel)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeContentPicker: View {
    let store: StoreOf<HomeFeature>
    let onSelect: (TodoCategory) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.isPreferencesLoading {
                        LoadingView()
                    } else {
                        let items = store.preferences.filter(\.isVisible)
                        ForEach(items, id: \.id) { item in
                            Button {
                                onSelect(item.category)
                            } label: {
                                HomeContentPickerLabel(
                                    text: item.localizedName,
                                    systemName: item.symbolName,
                                    imageColor: item.color
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }
                } header: {
                    Text("TODO", bundle: PresentationResources.bundle)
                        .foregroundStyle(Color(.label))
                }

                Section {
                    Button {
                        store.send(.view(.tapCreateDevelopmentGoal))
                    } label: {
                        HomeContentPickerLabel(
                            text: String(
                                localized: "development_goal_create_title",
                                bundle: PresentationResources.bundle
                            ),
                            systemName: "flag.checkered",
                            imageColor: Color.accent
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    Text("development_goal_title", bundle: PresentationResources.bundle)
                        .foregroundStyle(Color(.label))
                }
            }
            .navigationTitle(Text(verbatim: "DevLog"))
            .navigationBarTitleDisplayMode(.inline)  //  설정 안하면 섹션 위에 내비게이션 large 만큼 영역 먹음
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.send(.sheet(.presented(.tapCloseButton)))
                    } label: {
                        Image(systemName: "xmark")
                            .bold()
                    }
                }
            }
        }
    }
}

private struct HomeContentPickerLabel: View {
    @ScaledMetric(relativeTo: .largeTitle) private var labelWidth = CGFloat(34)
    let text: String
    let systemName: String
    let imageColor: Color

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: CornerRadius.control)
                .fill(imageColor)
                .frame(width: labelWidth, height: labelWidth)
                .overlay {
                    Image(systemName: systemName)
                        .foregroundStyle(Color.white)
                        .font(.adaptive(.title3))
                }
            Text(text)
                .foregroundStyle(Color.label)
            Spacer()
        }
        .contentShape(.rect)
    }
}
