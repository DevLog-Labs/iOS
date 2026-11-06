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
    @ScaledMetric(relativeTo: .headline) private var buttonLabelHeight = CGFloat(40)
    let hasDraft: Bool
    let isDisabled: Bool
    let onAddRecord: () -> Void
    let onContinueRecord: () -> Void

    var body: some View {
        Group {
            if hasDraft {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        secondaryAddRecordButton
                        continueRecordButton
                    }
                    VStack(alignment: .trailing, spacing: 8) {
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
        .padding(.vertical, 12)
        .background(deviceType == .duo ? Color.appBackground : .surface, ignoresSafeAreaEdges: .bottom)
    }

    private var secondaryAddRecordButton: some View {
        Button(action: onAddRecord) {
            Text(RecordPresentation.text("development_record_add"))
                .font(.callout)
                .foregroundStyle(Color.accent)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity)
                .frame(height: buttonLabelHeight)
        }
        .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: 16), color: .primaryContainer)
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
                .font(.headline)
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity)
                .frame(height: buttonLabelHeight)
        }
        .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: 16), color: .accent)
        .disabled(isDisabled)
    }
}
