//
//  PushNotificationSettingsFeatureTests.swift
//  ProfileTabTests
//
//  Created by opfic on 6/12/26.
//

import Testing
import Foundation
import Domain
import PresentationShared
@testable import ProfileTab

@MainActor
struct PushNotificationSettingsFeatureTests {
    @Test("fetchSettings는 푸시 설정 상태를 갱신한다")
    func fetchSettings는_푸시_설정_상태를_갱신한다() async {
        let fetchSpy = FetchPushSettingsUseCaseSpy(
            settings: makePushNotificationSettings(isEnabled: true, hour: 9, minute: 0)
        )
        let adapter = PushNotificationSettingsStoreTestAdapter(fetchUseCase: fetchSpy)
        await adapter.fetchSettings()
        #expect(adapter.pushNotificationEnable)
        #expect(adapter.pushNotificationHour == 9)
        #expect(adapter.pushNotificationMinute == 0)
        #expect(adapter.sheetPushNotificationTime == adapter.viewPushNotificationTime)
    }

    @Test("fetchSettings는 서버 상태 반영 중 설정 업데이트를 다시 호출하지 않는다")
    func fetchSettings는_서버_상태_반영_중_설정_업데이트를_다시_호출하지_않는다() async {
        let fetchSpy = FetchPushSettingsUseCaseSpy(
            settings: makePushNotificationSettings(isEnabled: true, hour: 9, minute: 0)
        )
        let updateSpy = UpdatePushSettingsUseCaseSpy()
        let adapter = PushNotificationSettingsStoreTestAdapter(
            fetchUseCase: fetchSpy,
            updateUseCase: updateSpy
        )
        await adapter.fetchSettings()
        #expect(updateSpy.executeCallCount == 0)
    }

    @Test("setPushNotificationEnable은 활성화 상태를 변경한다")
    func setPushNotificationEnable은_활성화_상태를_변경한다() async {
        let adapter = PushNotificationSettingsStoreTestAdapter()
        await adapter.setPushNotificationEnable(true)
        #expect(adapter.pushNotificationEnable)
    }

    @Test("selectPresetTime은 화면과 시트 시간을 함께 변경한다")
    func selectPresetTime은_화면과_시트_시간을_함께_변경한다() async {
        let adapter = PushNotificationSettingsStoreTestAdapter()
        let date = makeDate(hour: 15, minute: 0)
        await adapter.selectPresetTime(date)
        #expect(adapter.viewPushNotificationTime == date)
        #expect(adapter.sheetPushNotificationTime == date)
        #expect(adapter.pushNotificationHour == 15)
        #expect(adapter.pushNotificationMinute == 0)
    }

    @Test("setShowTimePicker는 현재 화면 시간으로 시트를 연다")
    func setShowTimePicker는_현재_화면_시간으로_시트를_연다() async {
        let adapter = PushNotificationSettingsStoreTestAdapter()
        let date = makeDate(hour: 18, minute: 0)
        await adapter.setPushNotificationTime(view: date)
        await adapter.setShowTimePicker(true)
        #expect(adapter.showTimePicker)
        #expect(adapter.sheetPushNotificationTime == date)
    }

    @Test("시트 시간 변경은 확정 전까지 화면 시간을 변경하지 않는다")
    func 시트_시간_변경은_확정_전까지_화면_시간을_변경하지_않는다() async {
        let adapter = PushNotificationSettingsStoreTestAdapter()
        let viewDate = makeDate(hour: 9, minute: 0)
        let sheetDate = makeDate(hour: 10, minute: 35)

        await adapter.setPushNotificationTime(view: viewDate)
        await adapter.setShowTimePicker(true)
        await adapter.setPushNotificationTime(sheet: sheetDate)

        #expect(adapter.viewPushNotificationTime == viewDate)
        #expect(adapter.sheetPushNotificationTime == sheetDate)
    }

    @Test("confirmUpdate는 시트 시간을 화면 시간에 반영하고 시트를 닫는다")
    func confirmUpdate는_시트_시간을_화면_시간에_반영하고_시트를_닫는다() async {
        let adapter = PushNotificationSettingsStoreTestAdapter()
        let viewDate = makeDate(hour: 9, minute: 0)
        let sheetDate = makeDate(hour: 10, minute: 35)

        await adapter.setPushNotificationTime(view: viewDate)
        await adapter.setShowTimePicker(true)
        await adapter.setPushNotificationTime(sheet: sheetDate)
        await adapter.confirmUpdate()

        #expect(!adapter.showTimePicker)
        #expect(adapter.viewPushNotificationTime == sheetDate)
        #expect(adapter.sheetPushNotificationTime == sheetDate)
    }

