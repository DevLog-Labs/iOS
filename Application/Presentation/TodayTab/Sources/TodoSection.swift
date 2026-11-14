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
    let section: TodayFeature.SectionContent
    let isNavigationEnabled: Bool
    let selectedTodoId: String?
    let onSelect: (TodayTodoItem) -> Void
    let onInspect: (TodayTodoItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(section.title)
                    .font(.title3.bold())
                    .foregroundStyle(section.category.accentColor)
                Text("\(section.items.count)")
                    .font(.callout.bold())
                    .foregroundStyle(section.category.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(section.category.accentColor.opacity(0.1), in: .capsule)
                Spacer()
                if section.category == .today {
                    Text(String(localized: "today_pinned_first", bundle: PresentationResources.bundle))
                        .font(.callout)
                        .foregroundStyle(Color.secondaryLabel)
                }
            }

            LazyVStack(spacing: 0) {
                ForEach(Array(zip(section.items.indices, section.items)), id: \.1.id) { index, item in
                    TodoRow(
                        item: item,
                        isNavigationEnabled: isNavigationEnabled,
                        isSelected: item.id == selectedTodoId,
                        onSelect: { onSelect(item) },
                        onInspect: { onInspect(item) }
                    )
                    if index < section.items.count - 1 {
                        Divider().overlay(Color.secondarySeparator)
                    }
                }
            }
            .background {
                Rectangle()
                    .fill(Color.secondaryBackground)
            }
            // 선택한 행 배경이 목록 영역을 넘지 않도록 자름
            .clipShape(.rect)
        }
    }
}

private struct TodoRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let item: TodayTodoItem
    let isNavigationEnabled: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onInspect: () -> Void

    var body: some View {
        Button {
            guard isNavigationEnabled else { return }
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? Color.secondaryLabel : .label)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if !item.content.isEmpty {
                        Text(item.content)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryLabel)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                    todoMetadata
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.callout.bold())
                    .foregroundStyle(Color.tertiaryLabel)
                    // Mac은 옆 칸에 상세를 열어 화면 이동 표시 생략
                    .opacity(isNavigationEnabled && !isiOSAppOnMac ? 1 : 0)
            }
            .overlay {
                TodoInspectorInteractionView(action: onInspect)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isSelected ? Color.tintFill : .clear)
    }

    @ViewBuilder
    private var todoMetadata: some View {
        let category = TodoCategoryItem(from: item.category)
        HStack(spacing: 10) {
            Text("#\(item.number)")
                .foregroundStyle(Color.accent)

            Image(systemName: category.symbolName)
                .foregroundStyle(category.color)

            if let dueDate = item.dueDate {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(dueDateText(dueDate))
                }
                .foregroundStyle(dueDateColor(dueDate))
            }
        }
        .font(.caption.weight(.semibold))
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
