//
//  HomeFeatureTests.swift
//  HomeTabTests
//
//  Created by opfic on 6/14/26.
//

import Testing
import Foundation
import Core
import Domain
import PresentationShared
@testable import HomeTab

@MainActor
struct HomeFeatureTests {
    @Test("HomeFeature fetchData는 홈 상태를 갱신한다")
    func HomeFeature_fetchData는_홈_상태를_갱신한다() async throws {
        let context = makeHomeFetchDataContext()
        let adapter = StoreTestAdapter(
            fetchPreferencesUseCase: context.fetchPreferencesUseCaseSpy
        )

        try await verifyHomeFetchData(adapter: adapter)
    }

    @Test("HomeFeature fetchData는 진행 중 목표의 최신 확정 기록을 갱신한다")
    func HomeFeature_fetchData는_진행_중_목표의_최신_확정_기록을_갱신한다() async throws {
        let goal = try makeDevelopmentGoal(id: "goal", createdAt: 1)
        let version = try makeDevelopmentRecordVersion(
            id: "recent-version",
            recordID: "recent-record",
            title: "최근 기록",
            confirmedAt: 2
        )
        let goalsSpy = FetchDevelopmentGoalsUseCaseSpy()
        goalsSpy.result = .success([goal])
        let recentRecordSpy = FetchRecentDevelopmentRecordUseCaseSpy()
        await recentRecordSpy.setResult(.success(version), goalID: goal.id)
        let adapter = StoreTestAdapter(
            fetchDevelopmentGoalsUseCase: goalsSpy,
            recentRecordUseCase: recentRecordSpy
        )

        await adapter.fetchData()

        await waitUntil { adapter.hasDevelopmentGoalsLoaded }

        #expect(goalsSpy.queries == [.init(status: .inProgress)])
        #expect(await recentRecordSpy.goalIDs == [goal.id])
        #expect(adapter.developmentGoalItems.map(\.id) == [goal.id])
        #expect(adapter.developmentGoalItems.first?.recentRecord == version)
    }

