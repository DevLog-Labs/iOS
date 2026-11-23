//
//  View+OutlineButtonBackground.swift
//  PresentationShared
//
//  Created by opfic on 11/23/26.
//

import SwiftUI

public extension View {
    // 채우지 않은 버튼의 테두리 버튼 모양
    // Orca outline 버튼처럼 옅은 바탕, 테두리와 옅은 그림자
    func outlineButtonBackground() -> some View {
        background {
            RoundedRectangle(cornerRadius: CornerRadius.control)
                .fill(Color.outlineButtonFill)
                .strokeBorder(Color.inputBorder)
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        }
    }
}
