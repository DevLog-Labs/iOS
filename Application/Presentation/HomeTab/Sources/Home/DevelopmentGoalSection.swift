//
//  DevelopmentGoalSection.swift
//  HomeTab
//
//  Created by opfic on 9/20/26.
//

import SwiftUI
import PresentationShared

struct DevelopmentGoalSection: View {
    let items: [DevelopmentGoalItem]
    let isLoading: Bool
    let hasLoaded: Bool
    let hasLoadFailure: Bool
    let onSelect: (DevelopmentGoalItem) -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * AdaptiveSize.scale) {
            header
            content
        }
        .padding(.top, 8 * AdaptiveSize.scale)
    }

    @ViewBuilder
    private var content: some View {
        if !hasLoaded && isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32 * AdaptiveSize.scale)
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
            LazyVStack(spacing: 16 * AdaptiveSize.scale) {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        DevelopmentGoalCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8 * AdaptiveSize.scale) {
            Text("home_development_goal_section_title", bundle: PresentationResources.bundle)
                .font(.adaptive(.title2))
                .foregroundStyle(Color.label)
            if hasLoaded {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "home_development_goal_count_format", bundle: PresentationResources.bundle),
                        items.count
                    )
                )
                .font(.adaptive(.subheadline).weight(.medium))
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 10 * AdaptiveSize.scale)
                .padding(.vertical, 5 * AdaptiveSize.scale)
                .background(Color.accent.opacity(0.1), in: .capsule)
            }
            Spacer()
        }
    }
}

private struct DevelopmentGoalCard: View {
    let item: DevelopmentGoalItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * AdaptiveSize.scale) {
            HStack(spacing: 12 * AdaptiveSize.scale) {
                DevelopmentGoalStatusBadge()
                Spacer(minLength: 12 * AdaptiveSize.scale)
                if let recentRecord = item.recentRecord {
                    Text(recentRecord.confirmedAt, format: .dateTime.month().day().hour().minute())
                        .font(.adaptive(.caption))
                        .foregroundStyle(Color.tertiaryLabel)
                }
            }

            Text(item.goal.title)
                .font(.adaptive(.title3).weight(.semibold))
                .foregroundStyle(Color.label)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !item.goal.description.isEmpty {
                Text(item.goal.description)
                    .font(.adaptive(.subheadline))
                    .foregroundStyle(Color.secondaryLabel)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            DevelopmentTodoProgressView(progress: item.todoProgress)

            Divider().overlay(Color.secondarySeparator)

            if let recentRecord = item.recentRecord {
                VStack(alignment: .leading, spacing: 3 * AdaptiveSize.scale) {
                    Text("home_development_goal_recent_record", bundle: PresentationResources.bundle)
                        .font(.adaptive(.caption))
                        .foregroundStyle(Color.tertiaryLabel)
                    Text(recentRecord.title)
                        .font(.adaptive(.subheadline).weight(.medium))
                        .foregroundStyle(Color.label)
                        .lineLimit(1)
                }
            } else {
                Text("development_record_empty_title", bundle: PresentationResources.bundle)
                    .font(.adaptive(.caption))
                    .foregroundStyle(Color.tertiaryLabel)
            }
        }
        .padding(18 * AdaptiveSize.scale)
        .background(Color.secondaryBackground, in: .rect)
        .contentShape(.rect)
    }
}

struct DevelopmentTodoProgressView: View {
    let progress: DevelopmentGoalTodoProgress

    var body: some View {
        if progress.isEmpty {
            Text("home_development_goal_todo_empty", bundle: PresentationResources.bundle)
                .font(.adaptive(.caption))
                .foregroundStyle(Color.tertiaryLabel)
        } else {
            VStack(alignment: .leading, spacing: 8 * AdaptiveSize.scale) {
                HStack(spacing: 8 * AdaptiveSize.scale) {
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
                    .font(.adaptive(.caption).weight(.medium))
                    .foregroundStyle(Color.secondaryLabel)
                    Spacer(minLength: 8 * AdaptiveSize.scale)
                    Text(
                        String.localizedStringWithFormat(
                            String(
                                localized: "home_development_goal_todo_progress_percent_format",
                                bundle: PresentationResources.bundle
                            ),
                            progress.percentage
                        )
                    )
                    .font(.adaptive(.caption).weight(.semibold))
                    .foregroundStyle(Color.accent)
                }

                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.separator.opacity(0.6))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.accent)
                                .frame(width: proxy.size.width * progress.fraction)
                        }
                }
                .frame(height: 8 * AdaptiveSize.scale)
            }
        }
    }
}

private struct DevelopmentGoalStatusBadge: View {
    var body: some View {
        Label {
            Text("development_goal_status_in_progress", bundle: PresentationResources.bundle)
        } icon: {
            Image(systemName: "clock")
        }
        .font(.adaptive(.caption).weight(.semibold))
        .foregroundStyle(Color.accent)
        .padding(.horizontal, 10 * AdaptiveSize.scale)
        .padding(.vertical, 5 * AdaptiveSize.scale)
        .background(Color.accent.opacity(0.1), in: .rect(cornerRadius: CornerRadius.badge))
    }
}
