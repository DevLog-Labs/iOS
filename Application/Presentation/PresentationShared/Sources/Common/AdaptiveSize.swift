//
//  AdaptiveSize.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

// iPhone·Duo·iPad는 지금 크기 그대로, Mac은 Orca 데스크톱 크기로 줄인 글자와 화면 요소 크기
public enum AdaptiveSize {
    // 여백, 간격, 아이콘, 행 높이에 곱하는 배율
    // Mac은 Mac Catalyst가 iPad 화면을 Mac 창에 맞출 때 쓰는 77% 배율
    public static let scale: CGFloat = ProcessInfo.processInfo.isiOSAppOnMac ? 0.77 : 1

    // Mac 텍스트 스타일 글자 크기
    // iPhone·Duo·iPad는 시스템 텍스트 스타일을 그대로 써서 nil
    public static func macFontSize(_ style: Font.TextStyle) -> CGFloat? {
        guard ProcessInfo.processInfo.isiOSAppOnMac else { return nil }
        switch style {
        case .largeTitle: return 26
        case .title: return 21
        case .title2: return 16
        case .title3: return 15
        case .headline, .body: return 13
        case .callout: return 12.5
        case .subheadline, .footnote: return 11.5
        case .caption: return 11
        case .caption2: return 10.5
        @unknown default: return nil
        }
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
