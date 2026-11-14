//
//  TodoDetailContentView.swift
//  PresentationShared
//
//  Created by opfic on 3/2/26.
//

import SwiftUI
import Domain

struct TodoDetailContentView: View {
    @Environment(\.readableContentWidth) private var readableContentWidth
    let title: String
    let content: String
    let referenceItems: [Int: TodoReferenceItem]
    var number: Int
    var showsTitle = true
    var onOpenTodoID: ((String) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if showsTitle {
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .firstTextBaseline, spacing: 0, pinnedViews: .sectionFooters) {
                            Section {
                                Text(title)
                            } footer: {
                                Text("#\(number)")
                                    .foregroundStyle(Color.tertiaryLabel)
                                    .padding(.leading, 8)
                                    .background {
                                        Color.background.padding(.trailing, -16)
                                    }
                            }
                        }
                        .lineLimit(1)
                        .font(.title3.bold())
                    }
                    .scrollBounceBehavior(.always, axes: .horizontal)
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                    .padding(.horizontal, -16)
                }

                Group {
                    if content.isEmpty {
                        ContentUnavailableView(
                            String(
                                localized: "development_record_content_empty_title",
                                bundle: PresentationResources.bundle
                            ),
                            systemImage: "doc.text"
                        )
                    } else {
                        TodoMarkdownContentView(
                            content: content,
                            referenceItems: referenceItems,
                            isScrollEnabled: false,
                            onOpenTodoID: onOpenTodoID
                        )
                        .frame(minHeight: 120, alignment: .top)
                    }
                }
                .padding(.vertical, 16)
                .background(Color.secondaryBackground, in: .rect)
            }
            .padding()
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
    }
}
