//
//  CategoryManageFeature.swift
//  HomeTab
//
//  Created by opfic on 6/11/26.
//

import Domain
import PresentationShared
import SwiftUI

@Reducer
struct CategoryManageFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var categorySheet: CategorySheetState?
        @Presents var alert: AlertState<Action.Alert>?
        // 추가하거나 고칠 카테고리를 세부 정보 사이드바에 보여 달라고 한 횟수, 바뀌면 닫힌 세부 정보 사이드바를 엶
        var revealCount = 0
        var preferences: [TodoCategoryItem]
    }

    @ObservableState
    struct CategorySheetState: Equatable {
        var category: UserTodoCategory
        var preferences: [TodoCategoryItem]
        // 카테고리 추가로 방금 목록에 만든 카테고리
        var isNew = false

        var navigationTitle: String {
            isNew ? String(localized: "todo_manage_add_category_title", bundle: PresentationResources.bundle) : String(localized: "todo_manage_edit_category_title", bundle: PresentationResources.bundle)
        }
        var placeholder: String {
            category.name
        }
        var categoryNameCountText: String {
            "\(category.name.count)/20"
        }
        var isDuplicatedName: Bool {
            let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty {
                return false
            }

            // 원래 이름과 앱 언어에 관계없이 모든 언어의 표시 이름을 기본 카테고리 이름으로 취급
            if SystemTodoCategory.allCases.contains(where: { category in
                category.rawValue.caseInsensitiveCompare(name) == .orderedSame
                    || SystemTodoCategoryItem(from: category).localizedNames.contains {
                        $0.caseInsensitiveCompare(name) == .orderedSame
                    }
            }) {
                return true
            }

            if preferences.contains(where: { item in
                guard case .user(let userCategory) = item.category, userCategory.id != category.id else {
                    return false
                }

                return userCategory.name.caseInsensitiveCompare(name) == .orderedSame
            }) {
                return true
            }

            return false
        }
        var todoCategoryItem: TodoCategoryItem {
            TodoCategoryItem(
                from: .user(
                    UserTodoCategory(
                        id: category.id,
                        name: category.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        colorHex: category.colorHex
                    )
                )
            )
        }
    }

    enum Action: Equatable {
        case alert(PresentationAction<Alert>)
        case categorySheet(PresentationAction<CategorySheet>)
        case delegate(Delegate)
        case tapAddUserCategory
        case moveItem(from: IndexSet, target: Int)
        case tapItem(TodoCategoryItem)
        case tapEditUserCategory(TodoCategoryItem)
        case tapDeleteUserCategory(TodoCategoryItem)
        case setCategorySheet(CategorySheetState?)
        case selectCategory(TodoCategoryItem)

        enum Alert: Equatable {
            case confirmDeleteUserCategory(TodoCategoryItem)
        }

        enum Delegate: Equatable {
            case changed([TodoCategoryItem])
        }

        enum CategorySheet: BindableAction, Equatable {
            case binding(BindingAction<CategorySheetState>)
            case tapCloseButton
            case tapRandomColorButton
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmDeleteUserCategory(let item))):
                if let index = state.preferences.firstIndex(where: { $0.id == item.id }) {
                    state.preferences.remove(at: index)
                }
                if state.categorySheet?.category.id == item.id {
                    state.categorySheet = nil
                }
                return .send(.delegate(.changed(state.preferences)))
            case .alert:
                break
            case .delegate:
                break
            case .categorySheet(.dismiss):
                state.categorySheet = nil
            case .categorySheet(.presented(.tapCloseButton)):
                state.categorySheet = nil
            case .categorySheet(.presented(.binding)),
                 .categorySheet(.presented(.tapRandomColorButton)):
                guard Self.applyEditingCategory(state: &state) else { break }
                return .send(.delegate(.changed(state.preferences)))
            case .categorySheet:
                break
            case .tapAddUserCategory:
                state.revealCount += 1
                if let randomHexValue = Color.randomValue.hexValue {
                    // 목록에 새 카테고리를 바로 만들고 고른 채로 시트나 세부 정보 사이드바에 표시
                    let category = UserTodoCategory(
                        id: UUID().uuidString.lowercased(),
                        name: Self.newCategoryName(in: state.preferences),
                        colorHex: randomHexValue
                    )
                    state.preferences.append(TodoCategoryItem(from: .user(category)))
                    state.categorySheet = CategorySheetState(
                        category: category,
                        preferences: state.preferences,
                        isNew: true
                    )
                    return .send(.delegate(.changed(state.preferences)))
                }
            case .moveItem(let from, let target):
                state.preferences.move(fromOffsets: from, toOffset: target)
                let preferences = state.preferences
                state.categorySheet?.preferences = preferences
                return .send(.delegate(.changed(state.preferences)))
            case .tapItem(let item):
                if let index = state.preferences.firstIndex(where: { $0.id == item.id }) {
                    state.preferences[index].isVisible.toggle()
                }
                let preferences = state.preferences
                state.categorySheet?.preferences = preferences
                return .send(.delegate(.changed(state.preferences)))
            case .tapEditUserCategory(let item):
                state.revealCount += 1
                if item.isUserCategory, case .user(let category) = item.category {
                    state.categorySheet = CategorySheetState(
                        category: category,
                        preferences: state.preferences
                    )
                }
            case .tapDeleteUserCategory(let item):
                if item.isUserCategory {
                    state.alert = Self.deleteAlertState(for: item)
                }
            case .setCategorySheet(let sheet):
                state.categorySheet = sheet
            case .selectCategory(let item):
                // 직접 만든 카테고리만 이름과 색을 고칠 수 있음
                if case .user(let category) = item.category {
                    state.categorySheet = CategorySheetState(category: category, preferences: state.preferences)
                } else {
                    state.categorySheet = nil
                }
            }
            return .none
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$categorySheet, action: \.categorySheet) {
            CategoryManageSheetFeature()
        }
    }
}

