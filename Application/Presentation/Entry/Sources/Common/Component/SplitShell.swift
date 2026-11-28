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
    // 왼쪽 자리를 켜 둔 상태, 켜고 끄는 바인딩으로 가운데와 왼쪽 클로저에 넘김
    @State private var isLeftOn = true
    // 오른쪽 자리를 켜 둔 상태, 켜고 끄는 바인딩으로 가운데와 오른쪽 클로저에 넘김
    @State private var isRightOn = false
    // 가운데 화면이 올린 세부 정보 사이드바 내용, 오른쪽 자리에 그릴지는 쓰는 쪽에서 결정
    @State private var rightContent: DetailSideBarContent?
    // 이 폭보다 좁아지면 왼쪽 자리를 끄고 넓어지면 켬, 없으면 창 폭으로 바꾸지 않음
    private let leftFitWidth: CGFloat?
    private let center: (_ isLeftOn: Binding<Bool>, _ isRightOn: Binding<Bool>) -> Center
    private let left: (Binding<Bool>) -> Left
    private let right: (DetailSideBarContent?, Binding<Bool>) -> Right
    private let overlay: Overlay

    init(
        leftFitWidth: CGFloat? = nil,
        @ViewBuilder center: @escaping (_ isLeftOn: Binding<Bool>, _ isRightOn: Binding<Bool>) -> Center,
        @ViewBuilder left: @escaping (Binding<Bool>) -> Left,
        @ViewBuilder right: @escaping (DetailSideBarContent?, Binding<Bool>) -> Right,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.leftFitWidth = leftFitWidth
        self.center = center
        self.left = left
        self.right = right
        self.overlay = overlay()
    }

    var body: some View {
        HStack(spacing: 0) {
            left($isLeftOn)
            center($isLeftOn, $isRightOn)
                .onPreferenceChange(DetailSideBarContentPreferenceKey.self) { content in
                    rightContent = content
                }
            right(rightContent, $isRightOn)
        }
        .overlay { overlay }
        .onGeometryChange(for: Bool?.self) { proxy in
            leftFitWidth.map { $0 <= proxy.size.width }
        } action: { fits in
            if let fits {
                isLeftOn = fits
            }
        }
    }
}
