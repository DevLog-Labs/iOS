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
    @Bindable var store: StoreOf<CategoryManageFeature>

    var body: some View {
        CardCollectionView<TodoCategoryItem>
            .composable { view in
                view.updateContent(
                    items: store.preferences,
                    header: UIHostingConfiguration {
                        Text(String(localized: "todo_manage_description", bundle: PresentationResources.bundle))
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .margins(.horizontal, 16)
                    .margins(.vertical, 8),
                    footer: UIHostingConfiguration { EmptyView() }
                        .margins(.vertical, 8),
                    row: { item in
                        UIHostingConfiguration {
                            CategoryManageRow(
                                item: item,
                                onToggle: { store.send(.tapItem(item)) },
                                onEdit: { store.send(.tapEditUserCategory(item)) },
                                onDelete: { store.send(.tapDeleteUserCategory(item)) }
                            )
                        }
                        .margins(.horizontal, 0)
                        .margins(.vertical, 8)
                    },
                    onMove: { source, destination in
                        store.send(.moveItem(from: source, target: destination))
                    }
                )
            }
            .safeAreaInset(edge: .top, spacing: 0) { toolBar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    store.send(.tapAddUserCategory)
                } label: {
                    Label(
                        String(localized: "todo_manage_add_category_title", bundle: PresentationResources.bundle),
                        systemImage: "plus.circle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: 16), color: .accent)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(deviceType == .duo ? Color.appBackground : .surface, ignoresSafeAreaEdges: .bottom)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .sheet(
                item: $store.scope(state: \.categorySheet, action: \.categorySheet)
                    .activePresentation(when: isTabContentActive)
            ) { sheetStore in
                CategoryManageSheet(store: sheetStore)
            }
            .prominentAlert(store, state: \.alert, action: \.alert)
            .presentationDragIndicator(.visible)
    }

    private var toolBar: some View {
        ZStack {
            Text(String(localized: "todo_category_manage", bundle: PresentationResources.bundle))
                .font(.headline)
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
        .background(Color.appBackground, ignoresSafeAreaEdges: .top)
    }
}

private struct CategoryManageRow: View {
    let item: TodoCategoryItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if item.isUserCategory {
            CategoryManageRowContent(item: item, onToggle: onToggle)
                .background(Color.surface)
                .itemActions {
                    ItemActionButton(
                        color: Color.accent,
                        image: Image(systemName: "pencil"),
                        action: onEdit
                    )

                    ItemActionButton(
                        color: Color.red,
                        image: Image(systemName: "trash"),
                        action: onDelete
                    )
                }
        } else {
            CategoryManageRowContent(item: item, onToggle: onToggle)
        }
    }
}

private struct CategoryManageRowContent: View {
    let item: TodoCategoryItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.headline)
                .frame(width: 36, height: 36)
                .iconStyle(color: item.color, in: Circle())

            Text(item.localizedName)
                .lineLimit(1)

            Spacer(minLength: 8)

            Toggle(
                item.localizedName,
                isOn: Binding(get: { item.isVisible }, set: { _ in onToggle() })
            )
            .labelsHidden()
            .tint(Color.accent)
        }
        .padding(.trailing, 12)
        .frame(minHeight: 44)
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
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: 16), color: .accent)
            .disabled(!store.canSubmitUserCategory)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(deviceType == .duo ? Color.appBackground : .surface, ignoresSafeAreaEdges: .bottom)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    private var toolBar: some View {
        ZStack {
            Text(store.navigationTitle)
                .font(.headline)
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
        .background(Color.appBackground, ignoresSafeAreaEdges: .top)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "todo_manage_name_placeholder", bundle: PresentationResources.bundle))
                .font(.headline)
                .padding(.horizontal, 16)

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $store.category.name,
                    prompt: Text(store.placeholder).foregroundStyle(.secondary)
                )
                .font(.body)

                Text(store.categoryNameCountText)
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
            }
            .padding()
            .background(Color.surface, in: .rect(cornerRadius: 16))
            .tint(Color.accent)

            Text(store.nameMessage)
                .font(.footnote)
                .foregroundStyle(store.isDuplicatedName ? Color.danger : Color.textSecondary)
                .padding(.horizontal, 16)
        }
    }

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "todo_manage_color", bundle: PresentationResources.bundle))
                    .font(.headline)

                Spacer()

                Button {
                    store.send(.tapRandomColorButton)
                } label: {
                    Label(
                        String(localized: "todo_manage_random_color", bundle: PresentationResources.bundle),
                        systemImage: "shuffle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 16) {
                Image(systemName: store.todoCategoryItem.symbolName)
                    .font(.largeTitle)
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
                                            .font(.caption.bold())
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
            .background(Color.surface, in: .rect(cornerRadius: 16))
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "todo_preview", bundle: PresentationResources.bundle))
                .font(.headline)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "todo_manage_preview_description", bundle: PresentationResources.bundle))
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: 12) {
                    CategoryManageRowContent(item: store.todoCategoryItem, onToggle: {})
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(Color.textTertiary)
                }
                .allowsHitTesting(false)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface, in: .rect(cornerRadius: 16))
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
