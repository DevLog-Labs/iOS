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
    @Environment(\.deviceType) private var deviceType
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.setDetailSideBarPresented) private var setDetailSideBarPresented
    @Bindable var store: StoreOf<CategoryManageFeature>
    // 사이드바가 있는 창에서 칸으로 연 카테고리 관리를 닫고 이전 화면으로 돌아가는 동작
    var onBack: (() -> Void)?

    var body: some View {
        let selectedID = store.categorySheet?.category.id

        CardCollectionView<TodoCategoryItem>
            .composable { view in
                view.updateContent(
                    items: store.preferences,
                    header: UIHostingConfiguration {
                        // Mac은 목록 상자 왼쪽 끝에 맞춰 왼쪽 정렬
                        Text(String(localized: "todo_manage_description", bundle: PresentationResources.bundle))
                            .font(.adaptive(.footnote))
                            .foregroundStyle(Color.secondaryLabel)
                            .multilineTextAlignment(isiOSAppOnMac ? .leading : .center)
                            .frame(maxWidth: .infinity, alignment: isiOSAppOnMac ? .leading : .center)
                    }
                    .margins(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                    .margins(.top, isiOSAppOnMac ? 20 * AdaptiveSize.boardScale : 8)
                    .margins(.bottom, 8),
                    footer: UIHostingConfiguration {
                        // 사이드바가 있으면 목록 바로 아래에 추가 버튼 표시
                        if usesDesktopLayout {
                            Button {
                                store.send(.tapAddUserCategory)
                                setDetailSideBarPresented?(true)
                            } label: {
                                Label(
                                    String(localized: "todo_manage_add_category_title", bundle: PresentationResources.bundle),
                                    systemImage: "plus"
                                )
                                .font(.adaptive(isiOSAppOnMac ? .headline : .subheadline).weight(.semibold))
                                .foregroundStyle(Color.label)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6 * AdaptiveSize.boardScale)
                            }
                            .adaptiveButtonStyle(
                                shape: RoundedRectangle(cornerRadius: CornerRadius.control),
                                color: isiOSAppOnMac ? .tertiaryBackground : .fill
                            )
                            // Mac은 목록 상자와 같은 옅은 테두리
                            .overlay {
                                if isiOSAppOnMac {
                                    RoundedRectangle(cornerRadius: CornerRadius.control)
                                        .strokeBorder(Color.secondarySeparator)
                                }
                            }
                        }
                    }
                    // 목록 카드 배경과 같은 좌우 여백
                    .margins(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                    .margins(.vertical, isiOSAppOnMac ? 4 * AdaptiveSize.boardScale : 8),
                    row: { item in
                        UIHostingConfiguration {
                            CategoryManageRow(
                                item: item,
                                isSelected: usesDesktopLayout && item.id == selectedID,
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
                        .margins(.vertical, isiOSAppOnMac ? 0 : 8)
                    },
                    onMove: { source, destination in
                        store.send(.moveItem(from: source, target: destination))
                    }
                )
            }
            // 사이드바가 있으면 칸 가운데 보드 폭으로 표시
            .frame(maxWidth: usesDesktopLayout ? 600 * AdaptiveSize.boardScale : .infinity)
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                if usesDesktopLayout {
                    PaneTitleBar(
                        Text("todo_category_manage", bundle: PresentationResources.bundle),
                        onBack: onBack,
                        showsBackOnDesktop: true
                    )
                } else {
                    toolBar
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !usesDesktopLayout {
                    Button {
                        store.send(.tapAddUserCategory)
                    } label: {
                        Label(
                            String(localized: "todo_manage_add_category_title", bundle: PresentationResources.bundle),
                            systemImage: "plus.circle.fill"
                        )
                        .font(.adaptive(.headline))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: CornerRadius.control), color: .accent)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(deviceType == .duo ? Color.background : .secondaryBackground, ignoresSafeAreaEdges: .bottom)
                }
            }
            .background(Color.background.ignoresSafeArea())
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
                    CategorySideBarContent(store: sheetStore) {
                        if let item = store.preferences.first(where: { $0.id == sheetStore.category.id }) {
                            store.send(.tapDeleteUserCategory(item))
                        }
                    }
                } else {
                    DetailSideBarPlaceholder()
                }
            }
            // 창 폭이 바뀌어 칸과 시트를 오가면 저장 방식도 맞춤
            .onChange(of: usesDesktopLayout, initial: true) { _, usesDesktopLayout in
                store.send(.setSavesImmediately(usesDesktopLayout))
            }
            // 카테고리 관리를 벗어나면 카테고리를 보여 주던 세부 정보 사이드바도 닫음
            .onChange(of: isTabContentActive) { _, isActive in
                if usesDesktopLayout && !isActive {
                    setDetailSideBarPresented?(false)
                }
            }
    }

    private var toolBar: some View {
        ZStack {
            Text(String(localized: "todo_category_manage", bundle: PresentationResources.bundle))
                .font(.adaptive(.headline))
            HStack {
                Spacer()
                if #available(iOS 26.0, *) {
                    Button {
                        store.send(.tapDoneButton, animation: .default)
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .topBarButtonStyle()
                } else {
                    Button {
                        store.send(.tapDoneButton, animation: .default)
                    } label: {
                        Text(String(localized: "profile_done", bundle: PresentationResources.bundle))
                    }
                    .topBarButtonStyle(tint: Color.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }
}

private struct CategoryManageRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let item: TodoCategoryItem
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    // 사이드바가 있으면 행을 눌러 세부 정보 사이드바에 표시할 카테고리 선택
    let onSelect: (() -> Void)?

    var body: some View {
        if item.isUserCategory {
            content
                .background(Color.secondaryBackground)
                .itemActions {
                    ItemActionButton(
                        title: String(localized: "todo_edit", bundle: PresentationResources.bundle),
                        color: Color.accent,
                        image: Image(systemName: "pencil"),
                        action: onEdit
                    )

                    ItemActionButton(
                        title: String(localized: "common_delete", bundle: PresentationResources.bundle),
                        color: Color.red,
                        image: Image(systemName: "trash"),
                        action: onDelete
                    )
                }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        // Mac은 목록 상자 끝까지 이어지는 구분선 안쪽에 행 여백을 둠
        let row = CategoryManageRowContent(item: item, onToggle: onToggle)
            .padding(.leading, isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 0)
            .background(isSelected ? Color.fill : .clear)

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
    let item: TodoCategoryItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 12) {
            // Mac은 설정 행처럼 테두리 있는 아이콘 사각형에 카테고리 색 기호
            if isiOSAppOnMac {
                Image(systemName: item.symbolName)
                    .font(.adaptive(.body))
                    .foregroundStyle(item.color)
                    .frame(width: 25 * AdaptiveSize.boardScale, height: 25 * AdaptiveSize.boardScale)
                    .background(Color.tertiaryBackground, in: .rect(cornerRadius: CornerRadius.segment))
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.segment)
                            .strokeBorder(Color.secondarySeparator)
                    }
            } else {
                Image(systemName: item.symbolName)
                    .font(.adaptive(.headline))
                    .frame(width: 36, height: 36)
                    .iconStyle(color: item.color, in: Circle())
            }

            Text(item.localizedName)
                .font(.adaptive(.body))
                .lineLimit(1)

            Spacer(minLength: 8)

            Toggle(
                item.localizedName,
                isOn: Binding(get: { item.isVisible }, set: { _ in onToggle() })
            )
            .labelsHidden()
            .toggleStyle(.pill)
        }
        .padding(.trailing, isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 12)
        .frame(minHeight: isiOSAppOnMac ? 38 * AdaptiveSize.boardScale : 44)
    }
}

