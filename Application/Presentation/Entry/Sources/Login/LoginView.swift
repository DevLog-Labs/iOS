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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @State private var store: StoreOf<LoginFeature>

    init() {
        self._store = State(initialValue: Store(
            initialState: LoginFeature.State()
        ) {
            LoginFeature()
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * AdaptiveSize.boardScale) {
            RoundedRectangle(cornerRadius: 12 * AdaptiveSize.boardScale)
                .fill(Color.accent)
                .frame(width: 56 * AdaptiveSize.boardScale, height: 56 * AdaptiveSize.boardScale)
                .overlay {
                    Image(systemName: "doc.text")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30 * AdaptiveSize.boardScale, height: 30 * AdaptiveSize.boardScale)
                        .foregroundStyle(.white)
                }

            Text(String(localized: "login_intro_title", bundle: PresentationResources.bundle))
                .font(.adaptive(.title))
                .fontWeight(.heavy)
                .foregroundStyle(Color.label)
                .padding(.top, 8 * AdaptiveSize.boardScale)

            Text(String(localized: "login_intro_description", bundle: PresentationResources.bundle))
                .font(isiOSAppOnMac ? .system(size: 13 * AdaptiveSize.boardScale) : .subheadline)
                .foregroundStyle(Color.secondaryLabel)
                .lineSpacing(6 * AdaptiveSize.boardScale)

            VStack(spacing: 10 * AdaptiveSize.boardScale) {
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
            .padding(.top, 28 * AdaptiveSize.boardScale)

            Text(String(localized: "login_terms_notice", bundle: PresentationResources.bundle))
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8 * AdaptiveSize.boardScale)
        }
        .frame(maxWidth: 360 * AdaptiveSize.boardScale)
        .padding(32 * AdaptiveSize.boardScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
