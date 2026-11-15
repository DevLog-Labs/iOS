//
//  NavigationRouter.swift
//  PresentationShared
//
//  Created by 최윤진 on 1/1/26.
//

import SwiftUI

@Observable
public final class NavigationRouter<Route: Hashable> {
    public var path: [Route] = []

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

    public init() {}

    public func replace(with route: Route) {
        path = [route]
    }

    public func push(_ route: Route) {
        path.append(route)
    }
}
