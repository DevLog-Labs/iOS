//
//  RecordVersionDetailView.swift
//  Development
//
//  Created by opfic on 9/14/26.
//

import SwiftUI
import Domain
import PresentationShared

struct RecordVersionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType
    @Environment(\.isInDetailPanel) private var isInDetailPanel
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.readableContentWidth) private var readableContentWidth

    let store: StoreOf<RecordDetailFeature>
    let version: DevelopmentRecord.Version

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleSection
                content
                restoreSection
            }
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 22)
            .padding(.vertical, isiOSAppOnMac ? 18 * AdaptiveSize.boardScale : 20)
            .frame(maxWidth: readableContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background.ignoresSafeArea())
        .duoToolbarVisibility(showsBackButton: true)
        .prominentAlert(
            store,
            state: \.alert,
            action: \.alert
        )
        .overlay {
            if store.isRestoring {
                LoadingView()
            }
        }
        .onChange(of: store.restoredSourceVersionID) { _, sourceVersionID in
            guard sourceVersionID == version.id else { return }
            dismiss()
        }
    }

    @ViewBuilder
    private var topBar: some View {
        if isInDetailPanel {
            // 상세 판 위쪽 막대에 "버전 이력 / 버전" 경로 표시
            DetailPanelBar(
                location: Text(RecordPresentation.text("development_record_history_title")),
                title: Text(RecordPresentation.versionLabel(version.number))
            )
        } else {
            // Duo는 뒤로 버튼을 오른쪽 세로 막대에 표시
            RecordTopBar(RecordPresentation.text("development_record_previous_version_title")) {
                if deviceType != .duo {
                    NavigationBackButton(action: { dismiss() })
                        .disabled(store.isRestoring)
                }
            } trailing: {
                EmptyView()
            }
        }
    }

    // "이전 버전" 표시와 큰 제목, 버전·종류 배지, 날짜
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(RecordPresentation.text("development_record_previous_version_title"))
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)

            Text(version.title)
                .font(.system(size: isiOSAppOnMac ? 19 * AdaptiveSize.boardScale : 26, weight: .heavy))
                .foregroundStyle(Color.label)
                .padding(.vertical, 8)

            HStack(spacing: 8) {
                TodoBadge(RecordPresentation.versionLabel(version.number))
                RecordVersionKindBadge(kind: version.kind)
                Text(version.confirmedAt, format: .dateTime.month().day().hour().minute())
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
            }
        }
        // 본문 첫 제목의 위쪽 여백은 Markdown 화면이 빼고 그려서 배지 아래에 둠
        .padding(.bottom, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 18)
    }

    @ViewBuilder
    private var content: some View {
        if version.markdownContent.isEmpty {
            EmptyStateView(
                RecordPresentation.text("development_record_content_empty_title"),
                systemImage: "doc.text"
            )
        } else {
            MarkdownContentView(content: version.markdownContent, isScrollEnabled: false)
                // MarkdownRenderer 내부의 좌우 여백을 상쇄해 제목과 정렬
                .padding(.horizontal, -16)
        }
    }

    // 구분선 아래 되돌리기 안내와 되돌리기 버튼
    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)

            Group {
                if !store.allowsMutation {
                    Text(RecordPresentation.text("development_record_read_only_message"))
                } else if store.record.draft != nil {
                    Text(RecordPresentation.text("development_record_restore_draft_message"))
                } else {
                    Text(String.localizedStringWithFormat(
                        RecordPresentation.text("development_record_restore_current_version_format"),
                        RecordPresentation.versionLabel(store.currentVersion?.number ?? version.number)
                    ))
                }
            }
            .font(.adaptive(.footnote))
            .foregroundStyle(Color.secondaryLabel)
            .lineSpacing(4)
            .padding(.top, isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 16)

            if store.allowsMutation {
                Button {
                    store.send(.view(.restore(version)))
                } label: {
                    RecordButtonLabel(
                        RecordPresentation.text("development_record_restore_button"),
                        systemImage: "arrow.uturn.backward"
                    )
                }
                .buttonStyle(RecordButtonStyle(isProminent: false))
                .disabled(store.isRestoring || store.record.draft != nil)
                .padding(.top, isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 14)
            }
        }
        .padding(.top, isiOSAppOnMac ? 20 * AdaptiveSize.boardScale : 26)
    }
}