    @Test("rollbackUpdate는 화면 시간을 유지하고 시트를 닫는다")
    func rollbackUpdate는_화면_시간을_유지하고_시트를_닫는다() async {
        let adapter = PushNotificationSettingsStoreTestAdapter()
        let viewDate = makeDate(hour: 9, minute: 0)
        let sheetDate = makeDate(hour: 10, minute: 35)

        await adapter.setPushNotificationTime(view: viewDate)
        await adapter.setShowTimePicker(true)
        await adapter.setPushNotificationTime(sheet: sheetDate)
        await adapter.rollbackUpdate()

        #expect(!adapter.showTimePicker)
        #expect(adapter.viewPushNotificationTime == viewDate)
        #expect(adapter.sheetPushNotificationTime == viewDate)
    }

    @Test("setSheetHeight는 시트 높이 상태를 변경한다")
    func setSheetHeight는_시트_높이_상태를_변경한다() async {
        let adapter = PushNotificationSettingsStoreTestAdapter()
        await adapter.setShowTimePicker(true)
        await adapter.setSheetHeight(240)
        #expect(adapter.sheetHeight == 240)
    }

    @Test("푸시 설정 조회가 지연되면 로딩 상태를 표시하고 완료되면 해제한다")
    func 푸시_설정_조회가_지연되면_로딩_상태를_표시하고_완료되면_해제한다() async {
        let clock = TestClock()
        let fetchSpy = FetchPushSettingsUseCaseSpy()
        fetchSpy.shouldSuspend = true
        let adapter = PushNotificationSettingsStoreTestAdapter(
            fetchUseCase: fetchSpy,
            configureDependencies: {
                $0.continuousClock = clock
            }
        )

        await adapter.fetchSettings()

        #expect(fetchSpy.executeCallCount == 1)
        #expect(!adapter.isLoading)

        await clock.advance(by: .milliseconds(300))
        await adapter.receiveDelayedLoading()

        #expect(adapter.isLoading)
        #expect(adapter.activeLoadingRow == .enable)

        fetchSpy.resume()
        await adapter.drainReceivedActions()

        #expect(!adapter.isLoading)
        #expect(adapter.activeLoadingRow == nil)
        #expect(adapter.pushNotificationHour == 9)
    }

    @Test("프리셋 시간 업데이트가 지연되면 해당 시간 row에 로딩 상태를 표시한다")
    func 프리셋_시간_업데이트가_지연되면_해당_시간_row에_로딩_상태를_표시한다() async {
        let clock = TestClock()
        let updateSpy = UpdatePushSettingsUseCaseSpy()
        updateSpy.shouldSuspend = true
        let adapter = PushNotificationSettingsStoreTestAdapter(
            updateUseCase: updateSpy,
            configureDependencies: {
                $0.continuousClock = clock
            }
        )
        let date = makeDate(hour: 15, minute: 0)

        await adapter.selectPresetTime(date)

        #expect(updateSpy.executeCallCount == 1)
        #expect(adapter.activeLoadingRow == .presetTime(hour: 15, minute: 0))
        #expect(!adapter.isLoading)

        await clock.advance(by: .milliseconds(300))
        await adapter.receiveDelayedLoading()

        #expect(adapter.isLoading)
        #expect(adapter.activeLoadingRow == .presetTime(hour: 15, minute: 0))

        updateSpy.resume()
        await adapter.drainReceivedActions()

        #expect(!adapter.isLoading)
        #expect(adapter.activeLoadingRow == nil)
    }

    @Test("커스텀 시간 업데이트가 지연되면 시트를 유지하고 Done 버튼 로딩 상태를 표시한다")
    func 커스텀_시간_업데이트가_지연되면_시트를_유지하고_Done_버튼_로딩_상태를_표시한다() async {
        let clock = TestClock()
        let updateSpy = UpdatePushSettingsUseCaseSpy()
        updateSpy.shouldSuspend = true
        let adapter = PushNotificationSettingsStoreTestAdapter(
            updateUseCase: updateSpy,
            configureDependencies: {
                $0.continuousClock = clock
            }
        )
        let date = makeDate(hour: 10, minute: 35)

        await adapter.setShowTimePicker(true)
        await adapter.setPushNotificationTime(sheet: date)
        await adapter.confirmUpdate()

        #expect(adapter.showTimePicker)
        #expect(adapter.activeLoadingRow == .customTime)
        #expect(!adapter.isLoading)

        await clock.advance(by: .milliseconds(300))
        await adapter.receiveDelayedLoading()

        #expect(adapter.showTimePicker)
        #expect(adapter.isLoading)
        #expect(adapter.activeLoadingRow == .customTime)

        updateSpy.resume()
        await adapter.drainReceivedActions()

        #expect(!adapter.showTimePicker)
        #expect(!adapter.isLoading)
        #expect(adapter.activeLoadingRow == nil)
    }

