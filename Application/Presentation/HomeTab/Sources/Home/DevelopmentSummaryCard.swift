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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let items: [DevelopmentGoalItem]
    let isLoading: Bool
    let hasLoaded: Bool
    let hasLoadFailure: Bool

    var body: some View {
        // 카드 없이 글자를 화면 여백에 맞추고 아래 구분선으로 나눔
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "flag")
                Text("home_development_summary_eyebrow", bundle: PresentationResources.bundle)
            }
            .font(.adaptive(.footnote))
            .foregroundStyle(Color.secondaryLabel)

            summaryTitle
                .padding(.top, 8)
                .padding(.bottom, 12)

            summaryContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, isiOSAppOnMac ? 4 * AdaptiveSize.boardScale : 8)
        .padding(.bottom, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.secondarySeparator)
        }
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
        .font(.adaptive(isiOSAppOnMac ? .title2 : .title3).weight(.bold))
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
                .font(.adaptive(.subheadline))
                .foregroundStyle(Color.secondaryLabel)
        } else if items.isEmpty {
            Text("home_development_summary_empty_message", bundle: PresentationResources.bundle)
                .font(.adaptive(.subheadline))
                .foregroundStyle(Color.secondaryLabel)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                DevelopmentTodoProgressView(progress: todoProgress)

                if let recentRecord {
                    HStack(spacing: 8) {
                        Text("home_development_summary_recent_record", bundle: PresentationResources.bundle)
                            .foregroundStyle(Color.secondaryLabel)
                        Text(recentRecord.title)
                            .foregroundStyle(Color.label)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(recentRecord.confirmedAt, format: .dateTime.month().day().hour().minute())
                            .foregroundStyle(Color.secondaryLabel)
                    }
                    .font(.adaptive(.footnote))
                    .padding(.top, 12)
                    .overlay(alignment: .top) {
                        Divider().overlay(Color.secondarySeparator)
                    }
                    .padding(.top, 14)
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
