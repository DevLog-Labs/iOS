//
//  View+Alert.swift
//  PresentationShared
//
//  Created by opfic on 7/30/26.
//

import ComposableArchitecture
import SwiftUI

public extension View {
    @preconcurrency @MainActor
    @ViewBuilder
    func prominentAlert<State, Action, AlertAction>(
        _ store: Store<State, Action>,
        state: KeyPath<State, AlertState<AlertAction>?>,
        action: CaseKeyPath<Action, PresentationAction<AlertAction>>
    ) -> some View where State: ObservableState {
        modifier(
            ProminentAlertModifier(
                store: store,
                alertState: state,
                alertAction: action
            )
        )
    }
}

private struct ProminentAlertModifier<State, Action, AlertAction>: ViewModifier
where State: ObservableState {
    @Environment(\.isTabContentActive) private var isTabContentActive

    let store: Store<State, Action>
    let alertState: KeyPath<State, AlertState<AlertAction>?>
    let alertAction: CaseKeyPath<Action, PresentationAction<AlertAction>>

    @preconcurrency @MainActor
    func body(content: Content) -> some View {
        @Bindable var store = store
        let item = $store.scope(state: alertState, action: alertAction)
        let alertStore = item.wrappedValue
        let state = store.state[keyPath: alertState]
        let isPresented: Binding<Bool> = Binding(item).activePresentation(when: isTabContentActive)

        if #available(iOS 26, *) {
            content.alert(
                state.map(\.title).map(Text.init) ?? Text(verbatim: ""),
                isPresented: isPresented,
                presenting: state,
                actions: { state in
                    ForEach(state.buttons) { button in
                        let usesDefaultAction = state.usesDefaultAction(for: button)

                        Button(
                            role: state.buttonRole(for: button),
                            action: {
                                button.withAction { action in
                                    if let action {
                                        alertStore?.send(action)
                                    }
                                }
                            }
                        ) {
                            Text(button.label)
                        }
                        .keyboardShortcut(
                            usesDefaultAction ? .defaultAction : nil
                        )
                    }
                },
                message: {
                    $0.message.map(Text.init)
                }
            )
        } else {
            ZStack {
                content
                    .allowsHitTesting(!isPresented.wrappedValue)

                if let state, isTabContentActive {
                    Color.black.opacity(0.32)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    confirmationAlert(state) { button in
                        button.withAction { action in
                            if let action {
                                alertStore?.send(action)
                            }
                            isPresented.wrappedValue = false
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.18), value: isPresented.wrappedValue)
        }
    }

    private func confirmationAlert(
        _ state: AlertState<AlertAction>,
        onSelect: @escaping (ButtonState<AlertAction>) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(state.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)

                if let message = state.message {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(Color.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)

            Divider()

            HStack(spacing: 0) {
                ForEach(Array(state.buttons.enumerated()), id: \.element.id) { index, button in
                    if 0 < index {
                        Divider()
                    }

                    Button {
                        onSelect(button)
                    } label: {
                        Text(button.label)
                    }
                    .foregroundStyle(
                        state.usesDefaultAction(for: button)
                            ? Color.accent
                            : Color.secondaryLabel
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .font(.body)
            .frame(height: 56)
        }
        .frame(maxWidth: 420)
        .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.dialog))
        .clipShape(.rect(cornerRadius: CornerRadius.dialog))
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
    }
}

extension AlertState {
    func buttonRole(for button: ButtonState<Action>) -> ButtonRole? {
        if #available(iOS 26, *), usesDefaultAction(for: button) { return .confirm }
        if buttons.count == 1 { return nil }
        return button.role.map(ButtonRole.init)
    }

    func usesDefaultAction(for button: ButtonState<Action>) -> Bool {
        guard 1 < buttons.count else { return true }
        if let destructiveButton = buttons.first(where: { $0.role == .destructive }) {
            return destructiveButton.id == button.id
        }
        return buttons.last(where: { $0.role != .cancel })?.id == button.id
    }
}
