//
//  SplitShell.swift
//  Entry
//
//  Created by opfic on 11/25/26.
//

import SwiftUI

// 왼쪽, 가운데, 오른쪽 자리와 창 전체를 덮는 자리만 있는 껍데기
// 자리마다 어떤 화면이 언제 나올지는 쓰는 쪽에서 결정
struct SplitShell<Left: View, Center: View, Right: View, Overlay: View>: View {
    private let left: Left
    private let center: Center
    private let right: Right
    private let overlay: Overlay

    init(
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.left = left()
        self.center = center()
        self.right = right()
        self.overlay = overlay()
    }

    var body: some View {
        HStack(spacing: 0) {
            left
            center
            right
        }
        .overlay { overlay }
    }
}
