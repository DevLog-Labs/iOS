//
//  GoalCreateView.swift
//  Development
//
//  Created by opfic on 9/20/26.
//

import SwiftUI
import Domain
import PresentationShared

public struct GoalCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<GoalCreateFeature>
    @FocusState private var focusedField: GoalCreateField?
    private let onCompletion: (DevelopmentGoal) -> Void

    public init(onCompletion: @escaping (DevelopmentGoal) -> Void = { _ in }) {
        self._store = State(initialValue: Store(
            initialState: GoalCreateFeature.State()
        ) {
            GoalCreateFeature()
        })
        self.onCompletion = onCompletion
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24 * AdaptiveSize.scale) {
                    GoalCreateTitleField(store: store, focusedField: $focusedField)
                    GoalCreateDescriptionEditor(store: store, focusedField: $focusedField)
                    GoalCreateStatusField()
                    GoalCreateTodoField(store: store)
                }
                .padding(.horizontal)
                .padding(.bottom, 20 * AdaptiveSize.scale)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                GoalCreateTopBar(
                    isSaving: store.isSaving,
                    onClose: { dismiss() }
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                GoalCreateSaveBar(
                    isSaving: store.isSaving,
                    isSaveEnabled: store.isReadyToSave,
                    onSave: save
                )
            }
            .background(Color.background.ignoresSafeArea())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .prominentAlert(store, state: \.alert, action: \.alert)
            .prominentSheet(item: $store.scope(state: \.todoSelection, action: \.todoSelection)) {
                GoalCreateTodoSelectionSheet(store: $0)
            }
            .onChange(of: store.result) { _, result in
                guard let result else { return }
                onCompletion(result)
                dismiss()
            }
        }
        .sheetDismissDisabled(store.isSaving)
    }

    private func save() {
        focusedField = nil
        store.send(.view(.save))
    }
}

private struct GoalCreateTopBar: View {
    let isSaving: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text(RecordPresentation.text("development_goal_create_title"))
                .font(.adaptive(.headline))

            HStack {
                Button(action: onClose) {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "xmark")
                    } else {
                        Text(RecordPresentation.text("common_close"))
                    }
                }
                .topBarButtonStyle(tint: Color.accent)
                .disabled(isSaving)

                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12 * AdaptiveSize.scale)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }
}

private struct GoalCreateTitleField: View {
    @Bindable var store: StoreOf<GoalCreateFeature>
    let focusedField: FocusState<GoalCreateField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * AdaptiveSize.scale) {
            Text(RecordPresentation.text("development_goal_create_title_label"))
                .font(.adaptive(.headline))

            TextField(
                RecordPresentation.text("development_goal_create_title_placeholder"),
                text: $store.title
            )
            .focused(focusedField, equals: .title)
            .font(.adaptive(.body))
            .padding()
            .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
        }
        .disabled(store.isSaving)
    }
}

private struct GoalCreateDescriptionEditor: View {
    @Bindable var store: StoreOf<GoalCreateFeature>
    let focusedField: FocusState<GoalCreateField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * AdaptiveSize.scale) {
            Text(RecordPresentation.text("development_goal_create_description_label"))
                .font(.adaptive(.headline))

            VStack(spacing: 16 * AdaptiveSize.scale) {
                GoalCreateModePicker(store: store, focusedField: focusedField)

                Group {
                    switch store.selectedTab {
                    case .write:
                        TextEditorContentLayout(minimumHeight: 120) {
                            Text(RecordPresentation.text("development_goal_create_markdown_hint"))
                                .font(.adaptive(.caption))
                                .foregroundStyle(Color.tertiaryLabel)
                            UIKitTextEditor
                                .composable(
                                    update: { textEditor in
                                        textEditor.updateInput(
                                            text: $store.markdownContent,
                                            isFocused: focusedField.wrappedValue == .content,
                                            onFocusChange: { isFocused in
                                                if isFocused {
                                                    focusedField.wrappedValue = .content
                                                } else if focusedField.wrappedValue == .content {
                                                    focusedField.wrappedValue = nil
                                                }
                                            },
                                            isEnabled: !store.isSaving
                                        )
                                    },
                                    sizeThatFits: { UIKitTextEditor.fittingSize(proposal: $0, textEditor: $1) }
                                )
                                .focused(focusedField, equals: .content)
                                .padding(12 * AdaptiveSize.scale)
                                .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                        }
                        .contentShape(.rect)
                        .onTapGesture { focusedField.wrappedValue = .content }
                    case .preview:
                        Group {
                            if store.markdownContent.isEmpty {
                                VStack(spacing: 8 * AdaptiveSize.scale) {
                                    Text(RecordPresentation.text("development_goal_create_preview_empty_title"))
                                        .font(.adaptive(.headline))
                                    Text(RecordPresentation.text("development_goal_create_preview_empty_message"))
                                        .font(.adaptive(.subheadline))
                                        .foregroundStyle(Color.secondaryLabel)
                                }
                                .multilineTextAlignment(.center)
                                .padding(12 * AdaptiveSize.scale)
                                .frame(maxWidth: .infinity, minHeight: 120 * AdaptiveSize.scale, alignment: .center)
                                .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                            } else {
                                MarkdownContentView(
                                    content: store.markdownContent,
                                    isScrollEnabled: false
                                )
                                    // MarkdownRenderer 내부의 좌우 여백을 상쇄해 입력 본문과 정렬
                                    .padding(.horizontal, -16)
                                    .padding(12 * AdaptiveSize.scale)
                                    .frame(minHeight: 120 * AdaptiveSize.scale, alignment: .topLeading)
                                    .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                            }
                        }
                    }
                }
                .frame(minHeight: 120 * AdaptiveSize.scale, alignment: .topLeading)
            }
        }
        .disabled(store.isSaving)
    }
}

