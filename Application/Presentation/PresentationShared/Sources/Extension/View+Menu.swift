//
//  View+Menu.swift
//  PresentationShared
//
//  Created by opfic on 9/14/26.
//

import SwiftUI

public struct ProminentMenuItem<Action: Hashable>: Identifiable {
    public let action: Action
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?

    public var id: Action { action }

    public init(
        action: Action,
        title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil
    ) {
        self.action = action
        self.title = title
        self.systemImage = systemImage
        self.role = role
    }
}

public extension View {
    func prominentMenu<Action: Hashable>(
        items: [ProminentMenuItem<Action>],
        isEnabled: Bool = true,
        onSelect: @escaping (Action) -> Void
    ) -> some View {
        ProminentMenu(
            label: self,
            items: items,
            isEnabled: isEnabled,
            onSelect: onSelect
        )
    }
}

private struct ProminentMenu<Label: View, Action: Hashable>: View {
    @State private var isPresented = false

    let label: Label
    let items: [ProminentMenuItem<Action>]
    let isEnabled: Bool
    let onSelect: (Action) -> Void

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            Menu {
                ForEach(items) { item in
                    Button(role: item.role) {
                        onSelect(item.action)
                    } label: {
                        menuItemLabel(item)
                    }
                }
            } label: {
                label
            }
            .disabled(!isEnabled)
        } else {
            Button {
                isPresented.toggle()
            } label: {
                label
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .popover(
                isPresented: $isPresented,
                attachmentAnchor: .point(.bottomTrailing),
                arrowEdge: .top
            ) {
                customMenu
                    .presentationCompactAdaptation(.popover)
                    .presentationBackground(Color.secondaryBackground)
            }
        }
    }

    private var customMenu: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if 0 < index {
                    Divider()
                }

                Button(role: item.role) {
                    isPresented = false
                    onSelect(item.action)
                } label: {
                    menuItemLabel(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .frame(minHeight: 52)
            }
        }
        .frame(minWidth: 220)
        .background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.menu))
        .compositingGroup()
        .clipShape(.rect(cornerRadius: CornerRadius.menu))
        .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
        .padding(8)
    }

    private func menuItemLabel(_ item: ProminentMenuItem<Action>) -> some View {
        HStack(spacing: 12) {
            if let systemImage = item.systemImage {
                Image(systemName: systemImage)
                    .frame(width: 22)
            }

            Text(item.title)
                .font(.body)

            Spacer(minLength: 0)
        }
        .foregroundStyle(item.role == .destructive ? Color.red : Color.primary)
    }
}
