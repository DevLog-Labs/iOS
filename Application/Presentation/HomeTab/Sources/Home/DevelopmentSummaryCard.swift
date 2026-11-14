//
//  DevelopmentSummaryCard.swift
//  HomeTab
//
//  Created by opfic on 9/20/26.
//

import Domain
import SwiftUI
import PresentationShared

struct DevelopmentSummaryCard: View {
    let items: [DevelopmentGoalItem]
    let isLoading: Bool
    let hasLoaded: Bool
    let hasLoadFailure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("home_development_summary_eyebrow", bundle: PresentationResources.bundle)
                        .font(.subheadline)
                        .foregroundStyle(Color.tertiaryLabel)
                    summaryTitle
                }
                Spacer(minLength: 16)
                Image(systemName: "flag.checkered")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accent)
                    .frame(width: 64, height: 64)
                    .background(Color.accent.opacity(0.1), in: .rect(cornerRadius: CornerRadius.control))
            }

            summaryContent
        }
        .padding(20)
        .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
    }

    @ViewBuilder
    private var summaryTitle: some View {
        let format = if items.count == 1 {
            String(
                localized: "home_development_summary_title_singular_format",
                bundle: PresentationResources.bundle
            )
        } else {
            String(
                localized: "home_development_summary_title_format",
                bundle: PresentationResources.bundle
            )
        }
        Text(
            String.localizedStringWithFormat(
                format,
                items.count
            )
        )
        .font(.title2.weight(.semibold))
        .foregroundStyle(Color.label)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var summaryContent: some View {
        if !hasLoaded && isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else if !hasLoaded && hasLoadFailure {
            Text("common_error_message", bundle: PresentationResources.bundle)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryLabel)
        } else if items.isEmpty {
            Text("home_development_summary_empty_message", bundle: PresentationResources.bundle)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryLabel)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                DevelopmentTodoProgressView(progress: todoProgress)

                if let recentRecord {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("home_development_summary_recent_record", bundle: PresentationResources.bundle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.tertiaryLabel)
                        HStack(spacing: 12) {
                            Text(recentRecord.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.label)
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            Text(recentRecord.confirmedAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(Color.tertiaryLabel)
                        }
                    }
                }
            }
        }
    }

    private var recentRecord: DevelopmentRecord.Version? {
        items.compactMap(\.recentRecord).max { $0.confirmedAt < $1.confirmedAt }
    }

    private var todoProgress: DevelopmentGoalTodoProgress {
        DevelopmentGoalTodoProgress(
            completedCount: items.reduce(0) { $0 + $1.todoProgress.completedCount },
            totalCount: items.reduce(0) { $0 + $1.todoProgress.totalCount }
        )
    }
}
