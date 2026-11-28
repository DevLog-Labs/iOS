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
    // inPane이 참이면 사이드바가 있는 창에서 상세 판 대신 PaneSplitView의 detail이 그림
    // isActive가 거짓이면 창 위에 덮는 시트와 상세 판은 띄우지 않고, 내비게이션에 쌓은 화면은 그대로 둠
    func compositionDetail<Item: Identifiable, Content: View, Panel: View>(
        item: Binding<Item?>,
        narrow: CompositionNarrow = .push,
        inPane: Bool = false,
        isActive: Bool = true,
        @ViewBuilder content: @escaping (Item) -> Content,
        @ViewBuilder panel: @escaping (Item) -> Panel
    ) -> some View {
        modifier(CompositionDetailModifier(
            item: item,
            narrow: narrow,
            inPane: inPane,
            isActive: isActive,
            detail: content,
            panel: panel
        ))
    }

    // 저장이나 닫기 버튼으로만 닫는 작성 화면
    // 좁은 창은 전체 화면이나 시트로 띄우고, 사이드바가 있는 창은 PaneSplitView의 detail이 그림
    // inPane이 거짓이면 사이드바가 있는 창에서도 시트로 띄움
    func compositionEditor<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        narrow: CompositionNarrow = .cover,
        inPane: Bool = true,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(CompositionEditorModifier(item: item, narrow: narrow, inPane: inPane, editor: content))
    }

    // 바꾸면 바로 저장하는 시트
    // 좁은 창은 시트로 띄우고, 사이드바가 있는 창은 SplitShell 오른쪽 세부 정보 사이드바에 표시
    func compositionSheet<Item: Identifiable, Sheet: View, Right: View>(
        item: Binding<Item?>,
        @ViewBuilder sheet: @escaping (Item) -> Sheet,
        @ViewBuilder right: @escaping (Item) -> Right
    ) -> some View {
        modifier(CompositionSheetModifier(item: item, sheet: sheet, right: right))
    }

    // 좁은 창은 시트로 띄우거나 내비게이션에 쌓고, 사이드바가 있는 창은 이 화면 대신 내비게이션 루트에 그림
    // isActive가 거짓이면 좁은 창에서 띄우지 않음
    func compositionCenter<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        narrow: CompositionNarrow,
        isActive: Bool = true,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(CompositionCenterModifier(item: item, narrow: narrow, isActive: isActive, center: content))
    }
}

// 창 폭이 바뀐 뒤 시스템이 표시할 때 받아 둔 바인딩으로 늦게 닫아도 지금 창 폭으로 거르도록 참조로 보관하는 값
private final class LiveLayout {
    private(set) var usesDesktopLayout = false
    private(set) var inPane = false

    // 그릴 때마다 지금 값으로 바꾸고 같은 참조를 돌려줌
    func update(usesDesktopLayout: Bool, inPane: Bool = false) -> LiveLayout {
        self.usesDesktopLayout = usesDesktopLayout
        self.inPane = inPane
        return self
    }
}

private struct CompositionDetailModifier<Item: Identifiable, Detail: View, Panel: View>: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @State private var layout = LiveLayout()
    let item: Binding<Item?>
    let narrow: CompositionNarrow
    let inPane: Bool
    let isActive: Bool
    let detail: (Item) -> Detail
    let panel: (Item) -> Panel

    func body(content: Content) -> some View {
        // 창 폭이 바뀌면 같은 상태를 짝이 되는 컨테이너가 다시 그리고, 빠지는 쪽의 늦은 닫힘은 상태를 지우지 않음
        let layout = layout.update(usesDesktopLayout: usesDesktopLayout, inPane: inPane)
        let narrowItem = item.hiddenInPane { layout.usesDesktopLayout }
        let panelItem = item.activePresentation(when: isActive)
            .hiddenInPane { !layout.usesDesktopLayout || layout.inPane }

        switch narrow {
        case .push:
            content
                .navigationDestination(item: narrowItem, interactivePop: true, destination: detail)
                .detailPanel(item: panelItem, content: panel)
        case .sheet:
            content
                .prominentSheet(item: narrowItem.activePresentation(when: isActive), content: detail)
                .detailPanel(item: panelItem, content: panel)
        case .cover:
            content
                .fullScreenCover(item: narrowItem.activePresentation(when: isActive), content: detail)
                .detailPanel(item: panelItem, content: panel)
        }
    }
}

private struct CompositionEditorModifier<Item: Identifiable, Editor: View>: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @State private var layout = LiveLayout()
    let item: Binding<Item?>
    let narrow: CompositionNarrow
    let inPane: Bool
    let editor: (Item) -> Editor

    func body(content: Content) -> some View {
        // 넓은 창으로 바뀌어 칸에 옮겨 그린 뒤 늦게 닫히는 화면은 작성 중인 초안을 지우지 않음
        let layout = layout.update(usesDesktopLayout: usesDesktopLayout)
        let narrowItem = item.hiddenInPane { layout.usesDesktopLayout }

        switch (narrow, inPane) {
        case (.cover, true):
            content
                .fullScreenCover(item: narrowItem, content: editor)
        case (.sheet, true):
            content
                .prominentSheet(item: narrowItem, content: editor)
        case (.cover, false):
            content
                .fullScreenCover(item: narrowItem, content: editor)
                .prominentSheet(item: item.hiddenInPane { !layout.usesDesktopLayout }, content: editor)
        case (.sheet, false):
            content
                .prominentSheet(item: item, content: editor)
        case (.push, _):
            content
                .navigationDestination(item: narrowItem, interactivePop: true, destination: editor)
        }
    }
}

private struct CompositionCenterModifier<Item: Identifiable, Center: View>: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @State private var layout = LiveLayout()
    let item: Binding<Item?>
    let narrow: CompositionNarrow
    let isActive: Bool
    let center: (Item) -> Center

    func body(content: Content) -> some View {
        // 창 폭이 바뀌어도 좁은 창의 표시를 같은 화면에 두어, 넓어진 뒤 늦게 닫히는 표시가 상태를 지우지 않음
        let layout = layout.update(usesDesktopLayout: usesDesktopLayout)
        let narrowItem = item.activePresentation(when: isActive).hiddenInPane { layout.usesDesktopLayout }
        let shown = Group {
            if usesDesktopLayout, let value = item.wrappedValue {
                center(value)
            } else {
                content
            }
        }

        switch narrow {
        case .sheet:
            shown
                .prominentSheet(item: narrowItem, content: center)
        case .cover:
            shown
                .fullScreenCover(item: narrowItem, content: center)
        case .push:
            shown
                .navigationDestination(item: narrowItem, interactivePop: true, destination: center)
        }
    }
}

private struct CompositionSheetModifier<Item: Identifiable, Sheet: View, Right: View>: ViewModifier {
    @Environment(\.isTabContentActive) private var isTabContentActive
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @State private var layout = LiveLayout()
    let item: Binding<Item?>
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
    }
}
