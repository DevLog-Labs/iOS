//
//  Tags.swift
//  PresentationShared
//
//  Created by 최윤진 on 2/6/26.
//

import SwiftUI

public struct Tag: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var height: CGFloat = 0
    private let name: String
    private let isEditing: Bool
    private let isCopyEnabled: Bool
    private var action: (() -> Void)?

    public init(
        _ name: String,
        isEditing: Bool,
        action: (() -> Void)? = nil
    ) {
        self.init(
            name,
            isEditing: isEditing,
            isCopyEnabled: false,
            action: action
        )
    }

    init(
        _ name: String,
        isEditing: Bool,
        isCopyEnabled: Bool,
        action: (() -> Void)?
    ) {
        self.name = name
        self.isEditing = isEditing
        self.isCopyEnabled = isCopyEnabled
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .foregroundStyle(Color.accent)
                .bold()
                .lineLimit(1)
                .padding(.vertical, 4)
                .padding(.leading, 8)
                .padding(.trailing, isEditing ? 0 : 8)
                .overlay {
                    if isCopyEnabled {
                        TagCopyMenuView(tagText: name)
                    }
                }
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                height = geo.size.height
                            }
                    }
                }

            if isEditing {
                Button {
                    action?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: height, height: height)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            Color.accent,
                            .black.opacity(colorScheme == .light ? 0 : 0.4)
                        )

                }
                .buttonStyle(.plain)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.badge)
                .fill(Color.accent.opacity(0.2))
        }
    }
}

public struct TagList: View {
    private let tags: [String]
    private let lineLimit: Int?
    private let showsOverflowIndicator: Bool
    private let isEditing: Bool
    private let action: ((String) -> Void)?
    private let verticalSpacing: CGFloat
    private let horizontalSpacing: CGFloat

    public init<C: Collection>(
        _ tags: C,
        lineLimit: Int? = nil,
        showsOverflowIndicator: Bool = true,
        isEditing: Bool = false,
        verticalSpacing: CGFloat = 8,
        horizontalSpacing: CGFloat = 8,
        action: ((String) -> Void)? = nil
    ) where C.Element == String {
        self.tags = Array(tags)
        self.lineLimit = lineLimit
        self.showsOverflowIndicator = showsOverflowIndicator
        self.isEditing = isEditing
        self.verticalSpacing = verticalSpacing
        self.horizontalSpacing = horizontalSpacing
        self.action = action
    }

    public var body: some View {
        Group {
            if let lineLimit {
                TagLayout(
                    lineLimit: lineLimit,
                    showsOverflowIndicator: showsOverflowIndicator,
                    verticalSpacing: verticalSpacing,
                    horizontalSpacing: horizontalSpacing
                ) {
                    contentTags
                    if showsOverflowIndicator {
                        Tag("...", isEditing: false)
                    }
                }
            } else {
                TagLayout(
                    showsOverflowIndicator: false,
                    verticalSpacing: verticalSpacing,
                    horizontalSpacing: horizontalSpacing
                ) {
                    contentTags
                }
            }
        }
    }

    @ViewBuilder
    private var contentTags: some View {
        ForEach(tags, id: \.self) { tagText in
            Tag(
                tagText,
                isEditing: isEditing,
                isCopyEnabled: true
            ) {
                action?(tagText)
            }
        }
    }
}

private struct TagLayout: Layout {
    struct Cache {
        var maxWidth: CGFloat = 0
        var rows: [Row] = []
    }

    var lineLimit: Int?
    var showsOverflowIndicator: Bool
    var verticalSpacing: CGFloat
    var horizontalSpacing: CGFloat

    init(
        showsOverflowIndicator: Bool = true,
        verticalSpacing: CGFloat = 8,
        horizontalSpacing: CGFloat = 8
    ) {
        self.showsOverflowIndicator = showsOverflowIndicator
        self.verticalSpacing = verticalSpacing
        self.horizontalSpacing = horizontalSpacing
    }

