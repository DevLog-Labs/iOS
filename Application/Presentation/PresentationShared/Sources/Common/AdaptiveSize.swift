//
//  AdaptiveSize.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

// iPhone·Duo·iPad는 지금 크기 그대로, Mac은 Orca 데스크톱 크기로 보이는 글자와 화면 요소 크기
public enum AdaptiveSize {
    // Mac이 iPad 화면을 Mac 창에 맞출 때 화면 전체에 곱하는 77% 배율
    // Mac 디자인 보드 크기를 이 배율로 나눠 화면에서 보드 크기로 표시
    private static let macScale: CGFloat = 0.77

    // Mac 텍스트 스타일 글자 크기
    // 디자인 보드 글자 크기를 macScale로 나눈 값
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
        return size / macScale
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
