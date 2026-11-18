//
//  DevelopmentGoalSection.swift
//  HomeTab
//
//  Created by opfic on 9/20/26.
//

import SwiftUI
import PresentationShared

struct DevelopmentGoalSection: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let items: [DevelopmentGoalItem]
    let isLoading: Bool
    let hasLoaded: Bool
    let hasLoadFailure: Bool
    let onSelect: (DevelopmentGoalItem) -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeSectionHeader {
                Text("home_development_goal_section_title", bundle: PresentationResources.bundle)
                if hasLoaded {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "home_development_goal_count_format", bundle: PresentationResources.bundle),
                            items.count
                        )
                    )
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondaryLabel)
                }
            } trailing: {
                EmptyView()
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if !hasLoaded && isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else if !hasLoaded && hasLoadFailure {
            ContentUnavailableView {
                Label(
                    String(localized: "common_error_title", bundle: PresentationResources.bundle),
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(String(localized: "common_error_message", bundle: PresentationResources.bundle))
            } actions: {
                Button(String(localized: "development_record_timeline_retry", bundle: PresentationResources.bundle)) {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
        } else if items.isEmpty {
            ContentUnavailableView {
                Label(
                    String(
                        localized: "home_development_goal_empty_title",
                        bundle: PresentationResources.bundle
                    ),
                    systemImage: "flag.checkered"
                )
            } description: {
                Text(
                    String(
                        localized: "home_development_goal_empty_message",
                        bundle: PresentationResources.bundle
                    )
                )
            }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        DevelopmentGoalRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        }
    }
}

// 카드 없이 아래 구분선으로 나눈 목표 행
private struct DevelopmentGoalRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let item: DevelopmentGoalItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                TodoBadge(
                    String(localized: "development_goal_status_in_progress", bundle: PresentationResources.bundle),
                    color: .tintLabel
                )
                if let recentRecord = item.recentRecord {
                    Text(recentRecord.confirmedAt, format: .dateTime.month().day().hour().minute())
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.secondaryLabel)
                }
            }

            Text(item.goal.title)
                .font(.adaptive(isiOSAppOnMac ? .body : .callout).weight(.bold))
                .foregroundStyle(Color.label)
                .lineLimit(2)
                .padding(.top, 8)

            if !item.goal.description.isEmpty {
                Text(item.goal.description)
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
                    .lineLimit(2)
                    .padding(.top, 4)
            }

            DevelopmentTodoProgressView(progress: item.todoProgress)
                .padding(.top, 10)

            HStack(spacing: 4) {
                if let recentRecord = item.recentRecord {
                    Text("home_development_goal_recent_record", bundle: PresentationResources.bundle)
                    Text(verbatim: "·")
                    Text(recentRecord.title)
                        .foregroundStyle(Color.label)
                } else {
                    Text("development_record_empty_title", bundle: PresentationResources.bundle)
                }
            }
            .font(.adaptive(.footnote))
            .foregroundStyle(Color.secondaryLabel)
            .lineLimit(1)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 14)
        .padding(.trailing, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)
        }
        .contentShape(.rect)
    }
}

struct DevelopmentTodoProgressView: View {
    let progress: DevelopmentGoalTodoProgress

    var body: some View {
        if progress.isEmpty {
            Text("home_development_goal_todo_empty", bundle: PresentationResources.bundle)
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(
                        String.localizedStringWithFormat(
                            String(
                                localized: "home_development_goal_todo_progress_format",
                                bundle: PresentationResources.bundle
                            ),
                            progress.completedCount,
                            progress.totalCount
                        )
                    )
                    Spacer(minLength: 8)
                    Text(
                        String.localizedStringWithFormat(
                            String(
                                localized: "home_development_goal_todo_progress_percent_format",
                                bundle: PresentationResources.bundle
                            ),
                            progress.percentage
                        )
                    )
                }
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)

                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.separator)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.accent)
                                .frame(width: proxy.size.width * progress.fraction)
                        }
                }
                .frame(height: 6)
            }
        }
    }
}
