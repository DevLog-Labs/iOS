//
//  NavigationBackButton.swift
//  PresentationShared
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import UIComposable

public struct NavigationBackButton: View {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    // 버튼이 놓인 화면을 쌓아 둔 내비게이션
    @State private var navigation = NavigationReference()
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        let back = {
            // 사이드바가 있는 창은 이전 화면이 밀려 들어오는 효과 없이 바로 돌아감
            // SwiftUI의 화면 닫기는 전환 효과를 끌 수 없어 쌓인 화면을 직접 뺌
            if usesDesktopLayout,
               let controller = navigation.controller,
               1 < controller.viewControllers.count {
                controller.popViewController(animated: false)
            } else {
                action()
            }
        }

        Group {
            if #available(iOS 26.0, *) {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                }
                .topBarButtonStyle()
            } else {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.adaptive(.title3).weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .adaptiveButtonStyle(shape: .circle, color: .secondaryBackground, glassEffect: .enabled)
            }
        }
        .background {
            NavigationReader.composable { reader in
                reader.reference = navigation
            }
        }
    }
}

private final class NavigationReference {
    weak var controller: UINavigationController?
}

private final class NavigationReader: UIViewController, UIComposable {
    var reference: NavigationReference? {
        didSet { reference?.controller = navigationController }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        reference?.controller = navigationController
    }
}
