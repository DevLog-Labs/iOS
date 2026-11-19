//
//  ToolbarButtons.swift
//  PresentationShared
//
//  Created by 최윤진 on 3/1/26.
//

import SwiftUI
import Domain

public struct ToolbarLeadingButton: ToolbarContent {
    var action: (() -> Void)?

    public init(action: (() -> Void)? = nil) {
        self.action = action
    }

    // iOS 버전과 상관없이 리퀴드 글래스 없이 아이콘만 표시
    public var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                action?()
            } label: {
                Image(systemName: "xmark")
            }
            .topBarButtonStyle()
        }
        .sharedBackgroundHidden()
    }
}

public struct ToolbarTrailingButton: ToolbarContent {
    var action: (() -> Void)?
    private var isDisabled: Bool = false

    public init(action: (() -> Void)? = nil) {
        self.action = action
    }

    public func disabled(_ isDisabled: Bool) -> ToolbarTrailingButton {
        var copy = self
        copy.isDisabled = isDisabled
        return copy
    }

    // iOS 버전과 상관없이 리퀴드 글래스 없이 아이콘만 표시
    public var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                action?()
            } label: {
                Image(systemName: "checkmark")
            }
            .topBarButtonStyle(tint: Color.accent)
            .disabled(isDisabled)
        }
        .sharedBackgroundHidden()
    }
}
