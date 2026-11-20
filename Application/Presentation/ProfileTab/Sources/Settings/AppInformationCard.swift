//
//  AppInformationCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct AppInformationCard: View {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let appVersion: String?
    let privacyPolicyURL: URL?
    let betaTestURL: URL?

    var body: some View {
        // 사이드바가 있는 창의 설정 화면은 위쪽 줄 경로가 정보라서 묶음 제목 없이 표시
        DesktopSettingsSection(
            header: usesDesktopLayout ? nil : Text("settings_information_section", bundle: PresentationResources.bundle)
        ) {
            if let appVersion {
                DesktopSettingsRow(
                    symbolName: "info.circle",
                    title: Text(String(localized: "settings_version", bundle: PresentationResources.bundle))
                ) {
                    Text(appVersion)
                        .foregroundStyle(Color.secondaryLabel)
                }
            }

            if let privacyPolicyURL {
                Link(destination: privacyPolicyURL) {
                    DesktopSettingsRow(
                        symbolName: "doc.text",
                        title: Text(String(localized: "settings_privacy_policy", bundle: PresentationResources.bundle))
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.adaptive(.footnote).weight(.semibold))
                            .foregroundStyle(Color.secondaryLabel)
                    }
                }
                .buttonStyle(.plain)
            }

            if let betaTestURL {
                Link(destination: betaTestURL) {
                    DesktopSettingsRow(
                        symbolName: "flask",
                        title: Text(String(localized: "settings_join_beta", bundle: PresentationResources.bundle)),
                        subtitle: Text(String(localized: "settings_join_beta_subtitle", bundle: PresentationResources.bundle))
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.adaptive(.footnote).weight(.semibold))
                            .foregroundStyle(Color.secondaryLabel)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
