//
//  HomeFeatureTests.swift
//  HomeTabTests
//
//  Created by opfic on 6/14/26.
//

import Testing
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

        #expect(adapter.sheet == .goalCreate(GoalCreateFeature.State()))

        await adapter.dismissSheet()

        #expect(adapter.sheet == nil)

        await adapter.tapDevelopmentGoal("goal")

        #expect(adapter.sheet == .goalDetail("goal"))
    }

    @Test("새 개발 목표를 저장하는 동안 시트를 바꾸지 않는다")
    func 새_개발_목표를_저장하는_동안_시트를_바꾸지_않는다() async {
        let adapter = StoreTestAdapter()

        await adapter.tapCreateDevelopmentGoal()
        await adapter.setGoalCreateSaving()
        await adapter.tapDevelopmentGoal("goal")
        await adapter.setSheet(nil)

        #expect(adapter.sheet?.goalCreateState?.isSaving == true)
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

        #expect(adapter.sheet == nil)
        #expect(adapter.developmentGoalItems.map(\.id) == [goal.id])
    }

    @Test("카테고리 관리가 열려 있으면 다시 열어도 바로 저장 상태를 유지한다")
    func 카테고리_관리가_열려_있으면_다시_열어도_바로_저장_상태를_유지한다() async {
        let adapter = StoreTestAdapter()

        await adapter.tapManageTodoCategory()
        await adapter.setCategoryManageSavesImmediately()
        await adapter.tapManageTodoCategory()

        #expect(adapter.sheet?.categoryManageState?.savesImmediately == true)
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

    @Test("HomeFeature orderTodoCategory는 카테고리 설정을 저장한다")
    func HomeFeature_orderTodoCategory는_카테고리_설정을_저장한다() async throws {
        let context = makeHomeOrderContext()
        let adapter = StoreTestAdapter(
            fetchPreferencesUseCase: context.fetchPreferencesUseCaseSpy,
            updatePreferencesUseCase: context.updatePreferencesUseCaseSpy
        )

        try await verifyHomeOrderTodoCategory(
            adapter: adapter,
            updatePreferencesUseCaseSpy: context.updatePreferencesUseCaseSpy
        )
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
