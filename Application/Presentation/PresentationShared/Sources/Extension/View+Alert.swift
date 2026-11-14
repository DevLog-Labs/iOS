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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.isTabContentActive) private var isTabContentActive

    let store: Store<State, Action>
    let alertState: KeyPath<State, AlertState<AlertAction>?>
    let alertAction: CaseKeyPath<Action, PresentationAction<AlertAction>>

    @preconcurrency @MainActor
    func body(content: Content) -> some View {
        @Bindable var store = store
        let item = $store.scope(state: alertState, action: alertAction)
            .activePresentation(when: isTabContentActive)
        let alert = Binding(
            get: {
                item.wrappedValue.flatMap { alertStore in
                    store.state[keyPath: alertState].map { PresentedAlert(state: $0, store: alertStore) }
                }
            },
            set: { alert in
                if alert == nil {
                    item.wrappedValue = nil
                }
            }
        )

        content
            .modifier(
                ProminentPresentation(item: alert) { alert, isShown, dismiss in
                    ZStack {
                        if isShown {
                            Color.dimming
                                .ignoresSafeArea()
                                .transition(.opacity)

                            confirmationAlert(alert.state) { button in
                                button.withAction { action in
                                    if let action {
                                        alert.store.send(action)
                                    }
                                    dismiss()
                                }
                            }
                            .padding(.horizontal, 20)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                        }
                    }
                }
            )
    }

    private func confirmationAlert(
        _ state: AlertState<AlertAction>,
        onSelect: @escaping (ButtonState<AlertAction>) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(state.title)
                .font(isiOSAppOnMac ? .system(size: 14, weight: .bold) : .headline.weight(.bold))
                .foregroundStyle(Color.label)
                .fixedSize(horizontal: false, vertical: true)

            if let message = state.message {
                Text(message)
                    .font(isiOSAppOnMac ? .system(size: 13) : .subheadline)
                    .foregroundStyle(Color.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

            HStack(spacing: 8) {
                ForEach(state.buttons) { button in
                    let usesDefaultAction = state.usesDefaultAction(for: button)

                    Button {
                        onSelect(button)
                    } label: {
                        Text(button.label)
                            .font(isiOSAppOnMac ? .system(size: 13, weight: .semibold) : .subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: isiOSAppOnMac ? 32 : 44)
                            .background(
                                usesDefaultAction ? Color.clear : .tertiaryBackground,
                                in: .rect(cornerRadius: CornerRadius.control)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: CornerRadius.control)
                                    .strokeBorder(Color.secondarySeparator)
                            }
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        button.role == .destructive
                            ? Color.danger : usesDefaultAction ? .accent : .label
                    )
                    .keyboardShortcut(
                        usesDefaultAction
                            ? .defaultAction : button.role == .cancel ? .cancelAction : nil
                    )
                }
            }
            .padding(.top, 20)
        }
        .padding(20)
        .frame(maxWidth: isiOSAppOnMac || horizontalSizeClass == .compact ? 300 : 320, alignment: .leading)
        .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.dialog))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.dialog)
                .strokeBorder(Color.separator)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.12), radius: 30, y: 24)
    }
}

private struct PresentedAlert<Action>: Identifiable {
    let state: AlertState<Action>
    let store: Store<AlertState<Action>, Action>

    var id: AlertState<Action>.ID { state.id }
}

extension AlertState {
    func usesDefaultAction(for button: ButtonState<Action>) -> Bool {
        guard 1 < buttons.count else { return true }
        if let destructiveButton = buttons.first(where: { $0.role == .destructive }) {
            return destructiveButton.id == button.id
        }
        return buttons.last(where: { $0.role != .cancel })?.id == button.id
    }
}
