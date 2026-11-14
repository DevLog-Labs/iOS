//
//  View+Sheet.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

public enum SheetDetent: Equatable {
    case large
    case height(CGFloat)
    case fraction(CGFloat)
}

public extension View {
    // OS와 기기에 상관없이 같은 모양으로 직접 그리는 시트
    func prominentSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(
            ProminentPresentation(item: item) { item, isShown, dismiss in
                ProminentSheet(isShown: isShown, dismiss: dismiss) {
                    content(item)
                }
            }
        )
    }

    func prominentSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        prominentSheet(
            item: Binding(
                get: { isPresented.wrappedValue ? SheetPresence() : nil },
                set: { isPresented.wrappedValue = $0 != nil }
            )
        ) { _ in
            content()
        }
    }

    func sheetDetent(_ detent: SheetDetent) -> some View {
        preference(key: SheetDetentKey.self, value: detent)
    }

    func sheetDismissDisabled(_ isDisabled: Bool = true) -> some View {
        preference(key: SheetDismissDisabledKey.self, value: isDisabled)
    }
}

private struct SheetPresence: Identifiable {
    var id: Bool { true }
}

private struct SheetDetentKey: PreferenceKey {
    static let defaultValue = SheetDetent.large

    static func reduce(value: inout SheetDetent, nextValue: () -> SheetDetent) {
        if value == .large {
            value = nextValue()
        }
    }
}

private struct SheetDismissDisabledKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct ProminentSheet<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var detent = SheetDetent.large
    @State private var isDismissDisabled = false
    @State private var dragOffset = CGFloat.zero
    let isShown: Bool
    let dismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        // 넓은 화면은 가운데 대화상자, 좁은 화면은 아래에서 올라오는 시트
        let isDialog = horizontalSizeClass == .regular

        GeometryReader { proxy in
            ZStack(alignment: isDialog ? .center : .bottom) {
                if isShown {
                    Color.dimming
                        .ignoresSafeArea()
                        .overlay { dismissArea }
                        .transition(.opacity)

                    if isDialog {
                        dialog(in: proxy)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                    } else {
                        bottomSheet(in: proxy)
                            .transition(.move(edge: .bottom))

                        // 내용의 목록·내비게이션 막대가 옆 안전 영역(Duo 레일)까지 넓어져 탭을 가로채므로
                        // 그 위에 닫기 영역을 올림
                        HStack(spacing: 0) {
                            dismissArea
                                .frame(width: proxy.safeAreaInsets.leading)
                            Spacer(minLength: 0)
                            dismissArea
                                .frame(width: proxy.safeAreaInsets.trailing)
                        }
                        .ignoresSafeArea()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onPreferenceChange(SheetDetentKey.self) { detent = $0 }
        .onPreferenceChange(SheetDismissDisabledKey.self) { isDismissDisabled = $0 }
    }

    private func dialog(in proxy: GeometryProxy) -> some View {
        let margin = CGFloat(16)
        let maxHeight = min(proxy.size.height - margin * 2, 600)

        return content
            // 시스템 시트처럼 내용은 좁은 화면 배치로 그림
            .environment(\.horizontalSizeClass, .compact)
            .frame(width: min(520, proxy.size.width - margin * 2), height: height(of: detent, in: maxHeight))
            .background(Color.secondaryBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.dialog))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.dialog)
                    .strokeBorder(Color.separator)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.12), radius: 30, y: 24)
    }

    private func bottomSheet(in proxy: GeometryProxy) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: CornerRadius.sheet, topTrailingRadius: CornerRadius.sheet)
        let bottomInset = proxy.safeAreaInsets.bottom

        return content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 아래 안전 영역까지 시트 바탕을 깔고, 내용은 안전 영역 위에 둠
            .safeAreaPadding(.bottom, bottomInset)
            .frame(height: height(of: detent, in: proxy.size.height - 10) + bottomInset)
            .background(Color.secondaryBackground)
            .clipShape(shape)
            .overlay {
                // 위쪽 테두리만 보이도록 양옆과 아래 선은 화면 밖으로 밀어냄
                shape
                    .strokeBorder(Color.separator)
                    .padding([.horizontal, .bottom], -1)
            }
            .overlay(alignment: .top) {
                grabber
            }
            .offset(y: dragOffset)
            .ignoresSafeArea(edges: .bottom)
    }

    private var dismissArea: some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture {
                if !isDismissDisabled {
                    dismiss()
                }
            }
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.sheetGrabber)
            .frame(width: 36, height: 5)
            .padding(.top, 6)
            .frame(width: 120, height: 20, alignment: .top)
            .contentShape(.rect)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !isDismissDisabled else { return }
                        dragOffset = max(value.translation.height, 0)
                    }
                    .onEnded { value in
                        if !isDismissDisabled, 80 < max(value.translation.height, value.predictedEndTranslation.height) {
                            dismiss()
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }

    private func height(of detent: SheetDetent, in maxHeight: CGFloat) -> CGFloat {
        switch detent {
        case .large:
            maxHeight
        case .height(let height):
            min(height, maxHeight)
        case .fraction(let fraction):
            maxHeight * fraction
        }
    }
}
