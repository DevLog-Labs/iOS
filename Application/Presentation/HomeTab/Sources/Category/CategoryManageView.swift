//
//  CategoryManageView.swift
//  HomeTab
//
//  Created by opfic on 6/16/25.
//

import SwiftUI
import PresentationShared

struct CategoryManageView: View {
    @Environment(\.isTabContentActive) private var isTabContentActive
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.setDetailSideBarPresented) private var setDetailSideBarPresented
    @Bindable var store: StoreOf<CategoryManageFeature>
    // 좁은 창에서 시트로 연 카테고리 관리를 닫는 동작
    var onClose: (() -> Void)?

    var body: some View {
        let selectedID = store.categorySheet?.category.id
        // Mac은 Orca 데스크톱처럼 좌우 페이지 여백과 목록 위아래 여백이 작음
        let margin = isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16
        let spacing = isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12

        ReorderableListView<TodoCategoryItem>
            .composable { view in
                view.updateContent(
                    items: store.preferences,
                    header: UIHostingConfiguration {
                        Text(String(localized: "todo_manage_description", bundle: PresentationResources.bundle))
                            .font(.adaptive(.footnote))
                            .foregroundStyle(Color.secondaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .margins(.horizontal, margin)
                    // 사이드바가 있으면 칸 제목 줄 아래를 한 번 더 띄움
                    .margins(.top, usesDesktopLayout ? 12 * AdaptiveSize.boardScale + spacing : spacing)
                    .margins(.bottom, spacing),
                    footer: UIHostingConfiguration {
                        Button {
                            store.send(.tapAddUserCategory)
                            if usesDesktopLayout {
                                setDetailSideBarPresented?(true)
                            }
                        } label: {
                            Text("todo_manage_add_category_title", bundle: PresentationResources.bundle)
                            .font(.adaptive(isiOSAppOnMac ? .headline : .subheadline).weight(.semibold))
                            .foregroundStyle(Color.label)
                            // 좁은 창은 목록 폭, 사이드바가 있으면 글자 폭
                            .frame(maxWidth: usesDesktopLayout ? nil : .infinity)
                            .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : 44)
                            .padding(.horizontal, 16 * AdaptiveSize.boardScale)
                            .background(Color.tertiaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                            .overlay {
                                RoundedRectangle(cornerRadius: CornerRadius.control)
                                    .strokeBorder(Color.secondarySeparator)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .margins(.horizontal, margin)
                    // iPad는 목록과 추가 버튼 사이를 조금 더 띄움
                    .margins(.top, spacing + (usesDesktopLayout && !isiOSAppOnMac ? 8 : 4 * AdaptiveSize.boardScale))
                    .margins(.bottom, usesDesktopLayout && !isiOSAppOnMac ? 8 : 4 * AdaptiveSize.boardScale),
                    row: { item in
                        UIHostingConfiguration {
                            CategoryManageRow(
                                item: item,
                                onToggle: { store.send(.tapItem(item)) },
                                onEdit: {
                                    store.send(.tapEditUserCategory(item))
                                    setDetailSideBarPresented?(true)
                                },
                                onDelete: { store.send(.tapDeleteUserCategory(item)) },
                                onSelect: usesDesktopLayout ? { store.send(.selectCategory(item)) } : nil
                            )
                        }
                        .margins(.horizontal, 0)
                        .margins(.vertical, 0)
                    },
                    onMove: { source, destination in
                        store.send(.moveItem(from: source, target: destination))
                    },
                    selectedID: usesDesktopLayout ? selectedID : nil,
                    // 좁은 창 구분선은 아이콘(28)과 간격(10) 뒤부터, 사이드바가 있으면 행 전체
                    separatorLeadingInset: usesDesktopLayout ? 0 : 38,
                    separatorColor: usesDesktopLayout ? .secondarySeparator : .separator
                )
            }
            // 사이드바가 있으면 칸 가운데 보드 폭으로 표시
            .frame(maxWidth: usesDesktopLayout ? 600 * AdaptiveSize.boardScale : .infinity)
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                if usesDesktopLayout {
                    PaneTitleBar(Text("todo_category_manage", bundle: PresentationResources.bundle))
                } else {
                    CategorySheetTopBar(
                        title: String(localized: "todo_category_manage", bundle: PresentationResources.bundle),
                        closeTitle: String(localized: "common_done", bundle: PresentationResources.bundle),
                        closesAtLeading: false,
                        onClose: { onClose?() }
                    )
                }
            }
            .background((usesDesktopLayout ? Color.background : .secondaryBackground).ignoresSafeArea())
            // 사이드바가 있으면 고른 카테고리를 시트 대신 세부 정보 사이드바에 표시
            .prominentSheet(
                item: $store.scope(state: \.categorySheet, action: \.categorySheet)
                    .activePresentation(when: isTabContentActive && !usesDesktopLayout)
            ) { sheetStore in
                CategoryManageSheet(store: sheetStore)
            }
            .prominentAlert(store, state: \.alert, action: \.alert)
            .detailSideBar(isActive: usesDesktopLayout) {
                if let sheetStore = store.scope(state: \.categorySheet, action: \.categorySheet.presented) {
                    ScrollView {
                        CategoryEditForm(store: sheetStore) {
                            if let item = store.preferences.first(where: { $0.id == sheetStore.category.id }) {
                                store.send(.tapDeleteUserCategory(item))
                            }
                        }
                    }
                } else {
                    DetailSideBarPlaceholder()
                }
            }
            // 카테고리 관리를 벗어나면 카테고리를 보여 주던 세부 정보 사이드바도 닫음
            .onChange(of: isTabContentActive) { _, isActive in
                if usesDesktopLayout && !isActive {
                    setDetailSideBarPresented?(false)
                }
            }
    }
}

// 좁은 창 시트 맨 위의 가운데 제목과 시트를 닫는 글자 버튼, 아래 구분선
// 카테고리 관리는 오른쪽 굵은 완료, 추가·수정은 왼쪽 닫기
private struct CategorySheetTopBar: View {
    let title: String
    let closeTitle: String
    let closesAtLeading: Bool
    let onClose: () -> Void

    var body: some View {
        let closeButton = Button(action: onClose) {
            Text(closeTitle)
                .font(.adaptive(.callout).weight(closesAtLeading ? .medium : .bold))
                .foregroundStyle(Color.label)
                .padding(.horizontal, 4)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)

        ZStack {
            Text(title)
                .font(.adaptive(.callout).bold())
                .lineLimit(1)
            HStack {
                if !closesAtLeading {
                    Spacer()
                }
                closeButton
                if closesAtLeading {
                    Spacer()
                }
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)
        }
        .background(Color.secondaryBackground, ignoresSafeAreaEdges: .top)
    }
}

private struct CategoryManageRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let item: TodoCategoryItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    // 사이드바가 있으면 행을 눌러 세부 정보 사이드바에 표시할 카테고리 선택
    let onSelect: (() -> Void)?

    var body: some View {
        if item.isUserCategory {
            content
                // 좁은 창은 밀어서 드러나는 동작 사각형을 행이 가리도록 시트 바탕을 채움
                .background(usesDesktopLayout ? Color.clear : .secondaryBackground)
                .itemActions {
                    ItemActionButton(
                        title: String(localized: "todo_edit", bundle: PresentationResources.bundle),
                        color: Color.label,
                        image: Image(systemName: "pencil"),
                        action: onEdit
                    )

                    ItemActionButton(
                        title: String(localized: "common_delete", bundle: PresentationResources.bundle),
                        color: Color.danger,
                        image: Image(systemName: "trash"),
                        role: .destructive,
                        action: onDelete
                    )
                }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        // 오른쪽 끝 reorder 핸들과의 간격
        let row = CategoryManageRowContent(item: item, onToggle: onToggle)
            .padding(.trailing, isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 12)

        if let onSelect {
            row
                .contentShape(.rect)
                .onTapGesture(perform: onSelect)
        } else {
            row
        }
    }
}

private struct CategoryManageRowContent: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let item: TodoCategoryItem
    let onToggle: () -> Void

    var body: some View {
        let iconSize = (isiOSAppOnMac ? 25 : 28) * AdaptiveSize.boardScale

        HStack(spacing: 10 * AdaptiveSize.boardScale) {
            // 테두리 있는 아이콘 사각형에 카테고리 색 기호
            Image(systemName: item.symbolName)
                .font(.adaptive(usesDesktopLayout ? .body : .callout))
                .foregroundStyle(item.color)
                .frame(width: iconSize, height: iconSize)
                .background(
                    isiOSAppOnMac ? Color.tertiaryBackground : .background,
                    in: .rect(cornerRadius: CornerRadius.control)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.control)
                        .strokeBorder(Color.secondarySeparator)
                }

            Text(item.localizedName)
                .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                .lineLimit(1)

            Spacer(minLength: 8)

            Toggle(
                item.localizedName,
                isOn: Binding(get: { item.isVisible }, set: { _ in onToggle() })
            )
            .labelsHidden()
            .toggleStyle(.pill)
        }
        .frame(minHeight: isiOSAppOnMac ? 38 * AdaptiveSize.boardScale : 50)
    }
}

private struct CategoryManageSheet: View {
    @Bindable var store: Store<CategoryManageFeature.CategorySheetState, CategoryManageFeature.Action.CategorySheet>

    var body: some View {
        ScrollView {
            CategoryEditForm(store: store)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            CategorySheetTopBar(
                title: store.navigationTitle,
                closeTitle: String(localized: "common_close", bundle: PresentationResources.bundle),
                closesAtLeading: true
            ) {
                store.send(.tapCloseButton)
            }
        }
        .background(Color.secondaryBackground.ignoresSafeArea())
    }
}

// 카테고리 이름과 색, 고친 값은 바로 저장
// 좁은 창은 시트, 사이드바가 있으면 세부 정보 사이드바에 표시
// Mac은 Mac 화면 크기, iPhone·Duo·iPad는 손가락으로 누르는 크기
private struct CategoryEditForm: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Bindable var store: Store<CategoryManageFeature.CategorySheetState, CategoryManageFeature.Action.CategorySheet>
    @FocusState private var isNameFocused: Bool
    // 세부 정보 사이드바에서 고른 카테고리를 지우는 동작
    var onDelete: (() -> Void)?

    var body: some View {
        let isPad = usesDesktopLayout && !isiOSAppOnMac
        let margin = isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16
        let spacing = isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12
        let colorSize = (isPad ? 34 : 30) * AdaptiveSize.boardScale

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6 * AdaptiveSize.boardScale) {
                Text(String(localized: "todo_manage_name_placeholder", bundle: PresentationResources.bundle))
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
                nameField
                if store.isDuplicatedName {
                    Text(String(localized: "todo_manage_name_duplicate", bundle: PresentationResources.bundle))
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.danger)
                }
            }
            .padding(.horizontal, margin)
            .padding(.vertical, (isiOSAppOnMac ? 4 : 8) * AdaptiveSize.boardScale)

            VStack(alignment: .leading, spacing: (isPad ? 10 : 8) * AdaptiveSize.boardScale) {
                HStack {
                    Text(String(localized: "todo_manage_color", bundle: PresentationResources.bundle))
                        .foregroundStyle(Color.secondaryLabel)
                    Spacer()
                    Button {
                        store.send(.tapRandomColorButton)
                    } label: {
                        Text(String(localized: "todo_manage_random_color", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.label)
                    }
                    .buttonStyle(.plain)
                }
                .font(.adaptive(.footnote))
                LazyVGrid(
                    columns: [GridItem(
                        .adaptive(minimum: colorSize, maximum: colorSize),
                        spacing: 10 * AdaptiveSize.boardScale
                    )],
                    alignment: .leading,
                    spacing: 10 * AdaptiveSize.boardScale
                ) {
                    ForEach(UserTodoCategoryItem.paletteHexValues, id: \.self) { colorHex in
                        Button {
                            store.send(.binding(.set(\.category.colorHex, colorHex)))
                        } label: {
                            Circle()
                                .fill(UserTodoCategoryItem.color(colorHex: colorHex))
                                .frame(width: colorSize, height: colorSize)
                                .overlay {
                                    if store.category.colorHex.caseInsensitiveCompare(colorHex) == .orderedSame {
                                        Image(systemName: "checkmark")
                                            .font(.adaptive(isPad ? .body : .callout).bold())
                                            .foregroundStyle(Color.background)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, margin)
            .padding(.vertical, spacing)

            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "todo_preview", bundle: PresentationResources.bundle))
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
                    .padding(.bottom, 6 * AdaptiveSize.boardScale)
                CategoryManageRowContent(item: store.todoCategoryItem, onToggle: {})
                    .allowsHitTesting(false)
                Text(String(localized: "todo_manage_preview_description", bundle: PresentationResources.bundle))
                    .font(.adaptive(.caption))
                    .foregroundStyle(Color.secondaryLabel)
                    .padding(.top, (isPad ? 8 : 6) * AdaptiveSize.boardScale)
                    .padding(.horizontal, isiOSAppOnMac ? 4 * AdaptiveSize.boardScale : 0)
            }
            .padding(.horizontal, margin)
            .padding(.vertical, spacing)

            // 방금 만든 카테고리는 지우는 버튼 없이 표시
            if let onDelete, !store.isNew {
                Button(action: onDelete) {
                    Text(String(localized: "todo_manage_delete_category_title", bundle: PresentationResources.bundle))
                        .font(.adaptive(isiOSAppOnMac ? .headline : .subheadline).weight(.semibold))
                        .foregroundStyle(Color.danger)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, margin)
                .padding(.vertical, (isiOSAppOnMac ? 16 : 20) * AdaptiveSize.boardScale)
            }
        }
    }

    private var nameField: some View {
        HStack(spacing: 8 * AdaptiveSize.boardScale) {
            TextField(
                "",
                text: $store.category.name,
                prompt: Text(store.placeholder).foregroundStyle(Color.secondaryLabel)
            )
            .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
            .focused($isNameFocused)
            Text(store.categoryNameCountText)
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)
                .monospacedDigit()
        }
        .tint(Color.label)
        .padding(.horizontal, 12 * AdaptiveSize.boardScale)
        .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : 44)
        .modifier(CategoryNameFieldBackground(isFocused: isNameFocused, isInvalid: store.isDuplicatedName))
    }
}

// 사이드바가 있으면 공용 입력칸 모양, 좁은 창 시트는 시트 바탕과 구분되는 채운 입력칸
private struct CategoryNameFieldBackground: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let isFocused: Bool
    let isInvalid: Bool

    func body(content: Content) -> some View {
        if usesDesktopLayout {
            content.inputBackground(isFocused: isFocused, isInvalid: isInvalid)
        } else {
            content
                .background(Color.tertiaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.control)
                        .strokeBorder(isInvalid ? Color.danger : .secondarySeparator)
                }
        }
    }
}
