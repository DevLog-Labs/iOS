//
//  CategoryManageFeatureTests.swift
//  HomeTabTests
//
//  Created by opfic on 6/11/26.
//

import Testing
import Foundation
import Domain
import PresentationShared
@testable import HomeTab

@MainActor
struct CategoryManageFeatureTests {
    @Test("항목을 누르면 표시 여부가 전환된다")
    func 항목을_누르면_표시_여부가_전환된다() {
        let item = TodoCategoryItem(from: .system(.issue))
        let driver = CategoryManageTestDriver(preferences: [item])

        driver.tapItem(item)

        #expect(driver.preferences.first?.isVisible == false)
    }

    @Test("항목을 이동하면 preferences 순서가 변경된다")
    func 항목을_이동하면_preferences_순서가_변경된다() {
        let issue = TodoCategoryItem(from: .system(.issue))
        let feature = TodoCategoryItem(from: .system(.feature))
        let driver = CategoryManageTestDriver(preferences: [issue, feature])

        driver.moveItem(from: IndexSet(integer: 0), target: 2)

        #expect(driver.preferences.map(\.id) == [feature.id, issue.id])
    }

    @Test("사용자 카테고리 추가를 누르면 카테고리 입력 시트 상태가 생성된다")
    func 사용자_카테고리_추가를_누르면_카테고리_입력_시트_상태가_생성된다() {
        let item = TodoCategoryItem(from: .system(.issue))
        let driver = CategoryManageTestDriver(preferences: [item])

        driver.tapAddUserCategory()

        #expect(driver.categorySheet?.category.name == "")
        #expect(driver.categorySheet?.category.colorHex.count == 7)
        #expect(driver.categorySheet?.preferences == [item])
    }

    @Test("카테고리 이름은 20자로 제한된다")
    func 카테고리_이름은_20자로_제한된다() {
        let driver = CategoryManageTestDriver(preferences: [])

        driver.tapAddUserCategory()
        driver.setCategoryName(String(repeating: "a", count: 25))

        #expect(driver.categorySheet?.category.name == String(repeating: "a", count: 20))
    }

