//
//  GoalCreateView.swift
//  Development
//
//  Created by opfic on 9/20/26.
//

import SwiftUI
import Domain
import PresentationShared

struct GoalCreateView: View {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Bindable var store: StoreOf<GoalCreateFeature>
    @FocusState private var focusedField: GoalCreateField?
    let onClose: () -> Void

    var body: some View {
        // 사이드바가 있으면 홈 내비게이션 안의 칸이라 시트용 내비게이션을 겹치지 않음
        if usesDesktopLayout {
            content
        } else {
            NavigationStack {
                content
            }
            .sheetDismissDisabled(store.isSaving)
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                GoalCreateTitleField(store: store, focusedField: $focusedField)
                GoalCreateDescriptionEditor(store: store, focusedField: $focusedField)
                // 사이드바가 있으면 연결된 Todo를 세부 정보 사이드바에 표시
                if !usesDesktopLayout {
                    GoalCreateStatusField()
                    GoalCreateTodoField(store: store)
                }
            }
            .padding(.horizontal)
            .padding(.top, usesDesktopLayout ? 12 : 0)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if usesDesktopLayout {
                PaneTitleBar(Text(RecordPresentation.text("development_goal_create_title"))) {
                    Button(action: save) {
                        Text(RecordPresentation.text("todo_manage_save"))
                            .font(.adaptive(.body).weight(.semibold))
                            .foregroundStyle(Color.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.isReadyToSave)
                    .opacity(store.isReadyToSave ? 1 : 0.4)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .topBarButtonStyle()
                    .disabled(store.isSaving)
                }
            } else {
                GoalCreateTopBar(
                    isSaving: store.isSaving,
                    onClose: onClose
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !usesDesktopLayout {
                GoalCreateSaveBar(
                    isSaving: store.isSaving,
                    isSaveEnabled: store.isReadyToSave,
                    onSave: save
                )
            }
        }
        .background(Color.background.ignoresSafeArea())
        .toolbarVisibility(.hidden, for: .navigationBar)
        .prominentAlert(store, state: \.alert, action: \.alert)
        .prominentSheet(item: $store.scope(state: \.todoSelection, action: \.todoSelection)) {
            GoalCreateTodoSelectionSheet(store: $0)
        }
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
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }
}

private struct GoalCreateTitleField: View {
    @Bindable var store: StoreOf<GoalCreateFeature>
    let focusedField: FocusState<GoalCreateField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(RecordPresentation.text("development_goal_create_title_label"))
                .font(.adaptive(.headline))

            TextField(
                RecordPresentation.text("development_goal_create_title_placeholder"),
                text: $store.title
            )
            .focused(focusedField, equals: .title)
            .font(.adaptive(.body))
            .padding()
            .inputBackground(isFocused: focusedField.wrappedValue == .title)
        }
        .disabled(store.isSaving)
    }
}

private struct GoalCreateDescriptionEditor: View {
    @Bindable var store: StoreOf<GoalCreateFeature>
    let focusedField: FocusState<GoalCreateField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(RecordPresentation.text("development_goal_create_description_label"))
                .font(.adaptive(.headline))

