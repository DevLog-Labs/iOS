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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @State var store: StoreOf<AccountFeature>
    // 설정 옆 칸에 넣은 화면은 뒤로 갈 곳이 없어 칸 제목 줄의 뒤로 버튼 생략
    let isPaneDetail: Bool
    // 앱 화면과 분리한 Mac 설정 화면은 위쪽 줄을 직접 그려 화면 제목 줄 생략
    let showsTopBar: Bool
    // 오프라인이면 로그아웃, 회원 탈퇴 비활성화
    let isNetworkConnected: Bool

    init(
        store: StoreOf<AccountFeature>,
        isNetworkConnected: Bool,
        isPaneDetail: Bool = false,
        showsTopBar: Bool = true
    ) {
        self._store = State(initialValue: store)
        self.isNetworkConnected = isNetworkConnected
        self.isPaneDetail = isPaneDetail
        self.showsTopBar = showsTopBar
    }

    var body: some View {
        // 인증 요청이 겹치지 않게 공급자 연결 중에는 로그아웃, 회원 탈퇴 비활성화
        let isProviderLoading = store.activeLoadingProvider != nil

        ScrollView {
            LazyVStack(alignment: .leading, spacing: isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 24) {
                AccountCurrentSection(
                    store: store,
                    accessory: SignOutButton(store: store, isNetworkConnected: isNetworkConnected)
                        .disabled(isProviderLoading)
                )
                AccountSocialSection(store: store)
                DeleteAccountSection(store: store, isNetworkConnected: isNetworkConnected)
                    .disabled(isProviderLoading)
            }
            // Mac 설정 화면은 묶음마다 보드의 위아래 8, 좌우 14 여백
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 24)
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        // 위쪽 줄 구분선과 첫 항목 사이 여백
        .contentMargins(
            .top,
            isiOSAppOnMac ? 20 * AdaptiveSize.boardScale : showsPaneTitleBar ? 24 : 12,
            for: .scrollContent
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsTopBar {
                topBar
            }
        }
        .background(Color.background)
        .duoToolbarVisibility(showsBackButton: true)
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

private struct AccountCurrentSection<Accessory: View>: View {
    let store: StoreOf<AccountFeature>
    let accessory: Accessory

    var body: some View {
        // 계정을 불러오지 못해도 로그아웃할 수 있게 행 유지
        // 묶음 제목이 현재 계정이라 로그인 중 배지 없이 표시
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
    }
}

private struct AccountSocialSection: View {
    let store: StoreOf<AccountFeature>

    var body: some View {
        let providers = AuthProvider.allCases.filter { $0 != store.currentProvider }

        DesktopSettingsSection(header: Text("account_social_section", bundle: PresentationResources.bundle)) {
            ForEach(providers, id: \.self) { provider in
                providerRow(provider)
            }
        }
    }

    private func providerRow(_ provider: AuthProvider) -> some View {
        let isConnected = store.connectedProviders.contains(provider)

        return ProviderRow(
            provider: provider,
            isConnected: isConnected,
            showsProgress: store.isLoading && store.activeLoadingProvider == provider,
            // 로그아웃, 회원 탈퇴 중에도 공급자 연결 비활성화
            isDisabled: store.isLoading
                || store.activeLoadingRow != nil
                || (!isConnected && store.presentationContext == nil),
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

// 현재 계정 행 오른쪽 로그아웃 버튼
private struct SignOutButton: View {
    let store: StoreOf<AccountFeature>
    let isNetworkConnected: Bool

    var body: some View {
        DesktopSettingsButton(
            title: String(localized: "settings_sign_out", bundle: PresentationResources.bundle),
            showsProgress: store.activeLoadingRow == .signOut
        ) {
            store.send(.setAlert(.signOut))
        }
        .disabled(!isNetworkConnected || store.isLoading)
    }
}

// 계정 연동 아래 회원 탈퇴 안내와 빨간 탈퇴 버튼
// GitHub 위험 구역처럼 설명 행 오른쪽 버튼으로 실행
private struct DeleteAccountSection: View {
    let store: StoreOf<AccountFeature>
    let isNetworkConnected: Bool

    var body: some View {
        DesktopSettingsSection {
            DesktopSettingsRow(
                title: Text(String(localized: "settings_delete_account", bundle: PresentationResources.bundle)),
                subtitle: Text("settings_delete_account_subtitle", bundle: PresentationResources.bundle)
            ) {
                DesktopSettingsButton(
                    title: String(localized: "settings_delete_account_action", bundle: PresentationResources.bundle),
                    role: .destructive,
                    showsProgress: store.activeLoadingRow == .deleteAuth
                ) {
                    store.send(.setAlert(.deleteAuth))
                }
                .disabled(!isNetworkConnected || store.isLoading)
            }
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
        let status = String(
            localized: isConnected ? "account_connected" : "account_not_connected",
            bundle: PresentationResources.bundle
        )
        let title = String(
            localized: isConnected ? "account_disconnect" : "account_connect",
            bundle: PresentationResources.bundle
        )

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
