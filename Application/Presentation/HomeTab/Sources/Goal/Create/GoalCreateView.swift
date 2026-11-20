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
        let inset = isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GoalCreateTitleField(store: store, focusedField: $focusedField)
                    .padding(.vertical, 8)
                    .padding(.horizontal, inset)
                GoalCreateDescriptionEditor(store: store, focusedField: $focusedField)
                    .padding(.horizontal, inset)
                // 사이드바가 있으면 연결된 Todo를 세부 정보 사이드바에 표시하고 저장은 칸 제목 줄에서 함
                if !usesDesktopLayout {
                    GoalCreateTodoRow(store: store)
                        .padding(.vertical, 12)
                        .padding(.horizontal, inset)
                    Button(action: save) {
                        if store.isSaving {
                            ProgressView()
                                .tint(Color.white)
                        } else {
                            Text(RecordPresentation.text("development_goal_save"))
                        }
                    }
                    .buttonStyle(RecordButtonStyle(fillsWidth: true))
                    .disabled(!store.isReadyToSave)
                    .padding(.vertical, 12)
                    .padding(.horizontal, inset)
                }
            }
            .padding(.top, usesDesktopLayout ? 8 : 0)
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
                // 시트 손잡이 아래부터 글자 닫기 버튼과 가운데 제목
                RecordTopBar(
                    RecordPresentation.text("development_goal_create_title"),
                    background: .secondaryBackground
                ) {
                    RecordTopBarTextButton(RecordPresentation.text("common_close"), action: onClose)
                        .disabled(store.isSaving)
                } trailing: {
                    EmptyView()
                }
                .padding(.top, 11)
                .background(Color.secondaryBackground, ignoresSafeAreaEdges: .top)
                // 아래에서 올라온 시트라 창 컨트롤 여백을 더하지 않음
                .environment(\.windowControlsInset, 0)
            }
        }
        .background((usesDesktopLayout ? Color.background : .secondaryBackground).ignoresSafeArea())
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

private struct GoalCreateTitleField: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: StoreOf<GoalCreateFeature>
    let focusedField: FocusState<GoalCreateField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RecordPresentation.text("development_goal_create_title_label"))
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)

            TextField(
                RecordPresentation.text("development_goal_create_title_placeholder"),
                text: $store.title
            )
            .focused(focusedField, equals: .title)
            .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
            // Mac은 Orca 한 줄 입력칸 높이 32
            .padding(.horizontal, 12 * AdaptiveSize.boardScale)
            .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : 44)
            .recordInputBackground(isFocused: focusedField.wrappedValue == .title)
        }
        .disabled(store.isSaving)
    }
}

private struct GoalCreateDescriptionEditor: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Bindable var store: StoreOf<GoalCreateFeature>
    let focusedField: FocusState<GoalCreateField?>.Binding

    var body: some View {
        // 사이드바가 있는 창은 입력칸을 더 높게 표시
        let minimumHeight = CGFloat(usesDesktopLayout ? 160 : 110) * AdaptiveSize.boardScale

        VStack(alignment: .leading, spacing: 0) {
            // 사이드바가 있는 창은 작성·미리보기 버튼을 설명 이름 오른쪽 같은 줄에 표시
            HStack {
                Text(RecordPresentation.text("development_goal_create_description_label"))
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
                if usesDesktopLayout {
                    Spacer()
                    modePicker
                }
            }
            .padding(.top, 12)
            .padding(.bottom, usesDesktopLayout ? 8 : 0)

            if !usesDesktopLayout {
                modePicker
                    .padding(.vertical, 8)
            }

            switch store.selectedTab {
            case .write:
                // 안내 문구는 입력칸 아래에 표시
                TextEditorContentLayout(minimumHeight: minimumHeight, placesHintBelow: true) {
                    Text(RecordPresentation.text("development_goal_create_markdown_hint"))
                        .font(.adaptive(.caption))
                        .foregroundStyle(Color.secondaryLabel)
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
                        .recordInputBackground(isMultiline: true, isFocused: focusedField.wrappedValue == .content)
                }
                .padding(.top, 8)
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
                        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .center)
                    } else {
                        MarkdownContentView(
                            content: store.markdownContent,
                            isScrollEnabled: false
                        )
                        // MarkdownRenderer 내부의 좌우 여백을 상쇄해 입력 본문과 정렬
                        .padding(.horizontal, -16)
                        .padding(12)
                        .frame(minHeight: minimumHeight, alignment: .topLeading)
                    }
                }
                .recordInputBackground(isMultiline: true)
                .padding(.top, 8)
            }
        }
        .disabled(store.isSaving)
    }

    private var modePicker: some View {
        RecordModePicker(isWriting: store.selectedTab == .write) {
            store.send(.binding(.set(\.selectedTab, .write)))
            focusedField.wrappedValue = .content
        } onPreview: {
            focusedField.wrappedValue = nil
            store.send(.binding(.set(\.selectedTab, .preview)))
        }
    }
}

// 카드 없이 페이지 여백에 맞춘 연결된 Todo 행
// 연결된 Todo 이름과 안내, 고른 개수, 펼침 화살표
private struct GoalCreateTodoRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let store: StoreOf<GoalCreateFeature>

    var body: some View {
        Button {
            store.send(.view(.selectTodos))
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(RecordPresentation.text("development_goal_create_todo_label"))
                        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                        .foregroundStyle(Color.label)
                    Text(RecordPresentation.text("development_goal_create_todo_hint"))
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.secondaryLabel)
                }
                .padding(.vertical, 10)
                Spacer(minLength: 0)
                Text(store.todoSelectionTitle)
                    .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                    .foregroundStyle(Color.secondaryLabel)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.adaptive(.footnote).weight(.semibold))
                    .foregroundStyle(Color.secondaryLabel)
            }
            .frame(minHeight: isiOSAppOnMac ? 38 * AdaptiveSize.boardScale : 50)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(store.isSaving)
    }
}

// 세부 정보 사이드바의 새 개발 목표 속성, 목표를 저장할 때 함께 저장
struct GoalCreateSideBarContent: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let store: StoreOf<GoalCreateFeature>

    var body: some View {
        ScrollView {
            GoalCreateTodoRow(store: store)
                .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
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

private enum GoalCreateField: Hashable {
    case title
    case content
}
