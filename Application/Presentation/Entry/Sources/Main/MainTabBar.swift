//
//  MainTabBar.swift
//  Entry
//
//  Created by opfic on 11/14/26.
//

import SwiftUI
import PresentationShared

// OS와 기기에 상관없이 같은 모양으로 직접 그리는 탭
// 가로는 화면 아래 탭 바, 세로는 Duo 세로 칸 아래쪽 탭
struct MainTabBar: View {
    @Binding var selectedTab: MainTab
    let axis: Axis
    let unreadPushCount: Int

    var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 0)) : AnyLayout(VStackLayout(spacing: 22))

        layout {
            ForEach(MainTab.allCases, id: \.self) { tab in
                MainTabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    badgeCount: tab == .notification ? unreadPushCount : 0,
                    isFlexible: axis == .horizontal
                ) {
                    selectedTab = tab
                }
            }
        }
    }
}

private struct MainTabBarItem: View {
    let tab: MainTab
    let isSelected: Bool
    let badgeCount: Int
    let isFlexible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 19))
                    .frame(width: 22, height: 22)
                    .overlay(alignment: .topLeading) {
                        if 0 < badgeCount {
                            Text(verbatim: badgeCount.formatted())
                                .font(.system(size: 10, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 4)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.accent, in: .capsule)
                                .fixedSize()
                                .offset(x: 14, y: -4)
                        }
                    }
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.label : .secondaryLabel)
            .frame(maxWidth: isFlexible ? .infinity : nil)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
