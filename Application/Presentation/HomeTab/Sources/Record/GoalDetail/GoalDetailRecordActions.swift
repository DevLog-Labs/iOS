//
//  GoalDetailRecordActions.swift
//  Development
//
//  Created by opfic on 9/15/26.
//

import SwiftUI
import PresentationShared

struct GoalDetailRecordActionBar: View {
    @Environment(\.deviceType) private var deviceType
    @ScaledMetric(relativeTo: .headline) private var buttonLabelHeight = 40 * AdaptiveSize.scale
    let hasDraft: Bool
    let isDisabled: Bool
    let onAddRecord: () -> Void
    let onContinueRecord: () -> Void

    var body: some View {
        Group {
            if hasDraft {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12 * AdaptiveSize.scale) {
                        secondaryAddRecordButton
                        continueRecordButton
                    }
                    VStack(alignment: .trailing, spacing: 8 * AdaptiveSize.scale) {
                        secondaryAddRecordButton
                        continueRecordButton
                    }
                }
            } else {
                primaryRecordButton(
                    RecordPresentation.text("development_record_add"),
                    action: onAddRecord
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12 * AdaptiveSize.scale)
        .background(deviceType == .duo ? Color.background : .secondaryBackground, ignoresSafeAreaEdges: .bottom)
    }

    private var secondaryAddRecordButton: some View {
        Button(action: onAddRecord) {
            Text(RecordPresentation.text("development_record_add"))
                .font(.adaptive(.callout))
                .foregroundStyle(Color.accent)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity)
                .frame(height: buttonLabelHeight)
        }
        .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: CornerRadius.control), color: .tintFill)
        .disabled(isDisabled)
    }

    private var continueRecordButton: some View {
        primaryRecordButton(
            RecordPresentation.text("development_record_continue"),
            action: onContinueRecord
        )
    }

    private func primaryRecordButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.adaptive(.headline))
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity)
                .frame(height: buttonLabelHeight)
        }
        .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: CornerRadius.control), color: .accent)
        .disabled(isDisabled)
    }
}
