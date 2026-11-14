//
//  ProminentPresentation.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

// 탭 바·사이드바까지 화면 전체를 덮는 표시 자리
struct ProminentPresentation<Item: Identifiable, Overlay: View>: ViewModifier {
    @State private var isCovered = false
    @State private var isShown = false
    @State private var presented: Item?
    let item: Binding<Item?>
    @ViewBuilder let overlay: (Item, Bool, @escaping () -> Void) -> Overlay

    func body(content: Content) -> some View {
        content
            .onChange(of: item.wrappedValue?.id, initial: true) { _, id in
                if id == nil {
                    hide()
                } else {
                    show()
                }
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { isCovered },
                    set: { isPresented in
                        // 내용 안에서 dismiss를 부르면 표시 상태도 함께 닫음
                        if !isPresented {
                            item.wrappedValue = nil
                        }
                    }
                ),
                onDismiss: {
                    if item.wrappedValue == nil {
                        presented = nil
                    }
                }
            ) {
                ZStack {
                    if let shown = item.wrappedValue ?? presented {
                        overlay(shown, isShown) {
                            item.wrappedValue = nil
                        }
                    }
                }
                .presentationBackground(.clear)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShown = true
                    }
                }
            }
    }

    private func show() {
        presented = item.wrappedValue
        guard !isCovered else { return }
        // 시스템 전체 화면 표시 애니메이션 없이 덮고, 나타나는 모양은 직접 그림
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isCovered = true
        }
    }

    // 다음 표시가 시스템 표시 순서를 기다리도록 닫힘은 바로 시작
    private func hide() {
        guard isCovered else { return }
        withAnimation(.easeIn(duration: 0.2)) {
            isShown = false
        }
        isCovered = false
    }
}
