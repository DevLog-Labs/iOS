//
//  AccountCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct AccountCard: View {
    @ScaledMetric(relativeTo: .headline) private var iconSize = 36
    let isNetworkConnected: Bool
    let isLoading: Bool
    let showsSignOutProgress: Bool
    let onAccount: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings_account_section", bundle: PresentationResources.bundle)
                .font(.title3.bold())
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 0) {
                Button(action: onAccount) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle")
                            .font(.headline)
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: 10))

                        Text(String(localized: "settings_account", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.textPrimary)

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

                Divider().overlay(Color.border)
                    .padding(.leading, 64)
                    .padding(.trailing, 16)

                Button(action: onSignOut) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .danger, in: RoundedRectangle(cornerRadius: 10))

                        Text(String(localized: "settings_sign_out", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.danger)

                        Spacer(minLength: 8)

                        if showsSignOutProgress {
                            ProgressView()
                        }

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
                .disabled(!isNetworkConnected || isLoading)
            }
            .groupBackground(in: .rect(cornerRadius: 16))
        }
    }
}
