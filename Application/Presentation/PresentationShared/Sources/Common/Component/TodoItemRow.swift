//
//  TodoItemRow.swift
//  PresentationShared
//
//  Created by 최윤진 on 2/21/26.
//

import SwiftUI
import Domain

public struct TodoItemRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @ScaledMetric(relativeTo: .headline) private var labelWidth = CGFloat(28)
    private let item: TodoListItem

    public init(_ item: TodoListItem) {
        self.item = item
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .resizable()
                .frame(width: labelWidth, height: labelWidth)
                .foregroundStyle(item.isCompleted ? Color.accent : Color.tertiaryLabel)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(item.isCompleted ? Color.secondaryLabel : .label)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Text("#\(item.number)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.tertiaryLabel)
                        .fixedSize(horizontal: true, vertical: false)
                }

                HStack(spacing: 8) {
                    RelativeTimeText(date: item.updatedAt)

                    if !item.tags.isEmpty {
                        TagList(
                            item.tags,
                            lineLimit: 1,
                            verticalSpacing: 4,
                            horizontalSpacing: 4
                        )
                    }
                }
            }

            Spacer(minLength: 4)

            if item.isPinned {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }

            // Mac은 옆 칸에 상세를 열어 화면 이동 표시 생략
            if !isiOSAppOnMac {
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.tertiaryLabel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
