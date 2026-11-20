//
//  RecordEditorView.swift
//  Development
//
//  Created by opfic on 9/13/26.
//

import SwiftUI
import Domain
import PresentationShared

public struct RecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @State private var store: StoreOf<RecordEditorFeature>
    @FocusState private var focusedField: Field?
    private let onCompletion: () -> Void
    // 칸에 그린 작성 화면을 닫는 동작, 없으면 시트를 닫음
    private let onClose: (() -> Void)?

    // 개발 목표와 기록 상세가 가진 작성 상태를 칸과 시트에 같이 그림
    init(
        store: StoreOf<RecordEditorFeature>,
        onCompletion: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self._store = State(initialValue: store)
        self.onCompletion = onCompletion
        self.onClose = onClose
    }

    public var body: some View {
        // 개발 목표 오른쪽 칸에 그리면 개발 목표 화면의 내비게이션을 겹치지 않음
        if usesPaneLayout {
            content
                .preference(key: PaneDetailEditingPreferenceKey.self, value: true)
        } else {
            NavigationStack {
                content
            }
            .sheetDismissDisabled(store.isLoading)
        }
    }

    private var content: some View {
        let inset = isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                versionRow
                    .padding(.top, inset)
                    .padding(.horizontal, inset)
                titleField
                    .padding(.vertical, 8)
                    .padding(.horizontal, inset)
                contentEditor
                    .padding(.horizontal, inset)
                confirmRow
                    .padding(.vertical, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 20)
                    .padding(.horizontal, inset)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background.ignoresSafeArea())
        .toolbarVisibility(.hidden, for: .navigationBar)
        .prominentAlert(store, state: \.alert, action: \.alert)
        .onChange(of: store.result) { _, result in
            guard result != nil else { return }
            onCompletion()
            close()
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var topBar: some View {
        if usesPaneLayout {
            PaneTitleBar(Text(title), onClose: close) {
                Button(action: save) {
                    Text(RecordPresentation.text("development_record_save"))
                        .font(.adaptive(.body).weight(.semibold))
                        .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
                .disabled(!store.isReadyToSave)
                .opacity(store.isReadyToSave ? 1 : 0.4)
            }
            .disabled(store.isLoading)
        } else {
            // 글자 닫기·저장 버튼과 가운데 제목
            RecordTopBar(title) {
                RecordTopBarTextButton(RecordPresentation.text("common_close"), action: close)
                    .disabled(store.isLoading)
            } trailing: {
                RecordTopBarTextButton(RecordPresentation.text("development_record_save"), isProminent: true, action: save)
                    .disabled(!store.isReadyToSave)
            }
        }
    }

    private var title: String {
        RecordPresentation.text(
            store.isCorrection
                ? "development_record_editor_correction_title"
                : "development_record_editor_title"
        )
    }

    private func save() {
        focusedField = nil
        store.send(.view(.save))
    }

    // 버전 이름과 오른쪽 끝 버전 배지
    private var versionRow: some View {
        HStack {
            Text(RecordPresentation.text("development_record_version"))
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)
            Spacer()
            TodoBadge(RecordPresentation.versionLabel(store.versionNumber), color: .tintLabel)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RecordPresentation.text("development_record_title"))
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)
            TextField(
                RecordPresentation.text("development_record_title_placeholder"),
                text: $store.title
            )
            .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
            .focused($focusedField, equals: .title)
            // Mac은 Orca 한 줄 입력칸 높이 32
            .padding(.horizontal, 12 * AdaptiveSize.boardScale)
            .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : 44)
            .recordInputBackground(isFocused: focusedField == .title)
        }
        .disabled(store.isLoading)
    }

    private var modePicker: some View {
        RecordModePicker(isWriting: store.selectedTab == .write) {
            store.send(.binding(.set(\.selectedTab, .write)))
            focusedField = .content
        } onPreview: {
            focusedField = nil
            DispatchQueue.main.async {
                store.send(.binding(.set(\.selectedTab, .preview)))
            }
        }
    }

    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 사이드바가 있는 창은 작성·미리보기 버튼을 내용 이름 오른쪽 같은 줄에 표시
            HStack {
                Text(RecordPresentation.text("development_record_content_label"))
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
                TextEditorContentLayout(minimumHeight: 150, placesHintBelow: true) {
                    Text(RecordPresentation.text("development_record_markdown_hint"))
                        .font(.adaptive(.caption))
                        .foregroundStyle(Color.secondaryLabel)
                    UIKitTextEditor
                        .composable(
                            update: { textEditor in
                                textEditor.updateInput(
                                    text: $store.markdownContent,
                                    isFocused: focusedField == .content,
                                    onFocusChange: { isFocused in
                                        if isFocused {
                                            focusedField = .content
                                        } else if focusedField == .content {
                                            focusedField = nil
                                        }
                                    },
                                    isEnabled: !store.isLoading
                                )
                            },
                            sizeThatFits: { UIKitTextEditor.fittingSize(proposal: $0, textEditor: $1) }
                        )
                        .focused($focusedField, equals: .content)
                        .padding(12)
                        .recordInputBackground(isMultiline: true, isFocused: focusedField == .content)
                }
                .padding(.top, 8)
                .contentShape(.rect)
                .onTapGesture { focusedField = .content }
            case .preview:
                Group {
                    if store.markdownContent.isEmpty {
                        VStack(spacing: 8) {
                            Text(RecordPresentation.text("development_record_preview_empty_title"))
                                .font(.adaptive(.headline))
                            Text(RecordPresentation.text("development_record_preview_empty_message"))
                                .font(.adaptive(.subheadline))
                                .foregroundStyle(Color.secondaryLabel)
                        }
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
                    } else {
                        MarkdownContentView(
                            content: store.markdownContent,
                            isScrollEnabled: false
                        )
                        // MarkdownRenderer 내부의 좌우 여백을 상쇄해 입력 본문과 정렬
                        .padding(.horizontal, -16)
                        .padding(12)
                        .frame(minHeight: 150, alignment: .topLeading)
                    }
                }
                .recordInputBackground(isMultiline: true)
                .padding(.top, 8)
            }
        }
        .disabled(store.isLoading)
    }

    // 확정하면 기록될 버전 안내와 글자 폭 확정 버튼
    private var confirmRow: some View {
        HStack(spacing: 10) {
            Text(String.localizedStringWithFormat(
                RecordPresentation.text("development_record_confirm_hint_format"),
                RecordPresentation.versionLabel(store.versionNumber)
            ))
            .font(.adaptive(.footnote))
            .foregroundStyle(Color.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                focusedField = nil
                store.send(.view(.confirm))
            } label: {
                if store.isLoading {
                    ProgressView()
                        .tint(Color.white)
                } else {
                    Text(RecordPresentation.text(
                        store.isCorrection
                            ? "development_record_confirm_correction"
                            : "development_record_confirm"
                    ))
                }
            }
            .buttonStyle(RecordButtonStyle())
            // 안내 문구가 길어도 확정 버튼 글자는 줄이지 않음
            .fixedSize()
            .disabled(!store.canConfirmVersion)
        }
    }
}

private enum Field: Hashable {
    case title
    case content
}
