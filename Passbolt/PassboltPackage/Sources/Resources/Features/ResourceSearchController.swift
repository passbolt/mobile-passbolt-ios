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
import Features

// MARK: - Interface

public struct ResourceSearchController {

  public var state: any DataSource<ResourceSearchState>
  public var refreshIfNeeded: @Sendable () async throws -> Void
  public var updateFilter: @Sendable ((inout ResourceSearchFilter) -> Void) -> Void

  public init(
    state: any DataSource<ResourceSearchState>,
    refreshIfNeeded: @escaping @Sendable () async throws -> Void,
    updateFilter: @escaping @Sendable ((inout ResourceSearchFilter) -> Void) -> Void
  ) {
    self.state = state
    self.refreshIfNeeded = refreshIfNeeded
    self.updateFilter = updateFilter
  }
}

extension ResourceSearchController: LoadableFeature {

  public typealias Context = ResourceSearchFilter

  #if DEBUG
  public static var placeholder: Self {
    Self(
      state: PlaceholderDataSource(),
      refreshIfNeeded: unimplemented0(),
      updateFilter: { _ in unimplemented() }
    )
  }
  #endif
}

public struct ResourceSearchFilter: Sendable, Equatable {

  public var text: String
  // empty types set is treated as all types available
  public var includedTypes: Set<ResourceSpecification.Slug>

  public init(
    text: String,
    includedTypes: Set<ResourceSpecification.Slug>
  ) {
    self.text = text
    self.includedTypes = includedTypes
  }
}

public typealias ResourceSearchResultItem = ResourceListItemDSV

public struct ResourceSearchState: Sendable, Equatable {

  public var filter: ResourceSearchFilter
  public var result: Array<ResourceSearchResultItem>

  public init(
    filter: ResourceSearchFilter,
    result: Array<ResourceSearchResultItem>
  ) {
    self.filter = filter
    self.result = result
  }
}
