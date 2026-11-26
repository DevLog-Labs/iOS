//
//  TreeSideBar.swift
//  Entry
//
//  Created by opfic on 11/25/26.
//

import SwiftUI
import PresentationShared

// Mac과 넓은 iPad 창에서 Finder처럼 위치를 고르는 트리 사이드바
struct TreeSideBar: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.paneWidth) private var paneWidth
    @Binding var selectedTab: AppTab
    let store: StoreOf<CompositionFeature>

    var body: some View {
        let location = store.sideBarLocations[selectedTab] ?? selectedTab.sideBarLocation
        let expandedGroups = store.expandedSideBarGroups
        let isCompact = (paneWidth ?? .infinity) < SideBarRow.compactWidth
        let collapseButton = Button {
            store.send(.binding(.set(\.isSideBarCollapsed, true)))
        } label: {
            Image(systemName: "sidebar.left")
        }
        .topBarButtonStyle()

        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 칸 제목 줄과 같은 높이의 사이드바 접기 줄
                PaneTitleBar(background: .secondaryBackground) {
                    EmptyView()
                } actions: {
                    if !isCompact {
                        collapseButton
                    }
                }
                // 아이콘만 보일 때는 아래 줄 아이콘과 같은 세로선에 배치
                .overlay(alignment: .leading) {
                    if isCompact {
                        collapseButton
                            .frame(width: isiOSAppOnMac ? 18 * AdaptiveSize.boardScale : 20)
                            .padding(.leading, isiOSAppOnMac ? (8 + 4 + 14 + 6) * AdaptiveSize.boardScale : 8 + 6 + 16 + 8)
                    }
                }
                ScrollView {
                    VStack(spacing: isiOSAppOnMac ? AdaptiveSize.boardScale : 2) {
                        ForEach([AppTab.home, .today, .notification], id: \.self) { tab in
                            SideBarRow(
                                title: Text(tab.title),
                                symbolName: tab.symbolName,
                                isSelected: location == tab.sideBarLocation,
                                badgeCount: tab == .notification ? store.unreadPushCount : 0
                            ) {
                                open(tab.sideBarLocation)
                            }
                        }
                        SideBarRow(
                            title: Text("development_goal_title", bundle: PresentationResources.bundle),
                            symbolName: "flag.checkered",
                            isExpanded: expandedGroups.contains(.developmentGoal)
                        ) {
                            store.send(.view(.tapSideBarGroup(.developmentGoal)), animation: .easeInOut(duration: 0.2))
                        }
                        if expandedGroups.contains(.developmentGoal) {
                            ForEach(store.sideBarContent.developmentGoals) { goal in
                                SideBarRow(
                                    title: Text(goal.title),
                                    symbolName: "flag",
                                    isChild: true,
                                    isSelected: location == .developmentGoal(goal.id)
                                ) {
                                    open(.developmentGoal(goal.id))
                                }
                            }
                        }
                        SideBarRow(
                            title: Text(verbatim: "Todo"),
                            symbolName: "tray.fill",
                            isSelected: location == .todoCategoryManagement,
                            isExpanded: expandedGroups.contains(.todo)
                        ) {
                            store.send(.view(.tapSideBarGroup(.todo)), animation: .easeInOut(duration: 0.2))
                        }
                        .contextMenu {
                            Button {
                                request(.createTodo)
                            } label: {
                                Label {
                                    Text("sidebar_new_todo", bundle: PresentationResources.bundle)
                                } icon: {
                                    Image(systemName: "square.and.pencil")
                                }
                            }
                            Button {
                                request(.manageTodoCategory)
                            } label: {
                                Label {
                                    Text("todo_category_manage", bundle: PresentationResources.bundle)
                                } icon: {
                                    Image(systemName: "square.grid.2x2")
                                }
                            }
                        }
                        if expandedGroups.contains(.todo) {
                            ForEach(store.sideBarContent.todoCategories) { item in
                                SideBarRow(
                                    title: Text(item.localizedName),
                                    symbolName: item.symbolName,
                                    symbolColor: item.color,
                                    isChild: true,
                                    isSelected: location == .todoCategory(item.id)
                                ) {
                                    open(.todoCategory(item.id))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8 * AdaptiveSize.boardScale)
                    .padding(.vertical, 10 * AdaptiveSize.boardScale)
                }
                VStack(spacing: isiOSAppOnMac ? AdaptiveSize.boardScale : 2) {
                    SideBarRow(
                        title: Text(AppTab.profile.title),
                        symbolName: AppTab.profile.symbolName,
                        isSelected: location == .profile
                    ) {
                        open(.profile)
                    }
                    SideBarRow(
                        title: Text("nav_settings", bundle: PresentationResources.bundle),
                        symbolName: "gearshape.fill",
                        isSelected: location == .settings
                    ) {
                        // 앱 화면과 분리한 설정 화면 표시
                        store.send(.binding(.set(\.isSettingsPresented, true)))
                    }
                }
                .padding(.horizontal, 8 * AdaptiveSize.boardScale)
                .padding(.vertical, 10 * AdaptiveSize.boardScale)
            }
            .padding(.top, geometry.windowControlsInset)
        }
        // 칸이 기본 폭보다 좁아도 잘라 내지 않고 지금 폭에 맞춰 배치
        .frame(width: paneWidth)
    }

    private func open(_ location: SideBarLocation) {
        selectedTab = location.tab
        store.send(.view(.tapSideBarItem(location.tab, .open(location))))
    }

    // Todo 우클릭 메뉴의 작성과 카테고리 관리는 홈 화면에서 표시
    private func request(_ action: SideBarRequest.Action) {
        selectedTab = .home
        store.send(.view(.tapSideBarItem(.home, action)))
    }
}

