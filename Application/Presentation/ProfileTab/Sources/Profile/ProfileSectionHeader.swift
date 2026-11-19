//
//  ProfileSectionHeader.swift
//  ProfileTab
//
//  Created by opfic on 11/19/26.
//

import SwiftUI
import PresentationShared

// 프로필 섹션 제목과 오른쪽 버튼 줄
struct ProfileSectionHeader<Trailing: View>: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    private let title: Text
    private let trailing: Trailing

    init(_ title: Text, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 6) {
            title
            Spacer(minLength: 0)
            trailing
        }
        .font(.adaptive(isiOSAppOnMac ? .callout : .subheadline).weight(.bold))
        .foregroundStyle(Color.label)
        .padding(.top, isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 20)
        .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .padding(.bottom, isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 10)
    }
}
