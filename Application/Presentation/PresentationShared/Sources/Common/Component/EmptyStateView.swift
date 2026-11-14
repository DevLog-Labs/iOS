//
//  EmptyStateView.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

public struct EmptyStateView: View {
    @ScaledMetric(relativeTo: .title2) private var iconSize = CGFloat(52)
    @ScaledMetric(relativeTo: .footnote) private var messageSize = CGFloat(13.5)
    @ScaledMetric(relativeTo: .footnote) private var messageWidth = CGFloat(280)
    private let title: String
    private let systemImage: String
    private let message: String?

    public init(_ title: String, systemImage: String, message: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.secondaryLabel)
                .frame(width: iconSize, height: iconSize)
                .background(Color.tertiaryBackground, in: .circle)
                .padding(.bottom, 4)
            Text(title)
                .font(.headline.bold())
            if let message {
                Text(message)
                    .font(.system(size: messageSize))
                    .foregroundStyle(Color.secondaryLabel)
                    .frame(maxWidth: messageWidth)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 72)
    }
}
