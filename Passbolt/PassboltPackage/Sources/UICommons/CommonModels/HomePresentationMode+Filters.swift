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

import CommonModels
import Resources

extension HomePresentationMode {

  public func resourcesFilter(
    searchText: String
  ) -> ResourcesFilter? {
    switch self {
    case .plainResourcesList:
      return .init(
        sorting: .nameAlphabetically,
        text: searchText
      )

    case .favoriteResourcesList:
      return .init(
        sorting: .nameAlphabetically,
        text: searchText,
        favoriteOnly: true
      )

    case .modifiedResourcesList:
      return .init(
        sorting: .modifiedRecently,
        text: searchText
      )

    case .sharedResourcesList:
      return .init(
        sorting: .nameAlphabetically,
        text: searchText,
        permissions: [.read, .write]
      )

    case .ownedResourcesList:
      return .init(
        sorting: .nameAlphabetically,
        text: searchText,
        permissions: [.owner]
      )
    case .expiredResourcesList:
      return .init(
        sorting: .nameAlphabetically,
        text: searchText,
        expiredOnly: true
      )

    case .foldersExplorer:
      return .none
    //      return .init(
    //        sorting: .nameAlphabetically,
    //        text: searchText,
    //        folders: .init(
    //          folderID: .none // root
    ////          flattenContent: true ??
    //        )
    //      )

    case .tagsExplorer:
      return .none

    case .resourceUserGroupsExplorer:
      return .none
    }
  }
}
