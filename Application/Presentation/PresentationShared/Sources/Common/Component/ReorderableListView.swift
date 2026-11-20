//
//  ReorderableListView.swift
//  PresentationShared
//
//  Created by opfic on 10/5/26.
//

import SwiftUI
import UIComposable

private let headerElementKind = "ReorderableListView.header"
private let footerElementKind = "ReorderableListView.footer"

// 바탕 없이 페이지 여백에 맞추고 구분선으로 나눈 순서 바꾸기 목록
public final class ReorderableListView<
    Item: Identifiable & Equatable
>: UICollectionView, UICoordinatedComposable where Item.ID: Sendable {
    private var items: [Item] = []
    private var headerContent: (any UIContentConfiguration)?
    private var footerContent: (any UIContentConfiguration)?
    private var rowContent: (Item) -> any UIContentConfiguration = { _ in UIListContentConfiguration.cell() }
    private var onMove: (IndexSet, Int) -> Void = { _, _ in }
    private var selectedID: Item.ID?
    private var separatorLeadingInset = CGFloat.zero
    private var separatorColor = UIColor.separator

    public init() {
        super.init(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func connect(coordinator: Coordinator) {
        coordinator.connect(self)
    }

    public func update(coordinator: Coordinator) {
        coordinator.apply()
    }

    public func disconnect(coordinator: Coordinator) {
        coordinator.disconnect()
    }

    public func updateContent(
        items: [Item],
        header: any UIContentConfiguration,
        footer: any UIContentConfiguration,
        row: @escaping (Item) -> any UIContentConfiguration,
        onMove: @escaping (IndexSet, Int) -> Void,
        selectedID: Item.ID? = nil,
        separatorLeadingInset: CGFloat = 0,
        separatorColor: Color
    ) {
        self.items = items
        headerContent = header
        footerContent = footer
        rowContent = row
        self.onMove = onMove
        self.selectedID = selectedID
        self.separatorLeadingInset = separatorLeadingInset
        self.separatorColor = UIColor(separatorColor)
    }

    /// 드래그 결과(제거 위치와 삽입 위치)를 `Array.move(fromOffsets:toOffset:)`의 목적지 의미로 변환한다.
    static func moveDestination(from source: Int, to target: Int) -> Int {
        source < target ? target + 1 : target
    }

    @MainActor
    public final class Coordinator {
        private weak var collectionView: ReorderableListView?
        private var dataSource: UICollectionViewDiffableDataSource<Int, Item.ID>?
        private var itemIDs: [Item.ID] = []
        private var itemsByID: [Item.ID: Item] = [:]
        private var hasAppliedInitialSnapshot = false
        private var selectedID: Item.ID?
        private var separatorLeadingInset = CGFloat.zero

        func connect(_ collectionView: ReorderableListView) {
            self.collectionView = collectionView
            collectionView.backgroundColor = .clear
            collectionView.allowsSelection = false
            collectionView.collectionViewLayout = makeLayout()
            collectionView.dataSource = makeDataSource(for: collectionView)
        }

        func disconnect() {
            dataSource?.reorderingHandlers.canReorderItem = nil
            dataSource?.reorderingHandlers.didReorder = nil
            dataSource?.supplementaryViewProvider = nil
            collectionView?.dataSource = nil
            dataSource = nil
            collectionView = nil
        }

        func apply() {
            guard let collectionView, let dataSource else { return }

            let newIDs = collectionView.items.map(\.id)
            let newItemsByID = Dictionary(
                collectionView.items.map { ($0.id, $0) },
                uniquingKeysWith: { _, latest in latest }
            )
            var changedIDs = newIDs.filter { id in
                guard let oldItem = itemsByID[id], let newItem = newItemsByID[id] else { return false }
                return oldItem != newItem
            }
            let isOrderChanged = newIDs != itemIDs

            // 고른 행이 바뀌면 이전 행과 새 행의 바탕을 다시 그림
            if selectedID != collectionView.selectedID {
                changedIDs += [selectedID, collectionView.selectedID].compactMap { $0 }.filter {
                    newItemsByID[$0] != nil && itemsByID[$0] != nil && !changedIDs.contains($0)
                }
                selectedID = collectionView.selectedID
            }

            // 창 폭이 바뀌어 구분선 시작 위치가 바뀌면 목록 배치를 다시 계산
            if separatorLeadingInset != collectionView.separatorLeadingInset {
                separatorLeadingInset = collectionView.separatorLeadingInset
                collectionView.collectionViewLayout.invalidateLayout()
            }

            itemIDs = newIDs
            itemsByID = newItemsByID

            if isOrderChanged {
                var snapshot = NSDiffableDataSourceSnapshot<Int, Item.ID>()
                snapshot.appendSections([0])
                snapshot.appendItems(newIDs)
                snapshot.reconfigureItems(changedIDs)
                dataSource.apply(snapshot, animatingDifferences: hasAppliedInitialSnapshot)
                hasAppliedInitialSnapshot = true
            } else if !changedIDs.isEmpty {
                var snapshot = dataSource.snapshot()
                snapshot.reconfigureItems(changedIDs)
                dataSource.apply(snapshot, animatingDifferences: false)
            }
        }

        private func makeLayout() -> UICollectionViewCompositionalLayout {
            let layoutConfiguration = UICollectionViewCompositionalLayoutConfiguration()
            layoutConfiguration.boundarySupplementaryItems = [
                boundaryItem(kind: headerElementKind, alignment: .top),
                boundaryItem(kind: footerElementKind, alignment: .bottom)
            ]

            // Mac은 Orca 데스크톱처럼 좌우 페이지 여백이 작음
            let margin = ProcessInfo.processInfo.isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16
            let layout = UICollectionViewCompositionalLayout(
                sectionProvider: { [weak self] _, environment in
                    var listConfiguration = UICollectionLayoutListConfiguration(appearance: .plain)
                    listConfiguration.backgroundColor = .clear
                    listConfiguration.separatorConfiguration.color = self?.collectionView?.separatorColor ?? .separator
                    // 시스템 reorder 핸들의 trailing 여백이 페이지 여백(16pt)보다 커서 셀을 그만큼 여백 밖으로 늘림
                    let handleOverhang: CGFloat = 7
                    // 구분선은 목록 오른쪽 끝까지 이어짐
                    let separatorInsets = NSDirectionalEdgeInsets(
                        top: 0,
                        leading: self?.collectionView?.separatorLeadingInset ?? 0,
                        bottom: 0,
                        trailing: handleOverhang
                    )
                    listConfiguration.itemSeparatorHandler = { indexPath, separatorConfiguration in
                        var separatorConfiguration = separatorConfiguration
                        separatorConfiguration.topSeparatorInsets = separatorInsets
                        separatorConfiguration.bottomSeparatorInsets = separatorInsets
                        if indexPath.item == 0 {
                            separatorConfiguration.topSeparatorVisibility = .hidden
                        }
                        if indexPath.item == (self?.itemIDs.count ?? 0) - 1 {
                            separatorConfiguration.bottomSeparatorVisibility = .hidden
                        }
                        return separatorConfiguration
                    }

                    let section = NSCollectionLayoutSection.list(
                        using: listConfiguration,
                        layoutEnvironment: environment
                    )
                    section.contentInsetsReference = .none
                    section.contentInsets = NSDirectionalEdgeInsets(
                        top: 0,
                        leading: margin,
                        bottom: 0,
                        trailing: margin - handleOverhang
                    )
                    return section
                },
                configuration: layoutConfiguration
            )
            return layout
        }

        private func boundaryItem(
            kind: String,
            alignment: NSRectAlignment
        ) -> NSCollectionLayoutBoundarySupplementaryItem {
            NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(44)
                ),
                elementKind: kind,
                alignment: alignment
            )
        }

        private func makeDataSource(
            for collectionView: ReorderableListView
        ) -> UICollectionViewDiffableDataSource<Int, Item.ID> {
            let secondaryBackground = UIColor(named: "SecondaryBackground", in: PresentationResources.bundle, compatibleWith: nil)
                ?? .secondarySystemGroupedBackground
            let fill = UIColor(named: "Fill", in: PresentationResources.bundle, compatibleWith: nil)
                ?? .systemFill
            let handle = UIColor(named: "TertiaryLabel", in: PresentationResources.bundle, compatibleWith: nil)
                ?? .tertiaryLabel

            let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item.ID> {
                [weak self] cell, _, id in
                guard let collectionView = self?.collectionView, let item = self?.itemsByID[id] else { return }

                cell.contentConfiguration = collectionView.rowContent(item)
                // 고른 행은 reorder 핸들까지 행 전체를 회색으로 채움
                let isSelected = id == collectionView.selectedID

                cell.configurationUpdateHandler = { cell, state in
                    var background = UIBackgroundConfiguration.clear()
                    if state.cellDragState != .none {
                        background.backgroundColor = secondaryBackground
                        background.cornerRadius = CornerRadius.group
                    } else if isSelected {
                        background.backgroundColor = fill
                    }
                    cell.backgroundConfiguration = background
                }

                cell.accessories = [
                    .reorder(
                        displayed: .always,
                        options: UICellAccessory.ReorderOptions(
                            reservedLayoutWidth: .actual,
                            tintColor: handle,
                            showsVerticalSeparator: false
                        )
                    )
                ]
            }

            let headerRegistration = supplementaryRegistration(kind: headerElementKind) { $0.headerContent }
            let footerRegistration = supplementaryRegistration(kind: footerElementKind) { $0.footerContent }

            let dataSource = UICollectionViewDiffableDataSource<Int, Item.ID>(
                collectionView: collectionView
            ) { collectionView, indexPath, id in
                collectionView.dequeueConfiguredReusableCell(
                    using: cellRegistration,
                    for: indexPath,
                    item: id
                )
            }

            dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
                let registration = kind == headerElementKind ? headerRegistration : footerRegistration
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: registration,
                    for: indexPath
                )
            }

            dataSource.reorderingHandlers.canReorderItem = { _ in true }
            dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
                self?.didReorder(transaction)
            }

            self.dataSource = dataSource
            return dataSource
        }

        private func supplementaryRegistration(
            kind: String,
            content: @escaping (ReorderableListView) -> (any UIContentConfiguration)?
        ) -> UICollectionView.SupplementaryRegistration<UICollectionViewListCell> {
            UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
                elementKind: kind
            ) { [weak self] view, _, _ in
                guard let collectionView = self?.collectionView else { return }

                view.contentConfiguration = content(collectionView)
                view.backgroundConfiguration = .clear()
            }
        }

        private func didReorder(_ transaction: NSDiffableDataSourceTransaction<Int, Item.ID>) {
            guard let collectionView,
                  case .remove(let source, _, _)? = transaction.difference.removals.first,
                  case .insert(let target, _, _)? = transaction.difference.insertions.first else { return }

            itemIDs = transaction.finalSnapshot.itemIdentifiers
            collectionView.onMove(
                IndexSet(integer: source),
                ReorderableListView.moveDestination(from: source, to: target)
            )
        }
    }
}
