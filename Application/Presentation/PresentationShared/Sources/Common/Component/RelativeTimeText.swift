//
//  RelativeTimeText.swift
//  PresentationShared
//
//  Created by opfic on 3/25/26.
//

import SwiftUI

public struct RelativeTimeText: View {
    let date: Date
    var bodyFont: Font = .caption2
    var bodyColor: Color = .textSecondary

    public init(
        date: Date,
        bodyFont: Font = .caption2,
        bodyColor: Color = .textSecondary
    ) {
        self.date = date
        self.bodyFont = bodyFont
        self.bodyColor = bodyColor
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            Text(
                String.localizedStringWithFormat(
                    String(localized: "relative_time_updated_format", bundle: PresentationResources.bundle),
                    RelativeTime.text(from: date, now: context.date)
                )
            )
                .font(bodyFont)
                .foregroundStyle(bodyColor)
        }
    }
}

public enum RelativeTime {
    public static func text(from date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))

        if seconds < 60 {
            return String.localizedStringWithFormat(
                String(localized: "relative_time_seconds_ago_format", bundle: PresentationResources.bundle),
                Int64(max(0, seconds))
            )
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return String.localizedStringWithFormat(
                String(localized: "relative_time_minutes_ago_format", bundle: PresentationResources.bundle),
                Int64(minutes)
            )
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return String.localizedStringWithFormat(
                String(localized: "relative_time_hours_ago_format", bundle: PresentationResources.bundle),
                Int64(hours)
            )
        } else {
            let days = seconds / 86400
            return String.localizedStringWithFormat(
                String(localized: "relative_time_days_ago_format", bundle: PresentationResources.bundle),
                Int64(days)
            )
        }
    }
}
