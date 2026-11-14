//
//  RecordPresentation.swift
//  Development
//
//  Created by opfic on 9/13/26.
//

import SwiftUI
import PresentationShared

enum RecordPresentation {
    static func text(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: PresentationResources.bundle)
    }

    static func versionLabel(_ number: Int) -> String {
        "#\(number)"
    }
}

enum RecordTimelineLayout {
    static let rowHeight: CGFloat = 88
    static let markerSize: CGFloat = 13
    static let lineWidth: CGFloat = 2
    static let markerTopPadding: CGFloat = 3
    static let lineXOffset = (markerSize - lineWidth) / 2
    static let lineYOffset = markerTopPadding + markerSize / 2
}

struct RecordTimelineConnector: View {
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !isFirst {
                line
                    .frame(height: RecordTimelineLayout.lineYOffset)
            }
            if !isLast {
                line
                    .frame(maxHeight: .infinity)
                    .padding(.top, RecordTimelineLayout.lineYOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var line: some View {
        Rectangle()
            .fill(Color.accent.opacity(0.45))
            .frame(width: RecordTimelineLayout.lineWidth)
            .offset(x: RecordTimelineLayout.lineXOffset)
    }
}