    @Test("시스템 카테고리 이름과 중복되면 저장할 수 없다", arguments: SystemTodoCategory.allCases.map(\.rawValue))
    func 시스템_카테고리_이름과_중복되면_저장할_수_없다(name: String) {
        let driver = CategoryManageTestDriver(preferences: [])

        driver.tapAddUserCategory()
        driver.setCategoryName("  \(name.uppercased())  ")

        #expect(driver.categorySheet?.isDuplicatedName == true)
        #expect(driver.categorySheet?.canSubmitUserCategory == false)
        #expect(driver.categorySheet?.nameMessage == String(
            localized: "todo_manage_name_duplicate", bundle: PresentationResources.bundle
        ))
    }

    @Test("다른 사용자 카테고리 이름은 대소문자를 구분하지 않고 중복을 검사한다")
    func 다른_사용자_카테고리_이름은_대소문자를_구분하지_않고_중복을_검사한다() {
        let category = UserTodoCategory(id: "custom", name: "Custom", colorHex: "#111111")
        let driver = CategoryManageTestDriver(preferences: [TodoCategoryItem(from: .user(category))])

        driver.tapAddUserCategory()
        driver.setCategoryName("  cUsToM  ")

        #expect(driver.categorySheet?.category.name == "  cUsToM  ")
        #expect(driver.categorySheet?.isDuplicatedName == true)
        #expect(driver.categorySheet?.canSubmitUserCategory == false)
        #expect(driver.categorySheet?.nameMessage == String(
            localized: "todo_manage_name_duplicate", bundle: PresentationResources.bundle
        ))

        driver.setCategoryName("Unique")

        #expect(driver.categorySheet?.isDuplicatedName == false)
        #expect(driver.categorySheet?.canSubmitUserCategory == true)
        #expect(driver.categorySheet?.nameMessage == String(
            localized: "todo_manage_name_hint", bundle: PresentationResources.bundle
        ))
    }

    @Test("수정 중인 카테고리의 원래 이름은 중복이 아니다")
    func 수정_중인_카테고리의_원래_이름은_중복이_아니다() {
        let category = UserTodoCategory(id: "custom", name: "Custom", colorHex: "#111111")
        let item = TodoCategoryItem(from: .user(category))
        let driver = CategoryManageTestDriver(preferences: [item])

        driver.tapEditUserCategory(item)

        #expect(driver.categorySheet?.isDuplicatedName == false)
        #expect(driver.categorySheet?.nameMessage == String(
            localized: "todo_manage_name_hint", bundle: PresentationResources.bundle
        ))
    }

    @Test("수정 내용이 없으면 저장할 수 없고 색상만 바꾸면 저장할 수 있다")
    func 수정_내용이_없으면_저장할_수_없고_색상만_바꾸면_저장할_수_있다() {
        let category = UserTodoCategory(id: "custom", name: "Custom", colorHex: "#111111")
        let item = TodoCategoryItem(from: .user(category))
        let driver = CategoryManageTestDriver(preferences: [item])

        driver.tapEditUserCategory(item)

        #expect(driver.categorySheet?.canSubmitUserCategory == false)

        driver.setCategoryColor("#222222")

        #expect(driver.categorySheet?.canSubmitUserCategory == true)
        #expect(driver.categorySheet?.isDuplicatedName == false)
        #expect(driver.categorySheet?.nameMessage == String(
            localized: "todo_manage_name_hint", bundle: PresentationResources.bundle
        ))
    }

    @Test("빈 이름은 중복 오류 대신 안내 문구를 표시한다", arguments: ["", "  ", "\n"])
    func 빈_이름은_중복_오류_대신_안내_문구를_표시한다(name: String) {
        let driver = CategoryManageTestDriver(preferences: [])

        driver.tapAddUserCategory()
        driver.setCategoryName(name)

        #expect(driver.categorySheet?.isDuplicatedName == false)
        #expect(driver.categorySheet?.canSubmitUserCategory == false)
        #expect(driver.categorySheet?.nameMessage == String(
            localized: "todo_manage_name_hint", bundle: PresentationResources.bundle
        ))
    }

    @Test("새 사용자 카테고리를 저장하면 이름을 trim한 항목이 추가되고 시트가 닫힌다")
    func 새_사용자_카테고리를_저장하면_이름을_trim한_항목이_추가되고_시트가_닫힌다() {
        let driver = CategoryManageTestDriver(preferences: [])

        driver.tapAddUserCategory()
        let colorHex = driver.categorySheet?.category.colorHex
        driver.setCategoryName("  Custom  ")
        driver.tapSaveButton()

        #expect(driver.preferences.count == 1)
        #expect(driver.userCategory(at: 0)?.name == "Custom")
        #expect(driver.userCategory(at: 0)?.colorHex == colorHex)
        #expect(driver.categorySheet == nil)
    }

    @Test("기존 사용자 카테고리를 저장하면 표시 여부를 유지한 채 항목을 교체한다")
    func 기존_사용자_카테고리를_저장하면_표시_여부를_유지한_채_항목을_교체한다() {
        let item = TodoCategoryItem(
            from: .user(
                UserTodoCategory(
                    id: "custom",
                    name: "Old",
                    colorHex: "#111111"
                )
            ),
            isVisible: false
        )
        let driver = CategoryManageTestDriver(preferences: [item])

        driver.tapEditUserCategory(item)
        driver.setCategoryName("New")
        driver.setCategoryColor("#222222")
        driver.tapSaveButton()

        #expect(driver.preferences.count == 1)
        #expect(driver.preferences.first?.isVisible == false)
        #expect(driver.userCategory(at: 0)?.name == "New")
        #expect(driver.userCategory(at: 0)?.colorHex == "#222222")
        #expect(driver.categorySheet == nil)
    }

    @Test("사용자 카테고리 삭제를 확인하면 항목이 제거된다")
    func 사용자_카테고리_삭제를_확인하면_항목이_제거된다() {
        let issue = TodoCategoryItem(from: .system(.issue))
        let item = TodoCategoryItem(
            from: .user(
                UserTodoCategory(
                    id: "custom",
                    name: "Custom",
                    colorHex: "#111111"
                )
            )
        )
        let driver = CategoryManageTestDriver(preferences: [issue, item])

        driver.tapDeleteUserCategory(item)
        driver.confirmDeleteUserCategory(item)

        #expect(driver.preferences.map(\.id) == [SystemTodoCategory.issue.rawValue])
        #expect(driver.alert == nil)
    }

    @Test("삭제 알림을 닫으면 알림 상태가 초기화된다")
    func 삭제_알림을_닫으면_알림_상태가_초기화된다() {
        let item = TodoCategoryItem(
            from: .user(
                UserTodoCategory(
                    id: "custom",
                    name: "Custom",
                    colorHex: "#111111"
                )
            )
        )
        let driver = CategoryManageTestDriver(preferences: [item])

        driver.tapDeleteUserCategory(item)
        driver.dismissAlert()

        #expect(driver.preferences == [item])
        #expect(driver.alert == nil)
    }

    @Test("시트 상태를 액션에 맞게 변경한다")
    func 시트_상태를_액션에_맞게_변경한다() {
        let category = UserTodoCategory(
            id: "custom",
            name: "Custom",
            colorHex: "#111111"
        )
        let sheet = CategoryManageFeature.CategorySheetState(
            category: category,
            preferences: []
        )
        let driver = CategoryManageTestDriver(preferences: [])

        driver.setCategorySheet(sheet)

        #expect(driver.categorySheet == sheet)

        driver.dismissCategorySheet()

        #expect(driver.categorySheet == nil)

        driver.setCategorySheet(sheet)
        driver.tapCloseButton()

        #expect(driver.categorySheet == nil)
    }

    @Test("바로 저장 상태에서 카테고리를 추가하면 번호를 붙인 새 이름으로 목록에 추가하고 고른다")
    func 바로_저장_상태에서_카테고리를_추가하면_번호를_붙인_새_이름으로_목록에_추가하고_고른다() {
        let name = String(localized: "todo_manage_new_category_name", bundle: PresentationResources.bundle)
        let category = UserTodoCategory(id: "custom", name: name, colorHex: "#111111")
        let driver = CategoryManageTestDriver(preferences: [TodoCategoryItem(from: .user(category))])

        driver.setSavesImmediately()
        driver.tapAddUserCategory()

        #expect(driver.preferences.count == 2)
        #expect(driver.userCategory(at: 1)?.name == "\(name) 2")
        #expect(driver.categorySheet?.category.id == driver.userCategory(at: 1)?.id)
    }

    @Test("바로 저장 상태에서 이름을 바꾸면 목록에 반영하고 빈 이름과 중복 이름은 반영하지 않는다")
    func 바로_저장_상태에서_이름을_바꾸면_목록에_반영하고_빈_이름과_중복_이름은_반영하지_않는다() {
        let category = UserTodoCategory(id: "custom", name: "Custom", colorHex: "#111111")
        let item = TodoCategoryItem(from: .user(category))
        let driver = CategoryManageTestDriver(preferences: [TodoCategoryItem(from: .system(.issue)), item])

        driver.setSavesImmediately()
        driver.selectCategory(item)
        driver.setCategoryName("  Renamed  ")

        #expect(driver.userCategory(at: 1)?.name == "Renamed")

        driver.setCategoryName("  ")

        #expect(driver.userCategory(at: 1)?.name == "Renamed")

        driver.setCategoryName("ISSUE")

        #expect(driver.userCategory(at: 1)?.name == "Renamed")
    }

    @Test("바로 저장 상태로 바뀌면 목록에 없는 새 카테고리 입력을 닫고 고치던 카테고리는 목록에 반영한다")
    func 바로_저장_상태로_바뀌면_목록에_없는_새_카테고리_입력을_닫고_고치던_카테고리는_목록에_반영한다() {
        let category = UserTodoCategory(id: "custom", name: "Custom", colorHex: "#111111")
        let item = TodoCategoryItem(from: .user(category))
        let driver = CategoryManageTestDriver(preferences: [item])

        driver.tapAddUserCategory()
        driver.setSavesImmediately()

        #expect(driver.categorySheet == nil)

        driver.setSavesImmediately(false)
        driver.selectCategory(item)
        driver.setCategoryName("Renamed")
        driver.setSavesImmediately()

        #expect(driver.categorySheet?.category.id == category.id)
        #expect(driver.userCategory(at: 0)?.name == "Renamed")
    }

    @Test("완료 버튼을 누르면 현재 preferences를 delegate로 전달한다")
    func 완료_버튼을_누르면_현재_preferences를_delegate로_전달한다() async {
        let item = TodoCategoryItem(from: .system(.issue))
        let store = TestStore(
            initialState: CategoryManageFeature.State(preferences: [item])
        ) {
            CategoryManageFeature()
        }

        await store.send(.tapDoneButton)
        await store.receive(.delegate(.done([item])))
    }
}

