//
//  PushNotificationSettingsView.swift
//  ProfileTab
//
//  Created by opfic on 5/14/25.
//

import SwiftUI
import PresentationShared

struct PushNotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.deviceType) private var deviceType
    @Environment(\.isTabContentActive) private var isTabContentActive
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @State var store: StoreOf<PushNotificationSettingsFeature>
    // 설정 옆 칸에 넣은 화면은 뒤로 갈 곳이 없어 칸 제목 줄의 뒤로 버튼 생략
    var isPaneDetail = false
    // 앱 화면과 분리한 Mac 설정 화면은 위쪽 줄을 직접 그려 화면 제목 줄 생략
    var showsTopBar = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 24) {
                EnableCard(store: store)
                TimeCard(store: store)
            }
            // Mac 설정 화면은 묶음마다 보드의 위아래 8, 좌우 14 여백
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 24)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // 위쪽 줄 구분선과 첫 항목 사이 여백
        .contentMargins(
            .top,
            isiOSAppOnMac ? 20 * AdaptiveSize.boardScale : showsPaneTitleBar ? 24 : 12,
            for: .scrollContent
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsTopBar {
                topBar
            }
        }
        .background(Color.background)
        .duoToolbarVisibility(showsBackButton: true)
        .onAppear { store.send(.fetchSettings) }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .prominentSheet(
            item: $store.scope(state: \.timePicker, action: \.timePicker)
                .activePresentation(when: isTabContentActive)
        ) { timePickerStore in
            TimePickerView(
                store: timePickerStore,
                showsProgressView: store.isLoading && store.activeLoadingRow == .customTime
            )
        }
    }

    @ViewBuilder
    private var topBar: some View {
        let title = Text(String(localized: "nav_push_settings", bundle: PresentationResources.bundle))

        if showsPaneTitleBar {
            // 일반 화면에서 밀어 넣은 화면이 칸 화면으로 바뀌어도 뒤로 갈 수 있게 뒤로 버튼 표시
            PaneTitleBar(title, onBack: isPaneDetail ? nil : { dismiss() }, showsBackOnDesktop: true)
        } else {
            // OS와 상관없이 같은 모양인 가운데 제목과 아래 구분선
            ZStack {
                title
                    .font(.adaptive(.callout).bold())
                HStack {
                    // Duo는 세로 막대의 뒤로 버튼 사용
                    if deviceType != .duo {
                        NavigationBackButton(action: { dismiss() })
                    }
                    Spacer()
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
}

private struct EnableCard: View {
    @Bindable var store: StoreOf<PushNotificationSettingsFeature>

    var body: some View {
        DesktopSettingsSection(footer: Text("push_settings_footer", bundle: PresentationResources.bundle)) {
            DesktopSettingsRow(
                symbolName: "bell",
                symbolColor: .tintLabel,
                title: Text("push_settings_enable", bundle: PresentationResources.bundle)
            ) {
                toggle
            }
        }
    }

    @ViewBuilder
    private var toggle: some View {
        if store.isLoading && store.activeLoadingRow == .enable {
            ProgressView()
        } else {
            Toggle("", isOn: $store.pushNotificationEnable)
                .labelsHidden()
                .toggleStyle(.pill)
                .disabled(store.activeLoadingRow != nil)
        }
    }
}

private struct TimeCard: View {
    @Environment(\.locale) private var locale
    let store: StoreOf<PushNotificationSettingsFeature>

    private static let presetHours = [9, 15, 18, 21]

    var body: some View {
        DesktopSettingsSection(
            header: Text("push_settings_time_section", bundle: PresentationResources.bundle),
            footer: Text("push_settings_custom_hint", bundle: PresentationResources.bundle)
        ) {
            ForEach(Self.presetHours, id: \.self) { hour in
                if let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
                    presetTimeButton(date, hour: hour)
                }
            }
            customTimeButton
        }
        .disabled(!store.pushNotificationEnable || store.activeLoadingRow != nil)
        .opacity(store.pushNotificationEnable ? 1.0 : 0.7)
    }

    private func presetTimeButton(_ date: Date, hour: Int) -> some View {
        let loadingRow = PushNotificationSettingsFeature.activeLoadingRow(for: date)
        let isSelected = store.activeLoadingRow != loadingRow
            && store.pushNotificationHour == hour
            && store.pushNotificationMinute == 0

        return Button {
            store.send(.selectPresetTime(date))
        } label: {
            DesktopSettingsRow(title: Text(formattedTimeString(date))) {
                if let loadingRow,
                   store.isLoading && store.activeLoadingRow == loadingRow {
                    ProgressView()
                } else {
                    SettingsCheck(isSelected: isSelected)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var customTimeButton: some View {
        Button {
            store.send(.tapCustomTime)
        } label: {
            // 사용자 설정 시간은 고른 경우에만 선택 원 표시
            DesktopSettingsRow(title: Text("push_settings_custom", bundle: PresentationResources.bundle)) {
                if store.isLoading && store.activeLoadingRow == .customTime {
                    ProgressView()
                } else if store.pushNotificationMinute != 0 {
                    SettingsCheck(isSelected: true)
                }
                Text(formattedTimeString(store.viewPushNotificationTime))
                    .foregroundStyle(Color.secondaryLabel)
                Image(systemName: "chevron.right")
                    .font(.adaptive(.footnote).weight(.semibold))
                    .foregroundStyle(Color.secondaryLabel)
            }
        }
        .buttonStyle(.plain)
    }

    private func formattedTimeString(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }
}

private struct TimePickerView: View {
    @Bindable var store: Store<
        PushNotificationSettingsFeature.TimePickerState,
        PushNotificationSettingsFeature.Action.TimePicker
    >
    let showsProgressView: Bool

    var body: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $store.time,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .onAppear { UIDatePicker.appearance().minuteInterval = 5 }
            .onDisappear { UIDatePicker.appearance().minuteInterval = 1 /* 기본값으로 복원 */ }
            .toolbar {
                ToolbarLeadingButton {
                    store.send(.tapCloseButton)
                }
                if showsProgressView {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                            .topBarProgressStyle()
                    }
                    .sharedBackgroundHidden()
                } else {
                    ToolbarTrailingButton {
                        store.send(.tapDoneButton)
                    }
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        store.send(.binding(.set(\.height, geometry.size.height)))
                    }
                }
            )
        }
        .sheetDetent(.height(store.height))
        .sheetGrabberHidden()
    }
}
