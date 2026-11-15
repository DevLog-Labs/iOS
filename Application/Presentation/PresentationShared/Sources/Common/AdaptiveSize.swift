//
//  AdaptiveSize.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

// iPhone·Duo·iPad는 지금 크기 그대로, Mac은 Orca 데스크톱 크기로 보이는 글자와 화면 요소 크기
public enum AdaptiveSize {
    // 디자인 보드 크기에 곱해 앱 크기로 바꾸는 배율
    // Mac은 iPad 화면을 Mac 창에 맞출 때 시스템이 곱하는 77% 배율을 되돌리는 1 / 0.77
    // iPhone·Duo·iPad는 보드 크기 그대로 써서 1
    public static let boardScale: CGFloat = ProcessInfo.processInfo.isiOSAppOnMac ? 1 / 0.77 : 1

    // Mac 텍스트 스타일 글자 크기
    // 디자인 보드 글자 크기에 boardScale을 곱한 값
    // iPhone·Duo·iPad는 시스템 텍스트 스타일을 그대로 써서 nil
    public static func macFontSize(_ style: Font.TextStyle) -> CGFloat? {
        guard ProcessInfo.processInfo.isiOSAppOnMac else { return nil }
        let size: CGFloat
        switch style {
        case .largeTitle: size = 26
        case .title: size = 21
        case .title2: size = 16
        case .title3: size = 15
        case .headline, .body: size = 13
        case .callout: size = 12.5
        case .subheadline, .footnote: size = 11.5
        case .caption: size = 11
        case .caption2: size = 10.5
        @unknown default: return nil
        }
        return size * boardScale
    }
}

public extension Font {
    // 텍스트 스타일 글자
    // iPhone·Duo·iPad는 시스템 텍스트 스타일, Mac은 Orca 데스크톱 글자 크기
    static func adaptive(_ style: Font.TextStyle) -> Font {
        guard let size = AdaptiveSize.macFontSize(style) else { return .system(style) }
        return .system(size: size, weight: style == .headline ? .semibold : .regular)
    }
}