private let categoryColorHexValues = [
    "#FF3B30", "#FF9500", "#34C759", "#1EA0A6", "#007AFF", "#AF52DE", "#FF2D55", "#8E8E93"
]

private struct CategoryManageSheet: View {
    @Environment(\.deviceType) private var deviceType
    @Bindable var store: Store<CategoryManageFeature.CategorySheetState, CategoryManageFeature.Action.CategorySheet>

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                nameCard
                colorCard
                previewCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .contentMargins(.top, 16, for: .scrollContent)
        .safeAreaInset(edge: .top, spacing: 0) { toolBar }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                store.send(.tapSaveButton)
            } label: {
                Text(store.submitTitle)
                    .font(.adaptive(.headline))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: CornerRadius.control), color: .accent)
            .disabled(!store.canSubmitUserCategory)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(deviceType == .duo ? Color.background : .secondaryBackground, ignoresSafeAreaEdges: .bottom)
        }
        .background(Color.background.ignoresSafeArea())
    }

    private var toolBar: some View {
        ZStack {
            Text(store.navigationTitle)
                .font(.adaptive(.headline))
            HStack {
                Button {
                    store.send(.tapCloseButton)
                } label: {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "xmark")
                    } else {
                        Text(String(localized: "common_close", bundle: PresentationResources.bundle))
                    }
                }
                .topBarButtonStyle()

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "todo_manage_name_placeholder", bundle: PresentationResources.bundle))
                .font(.adaptive(.headline))
                .padding(.horizontal, 16)

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $store.category.name,
                    prompt: Text(store.placeholder).foregroundStyle(Color.secondaryLabel)
                )
                .font(.adaptive(.body))

                Text(store.categoryNameCountText)
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
                    .monospacedDigit()
            }
            .padding()
            .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
            .tint(Color.accent)

            Text(store.nameMessage)
                .font(.adaptive(.footnote))
                .foregroundStyle(store.isDuplicatedName ? Color.danger : Color.secondaryLabel)
                .padding(.horizontal, 16)
        }
    }

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "todo_manage_color", bundle: PresentationResources.bundle))
                    .font(.adaptive(.headline))

                Spacer()

                Button {
                    store.send(.tapRandomColorButton)
                } label: {
                    Label(
                        String(localized: "todo_manage_random_color", bundle: PresentationResources.bundle),
                        systemImage: "shuffle"
                    )
                    .font(.adaptive(.subheadline))
                    .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 16) {
                Image(systemName: store.todoCategoryItem.symbolName)
                    .font(.adaptive(.largeTitle))
                    .frame(width: 88, height: 88)
                    .iconStyle(color: store.todoCategoryItem.color, in: Circle())

                HStack(spacing: 4) {
                    ForEach(categoryColorHexValues, id: \.self) { colorHex in
                        let color = Color(hexString: colorHex) ?? .gray
                        let isSelected = store.category.colorHex.caseInsensitiveCompare(colorHex) == .orderedSame

                        Button {
                            store.send(.binding(.set(\.category.colorHex, colorHex)))
                        } label: {
                            Circle()
                                .fill(color)
                                .padding(3)
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.adaptive(.caption).bold())
                                            .foregroundStyle(.white)
                                        Circle()
                                            .strokeBorder(color, lineWidth: 2)
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }

                    ColorPicker(
                        store.category.colorHex.isEmpty ? "#" : store.category.colorHex,
                        selection: $store.category.colorHex.colorValue,
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "todo_preview", bundle: PresentationResources.bundle))
                .font(.adaptive(.headline))
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "todo_manage_preview_description", bundle: PresentationResources.bundle))
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)

                HStack(spacing: 12) {
                    CategoryManageRowContent(item: store.todoCategoryItem, onToggle: {})
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(Color.tertiaryLabel)
                }
                .allowsHitTesting(false)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
    }
}

