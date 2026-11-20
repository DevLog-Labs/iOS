//
//  DesktopSettingsView.swift
//  ProfileTab
//
//  Created by opfic on 11/16/26.
//

import SwiftUI
import PresentationShared

// Mac과 사이드바가 있는 iPad 창에서 앱 화면과 분리해 창 전체에 표시하는 설정 화면
// 앱 사이드바 자리에 설정 목차, 나머지 자리에 고른 항목 화면 배치
// Mac은 Mac 화면 크기, iPad는 손가락으로 누르는 크기
public struct DesktopSettingsView: View {
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @State private var store = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    // 목차에서 다른 항목을 골라도 진행 중인 로그아웃, 회원 탈퇴가 취소되지 않게 설정 화면이 보관
    @State private var accountStore = Store(initialState: AccountFeature.State()) {
        AccountFeature()
    }
    private let onBusyChange: (Bool) -> Void
    private let onClose: () -> Void

    public init(onBusyChange: @escaping (Bool) -> Void, onClose: @escaping () -> Void) {
        self.onBusyChange = onBusyChange
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 0) {
            tableOfContents

            // 오른쪽 세부 정보 사이드바 없이 가운데 한 칸으로 표시
            page
                .safeAreaInset(edge: .top, spacing: 0) { titleBar }
                .environment(\.showsPaneTitleBar, true)
        }
        // 화면을 닫으면 Store가 해제되어 진행 중인 로그아웃, 회원 탈퇴가 취소되므로 끝날 때까지 화면 전체 비활성화
        .disabled(accountStore.activeLoadingRow != nil)
        // 진행 중인 로그아웃, 회원 탈퇴나 계정 화면에 떠 있는 알림창이 남아 있으면 창이 좁아져도 화면을 닫지 않게 알림
        // 다른 항목으로 옮긴 뒤 실패한 요청의 알림창은 보이지 않아 제외
        .onChange(
            of: accountStore.activeLoadingRow != nil || (store.selectedRoute == .account && accountStore.alert != nil),
            initial: true
        ) { _, isBusy in
            onBusyChange(isBusy)
        }
        .onAppear { store.send(.startObserving) }
    }

    private var tableOfContents: some View {
        VStack(spacing: 0) {
            // 칸 제목 줄과 같은 높이의 앱으로 돌아가기 줄
            PaneTitleBar(background: .secondaryBackground) {
                Button(action: onClose) {
                    HStack(spacing: 8 * AdaptiveSize.boardScale) {
                        Image(systemName: "arrow.left")
                        Text("settings_back_to_app", bundle: PresentationResources.bundle)
                    }
                    .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                    .foregroundStyle(Color.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            } actions: {
                EmptyView()
            }

            VStack(spacing: isiOSAppOnMac ? AdaptiveSize.boardScale : 2) {
                ForEach(ProfileRoute.settingsPages, id: \.self) { route in
                    let isSelected = store.selectedRoute == route
                    let isDisabled = !store.isNetworkConnected && (route == .pushNotification || route == .account)

                    Button {
                        store.send(.binding(.set(\.selectedRoute, route)))
                    } label: {
                        HStack(spacing: isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 10) {
                            Image(systemName: route.settingsSymbolName)
                                .foregroundStyle(Color.secondaryLabel)
                                .frame(width: isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 18)
                            Text(route.settingsTitle)
                        }
                        .font(isiOSAppOnMac ? .adaptive(.body).weight(.medium) : .subheadline.weight(.semibold))
                        .foregroundStyle(Color.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10 * AdaptiveSize.boardScale)
                        .frame(minHeight: isiOSAppOnMac ? 28 * AdaptiveSize.boardScale : 44)
                        .hoverHighlight(in: RoundedRectangle(cornerRadius: CornerRadius.control), isEnabled: !isSelected)
                        // 선택 표시는 마우스 표시와 같은 회색
                        .background {
                            RoundedRectangle(cornerRadius: CornerRadius.control)
                                .fill(isSelected ? Color.fill : .clear)
                        }
                        .contentShape(.rect)
                        .opacity(isDisabled ? 0.5 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                }
            }
            .padding(.horizontal, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 10)
            .padding(.vertical, 10 * AdaptiveSize.boardScale)

            Spacer(minLength: 0)
        }
        // 앱 사이드바 기본 폭
        .frame(width: isiOSAppOnMac ? 220 * AdaptiveSize.boardScale : 250)
        .background(Color.secondaryBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.separator)
                .frame(width: 1)
        }
    }

    // 설정 / 항목 경로와 닫기 버튼
    private var titleBar: some View {
        PaneTitleBar {
            HStack(spacing: isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 10) {
                Text("nav_settings", bundle: PresentationResources.bundle)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondaryLabel)
                Text(verbatim: "/")
                    .fontWeight(.regular)
                    .foregroundStyle(Color.secondaryLabel)
                Text(store.selectedRoute.settingsTitle)
            }
        } actions: {
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .topBarButtonStyle()
        }
    }

    @ViewBuilder
    private var page: some View {
        switch store.selectedRoute {
        case .theme:
            ThemeView(theme: $store.theme, isPaneDetail: true, showsTopBar: false)
        case .pushNotification:
            PushNotificationSettingsView(store: Store(
                initialState: PushNotificationSettingsFeature.State()
            ) {
                PushNotificationSettingsFeature()
            }, isPaneDetail: true, showsTopBar: false)
        case .account:
            AccountView(
                store: accountStore,
                settingsStore: store,
                isPaneDetail: true,
                showsTopBar: false
            )
        case .information:
            ScrollView {
                AppInformationCard(
                    appVersion: store.appVersion,
                    privacyPolicyURL: store.policyURL.flatMap { URL(string: $0) },
                    betaTestURL: store.betaTestURL
                )
                // Mac 보드의 묶음 위아래 8, 좌우 14 여백
                .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 24)
                .frame(maxWidth: readableContentWidth)
                .frame(maxWidth: .infinity)
            }
            // 위쪽 줄 구분선과 첫 항목 사이 여백
            .contentMargins(.top, isiOSAppOnMac ? 20 * AdaptiveSize.boardScale : 24, for: .scrollContent)
            .background(Color.background)
        case .settings, .activity, .recentTodo:
            EmptyView()
        }
    }
}

private extension ProfileRoute {
    // 설정 목차 순서
    static let settingsPages: [ProfileRoute] = [.theme, .pushNotification, .account, .information]

    var settingsTitle: String {
        switch self {
        case .theme:
            String(localized: "settings_theme", bundle: PresentationResources.bundle)
        case .pushNotification:
            String(localized: "settings_notifications", bundle: PresentationResources.bundle)
        case .account:
            String(localized: "settings_account_section", bundle: PresentationResources.bundle)
        case .information:
            String(localized: "settings_information", bundle: PresentationResources.bundle)
        case .settings, .activity, .recentTodo:
            ""
        }
    }

    var settingsSymbolName: String {
        switch self {
        case .theme:
            "desktopcomputer"
        case .pushNotification:
            "bell"
        case .account:
            "person"
        case .information:
            "info.circle"
        case .settings, .activity, .recentTodo:
            ""
        }
    }
}
