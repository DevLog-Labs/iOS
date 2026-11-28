//
//  CompositionContainer.swift
//  PresentationShared
//
//  Created by opfic on 11/27/26.
//

import SwiftUI

// 좁은 창에서 띄우는 컨테이너
public enum CompositionNarrow {
    case sheet
    case cover
    case push
}

public extension View {
    // 읽는 화면
    // 좁은 창은 내비게이션에 쌓거나 시트로 띄우고, 사이드바가 있는 창은 사이드바까지 덮는 상세 판으로 띄움
    // inPane이 참이면 사이드바가 있는 창에서 상세 판 대신 이 화면을 감싼 PaneSplitView의 상세 칸에 올림
    // emptyPane이 참이면 고른 항목이 없어도 상세 칸에 안내를 올림
    // isActive가 거짓이면 창 위에 덮는 시트와 상세 판은 띄우지 않고, 내비게이션에 쌓은 화면과 상세 칸은 그대로 둠
    // content는 상세 칸에 그릴 때만 닫는 동작을 받음
    func compositionDetail<Item: Identifiable, Content: View, Panel: View>(
        item: Binding<Item?>,
        narrow: CompositionNarrow = .push,
        inPane: Bool = false,
        emptyPane: Bool = false,
        isActive: Bool = true,
        @ViewBuilder content: @escaping (Item, (() -> Void)?) -> Content,
        @ViewBuilder panel: @escaping (Item) -> Panel
    ) -> some View {
        modifier(CompositionDetailModifier(
            item: item,
            narrow: narrow,
            inPane: inPane,
            emptyPane: emptyPane,
            isActive: isActive,
            detail: content,
            panel: panel
        ))
    }

    // 저장이나 닫기 버튼으로만 닫는 작성 화면
    // 좁은 창은 전체 화면이나 시트로 띄우고, 사이드바가 있는 창은 이 화면을 감싼 PaneSplitView의 상세 칸에 올림
    // 상세 칸에는 읽는 화면보다 작성 화면을 먼저 올리고, 작성 화면끼리는 바깥에 붙인 수정자의 화면을 올림
    // inPane이 거짓이면 사이드바가 있는 창에서도 시트로 띄움
    // isActive가 거짓이면 창 위에 띄우지 않고 상세 칸은 그대로 둠
    // content는 상세 칸에 그릴 때만 닫는 동작을 받음
    func compositionEditor<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        narrow: CompositionNarrow = .cover,
        inPane: Bool = true,
        isActive: Bool = true,
        @ViewBuilder content: @escaping (Item, (() -> Void)?) -> Content
    ) -> some View {
        modifier(CompositionEditorModifier(
            item: item,
            narrow: narrow,
            inPane: inPane,
            isActive: isActive,
            editor: content
        ))
    }

    // 바꾸면 바로 저장하는 시트
    // 좁은 창은 시트로 띄우고, 사이드바가 있는 창은 SplitShell 오른쪽 세부 정보 사이드바에 표시
    // reveal이 바뀌면 사이드바가 있는 창에서 닫힌 세부 정보 사이드바를 엶
    func compositionSheet<Item: Identifiable, Sheet: View, Right: View>(
        item: Binding<Item?>,
        reveal: Int = 0,
        @ViewBuilder sheet: @escaping (Item) -> Sheet,
        @ViewBuilder right: @escaping (Item) -> Right
    ) -> some View {
        modifier(CompositionSheetModifier(item: item, reveal: reveal, sheet: sheet, right: right))
    }

    // 좁은 창은 시트로 띄우거나 내비게이션에 쌓고, 사이드바가 있는 창은 이 화면 대신 내비게이션 루트에 그림
    // isActive가 거짓이면 좁은 창에서 띄우지 않음
    // closesRight가 참이면 사이드바가 있는 창에서 닫거나 탭 화면을 벗어날 때 세부 정보 사이드바도 닫음
    // 창 폭이 바뀌어 시트와 루트를 오갈 때는 상태가 남아 닫지 않음
    func compositionCenter<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        narrow: CompositionNarrow,
        isActive: Bool = true,
        closesRight: Bool = false,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(CompositionCenterModifier(
            item: item,
            narrow: narrow,
            isActive: isActive,
            closesRight: closesRight,
            center: content
        ))
    }

    // 고르는 화면
    // 좁은 창은 시트로 띄우고, 칸으로 나눈 화면은 compositionPickerAnchor를 붙인 버튼 옆 팝오버로 띄움
    // maxHeight가 없으면 팝오버를 내용 높이에 맞춤
    func compositionPicker<Content: View>(
        isPresented: Binding<Bool>,
        isActive: Bool = true,
        arrowEdge: Edge? = nil,
        maxHeight: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(CompositionPickerModifier(
            isPresented: isPresented,
            isActive: isActive,
            arrowEdge: arrowEdge,
            maxHeight: maxHeight,
            picker: content
        ))
    }

    // 바깥의 compositionPicker가 칸으로 나눈 화면에서 띄우는 팝오버를 붙일 버튼
    func compositionPickerAnchor() -> some View {
        modifier(CompositionPickerAnchorModifier())
    }
}

