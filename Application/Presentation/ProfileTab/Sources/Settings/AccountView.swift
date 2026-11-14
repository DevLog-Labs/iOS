//
//  AccountView.swift
//  ProfileTab
//
//  Created by opfic on 5/14/25.
//

import SwiftUI
import Core
import PresentationShared
import Domain

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.deviceType) private var deviceType
    @State var store: StoreOf<AccountFeature>

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24 * AdaptiveSize.scale) {
                AccountCurrentSection(store: store)
                AccountSocialSection(store: store)
            }
            .padding(.horizontal, 16 * AdaptiveSize.scale)
            .padding(.bottom, 24 * AdaptiveSize.scale)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // Mac 제목 줄 구분선과 첫 항목 사이 여백
        .contentMargins(.top, showsPaneTitleBar ? 12 : 0, for: .scrollContent)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background)
        .duoToolbarVisibility()
        .onAppear { store.send(.onAppear) }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .background {
            WindowSceneIdentifierReader {
                store.send(.setPresentationContext(
                    $0.map(AuthPresentationContext.init(identifier:))
                ))
            }
        }
    }

    @ViewBuilder
    private var topBar: some View {
        let title = Text(String(localized: "nav_account", bundle: PresentationResources.bundle))

        if showsPaneTitleBar {
            PaneTitleBar(title)
        } else {
            ZStack {
                title
                    .font(.adaptive(.headline))

                if deviceType != .duo {
                    HStack {
                        NavigationBackButton(action: { dismiss() })
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16 * AdaptiveSize.scale)
            .frame(maxWidth: readableContentWidth)
            .padding(.top, windowControlsInset)
            .padding(.bottom, 12 * AdaptiveSize.scale)
            .background(Color.background)
            .toolbarBackground(Color.background)
        }
    }
}

private struct AccountCurrentSection: View {
    let store: StoreOf<AccountFeature>

    var body: some View {
        if let currentProvider = store.currentProvider {
            VStack(alignment: .leading, spacing: 12 * AdaptiveSize.scale) {
                Text("account_current_section", bundle: PresentationResources.bundle)
                    .font(.adaptive(.title3).weight(.semibold))

                HStack(spacing: 12 * AdaptiveSize.scale) {
                    ProviderIdentity(
                        provider: currentProvider,
                        status: nil
                    )

                    Spacer(minLength: 8 * AdaptiveSize.scale)

                    Text("account_signed_in", bundle: PresentationResources.bundle)
                        .font(.adaptive(.caption).weight(.semibold))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 12 * AdaptiveSize.scale)
                        .padding(.vertical, 7 * AdaptiveSize.scale)
                        .background(Color.accent.opacity(0.1), in: .rect(cornerRadius: CornerRadius.badge))
                }
                .padding(16 * AdaptiveSize.scale)
                .frame(maxWidth: .infinity, alignment: .leading)
                .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
            }
        }
    }
}

private struct AccountSocialSection: View {
    let store: StoreOf<AccountFeature>

    var body: some View {
        let providers = AuthProvider.allCases.filter { $0 != store.currentProvider }
        VStack(alignment: .leading, spacing: 12 * AdaptiveSize.scale) {
            Text("account_social_section", bundle: PresentationResources.bundle)
                .font(.adaptive(.title3).weight(.semibold))

            VStack(spacing: 0) {
                ForEach(providers, id: \.self) { provider in
                    let isConnected = store.connectedProviders.contains(provider)
                    ProviderRow(
                        provider: provider,
                        isConnected: isConnected,
                        showsProgress: store.isLoading && store.activeLoadingProvider == provider,
                        isDisabled: store.isLoading || (!isConnected && store.presentationContext == nil),
                        action: {
                            if isConnected {
                                store.send(.unlinkFromProvider(provider))
                            } else {
                                store.send(.linkWithProvider(provider))
                            }
                        }
                    )

                    if provider != providers.last {
                        Divider().overlay(Color.separator)
                            .padding(.leading, 64 * AdaptiveSize.scale)
                            .padding(.trailing, 16 * AdaptiveSize.scale)
                    }
                }
            }
            .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
        }
    }
}

private struct ProviderRow: View {
    let provider: AuthProvider
    let isConnected: Bool
    let showsProgress: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12 * AdaptiveSize.scale) {
            ProviderIdentity(
                provider: provider,
                status: String(
                    localized: isConnected ? "account_connected" : "account_not_connected",
                    bundle: PresentationResources.bundle
                )
            )

            Spacer(minLength: 8 * AdaptiveSize.scale)

            Button(action: action) {
                ZStack {
                    Text(isConnected
                         ? String(localized: "account_disconnect", bundle: PresentationResources.bundle)
                         : String(localized: "account_connect", bundle: PresentationResources.bundle))
                        .opacity(showsProgress ? 0 : 1)

                    if showsProgress {
                        ProgressView()
                            .tint(isConnected ? Color.danger : Color.white)
                    }
                }
                .font(.adaptive(.caption).weight(.semibold))
                .foregroundStyle(isConnected ? Color.danger : Color.white)
                .padding(.horizontal, 12 * AdaptiveSize.scale)
                .padding(.vertical, 7 * AdaptiveSize.scale)
                .background(isConnected ? Color.clear : Color.accent, in: .rect(cornerRadius: CornerRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.control)
                        .stroke(isConnected ? Color.danger : Color.clear)
                }
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled && !showsProgress ? 0.5 : 1)
        }
        .padding(16 * AdaptiveSize.scale)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProviderIdentity: View {
    let provider: AuthProvider
    let status: String?

    var body: some View {
        HStack(spacing: 12 * AdaptiveSize.scale) {
            Image(provider.imageName, bundle: PresentationResources.bundle)
                .resizable()
                .scaledToFit()
                .frame(width: 20 * AdaptiveSize.scale, height: 20 * AdaptiveSize.scale)
                .frame(width: 36 * AdaptiveSize.scale, height: 36 * AdaptiveSize.scale)
                .background(Color.fill, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.adaptive(.headline))
                    .foregroundStyle(Color.label)

                if let status {
                    Text(status)
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
        }
    }
}

private extension AuthProvider {
    var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        case .github:
            return "GitHub"
        }
    }

    var imageName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        case .github:
            return "Github"
        }
    }
}
