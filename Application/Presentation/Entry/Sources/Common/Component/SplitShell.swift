//
//  SplitShell.swift
//  Entry
//
//  Created by opfic on 11/25/26.
//

import SwiftUI
import PresentationShared

// 가운데, 왼쪽, 오른쪽 자리와 창 전체를 덮는 자리만 있는 껍데기
// 자리마다 어떤 화면이 언제 나올지는 쓰는 쪽에서 결정
struct SplitShell<Center: View, Left: View, Right: View, Overlay: View>: View {
    // 가운데 화면이 올린 세부 정보 사이드바 내용, 오른쪽 자리에 그릴지는 쓰는 쪽에서 결정
    @State private var rightContent: DetailSideBarContent?
    private let center: Center
    private let left: Left
    private let right: (DetailSideBarContent?) -> Right
    private let overlay: Overlay

    init(
        @ViewBuilder center: () -> Center,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: @escaping (DetailSideBarContent?) -> Right,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.center = center()
        self.left = left()
        self.right = right
        self.overlay = overlay()
    }

    var body: some View {
        HStack(spacing: 0) {
            left
            center
                .onPreferenceChange(DetailSideBarContentPreferenceKey.self) { content in
                    rightContent = content
                }
            right(rightContent)
        }
        .overlay { overlay }
    }
}
