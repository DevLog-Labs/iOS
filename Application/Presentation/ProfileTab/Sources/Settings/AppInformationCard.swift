//
//  AppInformationCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct AppInformationCard: View {
    @ScaledMetric(relativeTo: .headline) private var iconSize = 36
    let appVersion: String?
    let privacyPolicyURL: URL?
    let betaTestURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings_information_section", bundle: PresentationResources.bundle)
                .font(.title3.bold())
                .foregroundStyle(Color.label)

            VStack(spacing: 0) {
                if let appVersion {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.headline)
                            .frame(width: iconSize, height: iconSize)
                            .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: 10))
                        Text(String(localized: "settings_version", bundle: PresentationResources.bundle))
                            .foregroundStyle(Color.label)

                        Spacer(minLength: 8)

                        Text(appVersion)
                            .foregroundStyle(Color.secondaryLabel)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let privacyPolicyURL {
                    if appVersion != nil {
                        Divider().overlay(Color.separator)
                            .padding(.leading, 64)
                            .padding(.trailing, 16)
                    }

                    Link(destination: privacyPolicyURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.headline)
                                .frame(width: iconSize, height: iconSize)
                                .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: 10))

                            Text(String(
                                localized: "settings_privacy_policy",
                                bundle: PresentationResources.bundle
                            ))
                            .foregroundStyle(Color.label)

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.secondaryLabel)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if let betaTestURL {
                    if appVersion != nil || privacyPolicyURL != nil {
                        Divider().overlay(Color.separator)
                            .padding(.leading, 64)
                            .padding(.trailing, 16)
                    }

                    Link(destination: betaTestURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "flask")
                                .font(.headline)
                                .frame(width: iconSize, height: iconSize)
                                .iconStyle(color: .accent, in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "settings_join_beta", bundle: PresentationResources.bundle))
                                    .foregroundStyle(Color.label)
                                Text(String(
                                    localized: "settings_join_beta_subtitle",
                                    bundle: PresentationResources.bundle
                                ))
                                .font(.footnote)
                                .foregroundStyle(Color.secondaryLabel)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.secondaryLabel)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .groupBackground(in: .rect(cornerRadius: 16))
        }
    }
}