    @Test("푸시 설정 조회에 실패하면 공통 에러 알림을 표시한다")
    func 푸시_설정_조회에_실패하면_공통_에러_알림을_표시한다() async {
        let fetchSpy = FetchPushSettingsUseCaseSpy()
        fetchSpy.error = PushNotificationSettingsTestError.failure
        let adapter = PushNotificationSettingsStoreTestAdapter(fetchUseCase: fetchSpy)

        await adapter.fetchSettings()

        #expect(adapter.alert == expectedPushNotificationSettingsErrorAlert())
    }

    @Test("설정 업데이트에 실패하면 알림을 표시하고 서버 상태로 되돌린다")
    func 설정_업데이트에_실패하면_알림을_표시하고_서버_상태로_되돌린다() async {
        let fetchSpy = FetchPushSettingsUseCaseSpy(
            settings: makePushNotificationSettings(isEnabled: true, hour: 9, minute: 0)
        )
        let updateSpy = UpdatePushSettingsUseCaseSpy()
        updateSpy.error = PushNotificationSettingsTestError.failure
        let adapter = PushNotificationSettingsStoreTestAdapter(
            fetchUseCase: fetchSpy,
            updateUseCase: updateSpy
        )
        let date = makeDate(hour: 21, minute: 0)

        await adapter.selectPresetTime(date)

        #expect(adapter.alert == expectedPushNotificationSettingsErrorAlert())
        #expect(adapter.pushNotificationEnable)
        #expect(adapter.pushNotificationHour == 9)
        #expect(adapter.pushNotificationMinute == 0)
    }
}

@MainActor
private struct PushNotificationSettingsStoreTestAdapter {
    private let store: TestStoreOf<PushNotificationSettingsFeature>

    var pushNotificationEnable: Bool { store.state.pushNotificationEnable }
    var viewPushNotificationTime: Date { store.state.viewPushNotificationTime }
    var sheetPushNotificationTime: Date { store.state.timePicker?.time ?? store.state.viewPushNotificationTime }
    var showTimePicker: Bool { store.state.timePicker != nil }
    var isLoading: Bool { store.state.isLoading }
    var activeLoadingRow: PushNotificationSettingsFeature.ActiveLoadingRow? { store.state.activeLoadingRow }
    var sheetHeight: CGFloat { store.state.timePicker?.height ?? .pi }
    var alert: AlertState<Never>? { store.state.alert }
    var pushNotificationHour: Int { store.state.pushNotificationHour }
    var pushNotificationMinute: Int { store.state.pushNotificationMinute }

