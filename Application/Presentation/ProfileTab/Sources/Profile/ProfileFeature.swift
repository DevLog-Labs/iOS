//
//  ProfileFeature.swift
//  ProfileTab
//
//  Created by opfic on 6/15/26.
//

import Combine
import Core
import Domain
import Foundation
import PresentationShared

@Reducer
struct ProfileFeature {
    private enum CancelID: Hashable {
        case networkConnectivity
    }

    enum LoadingTarget: Hashable {
        case developmentGoals
        case recentTodos

        var target: LoadingFeature.Target {
            switch self {
            case .developmentGoals:
                return LoadingFeature.Target("profile.developmentGoals")
            case .recentTodos:
                return LoadingFeature.Target("profile.recentTodos")
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        var name = ""
        var email = ""
        var isNetworkConnected = true
        var statusMessage = ""
        var avatarURL: URL?
        var avatarImageData: AvatarImageData?
        var recentTodos = [RecentTodoItem]()
        var developmentGoals = [DevelopmentGoal]()
        var hasDevelopmentGoalsLoaded = false
        var hasDevelopmentGoalsLoadFailure = false
        var earliestQuarterStart: Date?
        var selectedQuarterStart: Date?
        var showQuarterPicker = false
        var selectedQuarterPickerYear = Calendar.current.component(.year, from: Date())
        var activityQuarter: HeatmapQuarter?
        var dayActivitiesByDate: [Date: [HeatmapActivityItem]] = [:]
        var selectedActivityKinds: Set<ActivityKind> = [.created, .completed, .deleted]
        var selectedDay: HeatmapDay?
        var selectedTodoRoute: ProfileRoute?
        var showDoneButton = false
        var loading = LoadingFeature.State()
    }

    enum Action: BindableAction {
        case alert(PresentationAction<Never>)
        case binding(BindingAction<State>)
        case startObserving
        case fetchData
        case refresh
        case refreshRecentTodos
        case retryDevelopmentGoals
        case networkStatusChanged(Bool)
        case setAlert(Bool)
        case tapResetStatusMessageButton
        case willUpdateStatusMessage
        case setQuarterPickerPresented(Bool)
        case openQuarterPicker
        case selectQuarter(Date)
        case moveToCurrentQuarter
        case moveQuarter(Int)
        case selectDay(HeatmapDay?)
        case updateStatusTextFieldFocus(Bool)
        case store(StoreAction)
        case loading(LoadingFeature.Action)

        enum StoreAction {
            case fetchUserData(UserProfile)
            case setAvatarImageData(URL, Data)
            case setActivityQuarter(
                quarterStart: Date,
                quarter: HeatmapQuarter,
                dayActivitiesByDate: [Date: [HeatmapActivityItem]]
            )
            case updateRecentTodos([RecentTodoItem])
            case developmentGoalsLoaded([DevelopmentGoal])
            case developmentGoalsLoadFailed
        }
    }

    @Dependency(\.profileFetchUserDataUseCase) var fetchUserDataUseCase
    @Dependency(\.profileFetchImageDataUseCase) var fetchProfileImageDataUseCase
    @Dependency(\.profileFetchTodosUseCase) var fetchTodosUseCase
    @Dependency(\.profileFetchDevelopmentGoalsUseCase) var fetchDevelopmentGoalsUseCase
    @Dependency(\.fetchTodoCategoryPreferencesUseCase) var fetchPreferencesUseCase
    @Dependency(\.profileTodoMutationEventBus) var todoMutationEventBus
    @Dependency(\.profileUpsertStatusMessageUseCase) var upsertStatusMessageUseCase
    @Dependency(\.profileNetworkConnectivityUseCase) var networkConnectivityUseCase
    @Dependency(\.profileFetchHeatmapActivityTypesUseCase) var fetchHeatmapActivityTypesUseCase
    @Dependency(\.profileUpdateHeatmapActivityTypesUseCase) var updateHeatmapActivityTypesUseCase

    var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.dismiss):
                state.alert = nil
            case .alert:
                break
            case .binding(\.isCreatedActivitySelected):
                return updateHeatmapActivityKindsEffectIfNeeded(.created, state: state)
            case .binding(\.isCompletedActivitySelected):
                return updateHeatmapActivityKindsEffectIfNeeded(.completed, state: state)
            case .binding(\.isDeletedActivitySelected):
                return updateHeatmapActivityKindsEffectIfNeeded(.deleted, state: state)
            case .binding:
                break
            case .startObserving:
                return .merge(
                    observeNetworkConnectivityEffect(),
                    observeTodoMutationEffect()
                )
            case .fetchData, .refresh:
                state.hasDevelopmentGoalsLoadFailure = false
                if state.selectedQuarterStart == nil,
                   let quarterStart = HeatmapBuilder.quarterStart(for: Date()) {
                    state.selectedQuarterStart = quarterStart
                }
                let rawValues = fetchHeatmapActivityTypesUseCase.execute()
                let settings = HeatmapBuilder.normalizeActivityKinds(rawValues)
                if !settings.isEmpty {
                    state.selectedActivityKinds = settings
                }
                let showsIndicator = if case .fetchData = action { true } else { false }
                if let selectedQuarterStart = state.selectedQuarterStart {
                    return .merge(
                        fetchUserDataEffect(),
                        fetchActivityQuarterEffect(selectedQuarterStart, showsIndicator: showsIndicator),
                        fetchRecentTodosEffect(),
                        fetchDevelopmentGoalsEffect()
                    )
                }
                return .merge(
                    fetchUserDataEffect(),
                    fetchRecentTodosEffect(),
                    fetchDevelopmentGoalsEffect()
                )
            case .refreshRecentTodos:
                return fetchRecentTodosEffect()
            case .retryDevelopmentGoals:
                state.hasDevelopmentGoalsLoadFailure = false
                return fetchDevelopmentGoalsEffect()
            case .networkStatusChanged(let isConnected):
                state.isNetworkConnected = isConnected
            case .setAlert(let isPresented):
                state.alert = isPresented ? Self.alertState() : nil
            case .tapResetStatusMessageButton:
                state.statusMessage = ""
            case .willUpdateStatusMessage:
                if !state.isNetworkConnected { break }
                return updateStatusMessageEffect(state.statusMessage)
            case .setQuarterPickerPresented(let isPresented):
                state.showQuarterPicker = isPresented
            case .openQuarterPicker:
                if let selectedQuarterStart = state.selectedQuarterStart {
                    state.selectedQuarterPickerYear = Calendar.current.component(.year, from: selectedQuarterStart)
                }
                state.showQuarterPicker = true
            case .selectQuarter(let quarterStart):
                guard HeatmapBuilder.canSelectQuarter(quarterStart, state: state) else { break }
                state.showQuarterPicker = false
                return updateSelectedQuarter(to: quarterStart, state: &state)
            case .moveToCurrentQuarter:
                guard let currentQuarterStart = HeatmapBuilder.quarterStart(for: Date()),
                      state.selectedQuarterStart != currentQuarterStart else { break }
                return updateSelectedQuarter(to: currentQuarterStart, state: &state)
            case .moveQuarter(let delta):
                guard let selectedQuarterStart = state.selectedQuarterStart else { break }
                let monthDelta = 3 * delta
                guard let nextQuarterStart = Calendar.current.date(
                    byAdding: .month,
                    value: monthDelta,
                    to: selectedQuarterStart
                ) else { break }
                guard HeatmapBuilder.canSelectQuarter(nextQuarterStart, state: state) else { break }
                return updateSelectedQuarter(to: nextQuarterStart, state: &state)
            case .selectDay(let day):
                if let day, state.selectedDay?.date == day.date {
                    state.selectedDay = nil
                } else {
                    state.selectedDay = day
                }
            case .updateStatusTextFieldFocus(let focused):
                state.showDoneButton = focused
            case .store(.fetchUserData(let profile)):
                let previousAvatarURL = state.avatarURL
                state.name = profile.name
                state.email = profile.email
                state.statusMessage = profile.statusMessage
                state.avatarURL = profile.avatarURL
                if previousAvatarURL != profile.avatarURL {
                    state.avatarImageData = nil
                }
                if state.earliestQuarterStart == nil {
                    state.earliestQuarterStart = HeatmapBuilder.quarterStart(for: profile.createdAt)
                        ?? Calendar.current.startOfDay(for: profile.createdAt)
                }
                if let avatarURL = profile.avatarURL {
                    return fetchAvatarImageDataEffect(avatarURL)
                }
            case .store(.setAvatarImageData(let url, let data)):
                guard state.avatarURL == url else { break }
                let id = (state.avatarImageData?.id ?? 0) + 1
                state.avatarImageData = AvatarImageData(id: id, data: data)
            case .store(.setActivityQuarter(let quarterStart, let quarter, let dayActivitiesByDate)):
                guard state.selectedQuarterStart == quarterStart else { break }
                state.activityQuarter = quarter
                state.dayActivitiesByDate = dayActivitiesByDate
            case .store(.updateRecentTodos(let todos)):
                state.recentTodos = todos
            case .store(.developmentGoalsLoaded(let goals)):
                state.developmentGoals = goals
                state.hasDevelopmentGoalsLoaded = true
                state.hasDevelopmentGoalsLoadFailure = false
            case .store(.developmentGoalsLoadFailed):
                state.hasDevelopmentGoalsLoadFailure = true
            case .loading:
                break
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

private extension ProfileFeature {
    func observeNetworkConnectivityEffect() -> Effect<Action> {
        .publisher { [networkConnectivityUseCase] in
            networkConnectivityUseCase.observe()
                .map(Action.networkStatusChanged)
        }
        .cancellable(id: CancelID.networkConnectivity, cancelInFlight: true)
    }

