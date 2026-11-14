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

    private static func color(from hexString: String?) -> Color? {
        guard let hexString else { return nil }
        let trimmedHex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedHex = trimmedHex.hasPrefix("#") ? String(trimmedHex.dropFirst()) : trimmedHex
        guard sanitizedHex.count == 6,
              let hexValue = Int(sanitizedHex, radix: 16) else { return nil }

        return Color(
            red: Double((hexValue >> 16) & 0xFF) / 255,
            green: Double((hexValue >> 8) & 0xFF) / 255,
            blue: Double(hexValue & 0xFF) / 255
        )
    }
}
