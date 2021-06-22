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

extension UICollectionViewCompositionalLayout {
  
  internal static func accountSelectionLayout() -> UICollectionViewCompositionalLayout {
    let separator: NSCollectionLayoutSupplementaryItem = .init(
      layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(1.0)),
      elementKind: CollectionViewSeparator.kind,
      containerAnchor: .init(edges: .bottom)
    )
    
    let item: NSCollectionLayoutItem = .init(
      layoutSize: .init(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(64)
      )
    )
  
    let group: NSCollectionLayoutGroup = .vertical(
      layoutSize: .init(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(64)
      ),
      subitems: [item]
    )
    
    group.supplementaryItems = [separator]
    
    let section: NSCollectionLayoutSection = .init(group: group)
    section.decorationItems = [
      .background(elementKind: SectionDecorationView.reuseIdentifier)
    ]
    
    // This section needs to be offset from the top by 1, otherwise it's truncated.
    section.contentInsets = .init(top: 1, leading: 8, bottom: 0, trailing: 8)
    
    let layout: UICollectionViewCompositionalLayout = .init(section: section)

    layout.register(
      CollectionViewSeparator.self,
      forDecorationViewOfKind: CollectionViewSeparator.reuseIdentifier
    )
    
    layout.register(
      SectionDecorationView.self,
      forDecorationViewOfKind: SectionDecorationView.reuseIdentifier
    )
  
    return layout
  }
}