// 세부 정보 사이드바의 카테고리 속성, 고친 값은 바로 저장
// Mac은 Mac 화면 크기, iPad는 손가락으로 누르는 크기
private struct CategorySideBarContent: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: Store<CategoryManageFeature.CategorySheetState, CategoryManageFeature.Action.CategorySheet>
    @FocusState private var isNameFocused: Bool
    let onDelete: () -> Void

    var body: some View {
        let item = store.todoCategoryItem
        let colorSize = isiOSAppOnMac ? 30 * AdaptiveSize.boardScale : 34

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6 * AdaptiveSize.boardScale) {
                    Text(String(localized: "todo_manage_name_placeholder", bundle: PresentationResources.bundle))
                        .font(.adaptive(isiOSAppOnMac ? .subheadline : .footnote))
                        .foregroundStyle(Color.secondaryLabel)
                    HStack(spacing: 8 * AdaptiveSize.boardScale) {
                        TextField(
                            "",
                            text: $store.category.name,
                            prompt: Text(store.placeholder).foregroundStyle(Color.secondaryLabel)
                        )
                        .focused($isNameFocused)
                        Text(store.categoryNameCountText)
                            .font(.adaptive(isiOSAppOnMac ? .subheadline : .footnote))
                            .foregroundStyle(Color.secondaryLabel)
                            .monospacedDigit()
                    }
                    .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                    .tint(Color.accent)
                    .padding(.horizontal, 12 * AdaptiveSize.boardScale)
                    .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : 44)
                    .inputBackground(isFocused: isNameFocused, isInvalid: store.isDuplicatedName)
                    if store.isDuplicatedName {
                        Text(store.nameMessage)
                            .font(.adaptive(.footnote))
                            .foregroundStyle(Color.danger)
                    }
                }
                .padding(.horizontal, 14 * AdaptiveSize.boardScale)
                .padding(.vertical, 4 * AdaptiveSize.boardScale)

                VStack(alignment: .leading, spacing: 8 * AdaptiveSize.boardScale) {
                    HStack {
                        Text(String(localized: "todo_manage_color", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.secondaryLabel)
                        Spacer()
                        Button {
                            store.send(.tapRandomColorButton)
                        } label: {
                            Text(String(localized: "todo_manage_random_color", bundle: PresentationResources.bundle))
                                .foregroundStyle(Color.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.adaptive(isiOSAppOnMac ? .subheadline : .footnote))
                    LazyVGrid(
                        columns: [GridItem(
                            .adaptive(minimum: colorSize, maximum: colorSize),
                            spacing: 10 * AdaptiveSize.boardScale
                        )],
                        alignment: .leading,
                        spacing: 10 * AdaptiveSize.boardScale
                    ) {
                        ForEach(categoryColorHexValues, id: \.self) { colorHex in
                            Button {
                                store.send(.binding(.set(\.category.colorHex, colorHex)))
                            } label: {
                                Circle()
                                    .fill(Color(hexString: colorHex) ?? .gray)
                                    .frame(width: colorSize, height: colorSize)
                                    .overlay {
                                        if store.category.colorHex.caseInsensitiveCompare(colorHex) == .orderedSame {
                                            Image(systemName: "checkmark")
                                                .font(.adaptive(.callout).bold())
                                                .foregroundStyle(Color.background)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14 * AdaptiveSize.boardScale)
                .padding(.vertical, 8 * AdaptiveSize.boardScale)

                VStack(alignment: .leading, spacing: 6 * AdaptiveSize.boardScale) {
                    Text(String(localized: "todo_preview", bundle: PresentationResources.bundle))
                        .font(.adaptive(isiOSAppOnMac ? .subheadline : .footnote))
                        .foregroundStyle(Color.secondaryLabel)
                        .padding(.horizontal, 4 * AdaptiveSize.boardScale)
                    CategoryManageRowContent(item: item, onToggle: {})
                        .padding(.leading, 12 * AdaptiveSize.boardScale)
                        .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
                        .allowsHitTesting(false)
                    Text(String(localized: "todo_manage_preview_description", bundle: PresentationResources.bundle))
                        .font(.adaptive(.caption))
                        .foregroundStyle(Color.secondaryLabel)
                        .padding(.horizontal, 4 * AdaptiveSize.boardScale)
                }
                .padding(.horizontal, 14 * AdaptiveSize.boardScale)
                .padding(.vertical, 8 * AdaptiveSize.boardScale)

                Button(action: onDelete) {
                    Text(String(localized: "todo_manage_delete_category_title", bundle: PresentationResources.bundle))
                        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline).weight(.semibold))
                        .foregroundStyle(Color.danger)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14 * AdaptiveSize.boardScale)
                .padding(.vertical, 16 * AdaptiveSize.boardScale)
            }
        }
    }
}

private extension String {
    var colorValue: Color {
        get { Color(hexString: self) ?? .randomValue }
        set {
            if let hexValue = newValue.hexValue {
                self = hexValue
            }
        }
    }
}
