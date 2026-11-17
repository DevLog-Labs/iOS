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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
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
                .preference(key: PaneDetailEditingPreferenceKey.self, value: true)
        } else {
            NavigationStack {
                content
            }
            .sheetDismissDisabled(store.isLoading)
        }
    }

    private var content: some View {
        ScrollView {
            // Mac은 Orca 데스크톱 작성 칸처럼 간격을 좁히고 칸 좌우 여백 14로 표시
            LazyVStack(alignment: .leading, spacing: isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 20) {
                versionCard
                titleCard
                contentEditor
                // Mac은 확정 줄을 내용 아래에 이어서 표시
                if isiOSAppOnMac {
                    confirmBar
                }
            }
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : nil)
            .padding(.top, usesPaneLayout ? 12 : 0)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isiOSAppOnMac {
                confirmBar
            }
        }
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

    @ViewBuilder
    private var versionCard: some View {
        // Mac은 버전 이름 오른쪽 끝에 버전 배지 표시
        if isiOSAppOnMac {
            HStack {
                Text(RecordPresentation.text("development_record_version"))
                    .font(.adaptive(.subheadline))
                    .foregroundStyle(Color.secondaryLabel)
                Spacer()
                RecordVersionBadge(number: store.versionNumber, isCurrent: false)
            }
        } else {
            FieldSection(title: RecordPresentation.text("development_record_version")) {
                Text(RecordPresentation.versionLabel(store.versionNumber))
                    .font(.adaptive(.body))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
            }
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
            // Mac은 Orca 한 줄 입력칸 높이 32
            .padding(.all, isiOSAppOnMac ? 0 : nil)
            .padding(.horizontal, isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 0)
            .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : nil)
            .inputBackground(isFocused: focusedField == .title)
            // iPad 넓은 창은 기존 입력칸 바탕을 유지하도록 Mac 입력칸 모양은 Mac에서만 사용
            .environment(\.usesDesktopLayout, isiOSAppOnMac)
        }
        .disabled(store.isLoading)
    }

    private var contentEditor: some View {
        VStack(spacing: isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 16) {
            // Mac은 내용 이름을 두고 작성·미리보기 버튼을 이름 오른쪽 같은 줄에 표시
            if isiOSAppOnMac {
                HStack {
                    Text(RecordPresentation.text("development_record_content_label"))
                        .font(.adaptive(.subheadline))
                        .foregroundStyle(Color.secondaryLabel)
                    Spacer()
                    ModePicker(store: store, focusedField: _focusedField)
                }
            } else {
                ModePicker(store: store, focusedField: _focusedField)
            }

            switch store.selectedTab {
            case .write:
                // Mac은 안내 문구를 입력칸 아래에 표시
                TextEditorContentLayout(minimumHeight: 340, placesHintBelow: isiOSAppOnMac) {
                    Text(RecordPresentation.text("development_record_markdown_hint"))
                        .font(.adaptive(.caption))
                        .foregroundStyle(isiOSAppOnMac ? Color.secondaryLabel : .tertiaryLabel)
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
                        .inputBackground(isMultiline: true, isFocused: focusedField == .content)
                        // iPad 넓은 창은 기존 입력칸 바탕을 유지하도록 Mac 입력칸 모양은 Mac에서만 사용
                        .environment(\.usesDesktopLayout, isiOSAppOnMac)
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
                        .inputBackground(isMultiline: true)
                        // iPad 넓은 창은 기존 입력칸 바탕을 유지하도록 Mac 입력칸 모양은 Mac에서만 사용
                        .environment(\.usesDesktopLayout, isiOSAppOnMac)
                    } else {
                        MarkdownContentView(
                            content: store.markdownContent,
                            isScrollEnabled: false
                        )
                        // MarkdownRenderer 내부의 좌우 여백을 상쇄해 입력 본문과 정렬
                        .padding(.horizontal, -16)
                        .padding(12)
                        .frame(minHeight: 340, alignment: .topLeading)
                        .inputBackground(isMultiline: true)
                        // iPad 넓은 창은 기존 입력칸 바탕을 유지하도록 Mac 입력칸 모양은 Mac에서만 사용
                        .environment(\.usesDesktopLayout, isiOSAppOnMac)
                    }
                }
                .frame(minHeight: 340, alignment: .topLeading)
            }

        }
        .disabled(store.isLoading)
    }

    private var confirmBar: some View {
        let hint = Text(String.localizedStringWithFormat(
            RecordPresentation.text("development_record_confirm_hint_format"),
            RecordPresentation.versionLabel(store.versionNumber)
        ))
        .font(.adaptive(isiOSAppOnMac ? .subheadline : .caption))
        .foregroundStyle(isiOSAppOnMac ? Color.secondaryLabel : .tertiaryLabel)
        // Mac은 안내 문구 오른쪽에 글자 폭만큼의 확정 버튼을 한 줄로 표시
        let layout = isiOSAppOnMac
            ? AnyLayout(HStackLayout(spacing: 10 * AdaptiveSize.boardScale)) : AnyLayout(VStackLayout(spacing: 8))

        return layout {
            if isiOSAppOnMac {
                hint
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                .frame(maxWidth: isiOSAppOnMac ? nil : .infinity)
                // Mac은 버튼 모양이 배율 없이 더하는 여백 8을 빼고 보드 기준 좌우 여백 16, 높이 32로 표시
                .padding(.horizontal, isiOSAppOnMac ? 16 * AdaptiveSize.boardScale - 8 : 0)
                .padding(.vertical, isiOSAppOnMac ? 0 : 10)
                .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale - 16 : nil)
            }
            .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: CornerRadius.control), color: .accent)
            .disabled(!store.canConfirmVersion)

            if !isiOSAppOnMac {
                hint
            }
        }
        .padding(.horizontal, isiOSAppOnMac ? 0 : nil)
        .padding(.vertical, isiOSAppOnMac ? 4 * AdaptiveSize.boardScale : 12)
        .background(deviceType == .duo || isiOSAppOnMac ? Color.background : .secondaryBackground, ignoresSafeAreaEdges: .bottom)
    }

}

private struct FieldSection<Content: View>: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        // Mac은 입력칸 이름을 작은 회색 글자로 입력칸 바로 위에 표시
        VStack(alignment: .leading, spacing: isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 14) {
            Text(title)
                .font(.adaptive(isiOSAppOnMac ? .subheadline : .headline))
                .foregroundStyle(isiOSAppOnMac ? Color.secondaryLabel : .primary)
            content
        }
    }
}

private struct ModePicker: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
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
        .background(isiOSAppOnMac ? Color.tertiaryBackground : .separator, in: RoundedRectangle(cornerRadius: CornerRadius.control))
    }

    private func modeButton(
        _ title: String,
        tab: RecordEditorFeature.EditorTab
    ) -> some View {
        let isSelected = store.selectedTab == tab
        let selectedColor = isiOSAppOnMac ? Color.label : .accent

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

private enum Field: Hashable {
    case title
    case content
}
