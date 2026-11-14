//
//  TodoMarkdownContentView.swift
//  PresentationShared
//
//  Created by opfic on 3/25/26.
//

import SwiftUI
import Domain
import MarkdownRenderer

public struct MarkdownContentView: View {
    private let content: String
    private let isScrollEnabled: Bool

    public init(content: String, isScrollEnabled: Bool = true) {
        self.content = content
        self.isScrollEnabled = isScrollEnabled
    }

    public var body: some View {
        MarkdownRendererView(
            markdown: content,
            isScrollEnabled: isScrollEnabled,
            fontSize: AdaptiveSize.macFontSize(.body)
        )
            .frame(maxWidth: .infinity, maxHeight: isScrollEnabled ? .infinity : nil)
    }
}

struct TodoMarkdownContentView: View {
    let content: String
    let referenceItems: [Int: TodoReferenceItem]
    var isScrollEnabled = true
    var onOpenTodoID: ((String) -> Void)?

    var body: some View {
        MarkdownRendererView(
            markdown: content,
            references: rendererReferences,
            isScrollEnabled: isScrollEnabled,
            fontSize: AdaptiveSize.macFontSize(.body),
            onOpenReferenceID: onOpenTodoID
        )
        .frame(maxWidth: .infinity, maxHeight: isScrollEnabled ? .infinity : nil)
    }

    private var rendererReferences: [Int: MarkdownRendererReference] {
        referenceItems.mapValues { item in
            MarkdownRendererReference(
                referenceID: item.id,
                title: item.title,
                colorHex: item.category.color.hexValue ?? "#808080",
                iconDataURL: iconDataURL(for: item.category.symbolName)
            )
        }
    }

    private func iconDataURL(for symbolName: String) -> String? {
        let configuration = UIImage.SymbolConfiguration(
            pointSize: 11,
            weight: .bold
        )

        guard
            let image = UIImage(
                systemName: symbolName,
                withConfiguration: configuration
            )?.withTintColor(.white, renderingMode: .alwaysOriginal),
            let data = image.pngData()
        else {
            return nil
        }

        return "data:image/png;base64,\(data.base64EncodedString())"
    }
}
