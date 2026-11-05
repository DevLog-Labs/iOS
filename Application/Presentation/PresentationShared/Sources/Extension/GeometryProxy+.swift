//
//  GeometryProxy+.swift
//  PresentationShared
//
//  Created by opfic on 11/4/26.
//

import SwiftUI

public extension GeometryProxy {
    var windowControlsInset: CGFloat {
        guard #available(iOS 26.0, *),
              UIDevice.current.userInterfaceIdiom == .pad else { return 0 }
        return containerCornerInsets.topLeading.height
    }
}
