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

import struct Foundation.URL

public struct AutofillExtensionContext {

  public var completeWithCredential: @MainActor (Credential) -> Void
  public var completeWithError: @MainActor (TheError) -> Void
  public var cancelAndCloseExtension: @MainActor () -> Void
  public var requestedServiceIdentifiers: @MainActor () -> Array<ServiceIdentifier>

  public init(
    completeWithCredential: @escaping @MainActor (Credential) -> Void,
    completeWithError: @escaping @MainActor (TheError) -> Void,
    cancelAndCloseExtension: @escaping @MainActor () -> Void,
    requestedServiceIdentifiers: @escaping @MainActor () -> Array<ServiceIdentifier>
  ) {
    self.completeWithCredential = completeWithCredential
    self.completeWithError = completeWithError
    self.cancelAndCloseExtension = cancelAndCloseExtension
    self.requestedServiceIdentifiers = requestedServiceIdentifiers
  }
}

extension AutofillExtensionContext {

  public enum ServiceIdentifierTag {}
  public typealias ServiceIdentifier = Tagged<String, ServiceIdentifierTag>

  public struct Credential {

    public let user: String
    public let password: String

    public init(
      user: String,
      password: String
    ) {
      self.user = user
      self.password = password
    }
  }
}

extension AutofillExtensionContext: StaticFeature {

  #if DEBUG
  public static var placeholder: Self {
    Self(
      completeWithCredential: unimplemented(),
      completeWithError: unimplemented(),
      cancelAndCloseExtension: unimplemented(),
      requestedServiceIdentifiers: unimplemented()
    )
  }
  #endif
}

extension AutofillExtensionContext.ServiceIdentifier {

  internal func matches(url: String) -> Bool {
    URLString.domain(
      forURL: .init(rawValue: rawValue),
      matches: .init(rawValue: url)
    )
  }
}

extension Array where Element == AutofillExtensionContext.ServiceIdentifier {

  internal func matches(_ resource: ResourceListItemDSV) -> Bool {
    contains {
      guard let resourceURL: String = resource.url
      else { return false }
      return $0.matches(url: resourceURL)
    }
  }
}
