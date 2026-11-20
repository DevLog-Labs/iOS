//
//  UserTodoCategoryItem.swift
//  PresentationShared
//
//  Created by opfic on 3/30/26.
//

import SwiftUI
import Domain

public struct UserTodoCategoryItem: Identifiable, Hashable {
    public let userTodoCategory: UserTodoCategory

    public init(from userTodoCategory: UserTodoCategory) {
        self.userTodoCategory = userTodoCategory
    }

    public var id: String { userTodoCategory.id }

    public var symbolName: String { "tray.fill" }

    public var localizedName: String { userTodoCategory.name }

    public var color: Color { Self.color(colorHex: userTodoCategory.colorHex) }

    // 카테고리 색상 원으로 고를 수 있는 다크 색
    public static let paletteHexValues = palette.map(\.dark)

    // 색상 원의 다크 색과 짝이 되는 라이트 색
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
    public static func color(colorHex: String) -> Color {
        guard let pair = palette.first(where: { $0.dark.caseInsensitiveCompare(colorHex) == .orderedSame }),
              let dark = Color(hexString: pair.dark),
              let light = Color(hexString: pair.light) else {
            return Color(hexString: colorHex) ?? .gray
        }

        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}