    init(
        lineLimit: Int,
        showsOverflowIndicator: Bool = true,
        verticalSpacing: CGFloat = 8,
        horizontalSpacing: CGFloat = 8
    ) {
        self.lineLimit = lineLimit
        self.showsOverflowIndicator = showsOverflowIndicator
        self.verticalSpacing = verticalSpacing
        self.horizontalSpacing = horizontalSpacing
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func updateCache(
        _ cache: inout Cache,
        subviews: Subviews,
        proposal: ProposedViewSize
    ) {
        let width = effectiveMaxWidth(
            proposalWidth: proposal.width,
            fallbackWidth: 0
        )
        if cache.maxWidth != width {
            cache.maxWidth = width
            cache.rows = computeRows(maxWidth: width, subviews: subviews)
        } else if cache.rows.isEmpty {
            cache.rows = computeRows(maxWidth: width, subviews: subviews)
        }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        updateCache(&cache, subviews: subviews, proposal: proposal)
        let rows = limitedRows(cache.rows, subviews: subviews, maxWidth: cache.maxWidth)
        let height = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * verticalSpacing
        let rowsWidth = rows.map { $0.width }.max() ?? 0
        let width = (proposal.width ?? 0) > 0 ? (proposal.width ?? 0) : rowsWidth
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let width = effectiveMaxWidth(
            proposalWidth: proposal.width,
            fallbackWidth: bounds.width
        )
        if cache.maxWidth != width {
            cache.maxWidth = width
            cache.rows = computeRows(maxWidth: width, subviews: subviews)
        }
        let rows = limitedRows(cache.rows, subviews: subviews, maxWidth: width)
        let allowedIndices = Set(rows.flatMap { $0.indices })
        var minY = bounds.minY

        for row in rows {
            var minX = bounds.minX

            for index in row.indices {
                let size = fittedSize(of: subviews[index], maxWidth: width)
                subviews[index].place(
                    at: CGPoint(x: minX, y: minY),
                    proposal: ProposedViewSize(size)
                )
                minX += size.width + horizontalSpacing
            }

            minY += row.maxHeight + verticalSpacing
        }

        let hiddenPosition = CGPoint(x: bounds.maxX + 10000, y: bounds.maxY + 10000)
        for index in subviews.indices where !allowedIndices.contains(index) {
            subviews[index].place(
                at: hiddenPosition,
                proposal: ProposedViewSize(width: 0, height: 0)
            )
        }
    }

    private func effectiveMaxWidth(
        proposalWidth: CGFloat?,
        fallbackWidth: CGFloat
    ) -> CGFloat {
        if let proposalWidth, proposalWidth > 0 {
            return proposalWidth
        }
        if fallbackWidth > 0 {
            return fallbackWidth
        }
        return .infinity
    }

    private func computeRows(
        maxWidth: CGFloat,
        subviews: Subviews
    ) -> [Row] {
        let availableWidth = maxWidth > 0 ? maxWidth : .infinity
        var rows: [Row] = []
        var currentRow = Row()
        var currentWidth: CGFloat = 0
        let overflowIndex = subviews.count - 1
        let usesOverflowIndicator = usesOverflowIndicator
        let contentIndices = subviews.indices.filter { !usesOverflowIndicator || $0 != overflowIndex }

        for index in contentIndices {
            let subview = subviews[index]
            let size = fittedSize(of: subview, maxWidth: availableWidth)

            if currentWidth + size.width > availableWidth && !currentRow.indices.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                currentWidth = 0
            }

            currentRow.indices.append(index)
            currentRow.maxHeight = max(currentRow.maxHeight, size.height)
            currentWidth += size.width + horizontalSpacing
            currentRow.width = max(currentRow.width, currentWidth - horizontalSpacing)
        }

        if !currentRow.indices.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private func limitedRows(
        _ rows: [Row],
        subviews: Subviews,
        maxWidth: CGFloat
    ) -> [Row] {
        guard let lineLimit, 0 < lineLimit else {
            return rows
        }
        let limited = Array(rows.prefix(lineLimit))

        guard usesOverflowIndicator,
              lineLimit < rows.count,
              !subviews.isEmpty else {
            return limited
        }

        let overflowIndex = subviews.count - 1
        let overflowSize = fittedSize(of: subviews[overflowIndex], maxWidth: maxWidth)
        guard !limited.isEmpty else {
            return [Row(indices: [overflowIndex], maxHeight: overflowSize.height, width: overflowSize.width)]
        }

        var adjustedRows = limited
        var lastRow = adjustedRows.removeLast()
        var candidateIndices = lastRow.indices

        while !candidateIndices.isEmpty {
            let rowIndices = candidateIndices + [overflowIndex]
            let rowWidth = width(for: rowIndices, subviews: subviews, maxWidth: maxWidth)
            if rowWidth <= maxWidth {
                lastRow.indices = rowIndices
                lastRow.maxHeight = max(lastRow.maxHeight, overflowSize.height)
                lastRow.width = rowWidth
                adjustedRows.append(lastRow)
                return adjustedRows
            }
            candidateIndices.removeLast()
        }

        adjustedRows.append(
            Row(indices: [overflowIndex], maxHeight: overflowSize.height, width: overflowSize.width)
        )
        return adjustedRows
    }

    private func width(
        for indices: [Int],
        subviews: Subviews,
        maxWidth: CGFloat
    ) -> CGFloat {
        guard !indices.isEmpty else { return 0 }
        let widths = indices.reduce(CGFloat.zero) { partialResult, index in
            partialResult + fittedSize(of: subviews[index], maxWidth: maxWidth).width
        }
        return widths + CGFloat(max(0, indices.count - 1)) * horizontalSpacing
    }

    private func fittedSize(
        of subview: LayoutSubview,
        maxWidth: CGFloat
    ) -> CGSize {
        subview.sizeThatFits(
            ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil)
        )
    }

    private var usesOverflowIndicator: Bool {
        showsOverflowIndicator && (lineLimit ?? 0) > 0
    }

    struct Row {
        var indices: [Int] = []
        var maxHeight: CGFloat = 0
        var width: CGFloat = 0
    }
}
