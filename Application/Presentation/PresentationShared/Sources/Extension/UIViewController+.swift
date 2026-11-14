//
//  UIViewController+.swift
//  PresentationShared
//
//  Created by opfic on 7/25/26.
//

import UIKit

@MainActor
extension UIViewController {
    var visibleTabBarHeight: CGFloat {
        var topViewController = self

        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }

        if let tabBarController = (topViewController as? UITabBarController) ??
            topViewController.tabBarController {
            let tabBar = tabBarController.tabBar
            let frame = tabBar.convert(tabBar.bounds, to: nil)
            // 세로 레일이나 위쪽 탭 바는 제외하고 아래 가장자리에 가로로 놓인 탭 바만 포함
            guard !tabBar.isHidden,
                  frame.height < frame.width,
                  let window = tabBar.window,
                  window.bounds.midY < frame.midY else { return .zero }
            return tabBar.frame.height
        }

        for child in topViewController.children {
            let childHeight = child.visibleTabBarHeight
            if 0 < childHeight {
                return childHeight
            }
        }

        return .zero
    }
}
