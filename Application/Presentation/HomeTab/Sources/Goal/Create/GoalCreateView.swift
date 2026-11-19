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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
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
            // 전체 화면처럼 닫기·저장 버튼으로만 닫음
            .sheetDismissDisabled()
        }
    }

    private var content: some View {
        ScrollView {
            // Mac은 Orca 데스크톱 작성 칸처럼 간격을 좁히고 칸 좌우 여백 14로 표시
            LazyVStack(alignment: .leading, spacing: isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 24) {
                GoalCreateTitleField(store: store, focusedField: $focusedField)
                GoalCreateDescriptionEditor(store: store, focusedField: $focusedField)
                // 사이드바가 있으면 연결된 Todo를 세부 정보 사이드바에 표시
                if !usesDesktopLayout {
                    GoalCreateStatusField()
                    GoalCreateTodoField(store: store)
                }
            }
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : nil)
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
                    Image(systemName: "xmark")
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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: StoreOf<GoalCreateFeature>
    let focusedField: FocusState<GoalCreateField?>.Binding

    var body: some View {
        // Mac은 입력칸 이름을 작은 회색 글자로 입력칸 바로 위에 표시
        VStack(alignment: .leading, spacing: isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 14) {
            Text(RecordPresentation.text("development_goal_create_title_label"))
                .font(.adaptive(isiOSAppOnMac ? .subheadline : .headline))
                .foregroundStyle(isiOSAppOnMac ? Color.secondaryLabel : .primary)

            TextField(
                RecordPresentation.text("development_goal_create_title_placeholder"),
                text: $store.title
            )
            .focused(focusedField, equals: .title)
            .font(.adaptive(.body))
            // Mac은 Orca 한 줄 입력칸 높이 32
            .padding(.all, isiOSAppOnMac ? 0 : nil)
            .padding(.horizontal, isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 0)
            .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : nil)
            .inputBackground(isFocused: focusedField.wrappedValue == .title)
        }
        .disabled(store.isSaving)
    }
}

private struct GoalCreateDescriptionEditor: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: StoreOf<GoalCreateFeature>
    let focusedField: FocusState<GoalCreateField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 14) {
            // Mac은 작성·미리보기 버튼을 입력칸 이름 오른쪽 같은 줄에 표시
            HStack {
                Text(RecordPresentation.text("development_goal_create_description_label"))
                    .font(.adaptive(isiOSAppOnMac ? .subheadline : .headline))
                    .foregroundStyle(isiOSAppOnMac ? Color.secondaryLabel : .primary)
                if isiOSAppOnMac {
                    Spacer()
                    GoalCreateModePicker(store: store, focusedField: focusedField)
                }
            }

            VStack(spacing: 16) {
                if !isiOSAppOnMac {
                    GoalCreateModePicker(store: store, focusedField: focusedField)
                }

                Group {
                    switch store.selectedTab {
                    case .write:
                        // Mac은 안내 문구를 입력칸 아래에 표시
                        TextEditorContentLayout(minimumHeight: 120, placesHintBelow: isiOSAppOnMac) {
                            Text(RecordPresentation.text("development_goal_create_markdown_hint"))
                                .font(.adaptive(.caption))
                                .foregroundStyle(isiOSAppOnMac ? Color.secondaryLabel : .tertiaryLabel)
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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
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
        .background(isiOSAppOnMac ? Color.tertiaryBackground : .separator, in: .rect(cornerRadius: CornerRadius.control))
    }
}

private struct GoalCreateModeButton: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let selectedColor = isiOSAppOnMac ? Color.label : .accent

            // Mac은 칸 폭을 채우지 않고 글자 폭만큼 작게, 고른 조각은 강조색 대신 글자색과 옅은 테두리로 표시
            Text(title)
                .font(.adaptive(isiOSAppOnMac ? .subheadline : .body).weight(isiOSAppOnMac ? .semibold : .regular))
                .foregroundStyle(isSelected ? selectedColor : Color.secondaryLabel)
                .padding(.horizontal, isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 0)
                .padding(.vertical, isiOSAppOnMac ? 3 * AdaptiveSize.boardScale : 0)
                .frame(maxWidth: isiOSAppOnMac ? nil : .infinity, minHeight: isiOSAppOnMac ? nil : 36)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.segment)
                            .fill(Color.secondaryBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: CornerRadius.segment)
                                    .strokeBorder(isiOSAppOnMac ? Color.label.opacity(0.12) : .clear)
                            }
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
// Mac은 Mac 화면 크기, iPad는 손가락으로 누르는 크기
struct GoalCreateSideBarContent: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let store: StoreOf<GoalCreateFeature>

    var body: some View {
        ScrollView {
            Button {
                store.send(.view(.selectTodos))
            } label: {
                HStack(spacing: 10 * AdaptiveSize.boardScale) {
                    VStack(alignment: .leading, spacing: 2 * AdaptiveSize.boardScale) {
                        Text(RecordPresentation.text("development_goal_create_todo_label"))
                            .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                            .foregroundStyle(Color.label)
                        Text(RecordPresentation.text("development_goal_create_todo_hint"))
                            .font(.adaptive(isiOSAppOnMac ? .subheadline : .footnote))
                            .foregroundStyle(Color.secondaryLabel)
                    }
                    Spacer(minLength: 0)
                    Text(store.todoSelectionTitle)
                        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                        .foregroundStyle(Color.secondaryLabel)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.adaptive(.caption).weight(.semibold))
                        .foregroundStyle(Color.secondaryLabel)
                }
                .padding(.horizontal, 12 * AdaptiveSize.boardScale)
                .padding(.vertical, 6 * AdaptiveSize.boardScale)
                .frame(minHeight: isiOSAppOnMac ? 38 * AdaptiveSize.boardScale : 44)
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
