//
//  TodoSection.swift
//  TodayTab
//
//  Created by opfic on 9/13/26.
//

import SwiftUI
import Core
import PresentationShared

struct TodoSection: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let section: TodayFeature.SectionContent
    let isNavigationEnabled: Bool
    let highlightedTodoIds: [String]
    let onSelect: (TodayTodoItem) -> Void
    let onInspect: (TodayTodoItem) -> Void
    let onHover: (TodayTodoItem, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(section.title)
                    .font(.adaptive(.subheadline).bold())
                    .foregroundStyle(section.category.accentColor)
                Text("\(section.items.count)")
                    .font(.adaptive(.subheadline).weight(.medium))
                    .foregroundStyle(Color.secondaryLabel)
                Spacer()
                if section.category == .overdue {
                    Text(String(localized: "today_pinned_first", bundle: PresentationResources.bundle))
                        .font(.adaptive(.caption).weight(.medium))
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.top, isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 20)
            .padding(.bottom, isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 10)

            LazyVStack(spacing: 0) {
                ForEach(Array(zip(section.items.indices, section.items)), id: \.1.id) { index, item in
                    let isHighlighted = highlightedTodoIds.contains(item.id)
                    let isNextHighlighted = index < section.items.count - 1
                        && highlightedTodoIds.contains(section.items[index + 1].id)

                    TodoRow(
                        item: item,
                        isNavigationEnabled: isNavigationEnabled,
                        isHighlighted: isHighlighted,
                        // Mac은 둥근 선택·마우스 표시와 맞닿는 구분선 숨김
                        showsSeparator: !(isiOSAppOnMac && (isHighlighted || isNextHighlighted)),
                        onSelect: { onSelect(item) },
                        onInspect: { onInspect(item) }
                    )
                    .onHover { onHover(item, $0) }
                }
            }
            // Mac은 둥근 선택 표시가 칸 가장자리에 붙지 않도록 좌우 여백 표시
            .padding(.horizontal, isiOSAppOnMac ? 16 : 0)
            // 선택한 행 배경이 목록 영역을 넘지 않도록 자름
            .clipShape(.rect)
        }
    }
}

private struct TodoRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    let item: TodayTodoItem
    let isNavigationEnabled: Bool
    let isHighlighted: Bool
    let showsSeparator: Bool
    let onSelect: () -> Void
    let onInspect: () -> Void

    var body: some View {
        Button {
            guard isNavigationEnabled else { return }
            onSelect()
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.adaptive(.callout).weight(.semibold))
                            .strikethrough(item.isCompleted)
                            .foregroundStyle(item.isCompleted ? Color.secondaryLabel : .label)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        if item.isPinned {
                            Image(systemName: "star.fill")
                                .font(.system(size: isiOSAppOnMac ? 12.5 * AdaptiveSize.boardScale : 14))
                                .foregroundStyle(Color.important)
                        }
                    }
                    if !item.content.isEmpty {
                        Text(item.content)
                            .font(.adaptive(.footnote))
                            .foregroundStyle(Color.secondaryLabel)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 3)
                    }
                    todoMetadata
                        .padding(.top, 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.secondaryLabel)
                    // 칸 화면은 옆 칸에 상세를 열어 화면 이동 표시 생략
                    .opacity(isNavigationEnabled && !usesPaneLayout ? 1 : 0)
            }
            .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
            .padding(.trailing, 16)
            // 구분선은 글자 줄 시작부터 행 오른쪽 끝까지 표시
            .overlay(alignment: .bottom) {
                if showsSeparator {
                    Divider().overlay(Color.secondarySeparator)
                }
            }
            .contentShape(.rect)
            .overlay {
                TodoInspectorInteractionView(action: onInspect)
            }
        }
        .buttonStyle(.plain)
        .padding(.leading, 16)
        // 선택·마우스 표시는 같은 회색, Mac은 Orca 데스크톱처럼 둥근 사각형
        .background(
            isHighlighted ? Color.fill : .clear,
            in: .rect(cornerRadius: isiOSAppOnMac ? CornerRadius.control : 0)
        )
    }

    @ViewBuilder
    private var todoMetadata: some View {
        let category = TodoCategoryItem(from: item.category)
        HStack(spacing: 8) {
            Text("#\(item.number)")
                .fontWeight(.semibold)
                .foregroundStyle(Color.tintLabel)

            Image(systemName: category.symbolName)
                .foregroundStyle(category.color)

            if let dueDate = item.dueDate {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                    Text(dueDateText(dueDate))
                }
                .foregroundStyle(dueDateColor(dueDate))
            }
        }
        .font(.adaptive(.caption))
        .lineLimit(1)
    }

    private func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(date) {
            return String(localized: "today_section_today", bundle: PresentationResources.bundle)
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "today_due_yesterday", bundle: PresentationResources.bundle)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated))
    }

    private func dueDateColor(_ date: Date) -> Color {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.startOfDay(for: date) < calendar.startOfDay(for: Date()) {
            return .danger
        }
        return .secondaryLabel
    }
}

private extension TodayFeature.SectionCategory {
    var accentColor: Color {
        self == .overdue ? .danger : .label
    }
}
