//
//  EnvironmentValues+.swift
//  PresentationShared
//
//  Created by 최윤진 on 2/6/26.
//

import SwiftUI

public extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }

    var sceneWidth: CGFloat {
        self[SceneWidthKey.self]
    }

    var sceneHeight: CGFloat {
        self[SceneHeightKey.self]
    }

    var isiOSAppOnMac: Bool {
        self[IOSAppOnMacKey.self]
    }

    var windowControlsInset: CGFloat {
        get { self[WindowControlsInsetKey.self] }
        set { self[WindowControlsInsetKey.self] = newValue }
    }

    var readableContentWidth: CGFloat {
        get { self[ReadableContentWidthKey.self] }
        set { self[ReadableContentWidthKey.self] = newValue }
    }

    var sideBarRequest: SideBarRequest? {
        get { self[SideBarRequestKey.self] }
        set { self[SideBarRequestKey.self] = newValue }
    }

    // 접은 사이드바를 다시 펴는 동작, 사이드바를 접었을 때만 있음
    var expandSideBar: (() -> Void)? {
        get { self[ExpandSideBarKey.self] }
        set { self[ExpandSideBarKey.self] = newValue }
    }

    // 고른 대상과 고른 화면을 세부 정보 사이드바에 알리는 동작, 메인 창 탭 화면 안에서만 있음
    var selectDetailSideBarTarget: ((DetailSideBarTarget?, UUID) -> Void)? {
        get { self[SelectDetailSideBarTargetKey.self] }
        set { self[SelectDetailSideBarTargetKey.self] = newValue }
    }

    // 화면이 사라질 때 세부 정보 사이드바에서 그 화면을 빼는 동작, 메인 창 탭 화면 안에서만 있음
    var removeDetailSideBarTarget: ((UUID) -> Void)? {
        get { self[RemoveDetailSideBarTargetKey.self] }
        set { self[RemoveDetailSideBarTargetKey.self] = newValue }
    }

    // 세부 정보 사이드바가 열려 있는지 여부
    var isDetailSideBarPresented: Bool {
        get { self[IsDetailSideBarPresentedKey.self] }
        set { self[IsDetailSideBarPresentedKey.self] = newValue }
    }

    // 세부 정보 사이드바를 열고 닫는 동작, 세부 정보 사이드바가 있는 창 안에서만 있음
    var setDetailSideBarPresented: ((Bool) -> Void)? {
        get { self[SetDetailSideBarPresentedKey.self] }
        set { self[SetDetailSideBarPresentedKey.self] = newValue }
    }

    // 닫힌 세부 정보 사이드바를 칸 제목 줄 버튼으로 여는 동작, 창 오른쪽 끝 칸에서 사이드바를 닫았을 때만 있음
    var showDetailSideBar: (() -> Void)? {
        get { self[ShowDetailSideBarKey.self] }
        set { self[ShowDetailSideBarKey.self] = newValue }
    }

    // 폭을 바꿀 수 있는 칸의 지금 폭, 그런 칸 안에서만 있음
    var paneWidth: CGFloat? {
        get { self[PaneWidthKey.self] }
        set { self[PaneWidthKey.self] = newValue }
    }

    var showsPaneTitleBar: Bool {
        get { self[ShowsPaneTitleBarKey.self] }
        set { self[ShowsPaneTitleBarKey.self] = newValue }
    }

    // 사이드바 옆에 화면을 두는 Mac 화면 구조, Mac과 사이드바를 표시하는 iPad에서 사용
    var usesDesktopLayout: Bool {
        get { self[UsesDesktopLayoutKey.self] }
        set { self[UsesDesktopLayoutKey.self] = newValue }
    }

    // 목록 | 상세 두 칸으로 나눠 표시하는지 여부, 사이드바가 있는 창에서 사용
    var usesPaneLayout: Bool {
        get { self[UsesPaneLayoutKey.self] }
        set { self[UsesPaneLayoutKey.self] = newValue }
    }

    var deviceType: DeviceType {
        get { self[DeviceTypeKey.self] }
        set { self[DeviceTypeKey.self] = newValue }
    }

    private struct SafeAreaInsetsKey: EnvironmentKey {
        static var defaultValue: EdgeInsets {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                return EdgeInsets()
            }
            return window.safeAreaInsets.insets
        }
    }

    private struct SceneWidthKey: EnvironmentKey {
        static var defaultValue: CGFloat {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return UIScreen.main.bounds.width
            }
            return windowScene.screen.bounds.width
        }
    }

    private struct SceneHeightKey: EnvironmentKey {
        static var defaultValue: CGFloat {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return UIScreen.main.bounds.height
            }
            return windowScene.screen.bounds.height
        }
    }

    private struct WindowControlsInsetKey: EnvironmentKey {
        static let defaultValue = CGFloat.zero
    }

    private struct ReadableContentWidthKey: EnvironmentKey {
        static let defaultValue = CGFloat.infinity
    }

    private struct SideBarRequestKey: EnvironmentKey {
        static let defaultValue: SideBarRequest? = nil
    }

    private struct ExpandSideBarKey: EnvironmentKey {
        static let defaultValue: (() -> Void)? = nil
    }

    private struct SelectDetailSideBarTargetKey: EnvironmentKey {
        static let defaultValue: ((DetailSideBarTarget?, UUID) -> Void)? = nil
    }

    private struct RemoveDetailSideBarTargetKey: EnvironmentKey {
        static let defaultValue: ((UUID) -> Void)? = nil
    }

    private struct IsDetailSideBarPresentedKey: EnvironmentKey {
        static let defaultValue = false
    }

    private struct SetDetailSideBarPresentedKey: EnvironmentKey {
        static let defaultValue: ((Bool) -> Void)? = nil
    }

    private struct ShowDetailSideBarKey: EnvironmentKey {
        static let defaultValue: (() -> Void)? = nil
    }

    private struct PaneWidthKey: EnvironmentKey {
        static let defaultValue: CGFloat? = nil
    }

    private struct ShowsPaneTitleBarKey: EnvironmentKey {
        static let defaultValue = false
    }

    private struct UsesDesktopLayoutKey: EnvironmentKey {
        static var defaultValue: Bool {
            ProcessInfo.processInfo.isiOSAppOnMac
        }
    }

    private struct UsesPaneLayoutKey: EnvironmentKey {
        static var defaultValue: Bool {
            ProcessInfo.processInfo.isiOSAppOnMac
        }
    }

    private struct DeviceTypeKey: EnvironmentKey {
        // 접힘 전환 중 값이 잠시 바뀌므로 첫 판별 결과로 고정
        static let defaultValue: DeviceType = {
            if ProcessInfo.processInfo.isiOSAppOnMac { return .mac }
            if UIDevice.current.userInterfaceIdiom == .pad { return .ipad }
            guard #available(iOS 27.1, *),
                  let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return .bar
            }
            let traits = windowScene.traitCollection
            return traits.verticalBarEdge != .unspecified
                || traits.horizontalSizeClass == .regular
                ? .duo : .bar
        }()
    }

    private struct IOSAppOnMacKey: EnvironmentKey {
        static var defaultValue: Bool {
            ProcessInfo.processInfo.isiOSAppOnMac
        }
    }
}

extension UIEdgeInsets {
    var insets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}