private struct GoalCreateModePicker: View {
    @Bindable var store: StoreOf<GoalCreateFeature>
    let focusedField: FocusState<GoalCreateField?>.Binding

    var body: some View {
        HStack(spacing: 0) {
            GoalCreateModeButton(
                title: RecordPresentation.text("development_record_write"),
                isSelected: store.selectedTab == .write
            ) {
                store.send(.binding(.set(\.selectedTab, .write)))
                focusedField.wrappedValue = .content
            }
            GoalCreateModeButton(
                title: RecordPresentation.text("development_record_preview"),
                isSelected: store.selectedTab == .preview
            ) {
                focusedField.wrappedValue = nil
                store.send(.binding(.set(\.selectedTab, .preview)))
            }
        }
        .padding(2)
        .background(Color.separator, in: .rect(cornerRadius: CornerRadius.control))
    }
}

private struct GoalCreateModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.adaptive(.body))
                .foregroundStyle(isSelected ? Color.accent : Color.secondaryLabel)
                .frame(maxWidth: .infinity, minHeight: 36 * AdaptiveSize.scale)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.segment)
                            .fill(Color.secondaryBackground)
                            .shadow(color: Color.secondaryLabel.opacity(0.08), radius: 2, y: 2)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct GoalCreateStatusField: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14 * AdaptiveSize.scale) {
            Text(RecordPresentation.text("development_goal_create_status"))
                .font(.adaptive(.headline))

            HStack {
                GoalStatusBadge(status: .inProgress)
                Spacer()
            }
            .padding(20 * AdaptiveSize.scale)
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
    }
}

private struct GoalCreateTodoField: View {
    @Bindable var store: StoreOf<GoalCreateFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * AdaptiveSize.scale) {
            Text(RecordPresentation.text("development_goal_create_todo_label"))
                .font(.adaptive(.headline))

            HStack(spacing: 12 * AdaptiveSize.scale) {
                VStack(alignment: .leading, spacing: 4 * AdaptiveSize.scale) {
                    Text(RecordPresentation.text("development_goal_create_todo_optional"))
                        .font(.adaptive(.callout))
                        .foregroundStyle(Color.secondaryLabel)
                    Text(RecordPresentation.text("development_goal_create_todo_hint"))
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.tertiaryLabel)
                }
                Spacer(minLength: 12 * AdaptiveSize.scale)
                Button {
                    store.send(.view(.selectTodos))
                } label: {
                    Text(todoButtonTitle)
                        .font(.adaptive(.callout).weight(.semibold))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 16 * AdaptiveSize.scale)
                        .padding(.vertical, 9 * AdaptiveSize.scale)
                        .background(Color.tintFill, in: .rect(cornerRadius: CornerRadius.control))
                }
                .buttonStyle(.plain)
            }
            .padding(20 * AdaptiveSize.scale)
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
        .disabled(store.isSaving)
    }

    private var todoButtonTitle: String {
        guard !store.selectedTodoIDs.isEmpty else {
            return RecordPresentation.text("development_goal_create_todo_select")
        }
        return String.localizedStringWithFormat(
            RecordPresentation.text("development_goal_create_todo_selected_format"),
            store.selectedTodoIDs.count
        )
    }
}

private struct GoalCreateSaveBar: View {
    @Environment(\.deviceType) private var deviceType
    let isSaving: Bool
    let isSaveEnabled: Bool
    let onSave: () -> Void

    var body: some View {
        VStack {
            Button(action: onSave) {
                Group {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(RecordPresentation.text("development_goal_save"))
                    }
                }
                .font(.adaptive(.headline))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10 * AdaptiveSize.scale)
            }
            .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: CornerRadius.control), color: .accent)
            .disabled(!isSaveEnabled)

        }
        .padding(.horizontal)
        .padding(.vertical, 12 * AdaptiveSize.scale)
        .background(deviceType == .duo ? Color.background : .secondaryBackground, ignoresSafeAreaEdges: .bottom)
    }
}

private enum GoalCreateField: Hashable {
    case title
    case content
}
