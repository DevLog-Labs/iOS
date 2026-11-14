//
//  DropdownMenu.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

public struct DropdownMenuSection {
    let title: String?
    let items: [DropdownMenuItem]

    public init(_ title: String? = nil, items: [DropdownMenuItem]) {
        self.title = title
        self.items = items
    }
}

public struct DropdownMenuItem {
    enum Kind {
        case action(() -> Void)
        case submenu([DropdownMenuSection])
    }

    let title: String
    let systemImage: String?
    let imageColor: Color?
    let isChecked: Bool
    let role: ButtonRole?
    let kind: Kind

    public init(
        _ title: String,
        systemImage: String? = nil,
        imageColor: Color? = nil,
        isChecked: Bool = false,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.imageColor = imageColor
        self.isChecked = isChecked
        self.role = role
        self.kind = .action(action)
    }

    public init(
        _ title: String,
        systemImage: String? = nil,
        imageColor: Color? = nil,
        submenu: [DropdownMenuSection]
    ) {
        self.title = title
        self.systemImage = systemImage
        self.imageColor = imageColor
        self.isChecked = false
        self.role = nil
        self.kind = .submenu(submenu)
    }
}

// OS와 기기에 상관없이 같은 모양으로 직접 그리는 메뉴
public struct DropdownMenu<Label: View>: View {
    @State private var isLocalPresented = false
    @State private var anchor = CGRect.zero
    private let isPresented: Binding<Bool>?
    private let sections: [DropdownMenuSection]
    private let label: Label

    public init(
        isPresented: Binding<Bool>? = nil,
        sections: [DropdownMenuSection],
        @ViewBuilder label: () -> Label
    ) {
        self.isPresented = isPresented
        self.sections = sections
        self.label = label()
    }

    public var body: some View {
        let presented = isPresented ?? $isLocalPresented

        Button {
            setPresented(true, binding: presented)
        } label: {
            label
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            anchor = frame
        }
        .fullScreenCover(isPresented: presented) {
            DropdownMenuPanel(anchor: $anchor, sections: sections) {
                setPresented(false, binding: presented)
            }
            .presentationBackground(.clear)
        }
    }

    // 시스템 전체 화면 표시 애니메이션 없이 메뉴만 바로 표시
    private func setPresented(_ value: Bool, binding: Binding<Bool>) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            binding.wrappedValue = value
        }
    }
}

private struct DropdownMenuPanel: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @State private var height = CGFloat.zero
    @State private var submenu: DropdownMenuItem?
    @Binding var anchor: CGRect
    let sections: [DropdownMenuSection]
    let dismiss: () -> Void

    var body: some View {
        let width = CGFloat(isiOSAppOnMac ? 200 : 250)
        let radius = CGFloat(isiOSAppOnMac ? 10 : 14)
        let spacing = CGFloat(6)
        let margin = CGFloat(16)

        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(.rect)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                let below = frame.maxY - anchor.maxY - spacing - margin
                let above = anchor.minY - frame.minY - spacing - margin
                let opensBelow = height <= below || above <= below
                let visibleHeight = min(height, max(opensBelow ? below : above, 0))
                let leading = min(max(anchor.minX - frame.minX, margin), frame.width - width - margin)
                let top = opensBelow
                    ? anchor.maxY - frame.minY + spacing : anchor.minY - frame.minY - spacing - visibleHeight

                ScrollView {
                    content
                        .padding(4)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { value in
                            height = value
                        }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .frame(width: width, height: visibleHeight)
                .background(Color.surface, in: .rect(cornerRadius: radius))
                .overlay {
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(Color.border, lineWidth: 1)
                }
                .clipShape(.rect(cornerRadius: radius))
                .shadow(color: Color.black.opacity(0.4), radius: 16, y: 12)
                .offset(x: leading, y: top)
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let submenu, case .submenu(let sections) = submenu.kind {
                DropdownMenuRow(
                    title: submenu.title,
                    systemImage: "chevron.left",
                    imageColor: Color.textSecondary
                ) {
                    self.submenu = nil
                }
                DropdownMenuDivider()
                DropdownMenuSections(sections: sections, onSelect: select)
            } else {
                DropdownMenuSections(sections: sections, onSelect: select)
            }
        }
    }

    private func select(_ item: DropdownMenuItem) {
        switch item.kind {
        case .action(let action):
            dismiss()
            action()
        case .submenu:
            submenu = item
        }
    }
}