private struct CategoryManageSheetFeature: Reducer {
    typealias State = CategoryManageFeature.CategorySheetState
    typealias Action = CategoryManageFeature.Action.CategorySheet

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.category.name):
                state.category.name = String(state.category.name.prefix(20))
            case .binding:
                break
            case .tapRandomColorButton:
                if let randomHexValue = Color.randomValue.hexValue {
                    state.category.colorHex = randomHexValue
                }
            case .tapCloseButton:
                break
            }
            return .none
        }
    }
}

private extension CategoryManageFeature {
    // 고치는 카테고리의 이름과 색을 목록에 반영, 비었거나 겹치는 이름은 저장하지 않고 입력 칸에만 둠
    static func applyEditingCategory(state: inout State) -> Bool {
        guard let sheet = state.categorySheet else { return false }
        let name = sheet.category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !sheet.isDuplicatedName,
              let index = state.preferences.firstIndex(where: { $0.id == sheet.category.id }) else { return false }
        var item = sheet.todoCategoryItem
        item.isVisible = state.preferences[index].isVisible
        guard state.preferences[index] != item else { return false }
        state.preferences[index] = item
        let preferences = state.preferences
        state.categorySheet?.preferences = preferences
        return true
    }

    // 기본 이름이 이미 있으면 뒤에 번호를 붙인 이름
    static func newCategoryName(in preferences: [TodoCategoryItem]) -> String {
        let name = String(localized: "todo_manage_new_category_name", bundle: PresentationResources.bundle)
        let names = Set(preferences.map { $0.localizedName.lowercased() })
        var candidate = name
        var number = 2
        while names.contains(candidate.lowercased()) {
            candidate = "\(name) \(number)"
            number += 1
        }
        return candidate
    }

    static func deleteAlertState(for item: TodoCategoryItem) -> AlertState<Action.Alert> {
        AlertState {
            TextState(String(localized: "todo_manage_delete_category_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_cancel", bundle: PresentationResources.bundle))
            }
            ButtonState(role: .destructive, action: .confirmDeleteUserCategory(item)) {
                TextState(String(localized: "common_delete", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(localized: "todo_manage_delete_category_message", bundle: PresentationResources.bundle))
        }
    }
}
