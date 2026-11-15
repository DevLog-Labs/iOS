//
//  PaneMenuButton.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI

// Mac 칸 제목 줄 오른쪽 끝에 두는 글자 없는 메뉴 버튼
public struct PaneMenuButton: View {
    private let systemImage: String
    private let badgeCount: Int
    private let sections: [DropdownMenuSection]

    public init(
        systemImage: String,
        badgeCount: Int = 0,
        sections: [DropdownMenuSection]
    ) {
        self.systemImage = systemImage
        self.badgeCount = badgeCount
        self.sections = sections
    }

    public var body: some View {
        DropdownMenu(sections: sections) {
            Image(systemName: systemImage)
                .topBarButtonStyle()
                // 걸린 필터 개수는 아이콘 오른쪽 위 강조색 배지로 표시
                .overlay(alignment: .topTrailing) {
                    if 0 < badgeCount {
                        Text(verbatim: badgeCount.formatted())
                            .font(.system(size: 9 * AdaptiveSize.boardScale, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 3 * AdaptiveSize.boardScale)
                            .frame(minWidth: 14 * AdaptiveSize.boardScale, minHeight: 14 * AdaptiveSize.boardScale)
                            .background(Color.accent, in: .capsule)
                            .fixedSize()
                            .padding([.top, .trailing], AdaptiveSize.boardScale)
                    }
                }
        }
    }
}
