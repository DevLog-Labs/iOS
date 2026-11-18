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
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    private let item: TodoListItem
    private let showsSeparator: Bool

    public init(_ item: TodoListItem, showsSeparator: Bool = false) {
        self.item = item
        self.showsSeparator = showsSeparator
    }

    public var body: some View {
        let circleSize = isiOSAppOnMac ? 17 * AdaptiveSize.boardScale : 20
        let spacing = isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16

        HStack(spacing: 12) {
            Image(systemName: item.isCompleted ? "checkmark.circle" : "circle")
                .resizable()
                .fontWeight(.medium)
                .frame(width: circleSize, height: circleSize)
                .foregroundStyle(item.isCompleted ? Color.accent : .secondaryLabel)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(item.title)
                            .foregroundStyle(item.isCompleted ? Color.secondaryLabel : .label)
                            .lineLimit(1)
                            .layoutPriority(1)
                        Text(verbatim: "#\(item.number)")
                            .fontWeight(.medium)
                            .foregroundStyle(Color.secondaryLabel)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .font(.adaptive(isiOSAppOnMac ? .body : .callout).weight(.semibold))

                    RelativeTimeText(date: item.updatedAt, bodyFont: .adaptive(.footnote))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if item.isPinned {
                    Image(systemName: "star.fill")
                        .font(.system(size: isiOSAppOnMac ? 12.5 * AdaptiveSize.boardScale : 14))
                        .foregroundStyle(Color.accent)
                }

                // 칸 화면은 옆 칸에 상세를 열어 화면 이동 표시 생략
                if !usesPaneLayout {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
            .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
            .padding(.trailing, spacing)
            // 구분선은 완료 원 오른쪽 글자 줄부터 표시
            .overlay(alignment: .bottom) {
                if showsSeparator {
                    Divider().overlay(Color.secondarySeparator)
                }
            }
        }
        .padding(.leading, spacing)
    }
}
