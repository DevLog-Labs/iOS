//
//  DuoTabBar.swift
//  Entry
//
//  Created by opfic on 11/25/26.
//

import SwiftUI
import PresentationShared

// Duo 세로 칸 경계선과 아래쪽 탭
// 위쪽 상태 표시와 툴바 버튼 자리는 시스템 세로 막대가 맡음
struct DuoTabBar: View {
    @Binding var selectedTab: AppTab
    let edge: HorizontalEdge
    let width: CGFloat
    let unreadPushCount: Int

    var body: some View {
        TabBar(
            selectedTab: $selectedTab,
            axis: .vertical,
            unreadPushCount: unreadPushCount
        )
        // 시스템 세로 막대 버튼처럼 화면 끝 쪽을 더 띄움
        .padding(edge == .trailing ? .trailing : .leading, 12)
        .frame(width: width)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .overlay(alignment: edge == .trailing ? .leading : .trailing) {
            Rectangle()
                .fill(Color.separator)
                .frame(width: 1)
                .ignoresSafeArea(edges: .vertical)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: edge == .trailing ? .trailing : .leading)
        .ignoresSafeArea(edges: .horizontal)
    }
}
