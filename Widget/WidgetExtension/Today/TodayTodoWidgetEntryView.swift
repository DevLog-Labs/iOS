//
//  TodayTodoWidgetEntryView.swift
//  WidgetExtension
//
//  Created by opfic on 4/15/26.
//

import SwiftUI
import WidgetCore

struct TodayTodoWidgetEntryView: View {
    let entry: TodayTodoWidgetEntry
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetContentMargins) private var widgetContentMargins

    var body: some View {
        Group {
            if entry.requiresReinstallation {
                reinstallContent
            } else {
                smallContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        Text("widget_today_title")
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var reinstallContent: some View {
        VStack(alignment: .leading) {
            header
            Spacer()
            Text("widget_today_reinstall_message")
                .font(.caption)
                .foregroundStyle(Color.secondaryLabel)
                .lineLimit(3)
            Spacer()
        }
        .padding(widgetContentMargins)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header

                Spacer(minLength: 8)

                if let snapshot = entry.snapshot {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(snapshot.totalCount)")
                            .font(.largeTitle.bold())
                        Text("widget_today_count_unit")
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(Color.accent)
                } else {
                    placeholder(width: 42, height: 30)
                }

                Spacer(minLength: 8)
            }
            .padding(.top, widgetContentMargins.top)
            .padding(.leading, widgetContentMargins.leading)
            .padding(.trailing, widgetContentMargins.trailing)

            Divider()

            if let footerURL {
                Link(destination: footerURL) {
                    footerContent
                        .padding(.top, 8)
                        .padding(.leading, widgetContentMargins.leading)
                        .padding(.trailing, widgetContentMargins.trailing)
                        .padding(.bottom, widgetContentMargins.bottom)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            } else {
                footerContent
                    .padding(.top, 8)
                    .padding(.leading, widgetContentMargins.leading)
                    .padding(.trailing, widgetContentMargins.trailing)
                    .padding(.bottom, widgetContentMargins.bottom)
            }
        }
    }

    private var footerURL: URL? {
        guard let item = entry.snapshot?.items.first else { return WidgetDeepLink.todayTodoURL }
        return WidgetDeepLink.todoURL(id: item.id) ?? WidgetDeepLink.todayTodoURL
    }

    @ViewBuilder
    private var footerContent: some View {
        if let snapshot = entry.snapshot {
            if let item = snapshot.items.first {
                todoRow(item)
            } else {
                Text("widget_today_empty_small")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } else {
            placeholderRow
        }
    }

    private func todoRow(_ item: WidgetTodayTodoSnapshot) -> some View {
        let style = WidgetTodoCategoryStyle(
            categoryID: item.categoryID,
            colorHex: item.categoryColorHex
        )

        return HStack(spacing: 6) {
            Image(systemName: style.symbolName)
                .font(.caption2.bold())
                .foregroundStyle(colorScheme == .dark ? Color.white : style.color)
                .frame(width: 22, height: 22)
                .background(
                    colorScheme == .dark ? style.color : style.color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 7)
                )

            Text("#\(item.number)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accent)

            Text(item.title)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
    }

    private var placeholderRow: some View {
        HStack(spacing: 6) {
            placeholder(width: 22, height: 22)
            placeholder(width: 22, height: 8)
            placeholder(width: 70, height: 8)
        }
        .frame(height: 24)
    }

    private func placeholder(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondaryLabel.opacity(0.18))
            .frame(width: width, height: height)
    }
}