// 창 폭이 바뀐 뒤 시스템이 표시할 때 받아 둔 바인딩으로 늦게 닫아도 지금 창 폭으로 거르도록 참조로 보관하는 값
private final class LiveLayout {
    private(set) var usesDesktopLayout = false
    private(set) var usesPaneLayout = false
    private(set) var inPane = false

    // 그릴 때마다 지금 값으로 바꾸고 같은 참조를 돌려줌
    func update(usesDesktopLayout: Bool = false, usesPaneLayout: Bool = false, inPane: Bool = false) -> LiveLayout {
        self.usesDesktopLayout = usesDesktopLayout
        self.usesPaneLayout = usesPaneLayout
        self.inPane = inPane
        return self
    }
}

private struct CompositionDetailModifier<Item: Identifiable, Detail: View, Panel: View>: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @State private var layout = LiveLayout()
    @State private var id = UUID()
    let item: Binding<Item?>
    let narrow: CompositionNarrow
    let inPane: Bool
    let emptyPane: Bool
    let isActive: Bool
    let detail: (Item, (() -> Void)?) -> Detail
    let panel: (Item) -> Panel

    func body(content: Content) -> some View {
        // 창 폭이 바뀌면 같은 상태를 짝이 되는 컨테이너가 다시 그리고, 빠지는 쪽의 늦은 닫힘은 상태를 지우지 않음
        let layout = layout.update(usesDesktopLayout: usesDesktopLayout, inPane: inPane)
        let narrowItem = item.hiddenInPane { layout.usesDesktopLayout }
        let panelItem = item.activePresentation(when: isActive)
            .hiddenInPane { !layout.usesDesktopLayout || layout.inPane }

        narrowContent(content, item: narrowItem)
            .detailPanel(item: panelItem, content: panel)
            // 가려진 탭에서도 상세 칸을 그대로 두도록 isActive와 상관없이 올림
            .transformPreference(PaneDetailContentPreferenceKey.self) { value in
                guard inPane, value == nil, item.wrappedValue != nil || emptyPane else { return }
                value = PaneDetailContent(id: id, isEditor: false) {
                    AnyView(paneContent)
                }
            }
    }

    @ViewBuilder
    private func narrowContent(_ content: Content, item: Binding<Item?>) -> some View {
        switch narrow {
        case .push:
            content
                .navigationDestination(item: item, interactivePop: true) { detail($0, nil) }
        case .sheet:
            content
                .prominentSheet(item: item.activePresentation(when: isActive)) { detail($0, nil) }
        case .cover:
            content
                .fullScreenCover(item: item.activePresentation(when: isActive)) { detail($0, nil) }
        }
    }

    // 상세 칸이 그릴 때마다 지금 고른 항목을 읽음
    @ViewBuilder
    private var paneContent: some View {
        if let value = item.wrappedValue {
            detail(value, { item.wrappedValue = nil })
                .environment(\.showsPaneTitleBar, true)
        } else {
            PanePlaceholder()
        }
    }
}

