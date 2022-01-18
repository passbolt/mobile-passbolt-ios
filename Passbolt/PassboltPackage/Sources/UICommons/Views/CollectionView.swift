//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
// Public License (AGPL) as published by the Free Software Foundation version 3.
//
// The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark
// license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate
// agreement with Passbolt SA.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License along with this program. If not,
// see GNU Affero General Public License v3 (http://www.gnu.org/licenses/agpl-3.0.html).
//
// @copyright     Copyright (c) Passbolt SA (https://www.passbolt.com)
// @license       https://opensource.org/licenses/AGPL-3.0 AGPL License
// @link          https://www.passbolt.com Passbolt (tm)
// @since         v1.0
//

import AegithalosCocoa
import Commons

open class CollectionView<Section: Hashable, Item: Hashable>:
  UICollectionView, UICollectionViewDragDelegate, UICollectionViewDropDelegate
{

  public lazy var dynamicBackgroundColor: DynamicColor = .always(self.backgroundColor) {
    didSet {
      self.backgroundColor = dynamicBackgroundColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public var dynamicTintColor: DynamicColor? {
    didSet {
      self.tintColor = dynamicTintColor?(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicRefreshControlColor: DynamicColor = .icon {
    didSet {
      self.refreshControl?.tintColor = dynamicRefreshControlColor(in: traitCollection.userInterfaceStyle)
    }
  }

  public var dynamicBorderColor: DynamicColor? {
    didSet {
      self.layer.borderColor = dynamicBorderColor?(in: traitCollection.userInterfaceStyle).cgColor
    }
  }

  public var emptyStateView: UIView? {
    didSet {
      oldValue?.removeFromSuperview()
      let wasHidden: Bool = oldValue?.isHidden ?? true
      guard let view = emptyStateView else { return }
      mut(view) {
        .combined(
          .hidden(wasHidden),
          .subview(of: self),
          .topAnchor(.equalTo, topAnchor, constant: 16),
          .bottomAnchor(.equalTo, bottomAnchor, constant: -16),
          .heightAnchor(.equalTo, heightAnchor, constant: -32),
          .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
          .trailingAnchor(.equalTo, trailingAnchor, constant: -16),
          .widthAnchor(.equalTo, self.widthAnchor, constant: -32)
        )
      }
    }
  }

  // swift-format-ignore: NoLeadingUnderscores
  private lazy var _dataSource: UICollectionViewDiffableDataSource<Section, Item> = setupDataSource()

  public init(
    layout: UICollectionViewLayout,
    cells: Array<CollectionViewCell.Type>,
    headers: Array<CollectionReusableView.Type> = [],
    footers: Array<CollectionReusableView.Type> = [],
    supplementaryViews: Array<CollectionViewSupplementaryView.Type> = []
  ) {
    super.init(
      frame: .zero,
      collectionViewLayout: layout
    )
    cells.forEach { cell in
      register(cell, forCellWithReuseIdentifier: cell.reuseIdentifier)
    }
    headers.forEach { header in
      register(
        header,
        forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
        withReuseIdentifier: header.reuseIdentifier
      )
    }
    footers.forEach { footer in
      register(
        footer,
        forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
        withReuseIdentifier: footer.reuseIdentifier
      )
    }
    supplementaryViews.forEach { supplementaryView in
      register(
        supplementaryView,
        forSupplementaryViewOfKind: supplementaryView.kind,
        withReuseIdentifier: supplementaryView.reuseIdentifier
      )
    }

    setup()
  }

  @available(*, unavailable)
  public init() {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  open func setup() {
    // prepared to override instead of overriding init
  }

  public func update(
    data: Array<(Section, Array<Item>)>,
    animated: Bool = true
  ) {
    var snapshot: NSDiffableDataSourceSnapshot<Section, Item> = .init()

    for (section, items) in data {
      snapshot.appendSections([section])
      snapshot.appendItems(items, toSection: section)
    }

    _dataSource.apply(
      snapshot,
      animatingDifferences: animated
    )

    if data.allSatisfy({ $0.1.isEmpty }) {
      emptyStateView?.isHidden = false
      emptyStateView.map(bringSubviewToFront)
    }
    else {
      emptyStateView?.isHidden = true
    }
  }

  public func section(at indexPath: IndexPath) -> Section {
    _dataSource.snapshot().sectionIdentifiers[indexPath.section]
  }

  public func dequeueOrMakeReusableCell<Cell: CollectionViewCell>(
    for: Cell.Type = Cell.self,
    at indexPath: IndexPath
  ) -> Cell {
    dequeueReusableCell(
      withReuseIdentifier: Cell.reuseIdentifier,
      for: indexPath
    ) as? Cell ?? .init()
  }

  open func setupCell(
    for item: Item,
    in section: Section,
    at indexPath: IndexPath
  ) -> CollectionViewCell? {
    unreachable("\(Self.self).\(#function) should be overriden to be used")
  }

  open func setupHeader(
    for section: Section,
    at indexPath: IndexPath
  ) -> CollectionReusableView? {
    unreachable("\(Self.self).\(#function) should be overriden to be used")
  }

  open func setupFooter(
    for section: Section,
    at indexPath: IndexPath
  ) -> CollectionReusableView? {
    unreachable("\(Self.self).\(#function) should be overriden to be used")
  }

  open func setupSupplementaryView(
    _ kind: String,
    for section: Section,
    at indexPath: IndexPath
  ) -> CollectionReusableView? {
    unreachable("\(Self.self).\(#function) should be overriden to be used")
  }

  internal func setReorderingEnabled(_ isEnabled: Bool) {
    self.dragInteractionEnabled = isEnabled
    self.dropDelegate = self
    self.dragDelegate = self
  }

  internal func move(
    from sourceSection: Section,
    at sourceIndexPath: IndexPath,
    to destinationSection: Section,
    at destinationIndexPath: IndexPath
  ) {
    unreachable("\(Self.self).\(#function) should be overriden to be used")
  }

  private func setupDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
    let dataSource: UICollectionViewDiffableDataSource<Section, Item> = .init(
      collectionView: self,
      cellProvider: { [weak self] _, indexPath, item in
        guard let self = self else { return nil }
        return self.setupCell(
          for: item,
          in: self.section(at: indexPath),
          at: indexPath
        )
      }
    )
    dataSource.supplementaryViewProvider = { [weak self] _, kind, indexPath in
      guard let self = self else { return nil }
      switch kind {
      case UICollectionView.elementKindSectionHeader:
        return self.setupHeader(for: self.section(at: indexPath), at: indexPath)

      case UICollectionView.elementKindSectionFooter:
        return self.setupFooter(for: self.section(at: indexPath), at: indexPath)

      case _:
        return self.setupSupplementaryView(kind, for: self.section(at: indexPath), at: indexPath)
      }
    }
    return dataSource
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    performDropWith coordinator: UICollectionViewDropCoordinator
  ) {
    let destinationIndexPath: IndexPath
    if let indexPath: IndexPath = coordinator.destinationIndexPath {
      destinationIndexPath = indexPath
    }
    else {
      let section: Int = collectionView.numberOfSections - 1
      let row: Int = collectionView.numberOfItems(inSection: section)
      destinationIndexPath = IndexPath(row: row, section: section)
    }
    reorderItems(
      coordinator: coordinator,
      destinationIndexPath: destinationIndexPath,
      collectionView: collectionView
    )
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    canHandle session: UIDropSession
  ) -> Bool {
    dragInteractionEnabled
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    dropSessionDidUpdate session: UIDropSession,
    withDestinationIndexPath destinationIndexPath: IndexPath?
  ) -> UICollectionViewDropProposal {
    if collectionView.hasActiveDrag {
      return UICollectionViewDropProposal(
        operation: .move,
        intent: .insertIntoDestinationIndexPath
      )
    }
    else {
      return UICollectionViewDropProposal(operation: .forbidden)
    }
  }

  private func reorderItems(
    coordinator: UICollectionViewDropCoordinator,
    destinationIndexPath: IndexPath,
    collectionView: UICollectionView
  ) {
    let items: Array<UICollectionViewDropItem> = coordinator.items
    if let item: UICollectionViewDropItem = items.first,
      let sourceIndexPath: IndexPath = item.sourceIndexPath
    {
      move(
        from: section(at: sourceIndexPath),
        at: sourceIndexPath,
        to: section(at: destinationIndexPath),
        at: destinationIndexPath
      )
    }
    else {
      assertionFailure("can't handle more than one item for moving")
    }
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    itemsForBeginning session: UIDragSession,
    at indexPath: IndexPath
  ) -> [UIDragItem] {
    let itemProvider: NSItemProvider = .init(object: "\(indexPath)" as NSItemProviderWriting)
    let dragItem: UIDragItem = .init(itemProvider: itemProvider)
    dragItem.localObject = _dataSource.itemIdentifier(for: indexPath)
    return [dragItem]
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    itemsForAddingTo session: UIDragSession,
    at indexPath: IndexPath,
    point: CGPoint
  ) -> [UIDragItem] {
    let itemProvider: NSItemProvider = .init(object: "\(indexPath)" as NSString)
    let dragItem: UIDragItem = .init(itemProvider: itemProvider)
    dragItem.localObject = _dataSource.itemIdentifier(for: indexPath)
    return [dragItem]
  }

  override open func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?
  ) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard traitCollection != previousTraitCollection
    else { return }
    updateColors()
  }

  private func updateColors() {
    let interfaceStyle: UIUserInterfaceStyle = traitCollection.userInterfaceStyle
    self.backgroundColor = dynamicBackgroundColor(in: interfaceStyle)
    self.tintColor = dynamicTintColor?(in: interfaceStyle)
    self.refreshControl?.tintColor = dynamicRefreshControlColor(in: interfaceStyle)
  }

  public var pullToRefreshPublisher: AnyPublisher<Void, Never> {
    if self.refreshControl == nil {
      let refreshControl: UIRefreshControl = .init()
      self.refreshControl?.tintColor = dynamicRefreshControlColor(in: traitCollection.userInterfaceStyle)
      mut(refreshControl) {
        .action(
          { [unowned self] in
            self.pullToRefreshSubject.send()
          },
          for: .valueChanged
        )
      }
      self.refreshControl = refreshControl
    }
    else {
      /* NOP */
    }
    return pullToRefreshSubject.eraseToAnyPublisher()
  }
  private let pullToRefreshSubject: PassthroughSubject<Void, Never> = .init()

  public func startDataRefresh() {
    assert(
      self.refreshControl != nil,
      "Cannot trigger data refresh without refresh control"
    )
    self.refreshControl?.beginRefreshing()
  }

  public func finishDataRefresh() {
    assert(
      self.refreshControl != nil,
      "Cannot finish data refresh without refresh control"
    )
    self.refreshControl?.endRefreshing()
  }
}

public struct SingleSection: Hashable {

  public static var section: Self = Self()

  private init() {}
}

extension CollectionView where Section == SingleSection {

  public func update(
    data: Array<Item>,
    animated: Bool = true
  ) {
    self.update(data: [(.section, data)])
  }
}
