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

                if store.appVersion != nil || privacyPolicyURL != nil || store.betaTestURL != nil {
                    AppInformationCard(
                        appVersion: store.appVersion,
                        privacyPolicyURL: privacyPolicyURL,
                        betaTestURL: store.betaTestURL
                    )
                }

                AccountCard(
                    isNetworkConnected: store.isNetworkConnected,
                    isLoading: store.isLoading,
                    showsSignOutProgress: store.activeLoadingRow == .signOut,
                    onAccount: { onNavigate(.account) },
                    onSignOut: { store.send(.setAlert(.signOut)) }
                )

                deleteAccountContent
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // Mac 제목 줄 구분선과 첫 항목 사이 여백
        .contentMargins(.top, showsPaneTitleBar ? 12 : 0, for: .scrollContent)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.appBackground)
        .duoToolbarVisibility()
        .prominentAlert(store, state: \.alert, action: \.alert)
    }

    @ViewBuilder
    private var topBar: some View {
        let title = Text(String(localized: "nav_settings", bundle: PresentationResources.bundle))

        if showsPaneTitleBar {
            PaneTitleBar(title)
        } else {
            ZStack {
                title
                    .font(.headline)

                if deviceType != .duo {
                    HStack {
                        NavigationBackButton(action: { dismiss() })
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: readableContentWidth)
            .padding(.top, windowControlsInset)
            .padding(.bottom, 12)
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground)
        }
    }

    private var deleteAccountContent: some View {
        VStack(spacing: 16) {
            Button {
                store.send(.setAlert(.deleteAuth))
            } label: {
                Group {
                    if store.activeLoadingRow == .deleteAuth {
                        ProgressView()
                            .tint(Color.danger)
                    } else {
                        Text(String(localized: "settings_delete_account", bundle: PresentationResources.bundle))
                            .bold()
                            .foregroundStyle(Color.danger)
                    }
                }
                .font(.system(.body))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .contentShape(.rect(cornerRadius: 16))
                .groupBackground(in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!store.isNetworkConnected || store.isLoading)

            Text("settings_delete_account_subtitle", bundle: PresentationResources.bundle)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}
