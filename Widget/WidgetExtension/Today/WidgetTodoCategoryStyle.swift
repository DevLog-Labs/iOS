//
//  WidgetTodoCategoryStyle.swift
//  WidgetExtension
//
//  Created by opfic on 9/24/26.
//

import SwiftUI

struct WidgetTodoCategoryStyle {
    let symbolName: String
    let color: Color

    init(categoryID: String, colorHex: String?) {
        switch categoryID {
        case "issue":
            symbolName = "exclamationmark.triangle"
            color = .danger
        case "feature":
            symbolName = "sparkles"
            color = .categoryFeature
        case "improvement":
            symbolName = "arrow.triangle.2.circlepath"
            color = .categoryImprovement
        case "review":
            symbolName = "eye"
            color = .categoryReview
        case "test":
            symbolName = "checkmark.shield"
            color = .categoryTest
        case "doc":
            symbolName = "doc.text"
            color = .categoryDoc
        case "research":
            symbolName = "magnifyingglass"
            color = .categoryResearch
        case "etc":
            symbolName = "ellipsis"
            color = .categoryEtc
        default:
            if let colorHex {
                symbolName = "tray.fill"
                color = Self.color(from: colorHex) ?? .gray
            } else {
                symbolName = "questionmark"
                color = .gray
            }
        }
    }

    // 앱 UserTodoCategoryItem의 색상 원 팔레트와 같은 다크 색과 라이트 짝
    private static let palette = [
        (dark: "#F87171", light: "#DC2626"),
        (dark: "#FB923C", light: "#EA580C"),
        (dark: "#FACC15", light: "#CA8A04"),
        (dark: "#34D399", light: "#059669"),
        (dark: "#4FC3C9", light: "#147D83"),
        (dark: "#60A5FA", light: "#2563EB"),
        (dark: "#A78BFA", light: "#7C3AED"),
        (dark: "#E879F9", light: "#C026D3")
    ]

    // 색상 원의 색은 테마에 맞는 짝으로, 그 밖의 색은 저장한 색 그대로 표시
    private static func color(from hexString: String) -> Color? {
        guard let pair = palette.first(where: { $0.dark.caseInsensitiveCompare(hexString) == .orderedSame }),
              let dark = uiColor(from: pair.dark),
              let light = uiColor(from: pair.light) else {
            return uiColor(from: hexString).map { Color(uiColor: $0) }
        }

        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    private static func uiColor(from hexString: String) -> UIColor? {
        let trimmedHex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedHex = trimmedHex.hasPrefix("#") ? String(trimmedHex.dropFirst()) : trimmedHex
        guard sanitizedHex.count == 6,
              let hexValue = Int(sanitizedHex, radix: 16) else { return nil }

        return UIColor(
            red: CGFloat((hexValue >> 16) & 0xFF) / 255,
            green: CGFloat((hexValue >> 8) & 0xFF) / 255,
            blue: CGFloat(hexValue & 0xFF) / 255,
            alpha: 1
        )
    }
}
