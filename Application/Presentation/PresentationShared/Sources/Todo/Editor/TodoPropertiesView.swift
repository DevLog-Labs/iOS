//
//  TodoPropertiesView.swift
//  PresentationShared
//
//  Created by opfic on 9/13/26.
//

import SwiftUI
import ComposableArchitecture
import Core

public struct TodoPropertiesView: View {
    @Bindable var store: StoreOf<TodoEditorFeature>
    @FocusState private var isTagFieldFocused: Bool
    var showsEditorActions = false
    var onSubmit: () -> Void = {}
    let onClose: () -> Void
    private let calendar = Calendar.current

    public init(
        store: StoreOf<TodoEditorFeature>,
        showsEditorActions: Bool = false,
        onSubmit: @escaping () -> Void = {},
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.showsEditorActions = showsEditorActions
        self.onSubmit = onSubmit
        self.onClose = onClose
    }

    public var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) { toolBar }
            .background(Color.background.ignoresSafeArea())
            .presentationDragIndicator(.visible)
    }

    private var toolBar: some View {
        ZStack {
            if !showsEditorActions {
                Text(String(localized: "todo_details", bundle: PresentationResources.bundle))
                    .font(.headline)
            }
            HStack {
                if !showsEditorActions {
                    if #available(iOS 26.0, *) {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .topBarButtonStyle()
                    } else {
                        Button {
                            onClose()
                        } label: {
                            Text(String(localized: "common_done", bundle: PresentationResources.bundle))
                        }
                        .topBarButtonStyle(tint: Color.accent)
                    }
                }
                Spacer()
                if showsEditorActions {
                    EditorToolbarActions(store: store, onSubmit: onSubmit)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        optionIcon("tag.fill", color: Color.accent)
                        Text(String(localized: "todo_category", bundle: PresentationResources.bundle))
                        Spacer()
                        Picker(
                            String(localized: "todo_category", bundle: PresentationResources.bundle),
                            selection: $store.selectedCategoryID
                        ) {
                            ForEach(store.categories, id: \.id) { item in
                                Text(item.localizedName)
                                    .tag(item.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.accent)
                    }
                    .padding(.vertical, 12)

                    Divider().overlay(Color.separator)

                    Toggle(isOn: $store.isCompleted) {
                        HStack(spacing: 12) {
                            optionIcon("circle", color: Color.secondaryLabel)
                            Text(String(localized: "todo_completed", bundle: PresentationResources.bundle))
                        }
                    }
                    .tint(Color.accent)
                    .padding(.vertical, 12)

                    Divider().overlay(Color.separator)

                    Toggle(isOn: $store.isPinned) {
                        HStack(spacing: 12) {
                            optionIcon("star.fill", color: Color.warning)
                            Text(String(localized: "todo_pinned", bundle: PresentationResources.bundle))
                        }
                    }
                    .tint(Color.accent)
                    .padding(.vertical, 12)

                    Divider().overlay(Color.separator)

                    dueDateControl
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .groupBackground(in: .rect(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "todo_tags", bundle: PresentationResources.bundle))
                        .font(.headline)
                        .padding(.horizontal, 16)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            TextField(
                                String(localized: "todo_add", bundle: PresentationResources.bundle),
                                text: $store.tagText
                            )
                            .frame(height: UIFont.preferredFont(forTextStyle: .title2).lineHeight)
                            .textInputAutocapitalization(.never)
                            .focused($isTagFieldFocused)
                            .onSubmit { submitTag() }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.fill, in: .rect(cornerRadius: 12))
                            .tint(Color.accent)

                            Button {
                                submitTag()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(canSubmitTag ? Color.secondaryBackground : Color.secondaryLabel)
                                    .padding(12)
                                    .background(
                                        canSubmitTag ? Color.accent : Color.fill,
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!canSubmitTag)
                        }

                        if store.tags.isEmpty {
                            Text(String(localized: "todo_no_tags", bundle: PresentationResources.bundle))
                                .foregroundStyle(Color.secondaryLabel)
                                .padding(.vertical, 4)
                        } else {
                            TagList(
                                store.tags,
                                isEditing: true,
                                action: { store.send(.removeTag($0)) }
                            )
                        }
                        Text(String(
                            localized: "todo_tag_duplicate_hint",
                            bundle: PresentationResources.bundle
                        ))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .groupBackground(in: .rect(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .contentMargins(.top, 16, for: .scrollContent)
    }

    private func optionIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.title3)
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.08), in: Circle())
    }

    private var dueDateControl: some View {
        DueDatePicker(selection: $store.selectedDueDate) {
            HStack(spacing: 12) {
                optionIcon("calendar", color: Color.secondaryLabel)
                Text(String(localized: "todo_due_date", bundle: PresentationResources.bundle))
                    .foregroundStyle(Color.label)
                Spacer()
                if let dueDate = store.dueDate {
                    Tag(dueDateText(for: dueDate), isEditing: true) {
                        store.send(.binding(.set(\.dueDate, nil)))
                    }
                    .padding(.vertical, -4)
                } else {
                    Text(String(localized: "todo_none", bundle: PresentationResources.bundle))
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
        }
    }

    private func close() {
        isTagFieldFocused = false
        onClose()
    }

    private func submitTag() {
        guard canSubmitTag else { return }

        let tagText = normalizedTagText
        store.send(.addTag(tagText))
        store.send(.binding(.set(\.tagText, "")))
    }

    private var normalizedTagText: String {
        store.tagText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitTag: Bool {
        !normalizedTagText.isEmpty && !store.tags.contains(normalizedTagText)
    }

    private func dueDateText(for dueDate: Date) -> String {
        let currentYear = calendar.component(.year, from: Date())
        let dueDateYear = calendar.component(.year, from: dueDate)

        if currentYear == dueDateYear {
            return dueDate.formatted(
                .dateTime.month(.defaultDigits).day(.defaultDigits)
            )
        }

        return dueDate.formatted(
            .dateTime.year(.twoDigits).month(.defaultDigits).day(.defaultDigits)
        )
    }
}

private struct DueDatePicker<Content: View>: View {
    @Environment(\.isTabContentActive) private var isTabContentActive
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @State private var isPresented: Bool = false
    @State private var height: CGFloat = .pi
    @Binding var dueDate: Date
    @ViewBuilder private var content: () -> Content

    init(
        selection dueDate: Binding<Date>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._dueDate = dueDate
        self.content = content
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            content()
        }
        .sheet(isPresented: $isPresented.activePresentation(when: isTabContentActive)) {
            DatePicker(
                "",
                selection: $dueDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.graphical)
            .presentationDragIndicator(.visible)
            .presentationDetents([.height(height)])
            .background {
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        height = geometry.size.height + safeAreaInsets.bottom + safeAreaInsets.top
                    }
                }
            }
        }
    }
}
