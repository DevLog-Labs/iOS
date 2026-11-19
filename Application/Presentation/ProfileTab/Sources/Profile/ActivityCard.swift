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
    @Environment(\.isTabContentActive) private var isTabContentActive
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: StoreOf<ProfileFeature>
    let onSelectTodoID: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileSectionHeader(
                Text(String(localized: "profile_quarterly_activity", bundle: PresentationResources.bundle))
            ) {
                if !store.isViewingCurrentQuarter {
                    Button {
                        store.send(.moveToCurrentQuarter)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundStyle(Color.tintLabel)
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
                        .foregroundStyle(Color.tintLabel)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        store.send(.moveQuarter(-1))
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.adaptive(.body))
                    }
                    .tint(Color.tintLabel)
                    .disabled(!store.canMoveToPreviousQuarter)
                    Spacer()
                    Button {
                        store.send(.openQuarterPicker)
                    } label: {
                        HStack(spacing: 4) {
                            Text(store.quarterTitle)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.adaptive(.caption2))
                        }
                        .foregroundStyle(Color.label)
                    }
                    .buttonStyle(.plain)
                    // 칸으로 나눈 화면은 분기 선택을 시트 대신 버튼 옆 팝오버로 표시
                    .popover(
                        isPresented: $store.showQuarterPicker
                            .hiddenInPane(!usesPaneLayout)
                            .activePresentation(when: isTabContentActive),
                        // Mac은 분기 표시 아래로 표시
                        arrowEdge: isiOSAppOnMac ? .top : nil
                    ) {
                        QuarterPickerSheet(store: store)
                            .frame(width: 320 * AdaptiveSize.boardScale)
                            .fixedSize(horizontal: false, vertical: true)
                            .presentationBackground(Color.secondaryBackground)
                            .presentationCompactAdaptation(.popover)
                    }
                    Spacer()
                    Button {
                        store.send(.moveQuarter(1))
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.adaptive(.body))
                    }
                    .tint(Color.tintLabel)
                    .disabled(!store.canMoveToNextQuarter)
                }
                .font(.adaptive(.footnote))
                .padding(.bottom, 6)

                if let quarter = store.activityQuarter {
                    HeatmapView(
                        quarter: quarter,
                        selectedActivityKinds: store.selectedActivityKinds,
                        selectedDay: store.selectedDay,
                        onSelectDay: { store.send(.selectDay($0)) }
                    )
                    .padding(.top, 4)
                    .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
                    if let selectedDay = store.selectedDay {
                        selectedDayDetailSection(for: selectedDay)
                            .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
                    }
                }
            }
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        }
    }

    @ViewBuilder
    private func selectedDayDetailSection(for day: HeatmapDay) -> some View {
        let activities = store.selectedDayActivities

        VStack(alignment: .leading, spacing: 12) {
            Text(day.date.formatted(.dateTime.year().month(.wide).day()))
                .font(.adaptive(.subheadline))
                .bold()

            if activities.isEmpty {
                Text(String(localized: "profile_activity_none", bundle: PresentationResources.bundle))
                    .font(.adaptive(.caption))
                    .foregroundStyle(Color.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(activities) { activity in
                    Button {
                        selectActivity(activity)
                    } label: {
                        let item = TodoCategoryItem(from: activity.category)
                        let rowColor = activity.isDeleted ? Color.secondaryLabel : .label
                        HStack(spacing: 8) {
                            Image(systemName: item.symbolName)
                                .foregroundStyle(item.color)
                                .frame(width: 20)
                            Text(activity.title)
                                .font(.adaptive(.caption))
                                .lineLimit(1)
                                .foregroundStyle(rowColor)
                            Text("#\(activity.number)")
                                .font(.adaptive(.caption))
                                .foregroundStyle(Color.secondaryLabel)
                            ForEach(activity.activityKindItems) { item in
                                Text(item.title)
                                    .font(.adaptive(.caption2))
                                    .foregroundStyle(item.badgeColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.badge)
                                            .fill(item.badgeColor.opacity(0.14))
                                    )
                            }
                            Spacer()
                            // 칸 화면은 옆 칸에 상세를 열어 화면 이동 표시 생략
                            if !activity.isDeleted, !usesPaneLayout {
                                Image(systemName: "chevron.right")
                                    .font(.adaptive(.caption).weight(.semibold))
                                    .foregroundStyle(Color.tertiaryLabel)
                            }
                        }
                        .contentShape(.rect)
                        // 행 배치를 바꾸지 않고 선택한 행 배경만 바깥으로 넓힘
                        // 선택 표시는 다른 목록 행과 같은 회색
                        .background {
                            if usesPaneLayout && store.selectedTodoRoute == .activity(activity.todoId) {
                                RoundedRectangle(cornerRadius: CornerRadius.control)
                                    .fill(Color.fill)
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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        // 칸으로 나눈 iPad 화면의 팝오버도 Mac과 같은 배치, 크기만 손가락 기준
        if isiOSAppOnMac || usesPaneLayout {
            desktopContent
        } else {
            mobileContent
        }
    }

    // Mac·iPad 넓은 화면 분기 선택 팝오버
    // 위쪽 제목·완료 줄, 바탕 없는 연도 행, 1~4분기 두 줄 격자 배치
    private var desktopContent: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(String(localized: "profile_select_quarter", bundle: PresentationResources.bundle))
                    .font(.system(size: isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 17, weight: .bold))
                HStack {
                    Spacer()
                    Button {
                        store.send(.setQuarterPickerPresented(false))
                    } label: {
                        Text(String(localized: "common_done", bundle: PresentationResources.bundle))
                            .font(.adaptive(isiOSAppOnMac ? .body : .callout).bold())
                            .foregroundStyle(Color.tintLabel)
                            .padding(.horizontal, 4 * AdaptiveSize.boardScale)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10 * AdaptiveSize.boardScale)
            .frame(height: isiOSAppOnMac ? 44 * AdaptiveSize.boardScale : 52)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.separator)
                    .frame(height: 1)
            }

            Menu {
                Picker("", selection: $store.selectedQuarterPickerYear) {
                    ForEach(store.availableQuarterYears, id: \.self) { year in
                        Text(verbatim: String(year))
                            .tag(year)
                    }
                }
            } label: {
                HStack(spacing: 10 * AdaptiveSize.boardScale) {
                    Text(String(localized: "profile_year", bundle: PresentationResources.bundle))
                        .foregroundStyle(Color.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: String(store.selectedQuarterPickerYear))
                        .foregroundStyle(Color.secondaryLabel)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.adaptive(.caption2))
                        .foregroundStyle(Color.secondaryLabel)
                }
                .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                .frame(minHeight: isiOSAppOnMac ? 38 * AdaptiveSize.boardScale : 50)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8 * AdaptiveSize.boardScale), count: 2),
                spacing: 8 * AdaptiveSize.boardScale
            ) {
                ForEach(1...4, id: \.self) { quarter in
                    desktopQuarterButton(for: quarter)
                }
            }
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.top, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
            .padding(.bottom, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        }
    }

    private var mobileContent: some View {
        // 팝오버가 Duo 상태 표시 영역과 겹치면 시스템 제목 줄이 그만큼 내려가므로 제목 줄을 직접 그림
        // OS와 상관없이 같은 모양인 글자 완료 버튼과 가운데 제목, 아래 구분선
        VStack(spacing: 0) {
            ZStack {
                Text(String(localized: "profile_select_quarter", bundle: PresentationResources.bundle))
                    .font(.adaptive(.callout).bold())
                HStack {
                    Spacer()
                    Button {
                        store.send(.setQuarterPickerPresented(false))
                    } label: {
                        Text(String(localized: "common_done", bundle: PresentationResources.bundle))
                            .font(.adaptive(.callout).weight(.medium))
                            .foregroundStyle(Color.tintLabel)
                            .padding(.horizontal, 4)
                            .frame(maxHeight: .infinity)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 48)
            .padding(.horizontal, 8)
            .overlay(alignment: .bottom) {
                Divider().overlay(Color.secondarySeparator)
            }
            // 손잡이 아래부터 위쪽 줄을 둠
            .padding(.top, 11)

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(String(localized: "profile_year", bundle: PresentationResources.bundle))
                        .font(.adaptive(.subheadline))
                        .foregroundStyle(Color.secondaryLabel)
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
        }
        .sheetDetent(.fraction(0.3))
    }

    // 고른 분기는 강조색 테두리와 옅은 바탕, 고를 수 없는 분기는 흐린 글자
    private func desktopQuarterButton(for quarter: Int) -> some View {
        let quarterStart = store.state.quarterStartForPicker(quarter: quarter)
        let isEnabled = store.state.isQuarterSelectableForPicker(quarter)
        let isSelected = store.state.isQuarterSelectedForPicker(quarter)
        let shape = RoundedRectangle(cornerRadius: CornerRadius.control)

        return Button {
            guard let quarterStart else { return }
            store.send(.selectQuarter(quarterStart))
        } label: {
            Text(
                String.localizedStringWithFormat(
                    String(localized: "profile_quarter_format", bundle: PresentationResources.bundle),
                    Int64(quarter)
                )
            )
            .font(.adaptive(isiOSAppOnMac ? .body : .subheadline).weight(.semibold))
            .foregroundStyle(isSelected ? Color.tintLabel : isEnabled ? .label : .tertiaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14 * AdaptiveSize.boardScale)
            .background(isSelected ? Color.tintFill : .tertiaryBackground, in: shape)
            .overlay {
                shape.strokeBorder(isSelected ? Color.accent : .secondarySeparator)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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
            .font(.adaptive(.subheadline).weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.control)
                    .fill(isSelected ? Color.accent : Color.tertiaryBackground)
            )
            .foregroundStyle(isSelected ? Color.white : isEnabled ? .label : .secondaryLabel)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
