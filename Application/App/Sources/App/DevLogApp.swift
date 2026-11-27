//
//  DevLogApp.swift
//  DevLog
//
//  Created by opfic on 5/2/25.
//

import SwiftUI
import Presentation
import Widget

@main
struct DevLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) var scenePhase
    @State private var windowEvent = TodoEditorWindowEvent()
    @State private var syncDate = Date()

    init() {
        AppGraph.shared.preparePresentationDependencies()
        #if DEBUG
        TouchIndicator.install()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                widgetURLRoute: { WidgetRoute(widgetURL: $0) },
                windowEvent: windowEvent,
                pushNotificationTodoIdPublisher: PushNotificationRoute.shared.observe(),
                clearPushNotificationRoute: { PushNotificationRoute.shared.clear() }
            )
            // 기기 글자 크기 설정과 관계없이 디자인 캔버스의 기본 글자 크기로 고정
            .dynamicTypeSize(.large)
            .autocorrectionDisabled()
            .onChange(of: scenePhase) { _, phase in
                guard phase == .background else { return }
                let now = Date()

                // 위젯 갱신은 앱 실행 시 로그인 세션 흐름에서 한 번 요청된다. (WidgetSessionSyncHandler.swift:47)
                // 따라서 이 백그라운드 트리거는 매번 최신 데이터를 다시 가져오기 위한 경로가 아니라,
                // 앱이 실행된 상태로 날짜가 넘어가서 Today widget의 분류 기준일이 바뀌었을 때만
                // 기존 위젯 갱신 흐름을 보조로 허용하기 위한 안전장치다.
                // 같은 날의 첫 백그라운드 진입을 막는 것은 의도된 동작이며,
                // 앱이 꺼져 있는 동안 날짜가 바뀐 경우는 다음 실행 시 세션 기반 갱신 요청이 담당한다.
                guard !Calendar.current.isDate(syncDate, inSameDayAs: now) else { return }

                syncDate = now
                AppGraph.shared
                    .widgetGraphSet
                    .widgetSyncEventBusGraph
                    .widgetSyncEventBus
                    .publish(.syncRequested)
            }
        }
    }
}
