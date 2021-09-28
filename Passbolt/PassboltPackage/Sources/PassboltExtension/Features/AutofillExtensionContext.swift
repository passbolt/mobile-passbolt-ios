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

import struct Accounts.ListViewResource
import Features

import struct Foundation.URL

public struct AutofillExtensionContext {

  public var completeWithCredential: (Credential) -> Void
  public var completeWithError: (TheError) -> Void
  public var completeExtensionConfiguration: () -> Void
  public var requestedServiceIdentifiersPublisher: () -> AnyPublisher<Array<ServiceIdentifier>, Never>

  public init(
    completeWithCredential: @escaping (Credential) -> Void,
    completeWithError: @escaping (TheError) -> Void,
    completeExtensionConfiguration: @escaping () -> Void,
    requestedServiceIdentifiersPublisher: @escaping () -> AnyPublisher<Array<ServiceIdentifier>, Never>
  ) {
    self.completeWithCredential = completeWithCredential
    self.completeWithError = completeWithError
    self.completeExtensionConfiguration = completeExtensionConfiguration
    self.requestedServiceIdentifiersPublisher = requestedServiceIdentifiersPublisher
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

extension AutofillExtensionContext: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    unreachable(
      "\(Self.self) does not support auto loading,"
        + " it has to be created manually using root ASCredentialProviderViewController instance."
    )
  }
}

#if DEBUG
extension AutofillExtensionContext {

