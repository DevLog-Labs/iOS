//
//  UIKitTextEditor.swift
//  PresentationShared
//
//  Created by opfic on 3/18/26.
//

import SwiftUI
import UIComposable

public final class UIKitTextEditor: UITextView, UICoordinatedComposable {
    private var textBinding: Binding<String>?
    private var isEditorFocused = false
    private var onFocusChange: ((Bool) -> Void)?
    private var placeholder: String?

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func connect(coordinator: Coordinator) {
        delegate = coordinator
        coordinator.textView = self
        configureAppearance()
    }

    public func update(coordinator: Coordinator) {
        coordinator.update()
    }

    public func disconnect(coordinator: Coordinator) {
        if delegate === coordinator {
            delegate = nil
        }
        coordinator.disconnect()
    }

    public func updateInput(
        text: Binding<String>,
        isFocused: Bool,
        onFocusChange: @escaping (Bool) -> Void,
        placeholder: String? = nil,
        isEnabled: Bool = true
    ) {
        textBinding = text
        isEditorFocused = isFocused
        self.onFocusChange = onFocusChange
        self.placeholder = placeholder
        isEditable = isEnabled
        isSelectable = isEnabled
    }

    public static func fittingSize(
        proposal: ProposedViewSize,
        textEditor: UIKitTextEditor
    ) -> CGSize? {
        guard let width = proposal.width, width.isFinite, 0 < width else { return nil }

        let size = textEditor.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        let proposedHeight = proposal.height ?? 0
        let height = proposedHeight.isFinite ? max(size.height, proposedHeight) : size.height
        return CGSize(width: width, height: height)
    }

    private func configureAppearance() {
        // 기기 글자 크기 설정과 관계없이 앱과 같은 기본 글자 크기로 고정
        font = AdaptiveSize.macFontSize(.body).map { UIFont.systemFont(ofSize: $0) }
            ?? UIFont.preferredFont(
                forTextStyle: .body,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
            )
        backgroundColor = .clear
        textColor = .label
        tintColor = .tintColor
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = true
        textContainer.lineBreakMode = .byWordWrapping
        textContainerInset = .zero
        isScrollEnabled = false
        autocorrectionType = .no
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    public final class Coordinator: NSObject, UITextViewDelegate {
        weak var textView: UIKitTextEditor?
        private weak var scrollView: UIScrollView?
        private var offsetObservation: NSKeyValueObservation?
        private var trackedOffset: CGPoint?
        private var isRestoringOffset = false

        func update() {
            guard let textView, let textBinding = textView.textBinding else { return }

            if !isShowingPlaceholder(in: textView) && textView.text != textBinding.wrappedValue {
                textView.text = textBinding.wrappedValue
            }

            applyPlaceholderIfNeeded(to: textView)

            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }

                if textView.isEditorFocused {
                    if !textView.isFirstResponder {
                        self.startTrackingOffset(for: textView)
                        textView.becomeFirstResponder()
                    }
                } else if textView.isFirstResponder {
                    textView.resignFirstResponder()
                }
            }
        }

        func disconnect() {
            stopTrackingOffset()
            textView = nil
        }

        public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
            startTrackingOffset(for: textView)
            return true
        }

        public func textViewDidBeginEditing(_ textView: UITextView) {
            guard let textView = textView as? UIKitTextEditor else { return }

            if isShowingPlaceholder(in: textView) {
                textView.text = nil
                textView.textColor = .label
            }

            if !textView.isEditorFocused {
                textView.isEditorFocused = true
                textView.onFocusChange?(true)
            }

            restoreOffsetIfNeeded()

            DispatchQueue.main.async { [weak self] in
                self?.restoreOffsetIfNeeded()
            }
        }

        public func textViewDidChange(_ textView: UITextView) {
            guard let textView = textView as? UIKitTextEditor else { return }

            stopTrackingOffset()
            textView.textBinding?.wrappedValue = textView.text
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            guard let textView = textView as? UIKitTextEditor else { return }

            if textView.isEditorFocused {
                textView.isEditorFocused = false
                textView.onFocusChange?(false)
            }

            stopTrackingOffset()
            applyPlaceholderIfNeeded(to: textView)
        }

        func applyPlaceholderIfNeeded(to textView: UIKitTextEditor) {
            guard let textBinding = textView.textBinding,
                  let placeholder = textView.placeholder else { return }

            if textBinding.wrappedValue.isEmpty && !textView.isFirstResponder {
                textView.text = placeholder
                textView.textColor = .placeholderText
            } else if isShowingPlaceholder(in: textView) {
                textView.text = textBinding.wrappedValue
                textView.textColor = .label
            }
        }

        func isShowingPlaceholder(in textView: UITextView) -> Bool {
            textView.textColor == .placeholderText
        }

        func startTrackingOffset(for textView: UITextView) {
            stopObservingOffset()
            scrollView = textView.enclosingScrollView
            trackedOffset = scrollView?.contentOffset
            observeOffsetIfNeeded()
        }

        func restoreOffsetIfNeeded() {
            guard let scrollView, let trackedOffset else { return }

            if scrollView.contentOffset != trackedOffset {
                isRestoringOffset = true
                scrollView.setContentOffset(trackedOffset, animated: false)
                isRestoringOffset = false
            }
        }

        func observeOffsetIfNeeded() {
            guard let scrollView else { return }

            offsetObservation = scrollView.observe(
                \.contentOffset,
                options: [.new]
            ) { [weak self] scrollView, _ in
                self?.handleOffsetChange(in: scrollView)
            }
        }

        func handleOffsetChange(in scrollView: UIScrollView) {
            guard let trackedOffset else {
                stopObservingOffset()
                return
            }

            if scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
                stopTrackingOffset()
                return
            }

            if isRestoringOffset {
                return
            }

            if scrollView.contentOffset != trackedOffset {
                restoreOffsetIfNeeded()
            }
        }

        func stopObservingOffset() {
            offsetObservation?.invalidate()
            offsetObservation = nil
        }

        func stopTrackingOffset() {
            stopObservingOffset()
            scrollView = nil
            trackedOffset = nil
        }

    }
}

/// 안내 문구와 편집기를 순서대로 배치하고 남은 최소 높이를 편집기에 제안합니다.
public struct TextEditorContentLayout: Layout {
    private let minimumHeight: CGFloat
    // Mac 작성 칸처럼 안내 문구를 편집기 아래에 둘지 여부
    private let placesHintBelow: Bool
    private let spacing = CGFloat(8)

    public init(minimumHeight: CGFloat, placesHintBelow: Bool = false) {
        self.minimumHeight = max(0, minimumHeight)
        self.placesHintBelow = placesHintBelow
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }

        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
            ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let hintSize = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil))
        let editorSize = subviews[1].sizeThatFits(ProposedViewSize(
            width: width,
            height: max(0, minimumHeight - hintSize.height - spacing)
        ))

        return CGSize(width: width, height: max(minimumHeight, hintSize.height + spacing + editorSize.height))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }

        let hintProposal = ProposedViewSize(width: bounds.width, height: nil)
        let hintSize = subviews[0].sizeThatFits(hintProposal)
        let editorHeight = max(0, bounds.height - hintSize.height - spacing)
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: placesHintBelow ? bounds.minY + editorHeight + spacing : bounds.minY),
            anchor: .topLeading,
            proposal: hintProposal
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: placesHintBelow ? bounds.minY : bounds.minY + hintSize.height + spacing),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: editorHeight)
        )
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var currentSuperview = superview

        while let view = currentSuperview {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }

            currentSuperview = view.superview
        }

        return nil
    }
}