private struct CompositionEditorModifier<Item: Identifiable, Editor: View>: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @State private var layout = LiveLayout()
    @State private var id = UUID()
    let item: Binding<Item?>
    let narrow: CompositionNarrow
    let inPane: Bool
    let isActive: Bool
    let editor: (Item, (() -> Void)?) -> Editor

    func body(content: Content) -> some View {
        // 넓은 창으로 바뀌어 칸에 옮겨 그린 뒤 늦게 닫히는 화면은 작성 중인 초안을 지우지 않음
        let layout = layout.update(usesDesktopLayout: usesDesktopLayout)
        let activeItem = item.activePresentation(when: isActive)
        let narrowItem = activeItem.hiddenInPane { layout.usesDesktopLayout }

        presentedContent(content, activeItem: activeItem, narrowItem: narrowItem, layout: layout)
            // 가려진 탭에서도 작성 중인 화면을 상세 칸에 그대로 두도록 isActive와 상관없이 올림
            .transformPreference(PaneDetailContentPreferenceKey.self) { value in
                guard inPane, item.wrappedValue != nil else { return }
                value = PaneDetailContent(id: id, isEditor: true) {
                    AnyView(paneContent)
                }
            }
    }

    @ViewBuilder
    private func presentedContent(
        _ content: Content,
        activeItem: Binding<Item?>,
        narrowItem: Binding<Item?>,
        layout: LiveLayout
    ) -> some View {
        switch (narrow, inPane) {
        case (.cover, true):
            content
                .fullScreenCover(item: narrowItem) { editor($0, nil) }
        case (.sheet, true):
            content
                .prominentSheet(item: narrowItem) { editor($0, nil) }
        case (.cover, false):
            content
                .fullScreenCover(item: narrowItem) { editor($0, nil) }
                .prominentSheet(item: activeItem.hiddenInPane { !layout.usesDesktopLayout }) { editor($0, nil) }
        case (.sheet, false):
            content
                .prominentSheet(item: activeItem) { editor($0, nil) }
        case (.push, _):
            content
                .navigationDestination(item: narrowItem, interactivePop: true) { editor($0, nil) }
        }
    }

    // 상세 칸이 그릴 때마다 지금 작성 중인 항목을 읽음
    @ViewBuilder
    private var paneContent: some View {
        if let value = item.wrappedValue {
            editor(value, { item.wrappedValue = nil })
        }
    }
}

private struct CompositionCenterModifier<Item: Identifiable, Center: View>: ViewModifier {
    @Environment(\.isTabContentActive) private var isTabContentActive
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.setDetailSideBarPresented) private var setDetailSideBarPresented
    @State private var layout = LiveLayout()
    let item: Binding<Item?>
    let narrow: CompositionNarrow
    let isActive: Bool
    let closesRight: Bool
    let center: (Item) -> Center

    func body(content: Content) -> some View {
        // 창 폭이 바뀌어도 좁은 창의 표시를 같은 화면에 두어, 넓어진 뒤 늦게 닫히는 표시가 상태를 지우지 않음
        let layout = layout.update(usesDesktopLayout: usesDesktopLayout)
        let narrowItem = item.activePresentation(when: isActive).hiddenInPane { layout.usesDesktopLayout }
        let isClosed = item.wrappedValue == nil
        let shown = Group {
            if usesDesktopLayout, let value = item.wrappedValue {
                center(value)
            } else {
                content
            }
        }

        presentedContent(shown, item: narrowItem)
            // 루트에 그린 화면을 닫거나 탭 화면을 벗어나면 그 화면이 보여 주던 세부 정보 사이드바도 닫음
            .onChange(of: isClosed) { _, isClosed in
                if closesRight && usesDesktopLayout && isClosed {
                    setDetailSideBarPresented?(false)
                }
            }
            .onChange(of: isTabContentActive) { _, isActive in
                if closesRight && usesDesktopLayout && !isActive && !isClosed {
                    setDetailSideBarPresented?(false)
                }
            }
    }

    @ViewBuilder
    private func presentedContent(_ shown: some View, item: Binding<Item?>) -> some View {
        switch narrow {
        case .sheet:
            shown
                .prominentSheet(item: item, content: center)
        case .cover:
            shown
                .fullScreenCover(item: item, content: center)
        case .push:
            shown
                .navigationDestination(item: item, interactivePop: true, destination: center)
        }
    }
}

