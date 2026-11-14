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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let goals: [DevelopmentGoal]
    let isLoading: Bool
    let hasLoaded: Bool
    let hasLoadFailure: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("development_goal_title", bundle: PresentationResources.bundle)
                .font(.title3.bold())

            if hasLoaded {
                statusGrid
            } else if isLoading || !hasLoadFailure {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            }

            if hasLoadFailure {
                HStack(spacing: 12) {
                    Text("common_error_message", bundle: PresentationResources.bundle)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryLabel)
                    Spacer(minLength: 0)
                    Button(action: onRetry) {
                        Text("profile_goal_retry", bundle: PresentationResources.bundle)
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .padding(16)
        .groupBackground(in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusGrid: some View {
        let counts = GoalCounts(goals: goals)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            statusTile(
                title: DevelopmentGoal.Status.inProgress.title,
                symbol: "clock",
                color: .accent,
                count: counts.inProgress
            )
            statusTile(
                title: DevelopmentGoal.Status.completed.title,
                symbol: "checkmark",
                color: .success,
                count: counts.completed
            )
            statusTile(
                title: DevelopmentGoal.Status.archived.title,
                symbol: "archivebox",
                color: .secondaryLabel,
                count: counts.archived
            )
        }
    }

    private func statusTile(title: String, symbol: String, color: Color, count: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 36, height: 36)
                .iconStyle(color: color, in: Circle())
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.secondaryLabel)
            Text(verbatim: String(count))
                .font(.title3.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}
