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

    let store: StoreOf<RecordDetailFeature>
    let version: DevelopmentRecord.Version

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                titleSection
                contentCard
                currentVersionCard
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.allowsMutation {
                restoreBar
            }
        }
        .background(Color.background.ignoresSafeArea())
        .toolbarVisibility(.hidden, for: .navigationBar)
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

    private var topBar: some View {
        HStack {
            NavigationBackButton(action: { dismiss() })
                .disabled(store.isRestoring)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(RecordPresentation.text("development_record_previous_version_title"))
                .font(.largeTitle.bold())

            Text(version.title)
                .font(.title3)
                .foregroundStyle(Color.secondaryLabel)
                .lineLimit(2)

            HStack(spacing: 8) {
                RecordVersionBadge(number: version.number, isCurrent: false)
                kindBadge
                Text(version.confirmedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryLabel)
            }
        }
    }

    private var contentCard: some View {
        Group {
            if version.markdownContent.isEmpty {
                ContentUnavailableView(
                    RecordPresentation.text("development_record_content_empty_title"),
                    systemImage: "doc.text"
                )
            } else {
                MarkdownContentView(content: version.markdownContent)
                    .frame(minHeight: 420)
            }
        }
        .padding(.vertical, 16)
        .background(Color.secondaryBackground, in: .rect(cornerRadius: 24))
    }

    private var currentVersionCard: some View {
        Label {
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
        } icon: {
            Image(
                systemName: statusSystemImage
            )
            .foregroundStyle(statusColor)
        }
        .font(.subheadline)
        .foregroundStyle(Color.secondaryLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.tertiaryBackground, in: .rect(cornerRadius: 18))
    }

    private var statusSystemImage: String {
        if !store.allowsMutation { return "lock" }
        return store.record.draft == nil ? "clock.arrow.circlepath" : "pencil"
    }

    private var statusColor: Color {
        if !store.allowsMutation { return .secondaryLabel }
        return store.record.draft == nil ? .accent : .warning
    }

    private var restoreBar: some View {
        Button {
            store.send(.view(.restore(version)))
        } label: {
            Text(RecordPresentation.text("development_record_restore_button"))
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: 16), color: .accent)
        .disabled(store.isRestoring || store.record.draft != nil)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(deviceType == .duo ? Color.background : .secondaryBackground, ignoresSafeAreaEdges: .bottom)
    }

    @ViewBuilder
    private var kindBadge: some View {
        switch version.kind {
        case .initial:
            statusBadge(
                RecordPresentation.text("development_record_version_initial"),
                foreground: .secondaryLabel,
                background: .tertiaryBackground
            )
        case .correction:
            statusBadge(
                RecordPresentation.text("development_record_version_correction"),
                foreground: .accent,
                background: .tintFill
            )
        case .rollback:
            statusBadge(
                RecordPresentation.text("development_record_version_rollback"),
                foreground: .warning,
                background: .warning.opacity(0.12)
            )
        }
    }

    private func statusBadge(
        _ title: String,
        foreground: Color,
        background: Color
    ) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background, in: .rect(cornerRadius: 8))
    }
}
