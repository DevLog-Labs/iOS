//
//  SettingsView.swift
//  ProfileTab
//
//  Created by opfic on 5/6/25.
//

import SwiftUI
import Domain
import PresentationShared

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.deviceType) private var deviceType
    @Bindable var store: StoreOf<SettingsFeature>
    let onNavigate: (ProfileRoute) -> Void

    private var privacyPolicyURL: URL? {
        guard let policyString = store.policyURL else { return nil }
        return URL(string: policyString)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                AppSettingsCard(
                    themeName: store.theme.localizedName(in: PresentationResources.bundle),
                    isNetworkConnected: store.isNetworkConnected,
                    onTheme: { onNavigate(.theme) },
                    onNotifications: { onNavigate(.pushNotification) }
                )

                AccountCard(
                    isNetworkConnected: store.isNetworkConnected,
                    onAccount: { onNavigate(.account) }
                )

                if store.appVersion != nil || privacyPolicyURL != nil || store.betaTestURL != nil {
                    AppInformationCard(
                        appVersion: store.appVersion,
                        privacyPolicyURL: privacyPolicyURL,
                        betaTestURL: store.betaTestURL
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // 위쪽 줄 구분선과 첫 묶음 사이 여백
        .contentMargins(.top, 12, for: .scrollContent)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background)
        .duoToolbarVisibility(showsBackButton: true)
    }

    @ViewBuilder
    private var topBar: some View {
        let title = Text(String(localized: "nav_settings", bundle: PresentationResources.bundle))

        if showsPaneTitleBar {
            PaneTitleBar(title, onBack: { dismiss() })
        } else {
            // OS와 상관없이 같은 모양인 가운데 제목과 아래 구분선
            ZStack {
                title
                    .font(.adaptive(.callout).bold())
                HStack {
                    // Duo는 세로 막대의 뒤로 버튼 사용
                    if deviceType != .duo {
                        NavigationBackButton(action: { dismiss() })
                    }
                    Spacer()
                }
            }
            .frame(height: 48)
            .padding(.horizontal, 8)
            .overlay(alignment: .bottom) {
                Divider().overlay(Color.secondarySeparator)
            }
            .padding(.top, windowControlsInset)
            .background(Color.background, ignoresSafeAreaEdges: .top)
        }
    }
}
