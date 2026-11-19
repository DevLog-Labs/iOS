//
//  GoalSummaryCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import Domain
import PresentationShared

private struct GoalCounts {
    let inProgress: Int
    let completed: Int
    let archived: Int

    init(goals: [DevelopmentGoal]) {
        var inProgress = 0
        var completed = 0
        var archived = 0
        for goal in goals {
            switch goal.status {
            case .inProgress:
                inProgress += 1
            case .completed:
                completed += 1
            case .archived:
                archived += 1
            }
        }
        self.inProgress = inProgress
        self.completed = completed
        self.archived = archived
    }
}

struct GoalSummaryCard: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let goals: [DevelopmentGoal]
    let isLoading: Bool
    let hasLoaded: Bool
    let hasLoadFailure: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileSectionHeader(Text("development_goal_title", bundle: PresentationResources.bundle))

            VStack(alignment: .leading, spacing: 12) {
                if hasLoaded {
                    statusGrid
                } else if isLoading || !hasLoadFailure {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 80)
                }

                if hasLoadFailure {
                    HStack(spacing: 12) {
                        Text("common_error_message", bundle: PresentationResources.bundle)
                            .font(.adaptive(.caption))
                            .foregroundStyle(Color.secondaryLabel)
                        Spacer(minLength: 0)
                        Button(action: onRetry) {
                            Text("profile_goal_retry", bundle: PresentationResources.bundle)
                                .font(.adaptive(.caption).weight(.semibold))
                        }
                    }
                }
            }
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
        }
    }

    // 카드 없이 위아래 구분선 안에서 세로선으로 나눈 세 칸
    private var statusGrid: some View {
        let counts = GoalCounts(goals: goals)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
        return layout {
            statusTile(
                title: DevelopmentGoal.Status.inProgress.title,
                symbol: "clock",
                color: .tintLabel,
                count: counts.inProgress,
                showsSeparator: true
            )
            statusTile(
                title: DevelopmentGoal.Status.completed.title,
                symbol: "checkmark.circle",
                color: .success,
                count: counts.completed,
                showsSeparator: true
            )
            statusTile(
                title: DevelopmentGoal.Status.archived.title,
                symbol: "archivebox",
                color: .secondaryLabel,
                count: counts.archived,
                showsSeparator: false
            )
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondarySeparator)
                .frame(height: 1)
        }
    }

    private func statusTile(title: String, symbol: String, color: Color, count: Int, showsSeparator: Bool) -> some View {
        let isVertical = dynamicTypeSize.isAccessibilitySize

        return VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.adaptive(.body))
                .foregroundStyle(color)
            Text(title)
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)
            Text(verbatim: String(count))
                .font(.adaptive(.title3).weight(.heavy))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
        // 칸 사이 구분선, 큰 글자에서 세로로 쌓으면 가로선
        .overlay(alignment: isVertical ? .bottom : .trailing) {
            if showsSeparator {
                Rectangle()
                    .fill(Color.secondarySeparator)
                    .frame(width: isVertical ? nil : 1, height: isVertical ? 1 : nil)
            }
        }
    }
}
