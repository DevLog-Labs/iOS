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
