//
//  RecentActivityCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

// 최근 활동 섹션
struct RecentActivityCard: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Bindable var store: StoreOf<ProfileFeature>
    let onSelectTodo: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileSectionHeader(Text("profile_recent_title", bundle: PresentationResources.bundle))

            if store.isRecentTodosLoading && store.recentTodos.isEmpty {
                LoadingView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if store.recentTodos.isEmpty {
                Text("profile_recent_empty", bundle: PresentationResources.bundle)
                    .font(.adaptive(.callout))
                    .foregroundStyle(Color.secondaryLabel)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                // 카드 없이 아래 구분선으로 나눈 행
                LazyVStack(spacing: 0) {
                    ForEach(store.recentTodos) { todo in
                        Button {
                            onSelectTodo(todo.id)
                        } label: {
                            RecentTodoRow(
                                todo: todo,
                                isSelected: usesPaneLayout && store.selectedTodoRoute == .recentTodo(todo.id)
                            )
                            .todoDetailPreview(todoId: todo.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            }
        }
    }
}

private struct RecentTodoRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    let todo: RecentTodoItem
    let isSelected: Bool

    var body: some View {
        let category = TodoCategoryItem(from: todo.category)
        let iconSize = isiOSAppOnMac ? 29 * AdaptiveSize.boardScale : 32
        let shape = RoundedRectangle(cornerRadius: CornerRadius.control)

        HStack(spacing: 10) {
            // 테두리 있는 카테고리 색 아이콘 사각형
            Image(systemName: category.symbolName)
                .font(.adaptive(isiOSAppOnMac ? .body : .subheadline).weight(.medium))
                .foregroundStyle(category.color)
                .frame(width: iconSize, height: iconSize)
                .background(Color.tertiaryBackground, in: shape)
                .overlay { shape.strokeBorder(Color.secondarySeparator) }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(todo.title)
                        .foregroundStyle(Color.label)
                        .font(.adaptive(isiOSAppOnMac ? .body : .callout).weight(.semibold))
                        .lineLimit(1)
                    if todo.isPinned {
                        Image(systemName: "star.fill")
                            .font(.adaptive(.caption).weight(.semibold))
                            .foregroundStyle(Color.important)
                    }
                }

                // #번호 · 카테고리 · 업데이트 시각
                HStack(spacing: 4) {
                    Text(verbatim: "#\(todo.number)")
                        .foregroundStyle(Color.tintLabel)
                    Text(category.localizedName)
                        .lineLimit(1)
                    Text(verbatim: "·")
                    RelativeTimeText(date: todo.updatedAt, bodyFont: .adaptive(.footnote))
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 칸 화면은 옆 칸에 상세를 열어 화면 이동 표시 생략
            if !usesPaneLayout {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.secondaryLabel)
            }
        }
        .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
        .padding(.trailing, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)
        }
        // 선택 표시는 마우스 표시와 같은 회색, Mac은 Orca 데스크톱처럼 둥근 사각형
        // 행 앞 여백까지 넓혀 행 전체에 표시
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: isiOSAppOnMac ? CornerRadius.control : 0)
                    .fill(Color.fill)
                    .padding(.leading, isiOSAppOnMac ? -14 * AdaptiveSize.boardScale : -16)
            }
        }
        .contentShape(.rect)
    }
}
