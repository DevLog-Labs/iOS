//
//  RecordVersionHistoryView.swift
//  Development
//
//  Created by opfic on 9/14/26.
//

import SwiftUI
import Domain
import PresentationShared

struct RecordVersionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout

    @Bindable var store: StoreOf<RecordDetailFeature>

    private var sortedVersions: [DevelopmentRecord.Version] {
        store.versions.sorted { $1.number < $0.number }
    }

    var body: some View {
        // 창 폭이 바뀌면 버전 이력이 새 자리에 나타난 뒤에 이전 버전을 띄움
        // 지금 값으로 다시 그리고, 빠지는 자리에서 늦게 들어온 닫힘은 읽을 때의 값으로 거름
        let versionDetail = $store.scope(state: \.versionDetail, action: \.versionDetail)
        let isShown = store.goalShownOnDesktop == usesDesktopLayout && store.historyShownOnDesktop == usesDesktopLayout
        let isHidden = {
            !isShown || store.goalShownOnDesktop != usesDesktopLayout || store.historyShownOnDesktop != usesDesktopLayout
        }

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                currentVersionSection
                HomeSectionHeader {
                    Text(RecordPresentation.text("development_record_version"))
                    Text(verbatim: "\(sortedVersions.count)")
                        .fontWeight(.medium)
                        .foregroundStyle(Color.secondaryLabel)
                } trailing: {
                    EmptyView()
                }
                ForEach(sortedVersions, id: \.id) { version in
                    Button {
                        if version.id == store.currentVersionID {
                            dismiss()
                        } else {
                            store.send(.view(.selectVersion(version)))
                        }
                    } label: {
                        VersionHistoryRow(
                            version: version,
                            isCurrent: version.id == store.currentVersionID,
                            // 이전 버전을 상세 판으로 연 동안 그 행을 회색으로 표시
                            isSelected: usesDesktopLayout && store.versionDetail?.version.id == version.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background.ignoresSafeArea())
        .duoToolbarVisibility(showsBackButton: true)
        .navigationDestination(
            item: versionDetail.hiddenInPane { usesDesktopLayout || isHidden() },
            interactivePop: true
        ) { destination in
            RecordVersionDetailView(
                store: store,
                version: destination.version
            )
        }
        // 사이드바가 있는 창은 이전 버전을 사이드바까지 덮는 상세 판으로 열기
        .detailPanel(
            item: versionDetail.hiddenInPane { !usesDesktopLayout || isHidden() }
        ) { destination in
            RecordVersionDetailView(
                store: store,
                version: destination.version
            )
        }
        .onAppear { store.send(.view(.appearHistory(onDesktop: usesDesktopLayout))) }
    }

    @ViewBuilder
    private var topBar: some View {
        if usesDesktopLayout {
            PaneTitleBar(
                Text(RecordPresentation.text("development_record_history_title")),
                onBack: { dismiss() },
                showsBackOnDesktop: true
            )
        } else {
            // Duo는 뒤로 버튼을 오른쪽 세로 막대에 표시
            RecordTopBar(RecordPresentation.text("development_record_history_title")) {
                if deviceType != .duo {
                    NavigationBackButton(action: { dismiss() })
                }
            } trailing: {
                EmptyView()
            }
        }
    }

    // 현재 버전 번호와 제목, 확정된 버전 안내
    @ViewBuilder
    private var currentVersionSection: some View {
        if let currentVersion = store.currentVersion {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                    Text(RecordPresentation.text("development_record_current_version"))
                    TodoBadge(RecordPresentation.versionLabel(currentVersion.number), color: .tintLabel)
                }
                .font(.adaptive(.footnote))
                .foregroundStyle(Color.secondaryLabel)

                Text(currentVersion.title)
                    .font(.adaptive(isiOSAppOnMac ? .title3 : .headline).bold())
                    .foregroundStyle(Color.label)
                    .lineLimit(2)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Text(RecordPresentation.text("development_record_current_version_message"))
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 18)
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.secondarySeparator)
                    .frame(height: 1)
            }
        }
    }
}

// 버전·종류·현재 배지와 제목, 날짜를 표시하는 버전 행
private struct VersionHistoryRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let version: DevelopmentRecord.Version
    let isCurrent: Bool
    let isSelected: Bool

    var body: some View {
        RecordListRow(isSelected: isSelected) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    TodoBadge(RecordPresentation.versionLabel(version.number))
                    RecordVersionKindBadge(kind: version.kind)
                    if isCurrent {
                        TodoBadge(RecordPresentation.text("development_record_version_current"), color: .tintLabel)
                    }
                }

                Text(version.title)
                    .font(.adaptive(isiOSAppOnMac ? .body : .callout).weight(.semibold))
                    .foregroundStyle(Color.label)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.top, 6)

                Text(version.confirmedAt, format: .dateTime.month().day().hour().minute())
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
                    .padding(.top, 3)
            }
        }
    }
}