private struct DropdownMenuSections: View {
    let sections: [DropdownMenuSection]
    let onSelect: (DropdownMenuItem) -> Void

    var body: some View {
        // 항목이 없는 묶음은 제목과 구분선까지 생략
        ForEach(Array(sections.filter { !$0.items.isEmpty }.enumerated()), id: \.offset) { index, section in
            if 0 < index {
                DropdownMenuDivider()
            }

            if let title = section.title {
                DropdownMenuSectionTitle(title: title)
            }

            ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                DropdownMenuRow(item: item) {
                    onSelect(item)
                }
            }
        }
    }
}

private struct DropdownMenuSectionTitle: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: isiOSAppOnMac ? 11.5 : 13, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: isiOSAppOnMac ? 24 : 30, alignment: .leading)
            .padding(.horizontal, isiOSAppOnMac ? 10 : 14)
    }
}

private struct DropdownMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.border)
            .frame(height: 1)
            .padding(.vertical, 4)
            .padding(.horizontal, -4)
    }
}

private struct DropdownMenuRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let title: String
    let systemImage: String?
    let imageColor: Color?
    let isChecked: Bool
    let isDestructive: Bool
    let hasSubmenu: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String?,
        imageColor: Color?,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.imageColor = imageColor
        self.isChecked = false
        self.isDestructive = false
        self.hasSubmenu = false
        self.action = action
    }

    init(item: DropdownMenuItem, action: @escaping () -> Void) {
        self.title = item.title
        self.systemImage = item.systemImage
        self.imageColor = item.imageColor
        self.isChecked = item.isChecked
        self.isDestructive = item.role == .destructive
        if case .submenu = item.kind {
            self.hasSubmenu = true
        } else {
            self.hasSubmenu = false
        }
        self.action = action
    }

    var body: some View {
        let iconSize = CGFloat(isiOSAppOnMac ? 14 : 18)

        Button {
            action()
        } label: {
            HStack(spacing: isiOSAppOnMac ? 8 : 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: iconSize * 0.8))
                        .foregroundStyle(isDestructive ? Color.danger : imageColor ?? .textSecondary)
                        .frame(width: iconSize, height: iconSize)
                }

                Text(title)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: iconSize * 0.8, weight: .semibold))
                        .foregroundStyle(Color.accent)
                } else if hasSubmenu {
                    Image(systemName: "chevron.right")
                        .font(.system(size: iconSize * 0.7, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .font(.system(size: isiOSAppOnMac ? 13 : 15))
            .foregroundStyle(isDestructive ? Color.danger : .primary)
            .frame(maxWidth: .infinity, minHeight: isiOSAppOnMac ? 28 : 44)
            .padding(.horizontal, isiOSAppOnMac ? 10 : 14)
            .contentShape(.rect)
        }
        .buttonStyle(DropdownMenuRowStyle(radius: isiOSAppOnMac ? 8 : 10))
    }
}

private struct DropdownMenuRowStyle: ButtonStyle {
    let radius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        Highlight(configuration: configuration, radius: radius)
    }

    private struct Highlight: View {
        @State private var isHovered = false
        let configuration: Configuration
        let radius: CGFloat

        var body: some View {
            configuration.label
                .background(
                    configuration.isPressed || isHovered ? Color.controlBackground : .clear,
                    in: .rect(cornerRadius: radius)
                )
                .onHover { isHovered = $0 }
        }
    }
}
