//
//  GoalDetailViewSupport.swift
//  Development
//
//  Created by opfic on 9/15/26.
//

import SwiftUI
import Domain
import PresentationShared

struct TimelineRow: View {
    let item: RecordTimelineItem
    let isFirst: Bool
    let isLast: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                HStack(alignment: .top, spacing: 16) {
                    timelineIndicator
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.label)
                            .lineLimit(2)
                        status
                        if item.hasDraft {
                            RelativeTimeText(
                                date: item.date,
                                bodyFont: .caption,
                                bodyColor: .tertiaryLabel
                            )
                        } else {
                            Text(item.date, format: .dateTime.month().day())
                                .font(.caption)
                                .foregroundStyle(Color.tertiaryLabel)
                        }
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.separator)
            }
            .contentShape(.rect)
            .frame(minHeight: RecordTimelineLayout.rowHeight, alignment: .top)
            .background(alignment: .topLeading) {
                RecordTimelineConnector(isFirst: isFirst, isLast: isLast)
            }
        }
        .buttonStyle(.plain)
    }

    private var timelineIndicator: some View {
        Circle()
            .fill(item.hasDraft ? Color.warning : .accent)
            .frame(width: RecordTimelineLayout.markerSize, height: RecordTimelineLayout.markerSize)
            .padding(.top, RecordTimelineLayout.markerTopPadding)
    }

    private var status: some View {
        Text(statusText)
            .font(.caption)
            .foregroundStyle(item.hasDraft ? Color.warning : .accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                item.hasDraft ? Color.warning.opacity(0.12) : Color.tintFill,
                in: .rect(cornerRadius: 8)
            )
    }

    private var statusText: String {
        guard let versionNumber = item.versionNumber else {
            return RecordPresentation.text("development_record_draft_status")
        }
        return String.localizedStringWithFormat(
            RecordPresentation.text("development_record_confirmed_version_format"),
            RecordPresentation.versionLabel(versionNumber)
        )
    }
}

struct GoalStatusBadge: View {
    let status: DevelopmentGoal.Status

    var body: some View {
        Label(status.title, systemImage: systemImage)
        .font(.caption.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(background, in: .capsule)
    }

    private var systemImage: String {
        switch status {
        case .inProgress:
            "clock"
        case .completed:
            "checkmark.circle.fill"
        case .archived:
            "archivebox.fill"
        }
    }

    private var foreground: Color {
        switch status {
        case .inProgress:
            .accent
        case .completed:
            .white
        case .archived:
            .secondaryLabel
        }
    }

    private var background: Color {
        switch status {
        case .inProgress:
            .tintFill
        case .completed:
            .accent
        case .archived:
            .tertiaryBackground
        }
    }
}
