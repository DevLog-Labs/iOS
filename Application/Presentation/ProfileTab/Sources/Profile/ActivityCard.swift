//
//  ActivityCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import Core
import Domain
import PresentationShared

struct ActivityCard: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: StoreOf<ProfileFeature>
    let onSelectTodoID: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(localized: "profile_quarterly_activity", bundle: PresentationResources.bundle))
                    .font(.headline)
                Spacer()
                if !store.isViewingCurrentQuarter {
                    Button {
                        store.send(.moveToCurrentQuarter)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .bold()
                            .foregroundStyle(Color.accent)
                    }
                    .buttonStyle(.plain)
                }
                Menu {
                    ForEach(ActivityKindItem.selectableItems) { activityKindItem in
                        if let activityKind = ActivityKind(rawValue: activityKindItem.rawValue) {
                            switch activityKind {
                            case .created:
                                Toggle(activityKindItem.title, isOn: $store.isCreatedActivitySelected)
                                    .disabled(store.isCreatedActivityToggleDisabled)
                            case .completed:
                                Toggle(activityKindItem.title, isOn: $store.isCompletedActivitySelected)
                                    .disabled(store.isCompletedActivityToggleDisabled)
                            case .deleted:
                                Toggle(activityKindItem.title, isOn: $store.isDeletedActivitySelected)
                                    .disabled(store.isDeletedActivityToggleDisabled)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .bold()
                        .foregroundStyle(Color.accent)
                }
            }

            HStack {
                Button {
                    store.send(.moveQuarter(-1))
                } label: {
                    Image(systemName: "chevron.left")
                }
                .tint(Color.accent)
                .disabled(!store.canMoveToPreviousQuarter)
                Spacer()
                Button {
                    store.send(.openQuarterPicker)
                } label: {
                    HStack(spacing: 4) {
                        Text(store.quarterTitle)
                            .font(.subheadline)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    store.send(.moveQuarter(1))
                } label: {
                    Image(systemName: "chevron.right")
                }
                .tint(Color.accent)
                .disabled(!store.canMoveToNextQuarter)
            }

            if let quarter = store.activityQuarter {
                HeatmapView(
                    quarter: quarter,
                    selectedActivityKinds: store.selectedActivityKinds,
                    selectedDay: store.selectedDay,
                    onSelectDay: { store.send(.selectDay($0)) }
                )
                if let selectedDay = store.selectedDay {
                    selectedDayDetailSection(for: selectedDay)
                }
            }
        }
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func selectedDayDetailSection(for day: HeatmapDay) -> some View {
        let activities = store.selectedDayActivities

        VStack(alignment: .leading, spacing: 12) {
            Text(day.date.formatted(.dateTime.year().month(.wide).day()))
                .font(.subheadline)
                .bold()

            if activities.isEmpty {
                Text(String(localized: "profile_activity_none", bundle: PresentationResources.bundle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(activities) { activity in
                    Button {
                        selectActivity(activity)
                    } label: {
                        let item = TodoCategoryItem(from: activity.category)
                        let rowColor = activity.isDeleted ? Color.secondary : .primary
                        HStack(spacing: 8) {
                            Image(systemName: item.symbolName)
                                .foregroundStyle(item.color)
                                .frame(width: 20)
                            Text(activity.title)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(rowColor)
                            Text("#\(activity.number)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(activity.activityKindItems) { item in
                                Text(item.title)
                                    .font(.caption2)
                                    .foregroundStyle(item.badgeColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(item.badgeColor.opacity(0.14))
                                    )
                            }
                            Spacer()
                            // Mac은 옆 칸에 상세를 열어 화면 이동 표시 생략
                            if !activity.isDeleted, !isiOSAppOnMac {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(.rect)
                        // 행 배치를 바꾸지 않고 선택한 행 배경만 바깥으로 넓힘
                        .background {
                            if store.selectedTodoRoute == .activity(activity.todoId) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primaryContainer)
                                    .padding(.horizontal, -8)
                                    .padding(.vertical, -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(activity.isDeleted)
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.top, 4)
    }

    private func selectActivity(_ activity: HeatmapActivityItem) {
        guard !activity.isDeleted else { return }
        onSelectTodoID(activity.todoId)
    }
}

struct QuarterPickerSheet: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(String(localized: "profile_year", bundle: PresentationResources.bundle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker(
                        "",
                        selection: $store.selectedQuarterPickerYear
                    ) {
                        ForEach(store.availableQuarterYears, id: \.self) { year in
                            Text(verbatim: String(year))
                                .tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(1...4, id: \.self) { quarter in
                        quarterSelectionButton(for: quarter)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(String(localized: "profile_select_quarter", bundle: PresentationResources.bundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarTrailingButton {
                    store.send(.setQuarterPickerPresented(false))
                }
            }
        }
        .presentationDetents([.fraction(0.3)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func quarterSelectionButton(for quarter: Int) -> some View {
        let quarterStart = store.state.quarterStartForPicker(quarter: quarter)
        let isEnabled = store.state.isQuarterSelectableForPicker(quarter)
        let isSelected = store.state.isQuarterSelectedForPicker(quarter)

        Button {
            guard let quarterStart else { return }
            store.send(.selectQuarter(quarterStart))
        } label: {
            Text(
                String.localizedStringWithFormat(
                    String(localized: "profile_quarter_format", bundle: PresentationResources.bundle),
                    Int64(quarter)
                )
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accent : Color.surfaceSecondary)
            )
            .foregroundStyle(isSelected ? .white : isEnabled ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
