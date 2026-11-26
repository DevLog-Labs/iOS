//
//  RecordDetailView.swift
//  Development
//
//  Created by opfic on 9/13/26.
//

import SwiftUI
import Domain
import PresentationShared

public struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType
    @Environment(\.isInDetailPanel) private var isInDetailPanel
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    // 개발 목표가 가진 상세 상태를 좁은 창의 내비게이션과 넓은 창의 상세 판에 같이 그림
    @Bindable var store: StoreOf<RecordDetailFeature>
    let onUpdate: () -> Void

    public var body: some View {
        // 창 폭이 바뀌면 기록 상세가 새 자리에 나타난 뒤에 안에서 연 화면을 띄움
        // 지금 값으로 다시 그리고, 빠지는 자리에서 늦게 들어온 닫힘은 읽을 때의 값으로 거름
        let editor = $store.scope(state: \.editor, action: \.editor)
        let isShown = store.goalShownOnDesktop == usesDesktopLayout && store.shownOnDesktop == usesDesktopLayout
        let isHidden = {
            !isShown || store.goalShownOnDesktop != usesDesktopLayout || store.shownOnDesktop != usesDesktopLayout
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch store.contentState {
                case .draft(let draft):
                    recordContent(
                        title: draft.title,
                        markdownContent: draft.markdownContent,
                        version: nil
                    )
                case .loaded:
                    if let version = store.currentVersion {
                        recordContent(
                            title: version.title,
                            markdownContent: version.markdownContent,
                            version: version
                        )
                        actionSection
                    }
                case .failed:
                    failureContent
                case .idle, .loading:
                    Color.clear.frame(height: 1)
                }
            }
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 22)
            .padding(.vertical, isiOSAppOnMac ? 18 * AdaptiveSize.boardScale : 20)
            .frame(maxWidth: readableContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background.ignoresSafeArea())
        .duoToolbarVisibility(showsBackButton: true)
        .onAppear { store.send(.view(.appear(onDesktop: usesDesktopLayout))) }
        .prominentAlert(store, state: \.alert, action: \.alert)
        // 좁은 창의 기록 정정은 닫기·저장·확정 버튼으로만 닫는 전체 화면
        .fullScreenCover(
            item: editor.hiddenInPane { usesDesktopLayout || isHidden() }
        ) { _ in
            correctionEditor
        }
        .prominentSheet(
            item: editor.hiddenInPane { !usesDesktopLayout || isHidden() }
        ) { _ in
            correctionEditor
        }
        .navigationDestination(
            item: $store.scope(state: \.history, action: \.history)
                .hiddenInPane(isHidden),
            interactivePop: true
        ) { _ in
            RecordVersionHistoryView(store: store)
        }
        .overlay {
            if store.isLoading || store.isRestoring {
                LoadingView()
            }
        }
        .onChange(of: store.restoredSourceVersionID) { _, sourceVersionID in
            guard sourceVersionID != nil else { return }
            onUpdate()
        }
    }

    @ViewBuilder
    private var correctionEditor: some View {
        if let editorStore = store.scope(state: \.editorContent, action: \.editorContent) {
            RecordEditorView(store: editorStore, onCompletion: finishEditing)
        }
    }

    @ViewBuilder
    private var topBar: some View {
        if isInDetailPanel {
            // 상세 판 위쪽 막대에 "개발 목표 / 기록" 경로 표시
            DetailPanelBar(location: Text(store.goalTitle), title: Text(panelTitle))
        } else {
            // Duo는 뒤로 버튼을 오른쪽 세로 막대에 표시
            RecordTopBar(RecordPresentation.text("development_record_detail_title")) {
                if deviceType != .duo {
                    NavigationBackButton(action: { dismiss() })
                        .disabled(store.isRestoring)
                }
            } trailing: {
                EmptyView()
            }
        }
    }

    // 상세 판 경로에 표시하는 기록 제목, 작성 중인 기록은 작성 중인 제목
    private var panelTitle: String {
        switch store.contentState {
        case .draft(let draft):
            draft.title
        default:
            store.currentVersion?.title ?? ""
        }
    }

    @ViewBuilder
    private func recordContent(
        title: String,
        markdownContent: String,
        version: DevelopmentRecord.Version?
    ) -> some View {
        Text(title)
            .font(.system(size: isiOSAppOnMac ? 19 * AdaptiveSize.boardScale : 26, weight: .heavy))
            .foregroundStyle(Color.label)

        // 확정·초안 배지, 버전 배지, 날짜
        HStack(spacing: 8) {
            if let version {
                TodoBadge(RecordPresentation.text("development_record_confirmed"), color: .tintLabel)
                TodoBadge(RecordPresentation.versionLabel(version.number))
                Text(version.confirmedAt, format: .dateTime.month().day().hour().minute())
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
            } else {
                TodoBadge(RecordPresentation.text("development_record_draft"), color: .warning)
            }
        }
        .padding(.top, 10)
        // 본문 첫 제목의 위쪽 여백은 Markdown 화면이 빼고 그려서 배지 아래에 둠
        .padding(.bottom, isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 20)

        if markdownContent.isEmpty {
            EmptyStateView(
                RecordPresentation.text("development_record_content_empty_title"),
                systemImage: "doc.text"
            )
        } else {
            MarkdownContentView(content: markdownContent, isScrollEnabled: false)
                // MarkdownRenderer 내부의 좌우 여백을 상쇄해 제목과 정렬
                .padding(.horizontal, -16)
        }
    }

    private var failureContent: some View {
        EmptyStateView(
            RecordPresentation.text("common_error_title"),
            systemImage: "exclamationmark.triangle",
            message: RecordPresentation.text("development_record_detail_error_message")
        ) {
            Button(RecordPresentation.text("development_record_detail_retry")) {
                store.send(.view(.fetch))
            }
            .buttonStyle(RecordButtonStyle())
        }
    }

    // 기록 정정과 버전 이력 버튼, 한 줄에 들어가지 않으면 세로로 표시
    private var actionSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { actionButtons }
            VStack(alignment: .leading, spacing: 8) { actionButtons }
        }
        .buttonStyle(RecordButtonStyle(isProminent: false))
        .padding(.top, isiOSAppOnMac ? 20 * AdaptiveSize.boardScale : 26)
    }

    // 목표가 진행 중이 아니면 버전 이력만 표시
    @ViewBuilder
    private var actionButtons: some View {
        if store.allowsMutation {
            Button {
                store.send(.view(.tapCorrection))
            } label: {
                RecordButtonLabel(RecordPresentation.text("development_record_correct"))
            }
        }
        Button {
            store.send(.view(.tapHistory))
        } label: {
            RecordButtonLabel(
                RecordPresentation.text("development_record_history_title"),
                systemImage: "clock.arrow.circlepath"
            )
        }
    }

    private func finishEditing() {
        store.send(.view(.finishEditing))
        onUpdate()
    }
}
