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

struct AccountView<Accessory: View, Footer: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.deviceType) private var deviceType
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @State var store: StoreOf<AccountFeature>
    // 설정 옆 칸에 넣은 화면은 뒤로 갈 곳이 없어 칸 제목 줄의 뒤로 버튼 생략
    let isPaneDetail: Bool
    // 앱 화면과 분리한 Mac 설정 화면은 위쪽 줄을 직접 그려 화면 제목 줄 생략
    let showsTopBar: Bool
    // Mac 설정 화면에서 현재 계정 행 오른쪽에 두는 로그아웃 버튼
    let accessory: Accessory
    // Mac 설정 화면에서 계정 연동 아래에 두는 회원 탈퇴
    let footer: Footer

    init(
        store: StoreOf<AccountFeature>,
        isPaneDetail: Bool = false,
        showsTopBar: Bool = true,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder footer: () -> Footer
    ) {
        self._store = State(initialValue: store)
        self.isPaneDetail = isPaneDetail
        self.showsTopBar = showsTopBar
        self.accessory = accessory()
        self.footer = footer()
    }

    var body: some View {
        // 인증 요청이 겹치지 않게 공급자 연결 중에는 로그아웃, 회원 탈퇴 비활성화
        let isProviderLoading = store.activeLoadingProvider != nil

        ScrollView {
            LazyVStack(alignment: .leading, spacing: isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 24) {
                AccountCurrentSection(store: store, accessory: accessory.disabled(isProviderLoading))
                AccountSocialSection(store: store)
                footer
                    .disabled(isProviderLoading)
            }
            // Mac 설정 화면은 묶음마다 보드의 위아래 8, 좌우 14 여백
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 24)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // Mac 제목 줄 구분선과 첫 항목 사이 여백
        .contentMargins(
            .top,
            isiOSAppOnMac ? 20 * AdaptiveSize.boardScale : showsPaneTitleBar ? 12 : 0,
            for: .scrollContent
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsTopBar {
                topBar
            }
        }
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
            // 일반 화면에서 밀어 넣은 화면이 칸 화면으로 바뀌어도 뒤로 갈 수 있게 뒤로 버튼 표시
            PaneTitleBar(title, onBack: isPaneDetail ? nil : { dismiss() }, showsBackOnDesktop: true)
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
            .padding(.horizontal, 16)
            .frame(maxWidth: readableContentWidth)
            .padding(.top, windowControlsInset)
            .padding(.bottom, 12)
            .background(Color.background)
            .toolbarBackground(Color.background)
        }
    }
}

extension AccountView where Accessory == EmptyView, Footer == EmptyView {
    init(store: StoreOf<AccountFeature>, isPaneDetail: Bool = false) {
        self.init(store: store, isPaneDetail: isPaneDetail) {
            EmptyView()
        } footer: {
            EmptyView()
        }
    }
}

private struct AccountCurrentSection<Accessory: View>: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let store: StoreOf<AccountFeature>
    let accessory: Accessory

    var body: some View {
        // Mac은 계정을 불러오지 못해도 로그아웃할 수 있게 행 유지
        // 묶음 제목이 현재 계정이라 로그인 중 배지 없이 표시
        if isiOSAppOnMac {
            let currentProvider = store.currentProvider

            DesktopSettingsSection(header: Text("account_current_section", bundle: PresentationResources.bundle)) {
                DesktopSettingsRow(
                    logo: currentProvider.map { Image($0.imageName, bundle: PresentationResources.bundle) },
                    title: Text(currentProvider?.displayName
                        ?? String(localized: "settings_account_section", bundle: PresentationResources.bundle))
                ) {
                    accessory
                }
            }
        } else if let currentProvider = store.currentProvider {
            VStack(alignment: .leading, spacing: 12) {
                Text("account_current_section", bundle: PresentationResources.bundle)
                    .font(.adaptive(.title3).weight(.semibold))

                HStack(spacing: 12) {
                    ProviderIdentity(
                        provider: currentProvider,
                        status: nil
                    )

                    Spacer(minLength: 8)

                    Text("account_signed_in", bundle: PresentationResources.bundle)
                        .font(.adaptive(.caption).weight(.semibold))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.accent.opacity(0.1), in: .rect(cornerRadius: CornerRadius.badge))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
            }
        }
    }
}

private struct AccountSocialSection: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let store: StoreOf<AccountFeature>

    var body: some View {
        let providers = AuthProvider.allCases.filter { $0 != store.currentProvider }

        if isiOSAppOnMac {
            DesktopSettingsSection(header: Text("account_social_section", bundle: PresentationResources.bundle)) {
                ForEach(providers, id: \.self) { provider in
                    providerRow(provider)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("account_social_section", bundle: PresentationResources.bundle)
                    .font(.adaptive(.title3).weight(.semibold))

                VStack(spacing: 0) {
                    ForEach(providers, id: \.self) { provider in
                        providerRow(provider)

                        if provider != providers.last {
                            Divider().overlay(Color.separator)
                                .padding(.leading, 64)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
            }
        }
    }

    private func providerRow(_ provider: AuthProvider) -> some View {
        let isConnected = store.connectedProviders.contains(provider)

        return ProviderRow(
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
    }
}

private struct ProviderRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let provider: AuthProvider
    let isConnected: Bool
    let showsProgress: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        let status = String(
            localized: isConnected ? "account_connected" : "account_not_connected",
            bundle: PresentationResources.bundle
        )
        let title = String(
            localized: isConnected ? "account_disconnect" : "account_connect",
            bundle: PresentationResources.bundle
        )

        if isiOSAppOnMac {
            DesktopSettingsRow(
                logo: Image(provider.imageName, bundle: PresentationResources.bundle),
                title: Text(provider.displayName),
                subtitle: Text(status)
            ) {
                DesktopSettingsButton(
                    title: title,
                    role: isConnected ? .normal : .prominent,
                    showsProgress: showsProgress,
                    action: action
                )
                .disabled(isDisabled)
            }
        } else {
            HStack(spacing: 12) {
                ProviderIdentity(provider: provider, status: status)

                Spacer(minLength: 8)

                Button(action: action) {
                    ZStack {
                        Text(title)
                            .opacity(showsProgress ? 0 : 1)

                        if showsProgress {
                            ProgressView()
                                .tint(isConnected ? Color.danger : Color.white)
                        }
                    }
                    .font(.adaptive(.caption).weight(.semibold))
                    .foregroundStyle(isConnected ? Color.danger : Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
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
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
