//
//  RecentActivityCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

// 최근 활동 카드
struct RecentActivityCard: View {
    @Bindable var store: StoreOf<ProfileFeature>
    let onSelectTodo: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile_recent_title", bundle: PresentationResources.bundle)
                .font(.title3.bold())
                .padding(.horizontal, 16)

            if store.isRecentTodosLoading && store.recentTodos.isEmpty {
                LoadingView()
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(Color.secondaryBackground, in: RoundedRectangle(cornerRadius: CornerRadius.group))
            } else if store.recentTodos.isEmpty {
                Text("profile_recent_empty", bundle: PresentationResources.bundle)
                    .font(.callout)
                    .foregroundStyle(Color.secondaryLabel)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(Color.secondaryBackground, in: RoundedRectangle(cornerRadius: CornerRadius.group))
            } else {
                VStack(spacing: 12) {
                    ForEach(store.recentTodos) { todo in
                        Button {
                            onSelectTodo(todo.id)
                        } label: {
                            RecentTodoCard(
                                todo: todo,
                                isSelected: store.selectedTodoRoute == .recentTodo(todo.id)
                            )
                            .todoDetailPreview(todoId: todo.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct RecentTodoCard: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @ScaledMetric(relativeTo: .title3) private var iconSize = CGFloat(44)
    let todo: RecentTodoItem
    let isSelected: Bool

    var body: some View {
        let category = TodoCategoryItem(from: todo.category)
        HStack(spacing: 12) {
            Image(systemName: category.symbolName)
                .font(.title3.weight(.semibold))
                .frame(width: iconSize, height: iconSize)
                .iconStyle(
                    color: category.color,
                    in: RoundedRectangle(cornerRadius: CornerRadius.control)
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(todo.title)
                        .foregroundStyle(Color.label)
                        .font(.headline)
                        .lineLimit(2)
                    if todo.isPinned {
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accent)
                    }
                }

                HStack(spacing: 6) {
                    Text(verbatim: "#\(todo.number)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accent)
                    Text(category.localizedName)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryLabel)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    RelativeTimeText(
                        date: todo.updatedAt,
                        bodyFont: .caption2,
                        bodyColor: .tertiaryLabel
                    )
                    .fixedSize(horizontal: true, vertical: false)
                }

                if !todo.tags.isEmpty {
                    TagList(todo.tags, lineLimit: 1)
                }
            }

            Spacer(minLength: 0)
            // Mac은 옆 칸에 상세를 열어 화면 이동 표시 생략
            if !isiOSAppOnMac {
                Image(systemName: "chevron.right")
                    .font(.callout.bold())
                    .foregroundStyle(Color.tertiaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(isSelected ? Color.tintFill : .secondaryBackground, in: Rectangle())
        .contentShape(.rect)
    }
}
