//
//  RecordDetailView.swift
//  Development
//
//  Created by opfic on 9/13/26.
//

import SwiftUI
import Domain
import PresentationShared

public struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    private let onUpdate: () -> Void
    @State private var store: StoreOf<RecordDetailFeature>

    public init(
        goalTitle: String,
        record: DevelopmentRecord,
        allowsMutation: Bool = true,
        onUpdate: @escaping () -> Void = { }
    ) {
        self.onUpdate = onUpdate
        self._store = State(initialValue: Store(
            initialState: RecordDetailFeature.State(
                goalTitle: goalTitle,
                record: record,
                allowsMutation: allowsMutation
            )
        ) {
            RecordDetailFeature()
        })
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                switch store.contentState {
                case .draft(let draft):
                    recordContent(
                        title: draft.title,
                        markdownContent: draft.markdownContent,
                        version: nil
                    )
                case .loaded:
                    if let version = store.currentVersion {
                        recordContent(
                            title: version.title,
                            markdownContent: version.markdownContent,
                            version: version
                        )
                        if store.allowsMutation {
                            actionSection
                        } else {
                            historyButton
                        }
                    }
                case .failed:
                    failureContent
                case .idle, .loading:
                    Color.clear.frame(height: 1)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background.ignoresSafeArea())
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear { store.send(.view(.fetch)) }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .prominentSheet(item: $store.scope(state: \.sheet, action: \.sheet)) { _ in
            RecordEditorView(
                goalId: store.record.goalId,
                goalTitle: store.goalTitle,
                record: store.record,
                baseVersion: store.currentVersion,
                onCompletion: finishEditing
            )
        }
        .navigationDestination(
            item: $store.scope(state: \.history, action: \.history),
            interactivePop: true
        ) { _ in
            RecordVersionHistoryView(store: store)
        }
        .overlay {
            if store.isLoading || store.isRestoring {
                LoadingView()
            }
        }
        .onChange(of: store.restoredSourceVersionID) { _, sourceVersionID in
            guard sourceVersionID != nil else { return }
            onUpdate()
        }
    }

    private var topBar: some View {
        HStack {
            NavigationBackButton(action: { dismiss() })
                .disabled(store.isRestoring)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    @ViewBuilder
    private func recordContent(
        title: String,
        markdownContent: String,
        version: DevelopmentRecord.Version?
    ) -> some View {
        titleSection(title: title, version: version)
        contentCard(markdownContent: markdownContent)
    }

    private func titleSection(
        title: String,
        version: DevelopmentRecord.Version?
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal) {
                Text(title)
                    .font(.title.bold())
                    .lineLimit(1)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 10) {
                Text(
                    version == nil
                        ? RecordPresentation.text("development_record_draft")
                        : RecordPresentation.text("development_record_confirmed")
                )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(version == nil ? Color.warning : Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        version == nil ? Color.warning.opacity(0.12) : Color.accent,
                        in: .rect(cornerRadius: CornerRadius.badge)
                    )

                if let version {
                    Text(RecordPresentation.versionLabel(version.number))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.tintFill, in: .rect(cornerRadius: CornerRadius.badge))

                    Text(version.confirmedAt, format: .dateTime.month().day().hour().minute())
                        .font(.callout)
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
        }
    }

    private func contentCard(markdownContent: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if markdownContent.isEmpty {
                EmptyStateView(
                    RecordPresentation.text("development_record_content_empty_title"),
                    systemImage: "doc.text"
                )
                .padding(.bottom, 72)
            } else {
                MarkdownContentView(content: markdownContent)
                    .frame(minHeight: 420)
            }
        }
        .padding(.vertical, 16)
        .background {
            Rectangle()
                .fill(Color.secondaryBackground)
        }
    }

    private var failureContent: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                RecordPresentation.text("common_error_title"),
                systemImage: "exclamationmark.triangle",
                description: Text(
                    RecordPresentation.text("development_record_detail_error_message")
                )
            )

            Button(RecordPresentation.text("development_record_detail_retry")) {
                store.send(.view(.fetch))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.secondaryBackground, in: .rect)
    }

    private var actionSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                correctionButton
                historyButton
            }

            VStack(spacing: 12) {
                correctionButton
                historyButton
            }
        }
    }

    private var correctionButton: some View {
        Button {
            store.send(.view(.tapCorrection))
        } label: {
            Label(
                RecordPresentation.text("development_record_correct"),
                systemImage: "pencil"
            )
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .adaptiveButtonStyle(shape: RoundedRectangle(cornerRadius: CornerRadius.control), color: .accent)
    }

    private var historyButton: some View {
        Button {
            store.send(.view(.tapHistory))
        } label: {
            Label(
                RecordPresentation.text("development_record_history_title"),
                systemImage: "clock.arrow.circlepath"
            )
            .font(.headline)
            .foregroundStyle(Color.tintLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .adaptiveButtonStyle(
            shape: RoundedRectangle(cornerRadius: CornerRadius.control),
            color: .tintFill
        )
    }

    private func finishEditing() {
        store.send(.view(.finishEditing))
        onUpdate()
    }
}
