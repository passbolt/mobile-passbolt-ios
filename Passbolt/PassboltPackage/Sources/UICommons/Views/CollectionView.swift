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
import Combine
import Commons

open class CollectionView<Section: Hashable, Item: Hashable>: UICollectionView, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
  
  public lazy var dynamicBackgroundColor: DynamicColor
  = .default(self.backgroundColor) {
    didSet {
      self.backgroundColor = dynamicBackgroundColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicTintColor: DynamicColor
  = .default(self.tintColor) {
    didSet {
      self.tintColor = dynamicTintColor(in: traitCollection.userInterfaceStyle)
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
          .centerYAnchor(.equalTo, centerYAnchor),
          .centerXAnchor(.equalTo, centerXAnchor),
          .leadingAnchor(.greaterThanOrEqualTo, leadingAnchor, constant: 16),
          .trailingAnchor(.lessThanOrEqualTo, trailingAnchor, constant: -16)
        )
      }
    }
  }
  
  private lazy var _dataSource: UICollectionViewDiffableDataSource<Section, Item> = setupDataSource()
  
  public init(
    layout: UICollectionViewLayout,
    cells: Array<CollectionViewCell.Type>,
    headers: Array<CollectionReusableView.Type> = [],
    footers: Array<CollectionReusableView.Type> = []
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
        forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
        withReuseIdentifier: footer.reuseIdentifier
      )
    }
    setup()
  }
  
  @available(*, unavailable)
  public init() {
    unreachable("\(Self.self).\(#function) should not be used")
  }
  
  @available(*, unavailable)
  required public init?(coder: NSCoder) {
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
    } else {
      emptyStateView?.isHidden = true
    }
  }
  
  public func section(at indexPath: IndexPath) -> Section {
    _dataSource.snapshot().sectionIdentifiers[indexPath.section]
  }
  
  open func setupCell(
    for item: Item,
    in section: Section,
    at indexPath: IndexPath
  ) -> CollectionViewCell? {
    unreachable("\(Self.self).\(#function) should be overriden to be used")
  }
  
  internal func setupHeader(
    for section: Section,
    at indexPath: IndexPath
  ) -> CollectionReusableView? {
    unreachable("\(Self.self).\(#function) should be overriden to be used")
  }

  internal func setupFooter(
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
    let dataSource = UICollectionViewDiffableDataSource<Section, Item>(
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
    dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
      guard let self = self else { return nil }
      switch kind {
      case UICollectionView.elementKindSectionHeader:
        return self.setupHeader(for: self.section(at: indexPath), at: indexPath)
        
      case UICollectionView.elementKindSectionFooter:
        return self.setupFooter(for: self.section(at: indexPath), at: indexPath)
      case _:
        return nil
      }
    }
    return dataSource
  }
  
  public func collectionView(
    _ collectionView: UICollectionView,
    performDropWith coordinator: UICollectionViewDropCoordinator
  ) {
    let destinationIndexPath: IndexPath
    if let indexPath = coordinator.destinationIndexPath {
      destinationIndexPath = indexPath
    } else {
      let section = collectionView.numberOfSections - 1
      let row = collectionView.numberOfItems(inSection: section)
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
    return self.dragInteractionEnabled
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
    } else {
      return UICollectionViewDropProposal(operation: .forbidden)
    }
  }
  
  private func reorderItems(
    coordinator: UICollectionViewDropCoordinator,
    destinationIndexPath: IndexPath,
    collectionView: UICollectionView
  ) {
    let items = coordinator.items
    if
      let item = items.first,
      let sourceIndexPath = item.sourceIndexPath
    {
      move(
        from: section(at: sourceIndexPath),
        at: sourceIndexPath,
        to: section(at: destinationIndexPath),
        at: destinationIndexPath
      )
    } else {
      assertionFailure("can't handle more than one item for moving")
    }
  }
  
  public func collectionView(
    _ collectionView: UICollectionView,
    itemsForBeginning session: UIDragSession,
    at indexPath: IndexPath
  ) -> [UIDragItem] {
    let itemProvider = NSItemProvider(object: "\(indexPath)" as NSItemProviderWriting)
    let dragItem = UIDragItem(itemProvider: itemProvider)
    dragItem.localObject = _dataSource.itemIdentifier(for: indexPath)
    return [dragItem]
  }
  
  public func collectionView(
    _ collectionView: UICollectionView,
    itemsForAddingTo session: UIDragSession,
    at indexPath: IndexPath,
    point: CGPoint
  ) -> [UIDragItem] {
    let itemProvider = NSItemProvider(object: "\(indexPath)" as NSString)
    let dragItem = UIDragItem(itemProvider: itemProvider)
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
    self.tintColor = dynamicTintColor(in: interfaceStyle)
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