@MainActor
private struct CategoryManageTestDriver {
    private let feature: StoreOf<CategoryManageFeature>

    var preferences: [TodoCategoryItem] {
        feature.state.preferences
    }

    var categorySheet: CategoryManageFeature.CategorySheetState? {
        feature.state.categorySheet
    }

    var alert: AlertState<CategoryManageFeature.Action.Alert>? {
        feature.state.alert
    }

    init(preferences: [TodoCategoryItem]) {
        feature = Store(
            initialState: CategoryManageFeature.State(preferences: preferences)
        ) {
            CategoryManageFeature()
        }
    }

    func setSavesImmediately(_ savesImmediately: Bool = true) {
        feature.send(.setSavesImmediately(savesImmediately))
    }

    func selectCategory(_ item: TodoCategoryItem) {
        feature.send(.selectCategory(item))
    }

    func tapItem(_ item: TodoCategoryItem) {
        feature.send(.tapItem(item))
    }

    func moveItem(from source: IndexSet, target: Int) {
        feature.send(.moveItem(from: source, target: target))
    }

    func tapAddUserCategory() {
        feature.send(.tapAddUserCategory)
    }

    func tapEditUserCategory(_ item: TodoCategoryItem) {
        feature.send(.tapEditUserCategory(item))
    }

