//
//  HomeView.swift
//  HomeTab
//
//  Created by opfic on 5/7/25.
//

import SwiftUI
import Domain
import PresentationShared

public struct HomeView: View {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.deviceType) private var deviceType
    @Environment(\.sideBarRequest) private var sideBarRequest
    @Environment(\.setDetailSideBarPresented) private var setDetailSideBarPresented
    @State private var router = NavigationRouter<HomeRoute>()
    @State private var store: StoreOf<HomeFeature>
    private let isSelected: Bool
    private let windowEvent: TodoEditorWindowEvent

    public init(
        isSelected: Bool,
        windowEvent: TodoEditorWindowEvent
    ) {
        self._store = State(initialValue: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        })
        self.isSelected = isSelected
        self.windowEvent = windowEvent
    }

    public var body: some View {
        let goalDetailID = store.sheet?.goalDetailState?.goalId
        let sideBarLocation: SideBarLocation = if let goalDetailID {
            .developmentGoal(goalDetailID)
        } else if usesDesktopLayout && store.sheet?.categoryManageState != nil {
            .todoCategoryManagement
        } else if router.path.last == .search {
            .search
        } else if case .category(let item)? = router.root {
            .todoCategory(item.id)
        } else {
            .home
        }
        // 사이드바가 있으면 카테고리 관리, 새 개발 목표, 개발 목표를 시트 대신 칸으로 표시
        let showsSheetAsPane = usesDesktopLayout
            && (store.sheet?.categoryManageState != nil || store.sheet?.goalCreateState != nil || goalDetailID != nil)
        // 칸으로 나눈 화면은 새로 만들기를 시트 대신 만들기 버튼 옆 팝오버로 표시
        let showsPickerAsPopover = usesPaneLayout && store.showContentPicker
        let sheetBinding = $store.scope(state: \.sheet, action: \.sheet)
            .activePresentation(when: isSelected)

        NavigationStack(path: $router.path) {
            // 사이드바가 있으면 새 개발 목표와 새 Todo를 홈 오른쪽 칸에서 작성
            PaneSplitView(splitsOnDesktop: store.sheet?.goalCreateState != nil || store.showTodoEditor) {
                homeContent
            } detail: {
                if let goalStore = store.scope(state: \.sheet?.goalCreateState, action: \.sheet.presented.goalCreate) {
                    GoalCreateView(store: goalStore)
                } else if let editorStore = store.scope(
                    state: \.fullScreenCover?.todoEditor,
                    action: \.fullScreenCover.presented.todoEditor
                ) {
                    TodoEditorView(store: editorStore, onClose: { store.send(.fullScreenCover(.dismiss)) })
                }
            }
            // 새 개발 목표에 연결한 Todo는 세부 정보 사이드바에 표시
            .compositionRight(isActive: store.sheet?.goalCreateState != nil) {
                if let goalStore = store.scope(state: \.sheet?.goalCreateState, action: \.sheet.presented.goalCreate) {
                    GoalCreateSideBarContent(store: goalStore)
                }
            }
            // 사이드바가 있으면 카테고리 관리를 시트 대신 홈 자리에 표시
            .compositionCenter(
                item: $store.scope(state: \.sheet?.categoryManageState, action: \.sheet.categoryManage),
                narrow: .sheet,
                isActive: isSelected
            ) { manageStore in
                CategoryManageView(store: manageStore) {
                    store.send(.sheet(.dismiss))
                }
            }
            // 좁은 창은 개발 목표를 홈 내비게이션에 쌓고, 넓어지면 같은 상태를 홈 자리에 표시하고 기록 작성은 오른쪽 칸에 표시
            .compositionCenter(
                item: $store.scope(state: \.sheet?.goalDetailState, action: \.sheet.goalDetail),
                narrow: .push
            ) { goalStore in
                GoalDetailView(store: goalStore, windowEvent: windowEvent)
                    .id(goalDetailID)
            }
            .navigationDestination(
                for: HomeRoute.self,
                interactivePop: {
                    switch $0 {
                    case .category: true
                    case .search: true
                    }
                },
                destination: {
                    destinationView($0)
                        .environment(\.showsPaneTitleBar, usesPaneLayout)
                        // 위에 쌓은 화면에 가려진 동안에도 창 폭이 바뀐 것을 받아 쌓아 연 상세를 옮김
                        .environment(\.usesDesktopLayout, usesDesktopLayout)
                }
            )
        }
        .desktopNavigationTransition()
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
        // 작성 중인 새 개발 목표나 수정 중인 개발 목표를 버린 뒤 미뤄 둔 사이드바 요청 처리
        .onChange(of: store.sideBarRequestAfterGoalDiscard) { _, request in
            handleSideBarRequest(request, showsSheetAsPane: showsSheetAsPane)
        }
        .onAppear {
            store.send(.view(.startObserving))
        }
        // 사이드바가 있으면 홈이 아닌 탭으로 켜지거나 좁은 창에서 넓어져도 사이드바 하위 항목을 채우도록 불러옴
        .onChange(of: usesDesktopLayout, initial: true) { _, usesDesktopLayout in
            if usesDesktopLayout && !isSelected {
                store.send(.view(.fetchData))
            }
        }
        .onChange(of: isSelected, initial: true) { _, isSelected in
            if isSelected {
                store.send(.view(.fetchData))
            }
        }
        // 카테고리 관리를 벗어나면 카테고리를 보여 주던 세부 정보 사이드바도 닫음
        // 창 폭이 바뀌어 칸과 시트를 오갈 때는 카테고리 관리 상태가 남아 닫지 않음
        .onChange(of: store.sheet?.categoryManageState == nil) { _, isClosed in
            if usesDesktopLayout && isClosed {
                setDetailSideBarPresented?(false)
            }
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        // 좁은 창의 새로 만들기
        .prominentSheet(
            item: Binding(
                get: { store.showContentPicker && !showsPickerAsPopover ? sheetBinding.wrappedValue : nil },
                // 앞 시트가 늦게 닫히며 보내는 닫힘이 칸이나 팝오버로 연 화면을 지우지 않도록 지금 상태로 판단
                set: { sheet in
                    // 내비게이션에 쌓은 개발 목표는 시트 닫힘으로 지우지 않음
                    guard store.sheet?.goalDetailState == nil else { return }
                    guard !usesDesktopLayout
                        || store.sheet?.categoryManageState == nil
                        && store.sheet?.goalCreateState == nil
                        && store.sheet?.goalDetailState == nil
                    else { return }
                    guard !(usesPaneLayout && store.showContentPicker) else { return }
                    sheetBinding.wrappedValue = sheet
                }
            )
        ) { _ in
            HomeContentPicker(store: store) { store.send(.view(.tapTodoCategory($0))) }
        }
        // 좁은 창은 새 개발 목표를 닫기, 저장 버튼으로만 닫는 시트로 작성
        .compositionEditor(
            item: $store.scope(state: \.sheet?.goalCreateState, action: \.sheet.goalCreate)
                .activePresentation(when: isSelected),
            narrow: .sheet
        ) { goalStore in
            GoalCreateView(store: goalStore)
        }
        .compositionEditor(
            item: $store.scope(state: \.fullScreenCover, action: \.fullScreenCover)
                .activePresentation(when: isSelected),
            content: coverContent
        )
    }

    private func handleSideBarRequest(_ request: SideBarRequest?, showsSheetAsPane: Bool) {
        // 이미 표시 중인 개발 목표를 다시 누르면 다시 열지 않고 쌓아 연 화면만 닫아 개발 목표 첫 화면 표시
        if case .open(.developmentGoal(let goalID))? = request?.action,
           store.sheet?.goalDetailState?.goalId == goalID {
            store.send(.sheet(.presented(.goalDetail(.view(.returnToGoal)))))
            return
        }
        // 작성 중인 새 개발 목표나 수정 중인 개발 목표가 있으면 칸을 닫기 전에 버릴지 물음
        if let request,
           request.action != .createTodo,
           store.sheet?.goalCreateState?.hasDraft == true || store.sheet?.goalDetailState?.goalEdit?.hasDraft == true {
            store.send(.view(.closeGoalDraftForSideBarRequest(request)))
            return
        }
        // 개발 목표 칸을 다른 화면으로 바꾸면 칸에서 바꾼 목표와 기록을 시트를 닫을 때처럼 홈과 사이드바 목록에 반영
        let refreshesDevelopmentGoals = request != nil
            && showsSheetAsPane
            && store.sheet?.isDevelopmentGoalPresentation == true
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
            // 사이드바가 있으면 개발 목표를 홈 루트에 그려 위에 쌓인 목록을 비움
            if usesDesktopLayout {
                router.path = []
            }
            store.send(.view(.tapDevelopmentGoal(goalID)))
        case .createTodo:
            // 홈 작성 버튼처럼 연결이 끊기면 열지 않고 쌓아 연 검색도 그대로 둠
            guard store.isNetworkConnected else { break }
            // 쌓아 연 검색은 내리고 홈 작성 버튼과 같은 방식으로 작성
            if router.root == .search {
                router.path = []
            }
            // 카테고리 목록이 보이면 그 목록이 자기 작성 버튼과 같은 방식으로 작성
            guard router.root == nil else { break }
            store.send(.store(.setPresentation(.contentPicker, true)))
        case .manageTodoCategory:
            // 카테고리를 불러오기 전 빈 목록으로 저장하지 않도록 무시
            guard !store.preferences.isEmpty else { break }
            // 사이드바가 있으면 카테고리 관리 칸을 홈 루트에 그려 위에 쌓인 목록을 비움
            if usesDesktopLayout {
                router.path = []
            }
            store.send(.view(.tapManageTodoCategory))
        case .open, nil:
            break
        }
        // 버릴지 묻는 중이면 칸이 그대로라 다시 불러오지 않음
        if refreshesDevelopmentGoals && store.actionAfterGoalDiscard == nil {
            store.send(.view(.fetchData))
        }
    }

    private var homeContent: some View {
        HomeColumns(store: store)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
            } action: { _, height in
                store.send(.binding(.set(\.visibleHeight, height)))
            }
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
            .background(Color.background)
            .duoToolbarVisibility()
            .toolbar {
                if deviceType == .duo {
                    // 세로 막대와 위쪽 막대 버튼을 리퀴드 글래스 묶음 없이 아이콘만 표시
                    duoToolbarItems
                        .sharedBackgroundHidden()
                }
            }
    }

    private var duoToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            // 접힌 뒤 펼칠 때 레일 아이콘이 사라지는 현상 방지
            Group {
                Button {
                    router.push(.search)
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

    @ViewBuilder
    private var topBar: some View {
        if usesPaneLayout {
            PaneTitleBar(Text("nav_home", bundle: PresentationResources.bundle)) {
                searchButton
                HomeCreateButton(store: store)
                    .popover(
                        isPresented: Binding(
                            get: { isSelected && store.showContentPicker },
                            // 좁은 창으로 바뀌며 팝오버가 닫혀도 같은 상태를 시트로 다시 그림
                            set: { isPresented in
                                if usesPaneLayout {
                                    store.send(.store(.setPresentation(.contentPicker, isPresented)))
                                }
                            }
                        ),
                        // 버튼 옆으로 붙으면 위쪽이 상태 표시 영역에 가려지므로 버튼 아래로 표시
                        arrowEdge: .top
                    ) {
                        HomeContentPicker(store: store) { store.send(.view(.tapTodoCategory($0))) }
                            // 화면이 낮거나 Duo 접는 선에 걸리면 팝오버 높이를 줄이고 목록을 스크롤
                            .frame(width: 320 * AdaptiveSize.boardScale)
                            .frame(minHeight: 0, idealHeight: min(640, store.visibleHeight), maxHeight: min(640, store.visibleHeight))
                            .presentationBackground(Color.secondaryBackground)
                            .presentationCompactAdaptation(.popover)
                    }
            }
        } else {
            HStack(spacing: 0) {
                Text("DevLog")
                    .font(.adaptive(.largeTitle).weight(.bold))
                Spacer()
                if deviceType != .duo {
                    searchButton
                    HomeCreateButton(store: store)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(maxWidth: readableContentWidth)
            .padding(.top, windowControlsInset)
            .padding(.bottom, 8)
            .background(Color.background)
            .toolbarBackground(Color.background)
        }
    }

    @ViewBuilder
    private var searchButton: some View {
        // 모든 기기에서 덮는 화면 대신 홈 내비게이션에 쌓아 열고, 사이드바가 있는 창은 사이드바 옆에 표시
        let openSearch = { router.push(.search) }

        if !usesPaneLayout {
            Button(action: openSearch) {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(HomeTopBarIconButtonStyle())
        } else {
            Button(action: openSearch) {
                Image(systemName: "magnifyingglass")
            }
            .topBarButtonStyle()
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
                windowEvent: windowEvent
            )
            .id(item.id)
        case .search:
            SearchView(windowEvent: windowEvent)
        }
    }
}

public enum HomeRoute: Hashable {
    case category(TodoCategoryItem)
    case search
}

private struct HomeCreateButton: View {
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    let store: StoreOf<HomeFeature>

    var body: some View {
        if !usesPaneLayout {
            Button {
                store.send(.store(.setPresentation(.contentPicker, true)))
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(HomeTopBarIconButtonStyle())
            .disabled(!store.isNetworkConnected)
        } else {
            Button {
                store.send(.store(.setPresentation(.contentPicker, true)))
            } label: {
                Image(systemName: "plus")
            }
            .topBarButtonStyle()
            .disabled(!store.isNetworkConnected)
        }
    }
}

// 좁은 화면 위쪽 줄의 배경 없는 40pt 아이콘 버튼
private struct HomeTopBarIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.adaptive(.title3).weight(.medium))
            .foregroundStyle(Color.label)
            .opacity(isEnabled && !configuration.isPressed ? 1 : 0.4)
            .frame(width: 40, height: 40)
            .contentShape(.rect)
    }
}

// 넓은 화면은 두 열, 좁은 화면과 오른쪽 칸이 열려 좁아진 왼쪽 칸은 한 열
private struct HomeColumns: View {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.paneWidth) private var paneWidth
    @Environment(\.readableContentWidth) private var readableContentWidth
    let store: StoreOf<HomeFeature>

    var body: some View {
        if usesDesktopLayout && paneWidth == nil {
            // 왼쪽 요약·카테고리, 오른쪽 진행 중인 개발의 두 열
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HomeDevelopmentSummary(store: store)
                        HomeTodoSection(store: store)
                    }
                }
                Divider().overlay(Color.secondarySeparator)
                ScrollView {
                    HomeDevelopmentGoals(store: store)
                }
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HomeDevelopmentSummary(store: store)
                    HomeTodoSection(store: store)
                    HomeDevelopmentGoals(store: store)
                }
                .frame(maxWidth: readableContentWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct HomeDevelopmentSummary: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let store: StoreOf<HomeFeature>

    var body: some View {
        DevelopmentSummaryCard(
            items: store.developmentGoalItems,
            isLoading: store.isDevelopmentGoalsLoading,
            hasLoaded: store.hasDevelopmentGoalsLoaded,
            hasLoadFailure: store.hasDevelopmentGoalsLoadFailure
        )
        .padding(.top, isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 16)
        .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .padding(.bottom, 4)
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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let store: StoreOf<HomeFeature>

    var body: some View {
        let items = store.preferences.filter(\.isVisible)
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 2 : 4

        VStack(alignment: .leading, spacing: 0) {
            HomeSectionHeader {
                Text(verbatim: "Todo")
            } trailing: {
                if !store.isPreferencesLoading {
                    Button {
                        store.send(.view(.tapManageTodoCategory))
                    } label: {
                        // 테두리 버튼 모양의 작은 버튼
                        Text("todo_edit", bundle: PresentationResources.bundle)
                            .font(.adaptive(.footnote).weight(.medium))
                            .foregroundStyle(Color.label)
                            .padding(.horizontal, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 10)
                            .frame(minHeight: isiOSAppOnMac ? 24 * AdaptiveSize.boardScale : 28)
                            .outlineButtonBackground()
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.isPreferencesLoading {
                LoadingView()
                    .frame(maxWidth: .infinity)
            } else {
                let visibleItems = store.isTodoCategoryExpanded
                    ? items
                    : Array(items.prefix(8))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .top), count: columnCount),
                    spacing: 0
                ) {
                    ForEach(visibleItems) { item in
                        HomeTodoCategoryLink(item: item)
                    }
                }
                .padding(.horizontal, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 10)
            }

            if !store.isPreferencesLoading, 8 < items.count {
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
    }
}

// 테두리 있는 아이콘 사각형과 이름 타일
private struct HomeTodoCategoryLink: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let item: TodoCategoryItem

    var body: some View {
        let tileSize = isiOSAppOnMac ? 37 * AdaptiveSize.boardScale : 40

        NavigationLink(value: HomeRoute.category(item)) {
            VStack(spacing: 6) {
                Image(systemName: item.symbolName)
                    .font(.adaptive(.body).weight(.medium))
                    .foregroundStyle(item.color)
                    .frame(width: tileSize, height: tileSize)
                    .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.control)
                            .strokeBorder(Color.secondarySeparator)
                    }
                Text(item.localizedName)
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.label)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// 새로 만들기 화면
// 위쪽 닫기 버튼과 제목 줄, 작은 제목 아래 구분선으로 나눈 TODO 카테고리와 새 개발 목표 배치
// 좁은 창은 시트, 사이드바가 있는 iPad 창은 손가락 크기 팝오버, Mac은 Mac 크기 팝오버 모양
private struct HomeContentPicker: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    let store: StoreOf<HomeFeature>
    let onSelect: (TodoCategory) -> Void

    var body: some View {
        let scale = AdaptiveSize.boardScale
        let headerHeight = isiOSAppOnMac ? 44 * scale : usesPaneLayout ? 52 : 48
        // 시트는 위쪽 손잡이 아래에 제목 줄을 둠
        let grabberInset = isiOSAppOnMac || usesPaneLayout ? 0 : CGFloat(11)

        VStack(spacing: 0) {
            if isiOSAppOnMac || usesPaneLayout {
                // 팝오버와 Mac은 X 닫기 버튼과 가운데 제목
                ZStack {
                    Text("home_create_title", bundle: PresentationResources.bundle)
                        .font(isiOSAppOnMac ? .system(size: 14 * scale, weight: .bold) : .adaptive(.headline).bold())
                    HStack {
                        if isiOSAppOnMac {
                            Button {
                                store.send(.sheet(.presented(.tapCloseButton)))
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.adaptive(.body))
                                    .foregroundStyle(Color.label)
                                    .frame(width: 28 * scale, height: 28 * scale)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                store.send(.sheet(.presented(.tapCloseButton)))
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .topBarButtonStyle()
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 10 * scale)
                .frame(height: headerHeight)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.separator)
                        .frame(height: 1)
                }
            } else {
                // 시트는 다른 시트처럼 손잡이 아래부터 글자 닫기 버튼과 가운데 제목
                RecordTopBar(
                    String(localized: "home_create_title", bundle: PresentationResources.bundle),
                    background: .secondaryBackground
                ) {
                    RecordTopBarTextButton(RecordPresentation.text("common_close")) {
                        store.send(.sheet(.presented(.tapCloseButton)))
                    }
                } trailing: {
                    EmptyView()
                }
                .padding(.top, grabberInset)
                // 아래에서 올라온 시트라 창 컨트롤 여백을 더하지 않음
                .environment(\.windowControlsInset, 0)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: isiOSAppOnMac ? 16 * scale : 24) {
                    section(Text("TODO", bundle: PresentationResources.bundle)) {
                        if store.isPreferencesLoading {
                            LoadingView()
                                .frame(maxWidth: .infinity, minHeight: isiOSAppOnMac ? 38 * scale : 50)
                        } else {
                            ForEach(store.preferences.filter(\.isVisible), id: \.id) { item in
                                row(title: Text(item.localizedName), symbolName: item.symbolName, color: item.color) {
                                    onSelect(item.category)
                                }
                            }
                        }
                    }

                    section(Text("development_goal_title", bundle: PresentationResources.bundle)) {
                        row(
                            title: Text("development_goal_create_title", bundle: PresentationResources.bundle),
                            symbolName: "flag",
                            color: Color.label
                        ) {
                            store.send(.view(.tapCreateDevelopmentGoal))
                        }
                    }
                }
                .padding(.horizontal, isiOSAppOnMac ? 14 * scale : 16)
                .padding(.vertical, isiOSAppOnMac ? 8 * scale : 12)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    store.send(.binding(.set(\.contentPickerHeight, height)))
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // 좁은 화면 시트는 목록 높이에 맞추고, 화면보다 길면 목록을 스크롤
        .sheetDetent(
            isiOSAppOnMac || store.contentPickerHeight == 0
                ? .large : .height(grabberInset + headerHeight + store.contentPickerHeight)
        )
    }

    // 작은 제목 아래 바탕과 테두리 없이 행 사이 구분선으로 나눈 묶음
    // 시트는 이름 앞에서 시작하는 구분선, 팝오버는 행 폭 전체 구분선
    private func section<Content: View>(_ header: Text, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)
                .padding(.bottom, 6 * AdaptiveSize.boardScale)

            VStack(spacing: 0) {
                Group(subviews: content()) { subviews in
                    ForEach(subviews) { subview in
                        subview

                        if subview.id != subviews.last?.id {
                            Rectangle()
                                .fill(isiOSAppOnMac || usesPaneLayout ? Color.secondarySeparator : .separator)
                                .frame(height: 1)
                                .padding(.leading, isiOSAppOnMac || usesPaneLayout ? 0 : 28 + 10)
                        }
                    }
                }
            }
        }
    }

    // 테두리 있는 아이콘 사각형과 이름 행
    private func row(title: Text, symbolName: String, color: Color, action: @escaping () -> Void) -> some View {
        let scale = AdaptiveSize.boardScale
        let iconSize = isiOSAppOnMac ? 25 * scale : 28

        return Button(action: action) {
            HStack(spacing: 10 * scale) {
                Image(systemName: symbolName)
                    .font(.adaptive(isiOSAppOnMac ? .body : .footnote))
                    .foregroundStyle(color)
                    .frame(width: iconSize, height: iconSize)
                    .background(
                        isiOSAppOnMac ? Color.tertiaryBackground : .background,
                        in: .rect(cornerRadius: CornerRadius.control)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.control)
                            .strokeBorder(Color.secondarySeparator)
                    }
                title
                    .foregroundStyle(Color.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
            .frame(minHeight: isiOSAppOnMac ? 38 * scale : 50)
            .hoverHighlight()
        }
        .buttonStyle(.plain)
    }
}
