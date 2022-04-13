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

import Accounts
import CommonModels
import Features
import NetworkClient

public struct ResourceTags {

  public var filteredTagsList: (AnyAsyncSequence<String>) -> AnyAsyncSequence<Array<ListViewResourceTag>>
  public var featureUnload: @FeaturesActor () async throws -> Void
}

extension ResourceTags: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let accountDatabase: AccountDatabase = try await features.instance()

    nonisolated func filteredTagsList(
      filter: AnyAsyncSequence<String>
    ) -> AnyAsyncSequence<Array<ListViewResourceTag>> {
      filter
        .map { (filter: String) async -> Array<ListViewResourceTag> in
          let tags: Array<ListViewResourceTag>
          do {
            tags =
              try await accountDatabase
              .fetchResourceTagList(filter)
          }
          catch {
            diagnostics.log(error)
            tags = .init()
          }

          return tags
        }
        .asAnyAsyncSequence()
    }

    @FeaturesActor func featureUnload() async throws {
      // always succeed
    }

    return Self(
      filteredTagsList: filteredTagsList(filter:),
      featureUnload: featureUnload
    )
  }
}

#if DEBUG

extension ResourceTags {

  public static var placeholder: Self {
    Self(
      filteredTagsList: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