private struct CompositionSheetModifier<Item: Identifiable, Sheet: View, Right: View>: ViewModifier {
    @Environment(\.isTabContentActive) private var isTabContentActive
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.setDetailSideBarPresented) private var setDetailSideBarPresented
    @State private var layout = LiveLayout()
    let item: Binding<Item?>
    let reveal: Int
    let sheet: (Item) -> Sheet
    let right: (Item) -> Right

    func body(content: Content) -> some View {
        // 넓은 창으로 바뀌어 세부 정보 사이드바로 옮긴 뒤 늦게 닫히는 시트는 고른 항목을 지우지 않음
        let layout = layout.update(usesDesktopLayout: usesDesktopLayout)

        content
            .prominentSheet(
                item: item.activePresentation(when: isTabContentActive)
                    .hiddenInPane { layout.usesDesktopLayout },
                content: sheet
            )
            // 고른 항목이 없으면 세부 정보 사이드바에 안내 표시
            .compositionRight(isActive: usesDesktopLayout) {
                if let value = item.wrappedValue {
                    right(value)
                } else {
                    DetailSideBarPlaceholder()
                }
            }
            .onChange(of: reveal) {
                if usesDesktopLayout {
                    setDetailSideBarPresented?(true)
                }
            }
    }
}

// compositionPicker가 compositionPickerAnchor에 넘기는 팝오버 내용
private struct CompositionPickerContent {
    let isPresented: Binding<Bool>
    let arrowEdge: Edge?
    let maxHeight: CGFloat?
    let content: () -> AnyView
}

private extension EnvironmentValues {
    var compositionPicker: CompositionPickerContent? {
        get { self[CompositionPickerKey.self] }
        set { self[CompositionPickerKey.self] = newValue }
    }

    private struct CompositionPickerKey: EnvironmentKey {
        static var defaultValue: CompositionPickerContent? { nil }
    }
}

private struct CompositionPickerModifier<Picker: View>: ViewModifier {
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @State private var layout = LiveLayout()
    let isPresented: Binding<Bool>
    let isActive: Bool
    let arrowEdge: Edge?
    let maxHeight: CGFloat?
    let picker: () -> Picker

    func body(content: Content) -> some View {
        // 창 폭이 바뀌어 팝오버와 시트를 오가면 같은 상태를 바뀐 쪽에 다시 그리고, 빠지는 쪽의 늦은 닫힘은 거름
        let layout = layout.update(usesPaneLayout: usesPaneLayout)
        let sheetBinding = Binding(
            get: { !layout.usesPaneLayout && isPresented.wrappedValue },
            set: { value in
                if !layout.usesPaneLayout {
                    isPresented.wrappedValue = value
                }
            }
        )
        let popoverBinding = Binding(
            get: { layout.usesPaneLayout && isPresented.wrappedValue },
            set: { value in
                if layout.usesPaneLayout {
                    isPresented.wrappedValue = value
                }
            }
        )

        content
            .prominentSheet(isPresented: sheetBinding.activePresentation(when: isActive)) {
                picker()
            }
            .environment(
                \.compositionPicker,
                CompositionPickerContent(
                    isPresented: popoverBinding.activePresentation(when: isActive),
                    arrowEdge: arrowEdge,
                    maxHeight: maxHeight
                ) {
                    AnyView(picker())
                }
            )
    }
}

private struct CompositionPickerAnchorModifier: ViewModifier {
    @Environment(\.compositionPicker) private var picker

    func body(content: Content) -> some View {
        content
            .popover(isPresented: picker?.isPresented ?? .constant(false), arrowEdge: picker?.arrowEdge) {
                if let picker {
                    Group {
                        // 화면이 낮거나 Duo 접는 선에 걸리면 팝오버 높이를 줄이고 목록을 스크롤
                        if let maxHeight = picker.maxHeight {
                            picker.content()
                                .frame(width: 320 * AdaptiveSize.boardScale)
                                .frame(minHeight: 0, idealHeight: maxHeight, maxHeight: maxHeight)
                        } else {
                            picker.content()
                                .frame(width: 320 * AdaptiveSize.boardScale)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .presentationBackground(Color.secondaryBackground)
                    .presentationCompactAdaptation(.popover)
                }
            }
    }
}
