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
