//
//  MarkdownRendererView.swift
//  MarkdownRenderer
//
//  Created by opfic on 8/1/26.
//

import SwiftUI

public struct MarkdownRendererView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo: .body) private var fontSize = 17

    @State private var contentHeight = CGFloat(1)

    private let markdown: String
    private let isScrollEnabled: Bool
    private let references: [Int: MarkdownRendererReference]
    private let onOpenReferenceID: ((String) -> Void)?

    public init(
        markdown: String,
        references: [Int: MarkdownRendererReference] = [:],
        isScrollEnabled: Bool = true,
        fontSize: CGFloat? = nil,
        onOpenReferenceID: ((String) -> Void)? = nil
    ) {
        // 글자 크기를 받지 않으면 기본 본문 크기
        if let fontSize {
            self._fontSize = ScaledMetric(wrappedValue: fontSize, relativeTo: .body)
        }
        self.markdown = markdown
        self.isScrollEnabled = isScrollEnabled
        self.references = references
        self.onOpenReferenceID = onOpenReferenceID
    }

    public var body: some View {
        MarkdownWebView(
            markdown: markdown,
            references: references,
            colorScheme: colorScheme,
            languageCode: locale.language.languageCode?.identifier ?? "und",
            fontSize: fontSize,
            isScrollEnabled: isScrollEnabled,
            onContentHeightChange: { height in
                guard contentHeight != height else { return }
                contentHeight = height
            },
            onOpenReferenceID: onOpenReferenceID,
            onOpenURL: { openURL($0) }
        )
        .frame(height: isScrollEnabled ? nil : contentHeight)
    }
}
