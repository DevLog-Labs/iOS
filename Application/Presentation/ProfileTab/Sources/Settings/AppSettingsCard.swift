//
//  AppSettingsCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct AppSettingsCard: View {
    let themeName: String
    let isNetworkConnected: Bool
    let onTheme: () -> Void
    let onNotifications: () -> Void

    var body: some View {
        DesktopSettingsSection(header: Text("settings_app_section", bundle: PresentationResources.bundle)) {
            Button(action: onTheme) {
                DesktopSettingsRow(
                    symbolName: "desktopcomputer",
                    symbolColor: .tintLabel,
                    title: Text(String(localized: "settings_theme", bundle: PresentationResources.bundle))
                ) {
                    Text(themeName)
                        .foregroundStyle(Color.secondaryLabel)
                        .multilineTextAlignment(.trailing)

                    Image(systemName: "chevron.right")
                        .font(.adaptive(.footnote).weight(.semibold))
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
            .buttonStyle(.plain)

            Button(action: onNotifications) {
                DesktopSettingsRow(
                    symbolName: "bell",
                    symbolColor: .tintLabel,
                    title: Text(String(localized: "settings_notifications", bundle: PresentationResources.bundle))
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