    init(
        fetchUseCase: FetchPushSettingsUseCase = FetchPushSettingsUseCaseSpy(),
        updateUseCase: UpdatePushSettingsUseCase = UpdatePushSettingsUseCaseSpy(),
        configureDependencies: ((inout DependencyValues) -> Void)? = nil
    ) {
        store = TestStore(initialState: PushNotificationSettingsFeature.State()) {
            PushNotificationSettingsFeature()
        } withDependencies: {
            $0.fetchPushSettingsUseCase = fetchUseCase
            $0.updatePushSettingsUseCase = updateUseCase
            $0.continuousClock = ContinuousClock()
            configureDependencies?(&$0)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
    }

    func fetchSettings() async {
        await store.send(.fetchSettings)
        await drainReceivedActions()
    }

    func setPushNotificationEnable(_ value: Bool) async {
        await store.send(.binding(.set(\.pushNotificationEnable, value))) {
            $0.pushNotificationEnable = value
        }
        await drainReceivedActions()
    }

    func setPushNotificationTime(view: Date?) async {
        guard let view else { return }
        await store.send(.binding(.set(\.viewPushNotificationTime, view))) {
            $0.viewPushNotificationTime = view
            $0.timePicker?.time = view
        }
    }

    func setPushNotificationTime(sheet: Date?) async {
        guard let sheet else { return }
        await store.send(.timePicker(.presented(.binding(.set(\.time, sheet))))) {
            $0.timePicker?.time = sheet
        }
    }

    func setShowTimePicker(_ value: Bool) async {
        if value {
            await store.send(.tapCustomTime) {
                $0.timePicker = PushNotificationSettingsFeature.TimePickerState(
                    time: $0.viewPushNotificationTime
                )
            }
        } else {
            await store.send(.timePicker(.dismiss)) {
                $0.timePicker = nil
            }
        }
    }

    func setSheetHeight(_ value: CGFloat) async {
        await store.send(.timePicker(.presented(.binding(.set(\.height, value))))) {
            $0.timePicker?.height = value
        }
    }

    func selectPresetTime(_ date: Date) async {
        await store.send(.selectPresetTime(date)) {
            $0.viewPushNotificationTime = date
            $0.timePicker?.time = date
        }
        await drainReceivedActions()
    }

    func confirmUpdate() async {
        let time = store.state.timePicker?.time
        await store.send(.timePicker(.presented(.tapDoneButton))) {
            if let time {
                $0.viewPushNotificationTime = time
            }
            $0.activeLoadingRow = .customTime
        }
        await drainReceivedActions()
    }

    func rollbackUpdate() async {
        await store.send(.timePicker(.presented(.tapCloseButton))) {
            $0.timePicker = nil
        }
    }

    func receiveDelayedLoading() async {
        let target = LoadingFeature.Target.default
        await store.receive(\.loading.delayedLoadingDidBecomeVisible, target) {
            $0.loading.scheduledDelayedTargets = []
            $0.loading.visibleDelayedTargets = [target]
            $0.loading.visibleTargets = [target]
            $0.loading.isLoading = true
        }
    }

    func drainReceivedActions() async {
        await store.skipReceivedActions(strict: false)
        await store.skipReceivedActions(strict: false)
        await store.skipReceivedActions(strict: false)
    }
}

private final class FetchPushSettingsUseCaseSpy: FetchPushSettingsUseCase {
    var settings: PushNotificationSettings
    var error: Error?
    var shouldSuspend = false
    private(set) var executeCallCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var shouldResume = false

    init(settings: PushNotificationSettings = makePushNotificationSettings()) {
        self.settings = settings
    }

    func execute() async throws -> PushNotificationSettings {
        executeCallCount += 1

        if shouldSuspend {
            await withCheckedContinuation { continuation in
                if shouldResume {
                    shouldResume = false
                    continuation.resume()
                } else {
                    self.continuation = continuation
                }
            }
        }

        if let error {
            throw error
        }

        return settings
    }

    func resume() {
        guard let continuation else {
            shouldResume = true
            return
        }

        self.continuation = nil
        continuation.resume()
    }
}

private final class UpdatePushSettingsUseCaseSpy: UpdatePushSettingsUseCase {
    var error: Error?
    var shouldSuspend = false
    private(set) var executeCallCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var shouldResume = false

    func execute(_: PushNotificationSettings) async throws {
        executeCallCount += 1

        if shouldSuspend {
            await withCheckedContinuation { continuation in
                if shouldResume {
                    shouldResume = false
                    continuation.resume()
                } else {
                    self.continuation = continuation
                }
            }
        }

        if let error {
            self.error = nil
            throw error
        }
    }

    func resume() {
        guard let continuation else {
            shouldResume = true
            return
        }

        self.continuation = nil
        continuation.resume()
    }
}

private enum PushNotificationSettingsTestError: Error {
    case failure
}

private func makePushNotificationSettings(
    isEnabled: Bool = true,
    hour: Int = 9,
    minute: Int = 0
) -> PushNotificationSettings {
    PushNotificationSettings(
        isEnabled: isEnabled,
        scheduledTime: DateComponents(hour: hour, minute: minute)
    )
}

private func makeDate(
    hour: Int,
    minute: Int
) -> Date {
    let baseDate = Date(timeIntervalSince1970: 0)
    return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? baseDate
}

private func expectedPushNotificationSettingsErrorAlert() -> AlertState<Never> {
    AlertState {
        TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
    } actions: {
        ButtonState(role: .cancel) {
            TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
        }
    } message: {
        TextState(String(localized: "common_error_message", bundle: PresentationResources.bundle))
    }
}
