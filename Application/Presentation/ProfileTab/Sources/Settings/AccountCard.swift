//
//  AccountCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct AccountCard: View {
    @ScaledMetric(relativeTo: .headline) private var iconSize = 36 * AdaptiveSize.scale
    let isNetworkConnected: Bool
    let isLoading: Bool
    let showsSignOutProgress: Bool
    let onAccount: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16 * AdaptiveSize.scale) {
            Text("settings_account_section", bundle: PresentationResources.bundle)
                .font(.adaptive(.title3).bold())
                .foregroundStyle(Color.label)

            VStack(spacing: 0) {
                Button(action: onAccount) {
                    HStack(spacing: 12 * AdaptiveSize.scale) {
                        Image(systemName: "person.crop.circle")
                            .font(.adaptive(.headline))
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: CornerRadius.control))

                        Text(String(localized: "settings_account", bundle: PresentationResources.bundle))
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

                Divider().overlay(Color.separator)
                    .padding(.leading, 64 * AdaptiveSize.scale)
                    .padding(.trailing, 16 * AdaptiveSize.scale)

                Button(action: onSignOut) {
                    HStack(spacing: 12 * AdaptiveSize.scale) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.adaptive(.headline))
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .danger, in: RoundedRectangle(cornerRadius: CornerRadius.control))

                        Text(String(localized: "settings_sign_out", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.danger)

                        Spacer(minLength: 8 * AdaptiveSize.scale)

                        if showsSignOutProgress {
                            ProgressView()
                        }

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
                .disabled(!isNetworkConnected || isLoading)
            }
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
    }
}
