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
    @State var store: StoreOf<PushNotificationSettingsFeature>

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                EnableCard(store: store)

                VStack(alignment: .leading, spacing: 12) {
                    Text("push_settings_time_section", bundle: PresentationResources.bundle)
                        .font(.title3.weight(.semibold))
                    TimeCard(store: store)
                }

                CustomTimeTipCard()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.appBackground)
        .duoToolbarVisibility()
        .onAppear { store.send(.fetchSettings) }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .sheet(
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
            PaneTitleBar(title)
        } else {
            ZStack {
                title
                    .font(.headline)

                if deviceType != .duo {
                    HStack {
                        NavigationBackButton(action: { dismiss() })
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: readableContentWidth)
            .padding(.top, windowControlsInset)
            .padding(.bottom, 12)
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground)
        }
    }
}

private struct EnableCard: View {
    @Bindable var store: StoreOf<PushNotificationSettingsFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "bell")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .iconStyle(color: .accent, in: Circle())

                Text("push_settings_enable", bundle: PresentationResources.bundle)
                    .font(.title3)

                Spacer(minLength: 8)

                if store.isLoading && store.activeLoadingRow == .enable {
                    ProgressView()
                } else {
                    Toggle("", isOn: $store.pushNotificationEnable)
                        .labelsHidden()
                        .tint(.accent)
                        .disabled(store.activeLoadingRow != nil)
                }
            }

            Divider().overlay(Color.border)

            Text("push_settings_footer", bundle: PresentationResources.bundle)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupBackground(in: .rect(cornerRadius: 16))
    }
}

private struct TimeCard: View {
    @Environment(\.locale) private var locale
    let store: StoreOf<PushNotificationSettingsFeature>

    private static let presetHours = [9, 15, 18, 21]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Self.presetHours, id: \.self) { hour in
                if let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
                    presetTimeButton(date, hour: hour)
                    Divider().overlay(Color.border)
                }
            }
            customTimeButton
        }
        .groupBackground(in: .rect(cornerRadius: 16))
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
            HStack {
                Text(formattedTimeString(date))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if let loadingRow,
                   store.isLoading && store.activeLoadingRow == loadingRow {
                    ProgressView()
                } else {
                    selectionIndicator(isSelected: isSelected)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var customTimeButton: some View {
        Button {
            store.send(.tapCustomTime)
        } label: {
            HStack(spacing: 8) {
                Text("push_settings_custom", bundle: PresentationResources.bundle)
                    .foregroundStyle(Color.textPrimary)
                Spacer(minLength: 8)
                if store.isLoading && store.activeLoadingRow == .customTime {
                    ProgressView()
                } else {
                    selectionIndicator(isSelected: store.pushNotificationMinute != 0)
                }
                Text(formattedTimeString(store.viewPushNotificationTime))
                    .foregroundStyle(Color.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func selectionIndicator(isSelected: Bool) -> some View {
        if isSelected {
            ZStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(Color.accent)
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.white)
            }
            .font(.title2)
        } else {
            Image(systemName: "circle")
                .font(.title2)
                .foregroundStyle(Color.border)
        }
    }

    private func formattedTimeString(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }
}

private struct CustomTimeTipCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info")
                .font(.caption.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(Color.surface, in: Circle())
            Text("push_settings_custom_hint", bundle: PresentationResources.bundle)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color.accent)
        .padding(16)
        .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 16))
        .padding(.bottom, 16)
        .background(Color.appBackground)
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
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                    }
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
        .presentationDragIndicator(.hidden)
        .presentationDetents([.height(store.height)])
    }
}
