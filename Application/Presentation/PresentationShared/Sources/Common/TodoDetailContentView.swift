//
//  TodoDetailContentView.swift
//  PresentationShared
//
//  Created by opfic on 3/2/26.
//

import SwiftUI
import Domain

struct TodoDetailContentView: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.readableContentWidth) private var readableContentWidth
    let todo: Todo
    let referenceItems: [Int: TodoReferenceItem]
    var showsTitle = true
    var onOpenTodoID: ((String) -> Void)?

    var body: some View {
        let category = TodoCategoryItem(from: todo.category)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if showsTitle {
                    Text(title)
                        .font(.system(size: isiOSAppOnMac ? 19 * AdaptiveSize.boardScale : 26, weight: .heavy))
                        .lineSpacing(isiOSAppOnMac ? 6 : 8)
                        .padding(.bottom, 12)
                }

                TagLayout(showsOverflowIndicator: false, verticalSpacing: 6, horizontalSpacing: 6) {
                    TodoBadge(category.localizedName, color: category.color)
                    if let dueDate = todo.dueDate {
                        TodoDueDateBadge(dueDate: dueDate, showsUntil: true)
                    }
                    ForEach(todo.tags, id: \.self) { tag in
                        TodoBadge(tag)
                    }
                }
                // 본문 첫 제목의 위쪽 여백은 Markdown 화면이 빼고 그려서 배지 아래에 둠
                .padding(.bottom, isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 20)

                if todo.content.isEmpty {
                    // 시스템 빈 화면 대신 Mac 글자 크기를 따르는 빈 화면 표시
                    EmptyStateView(
                        String(
                            localized: "development_record_content_empty_title",
                            bundle: PresentationResources.bundle
                        ),
                        systemImage: "doc.text"
                    )
                } else {
                    TodoMarkdownContentView(
                        content: todo.content,
                        referenceItems: referenceItems,
                        isScrollEnabled: false,
                        onOpenTodoID: onOpenTodoID
                    )
                    // MarkdownRenderer 내부의 좌우 여백을 상쇄해 제목과 정렬
                    .padding(.horizontal, -16)
                }
            }
            .padding(.horizontal, isiOSAppOnMac ? 22 * AdaptiveSize.boardScale : 24)
            .padding(.vertical, isiOSAppOnMac ? 18 * AdaptiveSize.boardScale : 20)
            .frame(maxWidth: readableContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    // 긴 제목은 줄을 바꾸고 번호는 제목 끝에 이어 표시
    private var title: AttributedString {
        var title = AttributedString(todo.title + " ")
        var number = AttributedString("#\(todo.number)")
        number.foregroundColor = Color.secondaryLabel
        number.font = .system(size: isiOSAppOnMac ? 19 * AdaptiveSize.boardScale : 26, weight: .semibold)
        title.append(number)
        return title
    }
}
