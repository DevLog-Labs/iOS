//
//  AppSettingsCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct AppSettingsCard: View {
    @ScaledMetric(relativeTo: .headline) private var iconSize = 36 * AdaptiveSize.scale
    let themeName: String
    let isNetworkConnected: Bool
    let onTheme: () -> Void
    let onNotifications: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16 * AdaptiveSize.scale) {
            Text("settings_app_section", bundle: PresentationResources.bundle)
                .font(.adaptive(.title3).bold())
                .foregroundStyle(Color.label)

            VStack(spacing: 0) {
                Button(action: onTheme) {
                    HStack(spacing: 12 * AdaptiveSize.scale) {
                        Image(systemName: "desktopcomputer")
                            .font(.adaptive(.headline))
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: CornerRadius.control))
                        Text(String(localized: "settings_theme", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.label)

                        Spacer(minLength: 8 * AdaptiveSize.scale)

                        Text(themeName)
                            .foregroundStyle(Color.secondaryLabel)
                            .multilineTextAlignment(.trailing)

                        Image(systemName: "chevron.right")
                            .font(.adaptive(.footnote).weight(.semibold))
                            .foregroundStyle(Color.secondaryLabel)
                    }
                    .padding(16 * AdaptiveSize.scale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.separator)
                    .padding(.leading, 64 * AdaptiveSize.scale)
                    .padding(.trailing, 16 * AdaptiveSize.scale)
                Button(action: onNotifications) {
                    HStack(spacing: 12 * AdaptiveSize.scale) {
                        Image(systemName: "bell")
                            .font(.adaptive(.headline))
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: CornerRadius.control))
                        Text(String(localized: "settings_notifications", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.label)

                        Spacer(minLength: 8 * AdaptiveSize.scale)

                        Image(systemName: "chevron.right")
                            .font(.adaptive(.footnote).weight(.semibold))
                            .foregroundStyle(Color.secondaryLabel)
                    }
                    .padding(16 * AdaptiveSize.scale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .opacity(isNetworkConnected ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!isNetworkConnected)
            }
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
    }
}
