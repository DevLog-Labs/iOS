//
//  GoalDetailViewSupport.swift
//  Development
//
//  Created by opfic on 9/15/26.
//

import SwiftUI
import Domain
import PresentationShared

// 제목과 상태·버전 배지, 날짜를 표시하는 개발 기록 행
struct RecordRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let item: RecordTimelineItem
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            RecordListRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.adaptive(isiOSAppOnMac ? .body : .callout).weight(.semibold))
                        .foregroundStyle(Color.label)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        TodoBadge(statusText, color: item.hasDraft ? .warning : .tintLabel)
                        if item.hasDraft {
                            RelativeTimeText(
                                date: item.date,
                                bodyFont: .adaptive(.footnote),
                                bodyColor: .secondaryLabel
                            )
                        } else {
                            Text(item.date, format: .dateTime.month().day())
                                .font(.adaptive(.footnote))
                                .foregroundStyle(Color.secondaryLabel)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
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
        switch status {
        case .inProgress:
            TodoBadge(status.title, color: .tintLabel)
        case .completed:
            TodoBadge(status.title, color: .success)
        case .archived:
            TodoBadge(status.title, color: .secondaryLabel)
        }
    }
}
