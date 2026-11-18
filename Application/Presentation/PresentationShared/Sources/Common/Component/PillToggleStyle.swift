//
//  PillToggleStyle.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

public struct PillToggleStyle: ToggleStyle {
    public func makeBody(configuration: Configuration) -> some View {
        PillToggle(configuration: configuration)
    }
}

public extension ToggleStyle where Self == PillToggleStyle {
    static var pill: PillToggleStyle { PillToggleStyle() }
}

private struct PillToggle: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.labelsVisibility) private var labelsVisibility
    let configuration: ToggleStyleConfiguration

    var body: some View {
        HStack(spacing: 8) {
            // 레이블을 숨긴 스위치는 시스템 스위치처럼 손잡이 폭만 차지
            if labelsVisibility != .hidden {
                configuration.label

                Spacer(minLength: 0)
            }

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    configuration.isOn.toggle()
                }
            } label: {
                // Mac은 손가락 크기보다 작은 Orca 데스크톱 스위치 크기
                let knob = (isiOSAppOnMac ? 14 : 18) * AdaptiveSize.boardScale

                Capsule()
                    .fill(configuration.isOn ? Color.accent : .switchOffFill)
                    .frame(
                        width: (isiOSAppOnMac ? 32 : 44) * AdaptiveSize.boardScale,
                        height: (isiOSAppOnMac ? 18 : 24) * AdaptiveSize.boardScale
                    )
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: knob, height: knob)
                            .shadow(color: Color.black.opacity(0.1), radius: 1.5, y: 1)
                            .padding((isiOSAppOnMac ? 2 : 3) * AdaptiveSize.boardScale)
                    }
            }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1 : 0.5)
        }
    }
}
