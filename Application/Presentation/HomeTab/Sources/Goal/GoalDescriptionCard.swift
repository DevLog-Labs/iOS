//
//  GoalDescriptionCard.swift
//  Development
//
//  Created by opfic on 9/20/26.
//

import SwiftUI
import PresentationShared

struct GoalDescriptionCard: View {
    let description: String
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16 * AdaptiveSize.scale) {
            Text(RecordPresentation.text("development_goal_description_title"))
                .font(.adaptive(.title3).bold())

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16 * AdaptiveSize.scale)
            } else if description.isEmpty {
                Text(RecordPresentation.text("development_goal_description_empty_message"))
                    .font(.adaptive(.body))
                    .foregroundStyle(Color.secondaryLabel)
            } else {
                MarkdownContentView(content: description)
                    .frame(minHeight: 120 * AdaptiveSize.scale)
            }
        }
        .padding(20 * AdaptiveSize.scale)
        .background(Color.secondaryBackground, in: .rect)
    }
}
