//
//  PaneMenuButton.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI

// 칸 제목 줄 오른쪽 끝에 두는 글자 없는 메뉴 버튼
public struct PaneMenuButton: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
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
        // 제목 줄 오른쪽 끝 버튼이라 메뉴 오른쪽 끝을 버튼 오른쪽 끝에 맞춤
        DropdownMenu(alignment: .trailing, sections: sections) {
            Image(systemName: systemImage)
                .topBarButtonStyle()
                // 걸린 필터 개수는 아이콘 오른쪽 위 흑백 배지로 표시
                .overlay(alignment: .topTrailing) {
                    if 0 < badgeCount {
                        Text(verbatim: badgeCount.formatted())
                            .font(.system(size: isiOSAppOnMac ? 9 * AdaptiveSize.boardScale : 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.background)
                            .padding(.horizontal, isiOSAppOnMac ? 3 * AdaptiveSize.boardScale : 4)
                            .frame(
                                minWidth: isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16,
                                minHeight: isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16
                            )
                            .background(Color.label, in: .capsule)
                            .fixedSize()
                            .padding([.top, .trailing], isiOSAppOnMac ? AdaptiveSize.boardScale : 2)
                    }
                }
        }
    }
}
