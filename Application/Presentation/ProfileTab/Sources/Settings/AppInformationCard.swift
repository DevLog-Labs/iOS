//
//  AppInformationCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct AppInformationCard: View {
    @ScaledMetric(relativeTo: .headline) private var iconSize = 36 * AdaptiveSize.scale
    let appVersion: String?
    let privacyPolicyURL: URL?
    let betaTestURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16 * AdaptiveSize.scale) {
            Text("settings_information_section", bundle: PresentationResources.bundle)
                .font(.adaptive(.title3).bold())
                .foregroundStyle(Color.label)

            VStack(spacing: 0) {
                if let appVersion {
                    HStack(spacing: 12 * AdaptiveSize.scale) {
                        Image(systemName: "info.circle")
                            .font(.adaptive(.headline))
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: CornerRadius.control))
                        Text(String(localized: "settings_version", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.label)

                        Spacer(minLength: 8 * AdaptiveSize.scale)

                        Text(appVersion)
                            .foregroundStyle(Color.secondaryLabel)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(16 * AdaptiveSize.scale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let privacyPolicyURL {
                    if appVersion != nil {
                        Divider().overlay(Color.separator)
                            .padding(.leading, 64 * AdaptiveSize.scale)
                            .padding(.trailing, 16 * AdaptiveSize.scale)
                    }

                    Link(destination: privacyPolicyURL) {
                        HStack(spacing: 12 * AdaptiveSize.scale) {
                            Image(systemName: "doc.text")
                                .font(.adaptive(.headline))
                                .frame(width: iconSize, height: iconSize)
                                .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: CornerRadius.control))

                            Text(String(
                                localized: "settings_privacy_policy",
                                bundle: PresentationResources.bundle
                            ))
                            .foregroundStyle(Color.label)

                            Spacer(minLength: 8 * AdaptiveSize.scale)

                            Image(systemName: "chevron.right")
                                .font(.adaptive(.footnote).weight(.semibold))
                                .foregroundStyle(Color.secondaryLabel)
                        }
                        .padding(16 * AdaptiveSize.scale)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if let betaTestURL {
                    if appVersion != nil || privacyPolicyURL != nil {
                        Divider().overlay(Color.separator)
                            .padding(.leading, 64 * AdaptiveSize.scale)
                            .padding(.trailing, 16 * AdaptiveSize.scale)
                    }

                    Link(destination: betaTestURL) {
                        HStack(spacing: 12 * AdaptiveSize.scale) {
                            Image(systemName: "flask")
                                .font(.adaptive(.headline))
                                .frame(width: iconSize, height: iconSize)
                                .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: CornerRadius.control))

                            VStack(alignment: .leading, spacing: 4 * AdaptiveSize.scale) {
                                Text(String(localized: "settings_join_beta", bundle: PresentationResources.bundle))
                                    .foregroundStyle(Color.label)
                                Text(String(
                                    localized: "settings_join_beta_subtitle",
                                    bundle: PresentationResources.bundle
                                ))
                                .font(.adaptive(.footnote))
                                .foregroundStyle(Color.secondaryLabel)
                            }

                            Spacer(minLength: 8 * AdaptiveSize.scale)

                            Image(systemName: "chevron.right")
                                .font(.adaptive(.footnote).weight(.semibold))
                                .foregroundStyle(Color.secondaryLabel)
                        }
                        .padding(16 * AdaptiveSize.scale)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
    }
}
