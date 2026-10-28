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
    @State private var router = NavigationRouter<Path>()
    @State var store: StoreOf<SearchFeature>

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    SearchResults(
                        store: store,
                        onSelectTodo: { router.push(.todo($0)) }
                    )
                    RecentSearchQuries(store: store)
                        .padding(.bottom, 8)
                    instruction
                }
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    topBar
                    tipCard
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .background(Color.appBackground)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .prominentAlert(store, state: \.alert, action: \.alert)
            .navigationDestination(for: Path.self, interactivePop: { _ in true }) { path in
                switch path {
                case .todo(let todoId):
                    TodoDetailView(store: Store(
                        initialState: TodoDetailFeature.State(todoId: todoId, showEditButton: true)
                    ) {
                        TodoDetailFeature()
                    })
                }
            }
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading) {
            if #available(iOS 26.0, *) {
                Button {
                    store.send(.binding(.set(\.isSearching, false)))
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .topBarButtonStyle(tint: Color.accent)
            } else {
                Button {
                    store.send(.binding(.set(\.isSearching, false)))
                    dismiss()
                } label: {
                    Text(String(localized: "common_close", bundle: PresentationResources.bundle))
                }
                .topBarButtonStyle(tint: Color.accent)
            }
            SearchField(store: store)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color.appBackground, ignoresSafeAreaEdges: .top)
    }

    private var tipCard: some View {
        HStack(alignment: .top) {
            Image(systemName: "info.circle.fill")
                .font(.title)
            VStack(alignment: .leading) {
                Text(String(
                    localized: "search_todo_number_tip_title",
                    bundle: PresentationResources.bundle
                ))
                    .bold()
                Text(String(
                    localized: "search_todo_number_tip_message",
                    bundle: PresentationResources.bundle
                ))
                    .foregroundStyle(Color.textSecondary)
                    .font(.caption)
            }
            Spacer()
        }
        .foregroundStyle(Color.onPrimaryContainer)
        .padding()
        .background {
            Rectangle()
                .fill(Color.appBackground)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primaryContainer)
        }
    }

    private var instruction: some View {
        HStack {
            Spacer()
            Text(String(
                localized: "search_scope_instruction",
                bundle: PresentationResources.bundle
            ))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

private struct SearchField: View {
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
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)
            TextField(
                "",
                text: searchQuery,
                prompt: Text(String(
                    localized: "search_prompt",
                    bundle: PresentationResources.bundle)
                )
                .foregroundStyle(Color.secondary),
            )
            .focused($isFocused)
            .onSubmit {
                store.send(.addRecentQuery(store.searchQuery))
            }
            if !store.searchQuery.isEmpty {
                Button {
                    store.send(.binding(.set(\.searchQuery, "")))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.title3)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
        }
        .onAppear {
            isFocused = true
        }
    }
}

private struct SearchResults: View {
    let store: StoreOf<SearchFeature>
    let onSelectTodo: (String) -> Void

    var body: some View {
        if !store.searchQuery.isEmpty {
            let todos = store.visibleTodos

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text(String(
                        localized: "search_results_title",
                        bundle: PresentationResources.bundle
                    ))
                        .font(.title3)
                        .bold()
                    Spacer()
                    Text(String.localizedStringWithFormat(
                        String(
                            localized: "search_result_count_format",
                            bundle: PresentationResources.bundle
                        ),
                        Int64(store.todos.count)
                    ))
                    .font(.callout.bold())
                    .foregroundStyle(Color.onPrimaryContainer)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primaryContainer, in: .capsule)
                }
                if store.isHashOnlyQuery {
                    VStack(spacing: 8) {
                        Text(String(
                            localized: "search_hash_guide_title",
                            bundle: PresentationResources.bundle)
                        )
                        .font(.headline)
                        Text(String(
                            localized: "search_hash_guide_message",
                            bundle: PresentationResources.bundle)
                        )
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else if store.isLoading && todos.isEmpty {
                    ProgressView()
                } else if todos.isEmpty {
                    Text(String(
                        localized: "todo_list_search_empty",
                        bundle: PresentationResources.bundle)
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(zip(todos.indices, todos)), id: \.1.id) { index, item in
                            Button {
                                onSelectTodo(item.id)
                            } label: {
                                SearchResultRow(item: item)
                                    .todoDetailPreview(todoId: item.id)
                            }
                            .buttonStyle(.plain)
                            if index < todos.count - 1 { Divider() }
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.surface)
                    }
                    if store.shouldShowMoreTodos {
                        Button {
                            store.send(.setShowAllTodos(true))
                        } label: {
                            Text(String(
                                localized: "search_show_more",
                                bundle: PresentationResources.bundle)
                            )
                            .foregroundStyle(Color.onPrimaryContainer)
                            .font(.callout.bold())
                        }
                        .adaptiveButtonStyle(color: .primaryContainer)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }
}

private struct SearchResultRow: View {
    @ScaledMetric(relativeTo: .title2) private var iconSize = CGFloat(48)
    let item: SearchTodoItem

    var body: some View {
        let category = TodoCategoryItem(from: item.category)

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14)
                .fill(category.color.opacity(0.2))
                .frame(width: iconSize, height: iconSize)
                .overlay {
                    Image(systemName: category.symbolName)
                        .font(.title3.bold())
                        .foregroundStyle(category.color)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("#\(item.number)")
                        .foregroundStyle(Color.accent)
                    Text("·")
                    Text(item.createdAt.formatted(.dateTime.month().day().weekday(.abbreviated)))
                }
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: item.isPinned ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(item.isPinned ? Color.orange : .textTertiary)
            Image(systemName: "chevron.right")
                .font(.callout.bold())
                .foregroundStyle(Color.textSecondary)
        }
        .padding()
    }
}

private struct RecentSearchQuries: View {
    let store: StoreOf<SearchFeature>

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "search_recent", bundle: PresentationResources.bundle))
                    .font(.title3)
                    .bold()
                Spacer()
                Button {
                    store.send(.clearRecentQueries)
                } label: {
                    Image(systemName: "trash")
                        .font(.callout)
                        .foregroundStyle(
                            store.recentQueries.isEmpty ?
                            Color.textSecondary : .onPrimaryContainer
                        )
                }
                .disabled(store.recentQueries.isEmpty)
                .padding(.trailing)
            }
            LazyVStack(spacing: 0) {
                ForEach(Array(zip(
                    store.recentQueries.indices,
                    store.recentQueries)), id: \.1
                ) { idx, query in
                    VStack(spacing: 0) {
                        HStack {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.textSecondary)
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
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .padding()
                        if idx < store.recentQueries.count - 1 { Divider() }
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.surface)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private enum Path: Hashable {
    case todo(String)
}
