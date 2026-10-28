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
    @State var store: StoreOf<AccountFeature>

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                AccountCurrentSection(store: store)
                AccountSocialSection(store: store)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.appBackground)
        .toolbarVisibility(.hidden, for: .navigationBar)
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

    private var topBar: some View {
        ZStack {
            Text(String(localized: "nav_account", bundle: PresentationResources.bundle))
                .font(.headline)

            HStack {
                NavigationBackButton(action: { dismiss() })
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Color.appBackground)
        .toolbarBackground(Color.appBackground)
    }
}

struct ToastLabel: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accent)
        }
    }
}

private struct AccountCurrentSection: View {
    let store: StoreOf<AccountFeature>

    var body: some View {
        if let currentProvider = store.currentProvider {
            VStack(alignment: .leading, spacing: 12) {
                Text("account_current_section", bundle: PresentationResources.bundle)
                    .font(.title3.weight(.semibold))

                HStack(spacing: 12) {
                    ProviderIdentity(
                        provider: currentProvider,
                        status: nil
                    )

                    Spacer(minLength: 8)

                    Text("account_signed_in", bundle: PresentationResources.bundle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.accent.opacity(0.1), in: .capsule)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface, in: .rect(cornerRadius: 16))
            }
        }
    }
}

private struct AccountSocialSection: View {
    let store: StoreOf<AccountFeature>

    var body: some View {
        let providers = AuthProvider.allCases.filter { $0 != store.currentProvider }
        VStack(alignment: .leading, spacing: 12) {
            Text("account_social_section", bundle: PresentationResources.bundle)
                .font(.title3.weight(.semibold))

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
                        Divider()
                            .padding(.leading, 64)
                            .padding(.trailing, 16)
                    }
                }
            }
            .background(Color.surface, in: .rect(cornerRadius: 16))
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
        HStack(spacing: 12) {
            ProviderIdentity(
                provider: provider,
                status: String(
                    localized: isConnected ? "account_connected" : "account_not_connected",
                    bundle: PresentationResources.bundle
                )
            )

            Spacer(minLength: 8)

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
                .font(.caption.weight(.semibold))
                .foregroundStyle(isConnected ? Color.danger : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isConnected ? Color.clear : Color.accent, in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(isConnected ? Color.danger : Color.clear)
                }
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled && !showsProgress ? 0.5 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProviderIdentity: View {
    let provider: AuthProvider
    let status: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(provider.imageName, bundle: PresentationResources.bundle)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .frame(width: 36, height: 36)
                .background(Color.surfaceSecondary, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                if let status {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
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
