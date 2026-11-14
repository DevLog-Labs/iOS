//
//  AppSettingsCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct AppSettingsCard: View {
    @ScaledMetric(relativeTo: .headline) private var iconSize = 36
    let themeName: String
    let isNetworkConnected: Bool
    let onTheme: () -> Void
    let onNotifications: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings_app_section", bundle: PresentationResources.bundle)
                .font(.title3.bold())
                .foregroundStyle(Color.primary)

            VStack(spacing: 0) {
                Button(action: onTheme) {
                    HStack(spacing: 12) {
                        Image(systemName: "desktopcomputer")
                            .font(.headline)
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: 10))
                        Text(String(localized: "settings_theme", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.primary)

                        Spacer(minLength: 8)

                        Text(themeName)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.trailing)

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 64)
                    .padding(.trailing, 16)
                Button(action: onNotifications) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell")
                            .font(.headline)
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: 10))
                        Text(String(localized: "settings_notifications", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.primary)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .opacity(isNetworkConnected ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!isNetworkConnected)
            }
            .groupBackground(in: .rect(cornerRadius: 16))
        }
    }
}