    @Test("HomeFeature fetchData는 연결 Todo 완료 수로 목표 진행률을 계산한다")
    func HomeFeature_fetchData는_연결_Todo_완료_수로_목표_진행률을_계산한다() async throws {
        let goal = try makeDevelopmentGoal(id: "goal", createdAt: 1)
        let todosSpy = HomeFetchTodosUseCaseSpy()
        todosSpy.page = TodoPage(
            items: [
                makeHomeTodo(id: "completed", goalID: goal.id, isCompleted: true),
                makeHomeTodo(id: "incomplete", goalID: goal.id, isCompleted: false),
                makeHomeTodo(id: "other", goalID: "other-goal", isCompleted: true)
            ],
            nextCursor: nil
        )
        let goalsSpy = FetchDevelopmentGoalsUseCaseSpy()
        goalsSpy.result = .success([goal])
        let adapter = StoreTestAdapter(
            fetchDevelopmentGoalsUseCase: goalsSpy,
            fetchTodosUseCase: todosSpy
        )

        await adapter.fetchData()

        await waitUntil { adapter.hasDevelopmentGoalsLoaded }

        #expect(adapter.developmentGoalItems.first?.todoProgress == .init(completedCount: 1, totalCount: 2))
        #expect(todosSpy.queries == [
            TodoQuery(
                sortTarget: .updatedAt,
                sortOrder: .latest,
                pageSize: 100,
                fetchAllPages: true
            )
        ])
    }

    @Test("HomeFeature fetchData 실패 뒤 재시도는 진행 중 목표를 갱신한다")
    func HomeFeature_fetchData_실패_뒤_재시도는_진행_중_목표를_갱신한다() async throws {
        let goalsSpy = FetchDevelopmentGoalsUseCaseSpy()
        goalsSpy.result = .failure(DevelopmentGoalTestError.failed)
        let adapter = StoreTestAdapter(fetchDevelopmentGoalsUseCase: goalsSpy)

        await adapter.fetchData()

        await waitUntil { adapter.hasDevelopmentGoalsLoadFailure }
        #expect(!adapter.hasDevelopmentGoalsLoaded)

        goalsSpy.result = .success([])
        await adapter.fetchData()

        await waitUntil { adapter.hasDevelopmentGoalsLoaded }
        #expect(adapter.developmentGoalItems.isEmpty)
        #expect(!adapter.hasDevelopmentGoalsLoadFailure)
    }

    @Test("HomeFeature tapTodoCategory는 editor를 지연 표시한다")
    func HomeFeature_tapTodoCategory는_editor를_지연_표시한다() async throws {
        let adapter = StoreTestAdapter()

        try await verifyHomeTapTodoCategory(adapter: adapter)
    }

    @Test("HomeFeature 카테고리 펼침 버튼은 펼침 상태를 전환한다")
    func HomeFeature_카테고리_펼침_버튼은_펼침_상태를_전환한다() async {
        let adapter = StoreTestAdapter()

        await adapter.tapTodoCategoryExpansionButton()

        #expect(adapter.isTodoCategoryExpanded)
    }

    @Test("개발 목표 생성과 상세 선택은 Feature sheet 상태를 전환한다")
    func 개발_목표_생성과_상세_선택은_Feature_sheet_상태를_전환한다() async {
        let adapter = StoreTestAdapter()

        await adapter.tapCreateDevelopmentGoal()

        #expect(adapter.goalCreate == GoalCreateFeature.State())

        await adapter.dismissGoalCreate()

        #expect(adapter.goalCreate == nil)

        await adapter.tapDevelopmentGoal("goal")

        #expect(adapter.goalDetail?.goalId == "goal")
    }

    @Test("작성 중인 새 개발 목표가 있으면 버릴지 물은 뒤 버리면 고른 목표를 연다")
    func 작성_중인_새_개발_목표가_있으면_버릴지_물은_뒤_버리면_고른_목표를_연다() async {
        let adapter = StoreTestAdapter()

        await adapter.tapCreateDevelopmentGoal()
        await adapter.setGoalCreateTitle("목표")
        await adapter.tapDevelopmentGoal("goal")

        #expect(adapter.alert == HomeFeature.discardGoalDraftAlertState(isEditing: false))
        #expect(adapter.goalCreate?.title == "목표")

        await adapter.discardGoalDraft()

        #expect(adapter.goalDetail?.goalId == "goal")
    }

    @Test("수정 중인 개발 목표가 있으면 버릴지 물은 뒤 버리면 고른 목표를 연다")
    func 수정_중인_개발_목표가_있으면_버릴지_물은_뒤_버리면_고른_목표를_연다() async throws {
        let goal = try makeDevelopmentGoal()
        var state = HomeFeature.State()
        state.goalDetail = GoalDetailFeature.State(goalId: goal.id)
        state.goalDetail?.goalEdit = GoalCreateFeature.State(goal: goal)
        state.goalDetail?.goalEdit?.title = "바꾼 제목"
        let adapter = StoreTestAdapter(initialState: state)

        await adapter.tapDevelopmentGoal("other")

        #expect(adapter.alert == HomeFeature.discardGoalDraftAlertState(isEditing: true))
        #expect(adapter.goalDetail?.goalEdit?.title == "바꾼 제목")

        await adapter.discardGoalDraft()

        #expect(adapter.goalDetail?.goalId == "other")
    }

    @Test("작성 중인 새 개발 목표를 버리지 않으면 칸을 유지한다")
    func 작성_중인_새_개발_목표를_버리지_않으면_칸을_유지한다() async {
        let adapter = StoreTestAdapter()

        await adapter.tapCreateDevelopmentGoal()
        await adapter.setGoalCreateTitle("목표")
        await adapter.tapDevelopmentGoal("goal")
        await adapter.cancelGoalDraftDiscard()

        #expect(adapter.alert == nil)
        #expect(adapter.goalCreate?.title == "목표")
    }

    @Test("작성 중인 새 개발 목표를 버리면 미뤄 둔 사이드바 요청을 다시 처리한다")
    func 작성_중인_새_개발_목표를_버리면_미뤄_둔_사이드바_요청을_다시_처리한다() async {
        let adapter = StoreTestAdapter()
        let request = SideBarRequest(id: UUID(), action: .open(.developmentGoal("goal")))

        await adapter.tapCreateDevelopmentGoal()
        await adapter.setGoalCreateTitle("목표")
        await adapter.sideBarRequested(request)

        #expect(adapter.alert == HomeFeature.discardGoalDraftAlertState(isEditing: false))
        #expect(adapter.goalDetail == nil)

        await adapter.discardGoalDraft()

        #expect(adapter.goalCreate == nil)
        #expect(adapter.goalDetail?.goalId == "goal")
    }

    @Test("입력하지 않은 새 개발 목표는 묻지 않고 고른 목표를 연다")
    func 입력하지_않은_새_개발_목표는_묻지_않고_고른_목표를_연다() async {
        let adapter = StoreTestAdapter()

        await adapter.tapCreateDevelopmentGoal()
        await adapter.tapDevelopmentGoal("goal")

        #expect(adapter.alert == nil)
        #expect(adapter.goalDetail?.goalId == "goal")
    }

    @Test("새 개발 목표를 저장하는 동안 시트를 바꾸지 않는다")
    func 새_개발_목표를_저장하는_동안_시트를_바꾸지_않는다() async {
        var state = HomeFeature.State()
        state.usesDesktopLayout = true
        let adapter = StoreTestAdapter(initialState: state)

        await adapter.tapCreateDevelopmentGoal()
        await adapter.setGoalCreateSaving()
        await adapter.tapDevelopmentGoal("goal")
        await adapter.sideBarRequested(SideBarRequest(id: UUID(), action: .open(.home)))

        #expect(adapter.goalCreate?.isSaving == true)
    }

    @Test("수정 중인 개발 목표를 버리고 칸을 닫으면 개발 목표 목록을 다시 조회한다")
    func 수정_중인_개발_목표를_버리고_칸을_닫으면_개발_목표_목록을_다시_조회한다() async throws {
        let goalsSpy = FetchDevelopmentGoalsUseCaseSpy()
        let goal = try makeDevelopmentGoal()
        var state = HomeFeature.State()
        state.goalDetail = GoalDetailFeature.State(goalId: goal.id)
        state.goalDetail?.goalEdit = GoalCreateFeature.State(goal: goal)
        state.goalDetail?.goalEdit?.title = "바꾼 제목"
        let adapter = StoreTestAdapter(initialState: state, fetchDevelopmentGoalsUseCase: goalsSpy)

        await adapter.tapManageTodoCategory()

        #expect(goalsSpy.queries.isEmpty)

        await adapter.discardGoalDraft()

        await waitUntil { !goalsSpy.queries.isEmpty }
        #expect(goalsSpy.queries == [.init(status: .inProgress)])
        #expect(adapter.goalDetail == nil)
    }

    @Test("수정 중인 개발 목표를 버리면 미뤄 둔 사이드바 요청을 다시 처리한다")
    func 수정_중인_개발_목표를_버리면_미뤄_둔_사이드바_요청을_다시_처리한다() async throws {
        let request = SideBarRequest(id: UUID(), action: .open(.developmentGoal("other")))
        let goal = try makeDevelopmentGoal()
        var state = HomeFeature.State()
        state.goalDetail = GoalDetailFeature.State(goalId: goal.id)
        state.goalDetail?.goalEdit = GoalCreateFeature.State(goal: goal)
        state.goalDetail?.goalEdit?.content = "바꾼 설명"
        let adapter = StoreTestAdapter(initialState: state)

        await adapter.sideBarRequested(request)

        #expect(adapter.alert == HomeFeature.discardGoalDraftAlertState(isEditing: true))
        #expect(adapter.goalDetail?.goalId == goal.id)

        await adapter.discardGoalDraft()

        #expect(adapter.goalDetail?.goalId == "other")
    }

    @Test("수정 중인 개발 목표를 저장하는 동안 시트를 바꾸지 않는다")
    func 수정_중인_개발_목표를_저장하는_동안_시트를_바꾸지_않는다() async throws {
        let goal = try makeDevelopmentGoal()
        var state = HomeFeature.State()
        state.usesDesktopLayout = true
        state.goalDetail = GoalDetailFeature.State(goalId: goal.id)
        state.goalDetail?.goalEdit = GoalCreateFeature.State(goal: goal)
        state.goalDetail?.goalEdit?.title = "바꾼 제목"
        state.goalDetail?.goalEdit?.isSaving = true
        let adapter = StoreTestAdapter(initialState: state)

        await adapter.tapDevelopmentGoal("other")
        await adapter.sideBarRequested(SideBarRequest(id: UUID(), action: .open(.home)))

        #expect(adapter.alert == nil)
        #expect(adapter.goalDetail?.goalEdit?.isSaving == true)
    }

    @Test("새 개발 목표를 저장하면 시트를 닫고 홈 데이터를 다시 조회한다")
    func 새_개발_목표를_저장하면_시트를_닫고_홈_데이터를_다시_조회한다() async throws {
        let goal = try makeDevelopmentGoal(id: "goal", createdAt: 1)
        let goalsSpy = FetchDevelopmentGoalsUseCaseSpy()
        goalsSpy.result = .success([goal])
        let adapter = StoreTestAdapter(fetchDevelopmentGoalsUseCase: goalsSpy)

        await adapter.tapCreateDevelopmentGoal()
        await adapter.goalCreateSaved(goal)
        await waitUntil { adapter.hasDevelopmentGoalsLoaded }

        #expect(adapter.goalCreate == nil)
        #expect(adapter.developmentGoalItems.map(\.id) == [goal.id])
    }

    @Test("카테고리 관리가 열려 있으면 다시 열어도 고르던 카테고리를 유지한다")
    func 카테고리_관리가_열려_있으면_다시_열어도_고르던_카테고리를_유지한다() async {
        let adapter = StoreTestAdapter()

        await adapter.tapManageTodoCategory()
        await adapter.tapAddCategoryManageItem()
        let id = adapter.categoryManage?.categorySheet?.category.id
        await adapter.tapManageTodoCategory()

        #expect(id != nil)
        #expect(adapter.categoryManage?.categorySheet?.category.id == id)
    }

    @Test("카테고리 관리에서 바로 저장한 변경은 마지막 값만 저장한다")
    func 카테고리_관리에서_바로_저장한_변경은_마지막_값만_저장한다() async {
        let updateSpy = UpdateTodoCategoryPreferencesUseCaseSpy()
        let adapter = StoreTestAdapter(updatePreferencesUseCase: updateSpy)
        let issue = TodoCategoryItem(from: .system(.issue))
        let feature = TodoCategoryItem(from: .system(.feature))

        await adapter.tapManageTodoCategory()
        await adapter.changeCategoryPreferences([issue, feature])
        await adapter.changeCategoryPreferences([feature, issue])
        await adapter.advanceClock(by: .seconds(1))
        await waitUntil { !updateSpy.updates.isEmpty }

        #expect(updateSpy.updates == [[feature.preference, issue.preference]])
        #expect(adapter.preferences == [feature, issue])
    }

    @Test("카테고리 관리 시트를 닫은 직후에도 마지막 변경을 저장한다")
    func 카테고리_관리_시트를_닫은_직후에도_마지막_변경을_저장한다() async {
        let updateSpy = UpdateTodoCategoryPreferencesUseCaseSpy()
        let adapter = StoreTestAdapter(updatePreferencesUseCase: updateSpy)
        let issue = TodoCategoryItem(from: .system(.issue))
        let feature = TodoCategoryItem(from: .system(.feature))

        await adapter.tapManageTodoCategory()
        await adapter.changeCategoryPreferences([feature, issue])
        await adapter.dismissCategoryManage()
        await adapter.advanceClock(by: .seconds(1))
        await waitUntil { !updateSpy.updates.isEmpty }

        #expect(!adapter.showCategoryManage)
        #expect(updateSpy.updates == [[feature.preference, issue.preference]])
    }

    @Test("카테고리 관리에서 고친 카테고리 설정은 바로 저장한다")
    func 카테고리_관리에서_고친_카테고리_설정은_바로_저장한다() async {
        let context = makeHomeFetchDataContext()
        let updateSpy = UpdateTodoCategoryPreferencesUseCaseSpy()
        let adapter = StoreTestAdapter(
            fetchPreferencesUseCase: context.fetchPreferencesUseCaseSpy,
            updatePreferencesUseCase: updateSpy
        )
        let feature = TodoCategoryItem(from: .system(.feature))

        await adapter.fetchData()
        await adapter.tapManageTodoCategory()
        await adapter.tapCategoryManageItem(feature)
        await adapter.advanceClock(by: .seconds(1))
        await waitUntil { !updateSpy.updates.isEmpty }

        #expect(updateSpy.updates.first?.first { $0.category == .system(.feature) }?.isVisible == false)
        #expect(adapter.preferences.first { $0.id == feature.id }?.isVisible == false)
    }

    @Test("TodoEditor 생성 delegate는 editor를 닫고 홈 데이터를 다시 조회한다")
    func TodoEditor_생성_delegate는_editor를_닫고_홈_데이터를_다시_조회한다() async throws {
        let context = makeHomeFetchDataContext()
        let trackSpy = TrackAnalyticsEventUseCaseSpy()
        let adapter = StoreTestAdapter(
            fetchPreferencesUseCase: context.fetchPreferencesUseCaseSpy,
            trackAnalyticsEventUseCase: trackSpy
        )

        await adapter.tapTodoCategory(.system(.feature))
        await adapter.todoEditorCreated()

        await waitUntil {
            context.fetchPreferencesUseCaseSpy.executeCount == 1
                && trackSpy.hasTrackedTodoCreate
        }

        #expect(!adapter.showTodoEditor)
    }

    @Test("HomeFeature startObserving은 네트워크 연결 상태를 반영한다")
    func HomeFeature_startObserving은_네트워크_연결_상태를_반영한다() async {
        let networkUseCaseSpy = ObserveNetworkConnectivityUseCaseSpy()
        let adapter = StoreTestAdapter(networkConnectivityUseCase: networkUseCaseSpy)

        await adapter.startObserving()

        #expect(adapter.isNetworkConnected)

        networkUseCaseSpy.currentValueSubject.send(false)
        await adapter.settle()

        #expect(!adapter.isNetworkConnected)
    }
}