            VStack(spacing: 16) {
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
                                .padding(12)
                                .inputBackground(isMultiline: true, isFocused: focusedField.wrappedValue == .content)
                        }
                        .contentShape(.rect)
                        .onTapGesture { focusedField.wrappedValue = .content }
                    case .preview:
                        Group {
                            if store.markdownContent.isEmpty {
                                VStack(spacing: 8) {
                                    Text(RecordPresentation.text("development_goal_create_preview_empty_title"))
                                        .font(.adaptive(.headline))
                                    Text(RecordPresentation.text("development_goal_create_preview_empty_message"))
                                        .font(.adaptive(.subheadline))
                                        .foregroundStyle(Color.secondaryLabel)
                                }
                                .multilineTextAlignment(.center)
                                .padding(12)
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                                .inputBackground(isMultiline: true)
                            } else {
                                MarkdownContentView(
                                    content: store.markdownContent,
                                    isScrollEnabled: false
                                )
                                    // MarkdownRenderer 내부의 좌우 여백을 상쇄해 입력 본문과 정렬
                                    .padding(.horizontal, -16)
                                    .padding(12)
                                    .frame(minHeight: 120, alignment: .topLeading)
                                    .inputBackground(isMultiline: true)
                            }
                        }
                    }
                }
                .frame(minHeight: 120, alignment: .topLeading)
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
                .frame(maxWidth: .infinity, minHeight: 36)
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
        VStack(alignment: .leading, spacing: 14) {
            Text(RecordPresentation.text("development_goal_create_status"))
                .font(.adaptive(.headline))

            HStack {
                GoalStatusBadge(status: .inProgress)
                Spacer()
            }
            .padding(20)
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
    }
}

private struct GoalCreateTodoField: View {
    @Bindable var store: StoreOf<GoalCreateFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(RecordPresentation.text("development_goal_create_todo_label"))
                .font(.adaptive(.headline))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(RecordPresentation.text("development_goal_create_todo_optional"))
                        .font(.adaptive(.callout))
                        .foregroundStyle(Color.secondaryLabel)
                    Text(RecordPresentation.text("development_goal_create_todo_hint"))
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.tertiaryLabel)
                }
                Spacer(minLength: 12)
                Button {
                    store.send(.view(.selectTodos))
                } label: {
                    Text(store.todoSelectionTitle)
                        .font(.adaptive(.callout).weight(.semibold))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.tintFill, in: .rect(cornerRadius: CornerRadius.control))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
        .disabled(store.isSaving)
    }
}

// 세부 정보 사이드바의 새 개발 목표 속성, 목표를 저장할 때 함께 저장
struct GoalCreateSideBarContent: View {
    let store: StoreOf<GoalCreateFeature>

    var body: some View {
        ScrollView {
            Button {
                store.send(.view(.selectTodos))
            } label: {
                HStack(spacing: 10 * AdaptiveSize.boardScale) {
                    VStack(alignment: .leading, spacing: 2 * AdaptiveSize.boardScale) {
                        Text(RecordPresentation.text("development_goal_create_todo_label"))
                            .font(.adaptive(.body))
                            .foregroundStyle(Color.label)
                        Text(RecordPresentation.text("development_goal_create_todo_hint"))
                            .font(.adaptive(.subheadline))
                            .foregroundStyle(Color.secondaryLabel)
                    }
                    Spacer(minLength: 0)
                    Text(store.todoSelectionTitle)
                        .font(.adaptive(.body))
                        .foregroundStyle(Color.secondaryLabel)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.adaptive(.caption).weight(.semibold))
                        .foregroundStyle(Color.secondaryLabel)
                }
                .padding(.horizontal, 12 * AdaptiveSize.boardScale)
                .padding(.vertical, 6 * AdaptiveSize.boardScale)
                .frame(minHeight: 38 * AdaptiveSize.boardScale)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(store.isSaving)
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
            .padding(.horizontal, 14 * AdaptiveSize.boardScale)
            .padding(.vertical, 8 * AdaptiveSize.boardScale)
        }
    }
}

private extension GoalCreateFeature.State {
    var todoSelectionTitle: String {
        guard !selectedTodoIDs.isEmpty else {
            return RecordPresentation.text("development_goal_create_todo_select")
        }
        return String.localizedStringWithFormat(
            RecordPresentation.text("development_goal_create_todo_selected_format"),
            selectedTodoIDs.count
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
                .padding(.vertical, 10)
            }
            .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: CornerRadius.control), color: .accent)
            .disabled(!isSaveEnabled)

        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(deviceType == .duo ? Color.background : .secondaryBackground, ignoresSafeAreaEdges: .bottom)
    }
}

private enum GoalCreateField: Hashable {
    case title
    case content
}
