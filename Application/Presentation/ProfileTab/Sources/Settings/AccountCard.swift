//
//  AccountCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct AccountCard: View {
    let isNetworkConnected: Bool
    let onAccount: () -> Void

    var body: some View {
        DesktopSettingsSection(header: Text("settings_account_section", bundle: PresentationResources.bundle)) {
            Button(action: onAccount) {
                DesktopSettingsRow(
                    symbolName: "person",
                    symbolColor: .tintLabel,
                    title: Text(String(localized: "settings_account", bundle: PresentationResources.bundle))
                ) {
                    Image(systemName: "chevron.right")
                        .font(.adaptive(.footnote).weight(.semibold))
                        .foregroundStyle(Color.secondaryLabel)
                }
                .opacity(isNetworkConnected ? 1 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(!isNetworkConnected)
        }
    }
}