    func fetchUserDataEffect() -> Effect<Action> {
        .run { [fetchUserDataUseCase] send in
            do {
                let profile = try await fetchUserDataUseCase.execute()
                await send(.store(.fetchUserData(profile)))
            } catch {
                await send(.setAlert(true))
            }
        }
    }

    func fetchDevelopmentGoalsEffect() -> Effect<Action> {
        .run { [fetchDevelopmentGoalsUseCase] send in
            await send(.loading(.begin(target: LoadingTarget.developmentGoals.target, mode: .immediate)))
            do {
                let goals = try await fetchDevelopmentGoalsUseCase.execute(.init())
                await send(.store(.developmentGoalsLoaded(goals)))
            } catch {
                await send(.store(.developmentGoalsLoadFailed))
            }
            await send(.loading(.end(target: LoadingTarget.developmentGoals.target, mode: .immediate)))
        }
    }

    func fetchAvatarImageDataEffect(_ url: URL) -> Effect<Action> {
        .run { [fetchProfileImageDataUseCase] send in
            do {
                let data = try await fetchProfileImageDataUseCase.execute(from: url)
                await send(.store(.setAvatarImageData(url, data)))
            } catch { }
        }
    }

    func fetchActivityQuarterEffect(
        _ quarterStart: Date,
        showsIndicator: Bool = true
    ) -> Effect<Action> {
        .run { [fetchTodosUseCase] send in
            if showsIndicator {
                await send(.loading(.begin(target: .default, mode: .delayed)))
            }
            do {
                let data = try await HeatmapBuilder.fetchQuarterActivityData(
                    from: quarterStart,
                    fetchTodosUseCase: fetchTodosUseCase
                )
                await send(
                    .store(
                        .setActivityQuarter(
                            quarterStart: quarterStart,
                            quarter: data.quarter,
                            dayActivitiesByDate: data.dayActivitiesByDate
                        )
                    )
                )
                if showsIndicator {
                    await send(.loading(.end(target: .default, mode: .delayed)))
                }
            } catch {
                if showsIndicator {
                    await send(.loading(.end(target: .default, mode: .delayed)))
                }
                await send(.setAlert(true))
            }
        }
    }

