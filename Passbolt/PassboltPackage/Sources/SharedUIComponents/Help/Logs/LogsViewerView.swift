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

import UICommons

public final class LogsViewerView: CollectionView<SingleSection, LogsViewerLogItem> {

  public init() {
    super.init(
      layout: .logsList(),
      cells: [LogsViewerLogCell.self]
    )
    let activityIndicator: ActivityIndicator = .init(style: .large)
    activityIndicator.dynamicColor = .icon
    emptyStateView = activityIndicator
  }

  public override func setup() {
    mut(self) {
      .custom { (subject: LogsViewerView) in
        subject.dynamicBackgroundColor = .background
      }
    }
  }

  public override func setupCell(
    for item: LogsViewerLogItem,
    in section: SingleSection,
    at indexPath: IndexPath
  ) -> CollectionViewCell? {
    dequeueOrMakeReusableCell(
      for: LogsViewerLogCell.self,
      at: indexPath
    )
    .updated(log: item.log)
  }
}

public struct LogsViewerLogItem: Hashable {

  private let id: UUID = .init()  // we want them to be always unique
  public var log: String
}

private final class LogsViewerLogCell: CollectionViewCell {

  private let label: Label = .init()

  fileprivate override func setup() {
    mut(label) {
      .combined(
        .font(.monospacedSystemFont(ofSize: 10, weight: .regular)),
        .textColor(dynamic: .primaryText),
        .numberOfLines(0),
        .lineBreakMode(.byWordWrapping),
        .subview(of: contentView),
        .edges(equalTo: contentView, insets: .init(top: 0, left: -8, bottom: 0, right: -8))
      )
    }

    mut(self) {
      .backgroundColor(.clear)
    }
  }

  fileprivate func updated(log: String) -> Self {
    label.text = log
    return self
  }

  fileprivate override func prepareForReuse() {
    super.prepareForReuse()
    label.text = ""
  }
}

extension UICollectionViewLayout {

  fileprivate static func logsList() -> UICollectionViewCompositionalLayout {

    let item: NSCollectionLayoutItem = .init(
      layoutSize: .init(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(16)
      )
    )

    let group: NSCollectionLayoutGroup = .vertical(
      layoutSize: .init(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(16)
      ),
      subitems: [item]
    )

    let section: NSCollectionLayoutSection = .init(group: group)

    return UICollectionViewCompositionalLayout(section: section)
  }
}
