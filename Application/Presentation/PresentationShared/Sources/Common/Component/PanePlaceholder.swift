//
//  PanePlaceholder.swift
//  PresentationShared
//
//  Created by opfic on 11/13/26.
//

import SwiftUI

// 상세 칸에서 고른 항목이 없을 때 표시하는 안내
public struct PanePlaceholder: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.adaptive(.largeTitle))
                .foregroundStyle(Color.tertiaryLabel)
            Text("pane_select_detail", bundle: PresentationResources.bundle)
                .font(.adaptive(.callout))
                .foregroundStyle(Color.secondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 목록 칸 제목 줄과 구분선 높이 맞춤
        .safeAreaInset(edge: .top, spacing: 0) {
            PaneTitleBar(Text(verbatim: ""))
        }
        .background(Color.background)
    }
}