    func updateStatusMessageEffect(_ message: String) -> Effect<Action> {
        .run { [upsertStatusMessageUseCase] send in
            do {
                try await upsertStatusMessageUseCase.execute(message)
            } catch {
                await send(.setAlert(true))
            }
        }
    }

    func updateHeatmapActivityKindsEffect(_ activityKinds: Set<ActivityKind>) -> Effect<Action> {
        .run { [updateHeatmapActivityTypesUseCase] _ in
            let rawValues = ActivityKindItem.selectableItems
                .map(\.rawValue)
                .filter { rawValue in
                    guard let activityKind = ActivityKind(rawValue: rawValue) else {
                        return false
                    }
                    return activityKinds.contains(activityKind)
                }
            updateHeatmapActivityTypesUseCase.execute(rawValues)
        }
    }

    func updateHeatmapActivityKindsEffectIfNeeded(
        _ activityKind: ActivityKind,
        state: State
    ) -> Effect<Action> {
        guard state.selectedActivityKinds != [activityKind] else { return .none }
        return updateHeatmapActivityKindsEffect(state.selectedActivityKinds)
    }

    func updateSelectedQuarter(
        to quarterStart: Date,
        state: inout State
    ) -> Effect<Action> {
        guard state.selectedQuarterStart != quarterStart else { return .none }
        state.selectedQuarterStart = quarterStart
        state.activityQuarter = nil
        state.dayActivitiesByDate = [:]
        state.selectedDay = nil
        return fetchActivityQuarterEffect(quarterStart)
    }

    static func alertState() -> AlertState<Never> {
        AlertState {
            TextState("")
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(localized: "common_error_message", bundle: PresentationResources.bundle))
        }
    }

}
