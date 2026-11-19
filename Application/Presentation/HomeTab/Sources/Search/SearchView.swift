//
//  SearchView.swift
//  HomeTab
//
//  Created by 최윤진 on 2/12/26.
//

import SwiftUI
import Domain
import PresentationShared

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.deviceType) private var deviceType
    @State private var store: StoreOf<SearchFeature>
    // 홈 내비게이션에 쌓아 연 검색에서 Todo 상세를 홈 내비게이션에 쌓는 동작
    private let onSelectTodo: (String) -> Void

    // 열 때마다 빈 입력칸으로 시작하고 최근 검색은 열 때 읽음
    // 닫으면 Store와 함께 진행 중인 검색 요청과 상세 판도 사라짐
    init(onSelectTodo: @escaping (String) -> Void) {
        @Dependency(\.homeFetchRecentSearchQueriesUseCase) var fetchRecentSearchQueriesUseCase
        self._store = State(initialValue: Store(
            initialState: SearchFeature.State(
                recentQueries: fetchRecentSearchQueriesUseCase.execute()
            )
        ) {
            SearchFeature()
        })
        self.onSelectTodo = onSelectTodo
    }

    var body: some View {
        content { todoId in
            // 사이드바가 있는 창은 사이드바까지 덮는 상세 판으로 열기
            // 좁은 창에서 쌓아 연 상세도 기억해 넓어지면 같은 Todo를 상세 판으로 표시
            store.send(.binding(.set(\.panelTodo, TodoIdItem(id: todoId))))
            if !usesDesktopLayout {
                onSelectTodo(todoId)
            }
        }
        .duoToolbarVisibility(showsBackButton: true)
        // 좁은 창에서 쌓아 연 결과 상세를 내리면 넓어져도 상세 판으로 다시 열지 않음
        .onAppear {
            if !usesDesktopLayout {
                store.send(.binding(.set(\.panelTodo, nil)))
            }
        }
    }

    private func content(onSelectTodo: @escaping (String) -> Void) -> some View {
        // 결과가 없으면 안내와 최근 검색 대신 빈 화면만 표시
        let isEmptyResult = !store.searchQuery.isEmpty
            && !store.isHashOnlyQuery
            && !store.isLoading
            && store.visibleTodos.isEmpty

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if isEmptyResult {
                    EmptyStateView(
                        String(localized: "todo_list_search_empty", bundle: PresentationResources.bundle),
                        systemImage: "magnifyingglass"
                    )
                } else {
                    tip
                    RecentSearchQuries(store: store)
                    SearchResults(store: store, onSelectTodo: onSelectTodo)
                }
            }
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                topBar
                SearchField(store: store)
                    .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                    .padding(.vertical, isiOSAppOnMac ? 4 * AdaptiveSize.boardScale : 8)
                    .frame(maxWidth: readableContentWidth)
            }
            .background(Color.background)
        }
        .background(Color.background.ignoresSafeArea())
        .prominentAlert(store, state: \.alert, action: \.alert)
        // 좁은 창으로 바뀌면 상세 판을 숨기고 넓어지면 다시 표시
        .detailPanel(item: $store.panelTodo.activePresentation(when: usesDesktopLayout)) { item in
            TodoDetailPanel(
                todoId: item.id,
                location: Text("search_title", bundle: PresentationResources.bundle),
                isEditable: true
            )
        }
    }

    @ViewBuilder
    private var topBar: some View {
        let close = { dismiss() }
        let title = Text(String(localized: "search_title", bundle: PresentationResources.bundle))

        // 사이드바가 있는 창은 사이드바 옆 칸 제목 줄과 같은 모양, 세부 정보가 없어 세부 정보 버튼 생략
        if usesDesktopLayout {
            PaneTitleBar(title, onClose: close) { EmptyView() }
                .environment(\.showDetailSideBar, nil)
        } else {
            // OS와 상관없이 같은 모양인 가운데 제목과 아래 구분선
            ZStack {
                title
                    .font(.adaptive(.callout).bold())
                HStack {
                    // Duo는 세로 막대의 뒤로 버튼 사용
                    if deviceType != .duo {
                        NavigationBackButton(action: close)
                    }
                    Spacer()
                }
            }
            .frame(height: 48)
            .padding(.horizontal, 8)
            .overlay(alignment: .bottom) {
                Divider().overlay(Color.secondarySeparator)
            }
            .padding(.top, windowControlsInset)
            .background(Color.background, ignoresSafeAreaEdges: .top)
        }
    }

    private var tip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.adaptive(.body))
                .foregroundStyle(Color.tintLabel)
            VStack(alignment: .leading, spacing: 0) {
                Text(String(
                    localized: "search_todo_number_tip_title",
                    bundle: PresentationResources.bundle
                ))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.label)
                Text(String(
                    localized: "search_todo_number_tip_message",
                    bundle: PresentationResources.bundle
                ))
                    .foregroundStyle(Color.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .font(.adaptive(.footnote))
        .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
    }
}

