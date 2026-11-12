//
//  View+ItemActions.swift
//  PresentationShared
//
//  Created by opfic on 9/23/26.
//

import SwiftUI
import ComposableArchitecture

public extension View {
    func itemActions<Actions: View>(@ViewBuilder content: () -> Actions) -> some View {
        modifier(ItemActionsModifier(actions: content()))
    }
}

public struct ItemActionButton: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac

    private let title: String
    private let color: Color
    private let image: Image
    private let action: () -> Void

    public init(
        title: String,
        color: Color,
        image: Image,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.color = color
        self.image = image
        self.action = action
    }

    public var body: some View {
        if isiOSAppOnMac {
            // Mac 우클릭 메뉴 항목은 아이콘과 제목 함께 표시
            Button(action: action) {
                Label {
                    Text(title)
                } icon: {
                    image
                }
            }
        } else {
            Button(action: action) {
                image
            }
            .buttonStyle(ItemActionButtonStyle(color: color))
        }
    }
}

private struct ItemActionsModifier<Actions: View>: ViewModifier {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @State private var store = Store(initialState: ItemActionsFeature.State()) {
        ItemActionsFeature()
    }
    let actions: Actions

    @ViewBuilder
    func body(content: Content) -> some View {
        if isiOSAppOnMac {
            content.contextMenu {
                actions
            }
        } else {
            let trayWidth = store.trayWidth

            ZStack(alignment: .trailing) {
                Group(subviews: actions) { subviews in
                    HStack(spacing: 8) {
                        ForEach(subviews) { subview in
                            subview
                                .background {
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key: ItemActionWidthsPreferenceKey.self,
                                            value: [geometry.size.width]
                                        )
                                    }
                                }
                        }
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, ItemActionsFeature.trailingPadding)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    store.send(.view(.setTrayWidth(width)))
                }
                .onPreferenceChange(ItemActionWidthsPreferenceKey.self) { widths in
                    store.send(.view(.setViewWidths(widths)))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .allowsHitTesting(store.isRevealed && !store.isDragging)
                .simultaneousGesture(TapGesture().onEnded {
                    withAnimation(.snappy) {
                        store.send(.view(.close))
                    }
                })

                content
                    .offset(x: max(
                        -trayWidth,
                        min(0, (store.isRevealed ? -trayWidth : 0) + store.dragTranslation)
                    ))
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            withAnimation(.snappy) {
                                store.send(.view(.close))
                            }
                        },
                        including: store.isRevealed ? .all : .none
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 12)
                            .onChanged { value in
                                store.send(.view(.changed(value.translation)))
                            }
                            .onEnded { value in
                                withAnimation(.snappy) {
                                    store.send(.view(.ended(value.translation.width)))
                                }
                            }
                    )
            }
            .clipped()
        }
    }
}

private struct ItemActionButtonStyle: ButtonStyle {
    @ScaledMetric(relativeTo: .body) private var size = 44

    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(color, in: .circle)
    }
}

private struct ItemActionWidthsPreferenceKey: PreferenceKey {
    static var defaultValue = [CGFloat]()

    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
        value.append(contentsOf: nextValue())
    }
}

@Reducer
private struct ItemActionsFeature {
    static let trailingPadding = CGFloat(16)

    @ObservableState
    struct State: Equatable {
        var trayWidth = CGFloat.zero
        var viewWidths = [CGFloat]()
        var isRevealed = false
        var isDragging = false
        var isScrolling = false
        var dragTranslation = CGFloat.zero
    }

    enum Action {
        case view(ViewAction)

        enum ViewAction {
            case setTrayWidth(CGFloat)
            case setViewWidths([CGFloat])
            case changed(CGSize)
            case ended(CGFloat)
            case close
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.setTrayWidth(let width)):
                state.trayWidth = width
            case .view(.setViewWidths(let widths)):
                state.viewWidths = widths
            case .view(.changed(let translation)):
                guard !state.isScrolling else { return .none }
                if !state.isDragging {
                    if abs(translation.width) <= abs(translation.height) {
                        state.isScrolling = true
                        return .none
                    }
                    state.isDragging = true
                }
                state.dragTranslation = translation.width
            case .view(.ended(let translation)):
                if state.isScrolling {
                    state.isScrolling = false
                    return .none
                }
                guard state.isDragging else { return .none }
                let wasRevealed = state.isRevealed
                let base = wasRevealed ? -state.trayWidth : 0
                let releasedOffset = max(-state.trayWidth, min(0, base + translation))
                let revealedWidth = max(0, -releasedOffset - Self.trailingPadding)
                if wasRevealed {
                    var fullyHiddenCount = 0
                    var trailingDistance = CGFloat.zero
                    for width in state.viewWidths.reversed() {
                        if revealedWidth <= trailingDistance {
                            fullyHiddenCount += 1
                        }
                        trailingDistance += width + 8
                    }
                    let requiredHiddenCount = (state.viewWidths.count + 1) / 2
                    state.isRevealed = !state.viewWidths.isEmpty
                        && fullyHiddenCount < requiredHiddenCount
                } else {
                    let firstVisibleWidth = state.viewWidths.last ?? 0
                    state.isRevealed = 0 < firstVisibleWidth
                        && firstVisibleWidth / 2 <= revealedWidth
                }
                state.isDragging = false
                state.dragTranslation = 0
            case .view(.close):
                state.isRevealed = false
            }
            return .none
        }
    }
}