  public static var placeholder: Self {
    Self(
      completeWithCredential: Commons.placeholder("You have to provide mocks for used methods"),
      completeWithError: Commons.placeholder("You have to provide mocks for used methods"),
      completeExtensionConfiguration: Commons.placeholder("You have to provide mocks for used methods"),
      requestedServiceIdentifiersPublisher: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif

extension AutofillExtensionContext.ServiceIdentifier {

  internal func matches(url: String) -> Bool {
    var resourceURL: String = url
    var serviceURL: String = rawValue

    // Pick and remove scheme from resource url
    let resourceScheme: Substring
    if let resourceSchemeRange = resourceURL.range(of: "https://") ?? resourceURL.range(of: "http://"), resourceSchemeRange.lowerBound == resourceURL.startIndex {
      resourceScheme = resourceURL[resourceSchemeRange]
      resourceURL.removeSubrange(resourceSchemeRange)
    }
    else {
      resourceScheme = ""
    }

    // Pick and remove scheme from service url
    let serviceScheme: Substring
    if let serviceSchemeRange = serviceURL.range(of: "https://") ?? serviceURL.range(of: "http://"), serviceSchemeRange.lowerBound == serviceURL.startIndex {
      serviceScheme = serviceURL[serviceSchemeRange]
      serviceURL.removeSubrange(serviceSchemeRange)
    }
    else {
      serviceScheme = ""
    }

    // Compare schemes if needed
    if !resourceScheme.isEmpty, !serviceScheme.isEmpty, resourceScheme != serviceScheme {
      return false
    }
    else if !resourceScheme.isEmpty, serviceScheme.isEmpty {
      return false
    }
    else {
      /* NOP */
    }

    // Remove path from resource url - ignoring in matching
    if let pathBeginningIndex = resourceURL.firstIndex(of: "/") {
      resourceURL.removeSubrange(pathBeginningIndex ..< resourceURL.endIndex)
    }
    else {
      /* NOP */
    }

    // Remove path from service url - ignoring in matching
    if let pathBeginningIndex = serviceURL.firstIndex(of: "/") {
      serviceURL.removeSubrange(pathBeginningIndex ..< serviceURL.endIndex)
    }
    else {
      /* NOP */
    }

    // Pick and remove port from resource url
    let resourcePort: Substring
    if let portRange = resourceURL.lastIndex(of: ":").map({ $0 ..< resourceURL.endIndex }), resourceURL[portRange].range(of: "^(:[0-9]{1,6})$", options: .regularExpression, range: nil, locale: nil) != nil {
      resourcePort = resourceURL[portRange]
      resourceURL.removeSubrange(portRange)
    }
    else {
      resourcePort = ""
    }

    // Pick and remove scheme from service url
    let servicePort: Substring
    if let portRange = serviceURL.lastIndex(of: ":").map({ $0 ..< serviceURL.endIndex }), serviceURL[portRange].range(of: "^(:[0-9]{1,6})$", options: .regularExpression, range: nil, locale: nil) != nil {
      servicePort = serviceURL[portRange]
      serviceURL.removeSubrange(portRange)
    }
    else {
      servicePort = ""
    }

    // Compare ports if needed
    if !resourcePort.isEmpty, !servicePort.isEmpty, resourceScheme != serviceScheme {
      return false
    }
    else if !resourcePort.isEmpty, servicePort.isEmpty {
      return false
    }
    else {
      /* NOP */
    }

    // Check for ipv4 address
    if serviceURL.matches(regex: ipv4Regex) {
      return resourceURL == serviceURL
    }
    // Check for ipv6 address
    else if serviceURL.matches(regex: ipv6Regex) {
      return resourceURL == serviceURL
    }
    // Match as domain
    else {
      let resourceDomainComponents = resourceURL.split(separator: ".").reversed()
      let serviceDomainComponents = serviceURL.split(separator: ".").reversed()

      guard resourceDomainComponents.count <= serviceDomainComponents.count
      else { return false }

      if resourceDomainComponents.count == 1 {
        return resourceURL == serviceURL
      }
      else {
        return zip(
          resourceDomainComponents,
          serviceDomainComponents
        )
        .reduce(true) { $0 && $1.0 == $1.1 }
      }
    }
  }
}

extension Array where Element == AutofillExtensionContext.ServiceIdentifier {

  internal func matches(_ resource: ListViewResource) -> Bool {
    contains {
      guard let resourceURL: String = resource.url
      else { return false }
      return $0.matches(url: resourceURL)
    }
  }
}

// regex based on  https://github.com/passbolt/passbolt_styleguide/blob/master/src/react-quickaccess/components/HomePage/canSuggestUrl.js
private let ipv4Regex: Regex = """
(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]\\d|\\d)(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]\\d|\\d)){3}
"""

// regex based on  https://github.com/passbolt/passbolt_styleguide/blob/master/src/react-quickaccess/components/HomePage/canSuggestUrl.js
private let ipv6Regex: Regex = """
(?:(?:[a-fA-F\\d]{1,4}:){7}(?:[a-fA-F\\d]{1,4}|:)|(?:[a-fA-F\\d]{1,4}:){6}(?:${v4}|:[a-fA-F\\d]{1,4}|:)|(?:[a-fA-F\\d]{1,4}:){5}(?::${v4}|(?::[a-fA-F\\d]{1,4}){1,2}|:)|(?:[a-fA-F\\d]{1,4}:){4}(?:(?::[a-fA-F\\d]{1,4}){0,1}:${v4}|(?::[a-fA-F\\d]{1,4}){1,3}|:)|(?:[a-fA-F\\d]{1,4}:){3}(?:(?::[a-fA-F\\d]{1,4}){0,2}:${v4}|(?::[a-fA-F\\d]{1,4}){1,4}|:)|(?:[a-fA-F\\d]{1,4}:){2}(?:(?::[a-fA-F\\d]{1,4}){0,3}:${v4}|(?::[a-fA-F\\d]{1,4}){1,5}|:)|(?:[a-fA-F\\d]{1,4}:){1}(?:(?::[a-fA-F\\d]{1,4}){0,4}:${v4}|(?::[a-fA-F\\d]{1,4}){1,6}|:)|(?::(?:(?::[a-fA-F\\d]{1,4}){0,5}:${v4}|(?::[a-fA-F\\d]{1,4}){1,7}|:)))(?:%[0-9a-zA-Z]{1,})?
"""