private struct SearchField: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let store: StoreOf<SearchFeature>
    @FocusState private var isFocused: Bool

    private var searchQuery: Binding<String> {
        Binding(
            get: { store.searchQuery },
            set: { query in
                guard query != store.searchQuery else { return }
                store.send(.binding(.set(\.searchQuery, query)))
            }
        )
    }

    var body: some View {
        let field = HStack(spacing: 8) {
            TextField(
                "",
                text: searchQuery,
                prompt: Text(String(
                    localized: "search_prompt",
                    bundle: PresentationResources.bundle)
                )
                .foregroundStyle(Color.secondaryLabel),
            )
            .focused($isFocused)
            .onSubmit {
                store.send(.addRecentQuery(store.searchQuery))
            }
            if !store.searchQuery.isEmpty {
                Button {
                    store.send(.binding(.set(\.searchQuery, "")))
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.secondaryLabel)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
        .padding(.horizontal, 12 * AdaptiveSize.boardScale)
        // Mac은 Orca 한 줄 입력칸 높이 32
        .frame(minHeight: (isiOSAppOnMac ? 32 : 44) * AdaptiveSize.boardScale)

        Group {
            if usesDesktopLayout {
                field.inputBackground(isFocused: isFocused)
            } else {
                // 좁은 화면은 라이트에서도 보이도록 옅은 회색 바탕과 테두리
                let shape = RoundedRectangle(cornerRadius: CornerRadius.control)
                field
                    .background(Color.tertiaryBackground, in: shape)
                    .overlay { shape.strokeBorder(Color.secondarySeparator) }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

// 최근 검색과 검색 결과의 머리줄
private struct SearchSectionHeader<Trailing: View>: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let title: String
    var count: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.adaptive(.subheadline).bold())
            if let count {
                Text(count)
                    .font(.adaptive(.subheadline).weight(.medium))
                    .foregroundStyle(Color.secondaryLabel)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .padding(.top, isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 20)
        .padding(.bottom, isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 10)
    }
}

private struct SearchResults: View {
    let store: StoreOf<SearchFeature>
    let onSelectTodo: (String) -> Void

    var body: some View {
        if !store.searchQuery.isEmpty {
            let todos = store.visibleTodos

            VStack(spacing: 0) {
                SearchSectionHeader(
                    title: String(localized: "search_results_title", bundle: PresentationResources.bundle),
                    count: String.localizedStringWithFormat(
                        String(
                            localized: "search_result_count_format",
                            bundle: PresentationResources.bundle
                        ),
                        Int64(store.todos.count)
                    )
                ) { EmptyView() }
                if store.isHashOnlyQuery {
                    VStack(spacing: 8) {
                        Text(String(
                            localized: "search_hash_guide_title",
                            bundle: PresentationResources.bundle)
                        )
                        .font(.adaptive(.headline))
                        Text(String(
                            localized: "search_hash_guide_message",
                            bundle: PresentationResources.bundle)
                        )
                        .font(.adaptive(.subheadline))
                        .foregroundStyle(Color.secondaryLabel)
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else if store.isLoading && todos.isEmpty {
                    ProgressView()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(todos) { item in
                            Button {
                                onSelectTodo(item.id)
                            } label: {
                                SearchResultRow(item: item)
                                    .todoDetailPreview(todoId: item.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if store.shouldShowMoreTodos {
                        Button {
                            store.send(.setShowAllTodos(true))
                        } label: {
                            Text(String(
                                localized: "search_show_more",
                                bundle: PresentationResources.bundle)
                            )
                            .foregroundStyle(Color.tintLabel)
                            .font(.adaptive(.callout).bold())
                        }
                        .adaptiveButtonStyle(color: .tintFill)
                        .padding(.top, 8)
                        .padding(.horizontal)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }
}

private struct SearchResultRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let item: SearchTodoItem

    var body: some View {
        let category = TodoCategoryItem(from: item.category)

        // 구분선은 아이콘 시작부터 행 오른쪽 끝까지 표시
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: category.symbolName)
                    .font(.adaptive(.body))
                    .foregroundStyle(category.color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.adaptive(.callout).weight(.semibold))
                        .lineLimit(1)
                    Text("#\(item.number) · \(item.createdAt.formatted(.dateTime.month().day().weekday(.abbreviated)))")
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.secondaryLabel)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.adaptive(.footnote).weight(.medium))
                    .foregroundStyle(Color.secondaryLabel)
            }
            .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
            .padding(.trailing, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)
        }
        .padding(.leading, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .contentShape(.rect)
    }
}

private struct RecentSearchQuries: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let store: StoreOf<SearchFeature>

    var body: some View {
        VStack(spacing: 0) {
            SearchSectionHeader(
                title: String(localized: "search_recent", bundle: PresentationResources.bundle)
            ) {
                Button {
                    store.send(.clearRecentQueries)
                } label: {
                    Image(systemName: "trash")
                        .font(.adaptive(.subheadline))
                        .foregroundStyle(
                            store.recentQueries.isEmpty ?
                            Color.tertiaryLabel : .secondaryLabel
                        )
                }
                .buttonStyle(.plain)
                .disabled(store.recentQueries.isEmpty)
            }
            LazyVStack(spacing: 0) {
                ForEach(store.recentQueries, id: \.self) { query in
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.secondaryLabel)
                                Text(query)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(.rect)
                            .onTapGesture {
                                store.send(.binding(.set(\.searchQuery, query)))
                            }
                            Button {
                                store.send(.removeRecentQuery(query))
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.adaptive(.footnote))
                                    .foregroundStyle(Color.secondaryLabel)
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.adaptive(.subheadline))
                        .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
                        .padding(.trailing, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                        Rectangle()
                            .fill(Color.secondarySeparator)
                            .frame(height: 1)
                    }
                    .padding(.leading, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
