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

internal enum HomePresentationMode: Hashable {

  case plainResourcesList
  case favoriteResourcesList
  case modifiedResourcesList
  case sharedResourcesList
  case ownedResourcesList
  case foldersExplorer
  case tagsExplorer
}

extension HomePresentationMode {

  internal var title: DisplayableString {
    switch self {
    case .plainResourcesList:
      return .localized(key: "home.presentation.mode.plain.resources.title")

    case .favoriteResourcesList:
      return .localized(key: "home.presentation.mode.favorite.resources.title")

    case .modifiedResourcesList:
      return .localized(key: "home.presentation.mode.modified.resources.title")

    case .sharedResourcesList:
      return .localized(key: "home.presentation.mode.shared.resources.title")

    case .ownedResourcesList:
      return .localized(key: "home.presentation.mode.owned.resources.title")

    case .foldersExplorer:
      return .localized(key: "home.presentation.mode.folders.explorer.title")

    case .tagsExplorer:
      return .localized(key: "home.presentation.mode.tags.explorer.title")
    }
  }

  internal var iconName: ImageNameConstant {
    switch self {
    case .plainResourcesList:
      return .list

    case .favoriteResourcesList:
      return .star

    case .modifiedResourcesList:
      return .clock

    case .sharedResourcesList:
      return .share

    case .ownedResourcesList:
      return .user

    case .foldersExplorer:
      return .folder

    case .tagsExplorer:
      return .tag
    }
  }
}
