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
    @Environment(\.deviceType) private var deviceType
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @State private var store: StoreOf<RecordEditorFeature>
    @FocusState private var focusedField: Field?
    private let onCompletion: () -> Void
    // 칸에 그린 작성 화면을 닫는 동작, 없으면 시트를 닫음
    private let onClose: (() -> Void)?

    public init(
        goalId: String,
        goalTitle: String,
        record: DevelopmentRecord? = nil,
        baseVersion: DevelopmentRecord.Version? = nil,
        onCompletion: @escaping () -> Void = { },
        onClose: (() -> Void)? = nil
    ) {
        self._store = State(initialValue: Store(
            initialState: RecordEditorFeature.State(
                goalId: goalId,
                goalTitle: goalTitle,
                record: record,
                baseVersion: baseVersion
            )
        ) {
            RecordEditorFeature()
        })
        self.onCompletion = onCompletion
        self.onClose = onClose
    }

    // 개발 목표가 가진 작성 상태를 칸과 시트에 같이 그림
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
        } else {
            NavigationStack {
                content
            }
            .sheetDismissDisabled(store.isLoading)
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                versionCard
                titleCard
                contentEditor
            }
            .padding(.horizontal)
            .padding(.top, usesPaneLayout ? 12 : 0)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { confirmBar }
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
                Button {
                    focusedField = nil
                    store.send(.view(.save))
                } label: {
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
            sheetTopBar
        }
    }

    private var title: String {
        RecordPresentation.text(
            store.isCorrection
                ? "development_record_editor_correction_title"
                : "development_record_editor_title"
        )
    }

    private var sheetTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                if #available(iOS 26.0, *) {
                    Image(systemName: "xmark")
                } else {
                    Text(RecordPresentation.text("common_close"))
                }
            }
            .topBarButtonStyle()
            .disabled(store.isLoading)
            Spacer()
            Text(title)
                .font(.adaptive(.headline))
            Spacer()
            Button {
                focusedField = nil
                store.send(.view(.save))
            } label: {
                if #available(iOS 26.0, *) {
                    Image(systemName: "checkmark")
                } else {
                    Text(RecordPresentation.text("development_record_save"))
                        .foregroundStyle(Color.accent)
                }
            }
            .topBarButtonStyle()
            .disabled(!store.isReadyToSave)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    private var versionCard: some View {
        FieldSection(title: RecordPresentation.text("development_record_version")) {
            Text(RecordPresentation.versionLabel(store.versionNumber))
                .font(.adaptive(.body))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
        }
    }

    private var titleCard: some View {
        FieldSection(title: RecordPresentation.text("development_record_title")) {
            TextField(
                RecordPresentation.text("development_record_title_placeholder"),
                text: $store.title
            )
            .font(.adaptive(.body))
            .focused($focusedField, equals: .title)
            .padding()
            .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
        }
        .disabled(store.isLoading)
    }

    private var contentEditor: some View {
        VStack(spacing: 16) {
            ModePicker(store: store, focusedField: _focusedField)

            switch store.selectedTab {
            case .write:
                TextEditorContentLayout(minimumHeight: 340) {
                    Text(RecordPresentation.text("development_record_markdown_hint"))
                        .font(.adaptive(.caption))
                        .foregroundStyle(Color.tertiaryLabel)
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
                        .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                }
                .frame(minHeight: 340, alignment: .topLeading)
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
                        .frame(maxWidth: .infinity, minHeight: 340, alignment: .center)
                        .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                    } else {
                        MarkdownContentView(
                            content: store.markdownContent,
                            isScrollEnabled: false
                        )
                        // MarkdownRenderer 내부의 좌우 여백을 상쇄해 입력 본문과 정렬
                        .padding(.horizontal, -16)
                        .padding(12)
                        .frame(minHeight: 340, alignment: .topLeading)
                        .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                    }
                }
                .frame(minHeight: 340, alignment: .topLeading)
            }

        }
        .disabled(store.isLoading)
    }

    private var confirmBar: some View {
        VStack(spacing: 8) {
            Button {
                focusedField = nil
                store.send(.view(.confirm))
            } label: {
                Group {
                    if store.isLoading {
                        ProgressView()
                    } else {
                        Text(RecordPresentation.text(
                            store.isCorrection
                                ? "development_record_confirm_correction"
                                : "development_record_confirm"
                        ))
                    }
                }
                .font(.adaptive(.headline))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: CornerRadius.control), color: .accent)
            .disabled(!store.canConfirmVersion)

            Text(String.localizedStringWithFormat(
                RecordPresentation.text("development_record_confirm_hint_format"),
                RecordPresentation.versionLabel(store.versionNumber)
            ))
            .font(.adaptive(.caption))
            .foregroundStyle(Color.tertiaryLabel)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(deviceType == .duo ? Color.background : .secondaryBackground, ignoresSafeAreaEdges: .bottom)
    }

}

private struct FieldSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.adaptive(.headline))
            content
        }
    }
}

private struct ModePicker: View {
    @Bindable var store: StoreOf<RecordEditorFeature>
    @FocusState var focusedField: Field?

    var body: some View {
        HStack(spacing: 0) {
            modeButton(
                RecordPresentation.text("development_record_write"),
                tab: .write
            )
            modeButton(
                RecordPresentation.text("development_record_preview"),
                tab: .preview
            )
        }
        .padding(2)
        .background(Color.separator, in: RoundedRectangle(cornerRadius: CornerRadius.control))
    }

    private func modeButton(
        _ title: String,
        tab: RecordEditorFeature.EditorTab
    ) -> some View {
        let isSelected = store.selectedTab == tab

        return Button {
            if tab == .write {
                store.send(.binding(.set(\.selectedTab, .write)))
                focusedField = .content
            } else {
                focusedField = nil
                DispatchQueue.main.async {
                    store.send(.binding(.set(\.selectedTab, .preview)))
                }
            }
        } label: {
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

private enum Field: Hashable {
    case title
    case content
}
