//
//  ReadableContentWidthReader.swift
//  Entry
//
//  Created by opfic on 11/25/26.
//

import SwiftUI

// 화면 영역의 readableContentGuide 폭 전달
struct ReadableContentWidthReader: UIViewRepresentable {
    let action: (CGFloat) -> Void

    func makeUIView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ReaderView, context: Context) {
        uiView.action = action
    }

    final class ReaderView: UIView {
        var action: ((CGFloat) -> Void)?
        private var width: CGFloat?

        override func layoutSubviews() {
            super.layoutSubviews()
            let width = readableContentGuide.layoutFrame.width
            guard width != self.width else { return }
            self.width = width
            // 레이아웃 중 상태 변경 방지
            DispatchQueue.main.async { [action] in
                action?(width)
            }
        }
    }
}
