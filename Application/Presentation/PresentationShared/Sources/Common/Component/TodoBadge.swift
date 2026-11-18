//
//  TodoBadge.swift
//  PresentationShared
//
//  Created by opfic on 11/18/26.
//

import SwiftUI

// Todo 카테고리·마감일·태그를 표시하는 작은 배지
public struct TodoBadge<Label: View, Trailing: View>: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    private let color: Color
    private let label: Label
    private let trailing: Trailing

    public init(
        color: Color = .secondaryLabel,
        @ViewBuilder label: () -> Label,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.color = color
        self.label = label()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 4 * AdaptiveSize.boardScale) {
            label
                .lineLimit(1)
            trailing
        }
        .font(.adaptive(isiOSAppOnMac ? .caption2 : .caption).weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 6 * AdaptiveSize.boardScale)
        .frame(height: isiOSAppOnMac ? 18.5 * AdaptiveSize.boardScale : 20)
        .background(color.opacity(0.13), in: .rect(cornerRadius: CornerRadius.badge))
    }
}

public extension TodoBadge where Label == Text, Trailing == EmptyView {
    init(_ title: String, color: Color = .secondaryLabel) {
        self.init(color: color) {
            Text(title)
        } trailing: {
            EmptyView()
        }
    }
}

// 마감일 배지, 마감일이 지난 Todo는 위험 색으로 표시
struct TodoDueDateBadge: View {
    let dueDate: Date
    var showsUntil = false

    var body: some View {
        let calendar = Calendar.autoupdatingCurrent
        let isOverdue = calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: Date())
        let format = showsUntil
            ? Date.FormatStyle.dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).day().weekday(.abbreviated)
        let date = dueDate.formatted(format)
        let until = String(localized: "todo_due_date_until_format", bundle: PresentationResources.bundle)

        TodoBadge(
            showsUntil ? String.localizedStringWithFormat(until, date) : date,
            color: isOverdue ? Color.danger : .secondaryLabel
        )
    }
}
