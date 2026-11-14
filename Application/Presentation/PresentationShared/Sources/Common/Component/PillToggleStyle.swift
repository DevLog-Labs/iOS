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
                Capsule()
                    .fill(configuration.isOn ? Color.accent : .switchOffFill)
                    .frame(width: 44, height: 24)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                            .shadow(color: Color.black.opacity(0.1), radius: 1.5, y: 1)
                            .padding(3)
                    }
            }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1 : 0.5)
        }
    }
}
