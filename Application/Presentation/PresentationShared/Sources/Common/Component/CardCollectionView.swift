//
//  CardCollectionView.swift
//  PresentationShared
//
//  Created by opfic on 10/5/26.
//

import SwiftUI
import UIComposable

private let cardBackgroundElementKind = "CardCollectionView.cardBackground"
private let headerElementKind = "CardCollectionView.header"
private let footerElementKind = "CardCollectionView.footer"

public final class CardCollectionView<
    Item: Identifiable & Equatable
>: UICollectionView, UICoordinatedComposable where Item.ID: Sendable {
    private var items: [Item] = []
    private var headerContent: (any UIContentConfiguration)?
    private var footerContent: (any UIContentConfiguration)?
    private var rowContent: (Item) -> any UIContentConfiguration = { _ in UIListContentConfiguration.cell() }
    private var onMove: (IndexSet, Int) -> Void = { _, _ in }

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
        onMove: @escaping (IndexSet, Int) -> Void
    ) {
        self.items = items
        headerContent = header
        footerContent = footer
        rowContent = row
        self.onMove = onMove
    }

    /// 드래그 결과(제거 위치와 삽입 위치)를 `Array.move(fromOffsets:toOffset:)`의 목적지 의미로 변환한다.
    static func moveDestination(from source: Int, to target: Int) -> Int {
        source < target ? target + 1 : target
    }

    @MainActor
    public final class Coordinator {
        private weak var collectionView: CardCollectionView?
        private var dataSource: UICollectionViewDiffableDataSource<Int, Item.ID>?
        private var itemIDs: [Item.ID] = []
        private var itemsByID: [Item.ID: Item] = [:]
        private var hasAppliedInitialSnapshot = false

        func connect(_ collectionView: CardCollectionView) {
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
            let changedIDs = newIDs.filter { id in
                guard let oldItem = itemsByID[id], let newItem = newItemsByID[id] else { return false }
                return oldItem != newItem
            }
            let isOrderChanged = newIDs != itemIDs

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

            let layout = UICollectionViewCompositionalLayout(
                sectionProvider: { [weak self] _, environment in
                    var listConfiguration = UICollectionLayoutListConfiguration(appearance: .plain)
                    listConfiguration.backgroundColor = .clear
                    listConfiguration.separatorConfiguration.color = UIColor(
                        named: ProcessInfo.processInfo.isiOSAppOnMac ? "SeparatorMac" : "Separator",
                        in: PresentationResources.bundle,
                        compatibleWith: nil
                    ) ?? .separator
                    // 시스템 reorder 핸들의 trailing 여백이 카드 안쪽 여백(16pt)보다 커서 셀을 그만큼 카드 밖으로 늘린다.
                    let handleOverhang: CGFloat = 7
                    let separatorInsets = NSDirectionalEdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 0,
                        trailing: 16 + handleOverhang
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
                    section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 16 - handleOverhang)

                    let background = NSCollectionLayoutDecorationItem.background(elementKind: cardBackgroundElementKind)
                    background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                    section.decorationItems = [background]
                    return section
                },
                configuration: layoutConfiguration
            )
            layout.register(CardBackgroundView.self, forDecorationViewOfKind: cardBackgroundElementKind)
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
            for collectionView: CardCollectionView
        ) -> UICollectionViewDiffableDataSource<Int, Item.ID> {
            let secondaryBackground = UIColor(named: "SecondaryBackground", in: PresentationResources.bundle, compatibleWith: nil)
                ?? .secondarySystemGroupedBackground
            let handle = UIColor(named: "TertiaryLabel", in: PresentationResources.bundle, compatibleWith: nil)
                ?? .tertiaryLabel

            let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item.ID> {
                [weak self] cell, _, id in
                guard let collectionView = self?.collectionView, let item = self?.itemsByID[id] else { return }

                cell.contentConfiguration = collectionView.rowContent(item)

                cell.configurationUpdateHandler = { cell, state in
                    var background = UIBackgroundConfiguration.clear()
                    if state.cellDragState != .none {
                        background.backgroundColor = secondaryBackground
                        background.cornerRadius = CornerRadius.group
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
            content: @escaping (CardCollectionView) -> (any UIContentConfiguration)?
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
                CardCollectionView.moveDestination(from: source, to: target)
            )
        }
    }
}

private final class CardBackgroundView: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SecondaryBackground", in: PresentationResources.bundle, compatibleWith: nil)
            ?? .secondarySystemGroupedBackground
        layer.cornerRadius = CornerRadius.group
        layer.cornerCurve = .continuous
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
