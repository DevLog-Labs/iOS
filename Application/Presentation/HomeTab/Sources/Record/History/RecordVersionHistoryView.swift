//
//  RecordVersionHistoryView.swift
//  Development
//
//  Created by opfic on 9/14/26.
//

import SwiftUI
import Domain
import PresentationShared

struct RecordVersionHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var store: StoreOf<RecordDetailFeature>

    private var sortedVersions: [DevelopmentRecord.Version] {
        store.versions.sorted { $1.number < $0.number }
    }

    private var currentVersion: DevelopmentRecord.Version? {
        store.currentVersion
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24 * AdaptiveSize.scale) {
                titleSection
                currentVersionCard
                historyCard
            }
            .padding(.horizontal)
            .padding(.bottom, 24 * AdaptiveSize.scale)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(Color.background)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .navigationDestination(
            item: $store.scope(state: \.versionDetail, action: \.versionDetail),
            interactivePop: true
        ) { destination in
            RecordVersionDetailView(
                store: store,
                version: destination.version
            )
        }
    }

    private var topBar: some View {
        HStack {
            NavigationBackButton(action: { dismiss() })
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12 * AdaptiveSize.scale)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8 * AdaptiveSize.scale) {
            Text(RecordPresentation.text("development_record_history_title"))
                .font(.adaptive(.largeTitle).bold())

            if let currentVersion {
                Text(currentVersion.title)
                    .font(.adaptive(.title3))
                    .foregroundStyle(Color.secondaryLabel)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var currentVersionCard: some View {
        if let currentVersion {
            HStack(alignment: .center, spacing: 16 * AdaptiveSize.scale) {
                Image(systemName: "doc.text")
                    .font(.adaptive(.title2))
                    .foregroundStyle(Color.accent)
                    .frame(width: 56 * AdaptiveSize.scale, height: 56 * AdaptiveSize.scale)
                    .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: CornerRadius.control))

                VStack(alignment: .leading, spacing: 6 * AdaptiveSize.scale) {
                    HStack(spacing: 8 * AdaptiveSize.scale) {
                        Text(RecordPresentation.text("development_record_current_version"))
                            .font(.adaptive(.headline))

                        RecordVersionBadge(number: currentVersion.number, isCurrent: false)
                    }

                    Text(RecordPresentation.text("development_record_current_version_message"))
                        .font(.adaptive(.subheadline))
                        .foregroundStyle(Color.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20 * AdaptiveSize.scale)
            .background(Color.tintFill, in: .rect(cornerRadius: CornerRadius.group))
        }
    }

    private var historyCard: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(sortedVersions.enumerated()), id: \.element.id) { index, version in
                Button {
                    if version.id == store.currentVersionID {
                        dismiss()
                    } else {
                        store.send(.view(.selectVersion(version)))
                    }
                } label: {
                    VersionHistoryRow(
                        version: version,
                        isCurrent: version.id == store.currentVersionID,
                        isLast: index == sortedVersions.count - 1
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24 * AdaptiveSize.scale)
        .background(Color.secondaryBackground, in: .rect)
    }

    private var footer: some View {
        Label(
            RecordPresentation.text(
                store.allowsMutation
                    ? "development_record_history_footer"
                    : "development_record_history_read_only_footer"
            ),
            systemImage: "lock"
        )
        .font(.adaptive(.caption))
        .foregroundStyle(Color.secondaryLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24 * AdaptiveSize.scale)
        .padding(.vertical, 12 * AdaptiveSize.scale)
        .background(Color.background, ignoresSafeAreaEdges: .bottom)
    }
}

private struct VersionHistoryRow: View {
    let version: DevelopmentRecord.Version
    let isCurrent: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 8 * AdaptiveSize.scale) {
            HStack(alignment: .top, spacing: 16 * AdaptiveSize.scale) {
                timelineIndicator

                VStack(alignment: .leading, spacing: 5 * AdaptiveSize.scale) {
                    HStack(spacing: 8 * AdaptiveSize.scale) {
                        RecordVersionBadge(number: version.number, isCurrent: false)

                        if isCurrent {
                            statusBadge(
                                RecordPresentation.text("development_record_version_current"),
                                foreground: .white,
                                background: .accent
                            )
                        }

                        kindBadge
                    }

                    Text(version.confirmedAt, format: .dateTime.month().day().hour().minute())
                        .font(.adaptive(.caption))
                        .foregroundStyle(Color.tertiaryLabel)

                    Text(version.title)
                        .font(.adaptive(.body).weight(.semibold))
                        .foregroundStyle(Color.label)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8 * AdaptiveSize.scale)

            Image(systemName: "chevron.right")
                .font(.adaptive(.callout).weight(.semibold))
                .foregroundStyle(Color.separator)
        }
        .contentShape(.rect)
        .frame(minHeight: RecordTimelineLayout.rowHeight, alignment: .top)
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle()
                    .fill(Color.accent.opacity(0.45))
                    .frame(width: RecordTimelineLayout.lineWidth)
                    .frame(maxHeight: .infinity)
                    .offset(
                        x: RecordTimelineLayout.lineXOffset,
                        y: RecordTimelineLayout.lineYOffset
                    )
            }
        }
    }

    private var timelineIndicator: some View {
        Circle()
            .fill(isCurrent ? Color.accent : Color.tertiaryLabel)
            .frame(
                width: RecordTimelineLayout.markerSize,
                height: RecordTimelineLayout.markerSize
            )
            .padding(.top, RecordTimelineLayout.markerTopPadding)
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
            .font(.adaptive(.caption).weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9 * AdaptiveSize.scale)
            .padding(.vertical, 5 * AdaptiveSize.scale)
            .background(background, in: .rect(cornerRadius: CornerRadius.badge))
    }
}

struct RecordVersionBadge: View {
    let number: Int
    let isCurrent: Bool

    var body: some View {
        Text(RecordPresentation.versionLabel(number))
            .font(.adaptive(.caption).weight(.semibold))
            .foregroundStyle(isCurrent ? Color.white : Color.accent)
            .padding(.horizontal, 10 * AdaptiveSize.scale)
            .padding(.vertical, 5 * AdaptiveSize.scale)
            .background(
                isCurrent ? Color.accent : Color.tintFill,
                in: .rect(cornerRadius: CornerRadius.badge)
            )
    }
}
