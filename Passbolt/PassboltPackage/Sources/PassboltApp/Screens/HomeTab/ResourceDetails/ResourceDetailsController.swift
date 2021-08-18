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
import Resources
import UIComponents

internal struct ResourceDetailsController {

  internal var loadResourceDetails: () -> AnyPublisher<ResourceDetails, TheError>
  internal var toggleDecrypt: (FieldName) -> AnyPublisher<String?, TheError>
}

extension ResourceDetailsController: UIController {

  internal typealias Context = Resource.ID

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {

    let accountDatabase: AccountDatabase = features.instance()
    let resources: Resources = features.instance()

    let lock: NSRecursiveLock = .init()
    var revealedFields: Set<FieldName> = .init()

    func loadResourceDetails() -> AnyPublisher<ResourceDetails, TheError> {
      accountDatabase.fetchDetailsViewResources(context)
        .map(ResourceDetails.from(detailsViewResource:))
        .eraseToAnyPublisher()
    }

    func toggleDecrypt(fieldName: FieldName) -> AnyPublisher<String?, TheError> {
      lock.lock()
      defer { lock.unlock() }

      if revealedFields.contains(fieldName) {
        return Just(nil)
        .setFailureType(to: TheError.self)
        .handleEvents(receiveOutput: { _ in
          lock.lock()
          revealedFields.remove(fieldName)
          lock.unlock()
        })
        .eraseToAnyPublisher()
      }
      else {
        return resources.loadResourceSecret(context)
          .map { resourceSecret in
            resourceSecret[dynamicMember: fieldName.rawValue] as String? ?? ""
          }
          .handleEvents(receiveOutput: { _ in
            lock.lock()
            revealedFields.insert(fieldName)
            lock.unlock()
          })
          .eraseToAnyPublisher()
      }
    }

    return Self(
      loadResourceDetails: loadResourceDetails,
      toggleDecrypt: toggleDecrypt(fieldName:)
    )
  }
}
