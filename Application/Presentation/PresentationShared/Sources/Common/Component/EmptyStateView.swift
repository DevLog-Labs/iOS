//
//  EmptyStateView.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

// 아이콘 원, 제목, 설명 아래에 다시 시도 같은 버튼을 두는 빈 화면
public struct EmptyStateView<Actions: View>: View {
    @ScaledMetric(relativeTo: .title2) private var iconSize = CGFloat(52)
    @ScaledMetric(relativeTo: .footnote) private var messageSize = CGFloat(13.5)
    @ScaledMetric(relativeTo: .footnote) private var messageWidth = CGFloat(280)
    private let title: String
    private let systemImage: String
    private let message: String?
    private let actions: Actions

    public init(
        _ title: String,
        systemImage: String,
        message: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.adaptive(.title2))
                .foregroundStyle(Color.secondaryLabel)
                .frame(width: iconSize, height: iconSize)
                .background(Color.tertiaryBackground, in: .circle)
                .padding(.bottom, 4)
            Text(title)
                .font(.adaptive(.headline).bold())
            if let message {
                Text(message)
                    .font(.system(size: messageSize))
                    .foregroundStyle(Color.secondaryLabel)
                    .frame(maxWidth: messageWidth)
            }
            if Actions.self != EmptyView.self {
                actions
                    .padding(.top, 12)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 72)
    }
}

public extension EmptyStateView where Actions == EmptyView {
    init(_ title: String, systemImage: String, message: String? = nil) {
        self.init(title, systemImage: systemImage, message: message) { EmptyView() }
    }
}