// Mac과 iPad가 같은 모양으로 쓰는 트리 사이드바 항목
// Mac은 Mac 화면 크기, iPad는 손가락으로 누르는 크기
private struct SideBarRow: View {
    // 이름이 들어갈 자리가 없어 아이콘만 표시하는 폭
    static let compactWidth = ProcessInfo.processInfo.isiOSAppOnMac ? 104 * AdaptiveSize.boardScale : 120

    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.paneWidth) private var paneWidth
    let title: Text
    let symbolName: String
    var symbolColor: Color?
    var isChild = false
    var isSelected = false
    // 묶음 이름 줄만 펼침 여부가 있음
    var isExpanded: Bool?
    var badgeCount = 0
    let action: () -> Void

    var body: some View {
        let isCompact = (paneWidth ?? .infinity) < Self.compactWidth

        Button(action: action) {
            HStack(spacing: isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 8) {
                Image(systemName: "chevron.right")
                    .font(.adaptive(.caption2).weight(.bold))
                    .foregroundStyle(Color.secondaryLabel)
                    .rotationEffect(.degrees(isExpanded == true ? 90 : 0))
                    .opacity(isExpanded == nil ? 0 : 1)
                    .frame(width: isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                Image(systemName: symbolName)
                    .font(.adaptive(.body))
                    .foregroundStyle(symbolColor ?? .secondaryLabel)
                    .frame(width: isiOSAppOnMac ? 18 * AdaptiveSize.boardScale : 20)
                    // 아이콘만 보일 때 읽지 않은 알림은 아이콘 오른쪽 위 점으로 표시
                    .overlay(alignment: .topTrailing) {
                        if isCompact && 0 < badgeCount {
                            Circle()
                                .fill(Color.accent)
                                .frame(width: 7 * AdaptiveSize.boardScale, height: 7 * AdaptiveSize.boardScale)
                                .offset(x: 3 * AdaptiveSize.boardScale, y: -2 * AdaptiveSize.boardScale)
                        }
                    }
                title
                    .font(.adaptive(isiOSAppOnMac ? .body : .subheadline).weight(isChild ? .medium : .semibold))
                    .lineLimit(1)
                    // 아이콘만 보일 때도 이름 줄 높이는 유지
                    .frame(maxWidth: isCompact ? 0 : nil)
                    .opacity(isCompact ? 0 : 1)
                // 읽지 않은 개수는 이름 바로 오른쪽에 표시
                if !isCompact && 0 < badgeCount {
                    Text(verbatim: badgeCount.formatted())
                        .font(.adaptive(.caption2))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 4 * AdaptiveSize.boardScale)
                        .frame(minWidth: 18 * AdaptiveSize.boardScale, minHeight: 18 * AdaptiveSize.boardScale)
                        .background(Color.accent, in: .capsule)
                        .fixedSize()
                }
            }
            .foregroundStyle(Color.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, isiOSAppOnMac ? (isChild && !isCompact ? 22 : 4) * AdaptiveSize.boardScale : (isChild && !isCompact ? 34 : 6))
            .padding(.trailing, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 10)
            .frame(minHeight: isiOSAppOnMac ? 28 * AdaptiveSize.boardScale : 44)
            .hoverHighlight(in: RoundedRectangle(cornerRadius: CornerRadius.control), isEnabled: !isSelected)
            // 선택 표시는 마우스 표시와 같은 회색
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.control)
                    .fill(isSelected ? Color.fill : .clear)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
