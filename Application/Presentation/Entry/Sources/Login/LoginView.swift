//
//  LoginView.swift
//  Entry
//
//  Created by opfic on 12/30/24.
//

import SwiftUI
import Core
import PresentationShared
import Domain

struct LoginView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sceneWidth) var sceneWidth
    @State private var store: StoreOf<LoginFeature>

    init() {
        self._store = State(initialValue: Store(
            initialState: LoginFeature.State()
        ) {
            LoginFeature()
        })
    }

    var body: some View {
        VStack {
            Spacer()
            Spacer()
            Image("Primary", bundle: PresentationResources.bundle)
                .resizable()
                .scaledToFit()
                .frame(width: sceneWidth / 4)
            Spacer()

            VStack(spacing: 24) {
                Text(String(localized: "login_intro_title", bundle: PresentationResources.bundle))
                    .font(.title)
                    .fontWeight(.heavy)
                    .multilineTextAlignment(.center)
                Text(String(localized: "login_intro_description", bundle: PresentationResources.bundle))
                    .padding(.horizontal)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()

            VStack(spacing: 20) {
                signInButton(
                    provider: .google,
                    logo: Image("Google", bundle: PresentationResources.bundle),
                    text: String(localized: "login_google_sign_in", bundle: PresentationResources.bundle)
                )

                signInButton(
                    provider: .github,
                    logo: Image("Github", bundle: PresentationResources.bundle),
                    text: String(localized: "login_github_sign_in", bundle: PresentationResources.bundle)
                )

                signInButton(
                    provider: .apple,
                    logo: Image("Apple", bundle: PresentationResources.bundle),
                    text: String(localized: "login_apple_sign_in", bundle: PresentationResources.bundle)
                )
            }
            .padding(.bottom, 30)
            Text(String(localized: "login_terms_notice", bundle: PresentationResources.bundle))
                .font(.caption2)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.vertical)
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .background {
            WindowSceneIdentifierReader {
                store.send(.setPresentationContext(
                    $0.map(AuthPresentationContext.init(identifier:))
                ))
            }
        }
    }

    private func signInButton(
        provider: AuthProvider,
        logo: Image,
        text: String
    ) -> some View {
        LoginButton(
            logo: logo,
            text: text,
            showsProgressView: store.activeSignInProvider == provider
        ) {
            store.send(.tapSignInButton(provider))
        }
        .disabled(store.isLoading || store.presentationContext == nil)
        .opacity(store.isLoading ? 0.5 : 1)
    }
}