    func tapDeleteUserCategory(_ item: TodoCategoryItem) {
        feature.send(.tapDeleteUserCategory(item))
    }

    func setCategorySheet(_ sheet: CategoryManageFeature.CategorySheetState?) {
        feature.send(.setCategorySheet(sheet))
    }

    func dismissCategorySheet() {
        feature.send(.categorySheet(.dismiss))
    }

    func setCategoryName(_ name: String) {
        feature.send(.categorySheet(.presented(.binding(.set(\.category.name, name)))))
    }

    func setCategoryColor(_ colorHex: String) {
        feature.send(.categorySheet(.presented(.binding(.set(\.category.colorHex, colorHex)))))
    }

    func tapSaveButton() {
        feature.send(.categorySheet(.presented(.tapSaveButton)))
    }

    func tapCloseButton() {
        feature.send(.categorySheet(.presented(.tapCloseButton)))
    }

    func confirmDeleteUserCategory(_ item: TodoCategoryItem) {
        feature.send(.alert(.presented(.confirmDeleteUserCategory(item))))
    }

    func dismissAlert() {
        feature.send(.alert(.dismiss))
    }

    func userCategory(at index: Int) -> UserTodoCategory? {
        guard case .user(let category) = preferences[index].category else {
            return nil
        }

        return category
    }
}
