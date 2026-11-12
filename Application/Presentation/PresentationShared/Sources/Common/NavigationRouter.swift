//
//  NavigationRouter.swift
//  PresentationShared
//
//  Created by 최윤진 on 1/1/26.
//

import SwiftUI

@Observable
public final class NavigationRouter<Route: Hashable> {
    public var path: [Route] = [] {
        didSet { recordForwardPath(from: oldValue) }
    }
    // 뒤로 간 경로, 마지막 요소가 다음 앞으로 이동 대상
    private var forwardPath: [Route] = []

    public var root: Route? {
        path.first
    }

    public var detailPath: [Route] {
        get {
            Array(path.dropFirst())
        }
        set {
            if let route = root {
                path = [route] + newValue
            } else {
                path = newValue
            }
        }
    }

    public var history: NavigationHistoryState {
        NavigationHistoryState(canGoBack: !path.isEmpty, canGoForward: !forwardPath.isEmpty)
    }

    public init() {}

    public func replace(with route: Route) {
        path = [route]
    }

    public func push(_ route: Route) {
        path.append(route)
    }

    public func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func goForward() {
        guard let route = forwardPath.last else { return }
        path.append(route)
    }

    private func recordForwardPath(from oldPath: [Route]) {
        if path.count < oldPath.count, Array(oldPath.prefix(path.count)) == path {
            forwardPath.append(contentsOf: oldPath.dropFirst(path.count).reversed())
        } else if oldPath.count < path.count, Array(path.prefix(oldPath.count)) == oldPath {
            for route in path.dropFirst(oldPath.count) {
                if forwardPath.last == route {
                    forwardPath.removeLast()
                } else {
                    forwardPath.removeAll()
                }
            }
        } else if path != oldPath {
            forwardPath.removeAll()
        }
    }
}

public struct NavigationHistoryState: Equatable {
    public var canGoBack = false
    public var canGoForward = false

    public init(canGoBack: Bool = false, canGoForward: Bool = false) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }
}

public struct NavigationStep: Equatable {
    public enum Direction: Equatable {
        case back
        case forward
    }

    public let id: UUID
    public let direction: Direction

    public init(id: UUID, direction: Direction) {
        self.id = id
        self.direction = direction
    }
}

public struct NavigationHistoryPreferenceKey: PreferenceKey {
    public static let defaultValue = NavigationHistoryState()

    public static func reduce(value: inout NavigationHistoryState, nextValue: () -> NavigationHistoryState) {
        let next = nextValue()
        value = NavigationHistoryState(
            canGoBack: value.canGoBack || next.canGoBack,
            canGoForward: value.canGoForward || next.canGoForward
        )
    }
}

public extension View {
    // 탭 경로의 뒤로/앞으로 상태 보고와 사이드바 명령 반영
    func navigationHistory<Route: Hashable>(_ router: NavigationRouter<Route>) -> some View {
        modifier(NavigationHistoryModifier(router: router))
    }
}

private struct NavigationHistoryModifier<Route: Hashable>: ViewModifier {
    @Environment(\.navigationStep) private var step
    let router: NavigationRouter<Route>

    func body(content: Content) -> some View {
        content
            .preference(key: NavigationHistoryPreferenceKey.self, value: router.history)
            .onChange(of: step) { _, step in
                switch step?.direction {
                case .back:
                    router.goBack()
                case .forward:
                    router.goForward()
                case nil:
                    break
                }
            }
    }
}
