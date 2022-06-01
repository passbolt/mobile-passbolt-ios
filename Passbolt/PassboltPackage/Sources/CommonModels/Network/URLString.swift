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

import Commons
import Foundation

public enum URLStringTag {}
public typealias URLString = Tagged<String, URLStringTag>

extension URLString {

  public static func domain(forURL: URLString, matches: URLString) -> Bool {
    var targetURL: String = matches.rawValue
    var checkedURL: String = forURL.rawValue

    // Pick and remove scheme from target url
    let targetURLScheme: Substring
    if let schemeRange = targetURL.range(of: "https://") ?? targetURL.range(of: "http://"),
      schemeRange.lowerBound == targetURL.startIndex
    {
      targetURLScheme = targetURL[schemeRange]
      targetURL.removeSubrange(schemeRange)
    }
    else {
      targetURLScheme = ""
    }

    // Pick and remove scheme from checked url
    let checkedScheme: Substring
    if let schemeRange = checkedURL.range(of: "https://") ?? checkedURL.range(of: "http://"),
      schemeRange.lowerBound == checkedURL.startIndex
    {
      checkedScheme = checkedURL[schemeRange]
      checkedURL.removeSubrange(schemeRange)
    }
    else {
      checkedScheme = ""
    }

    // Compare schemes if needed
    if !targetURLScheme.isEmpty, !checkedScheme.isEmpty, targetURLScheme != checkedScheme {
      return false
    }
    else if !targetURLScheme.isEmpty, checkedScheme.isEmpty {
      return false
    }
    else {
      /* NOP */
    }

    // Remove path from target url - ignoring in matching
    if let pathBeginningIndex = targetURL.firstIndex(of: "/") {
      targetURL.removeSubrange(pathBeginningIndex..<targetURL.endIndex)
    }
    else {
      /* NOP */
    }

    // Remove path from checked url - ignoring in matching
    if let pathBeginningIndex = checkedURL.firstIndex(of: "/") {
      checkedURL.removeSubrange(pathBeginningIndex..<checkedURL.endIndex)
    }
    else {
      /* NOP */
    }

    // Pick and remove port from target url
    let targetURLPort: Substring
    if let portRange = targetURL.lastIndex(of: ":").map({ $0..<targetURL.endIndex }),
      targetURL[portRange].range(of: "^(:[0-9]{1,6})$", options: .regularExpression, range: nil, locale: nil) != nil
    {
      targetURLPort = targetURL[portRange]
      targetURL.removeSubrange(portRange)
    }
    else {
      targetURLPort = ""
    }

    // Pick and remove scheme from checked url
    let checkedURLPort: Substring
    if let portRange = checkedURL.lastIndex(of: ":").map({ $0..<checkedURL.endIndex }),
      checkedURL[portRange].range(of: "^(:[0-9]{1,6})$", options: .regularExpression, range: nil, locale: nil) != nil
    {
      checkedURLPort = checkedURL[portRange]
      checkedURL.removeSubrange(portRange)
    }
    else {
      checkedURLPort = ""
    }

    // Compare ports if needed
    if !targetURLPort.isEmpty, !checkedURLPort.isEmpty, targetURLScheme != checkedScheme {
      return false
    }
    else if !targetURLPort.isEmpty, checkedURLPort.isEmpty {
      return false
    }
    else {
      /* NOP */
    }

    // Check for ipv4 address
    if checkedURL.matches(regex: ipv4Regex) {
      return targetURL == checkedURL
    }
    // Check for ipv6 address
    else if checkedURL.matches(regex: ipv6Regex) {
      return targetURL == checkedURL
    }
    // Match as domain
    else {
      let targetDomainComponents = targetURL.split(separator: ".").reversed()
      let checkedDomainComponents = checkedURL.split(separator: ".").reversed()

      guard
        !targetDomainComponents.isEmpty,
        !checkedDomainComponents.isEmpty,
        targetDomainComponents.count <= checkedDomainComponents.count
      else { return false }

      if targetDomainComponents.count == 1 {
        return targetURL == checkedURL
      }
      else {
        return zip(
          targetDomainComponents,
          checkedDomainComponents
        )
        .reduce(true) { $0 && $1.0 == $1.1 }
      }
    }
  }

  public func hasSuffix(_ suffix: String) -> Bool {
    rawValue.hasSuffix(suffix)
  }

  public func asURL() -> Result<URL, URLInvalid> {
    if let url: URL = .init(string: self.rawValue) {
      return .success(url)
    }
    else {
      return .failure(.error(rawString: self.rawValue))
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

#if DEBUG

// cannot conform to RandomlyGenerated
extension URLString {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Generator<Self> {
    Generator<String>
      .randomURL(using: randomnessGenerator)
      .map(Self.init(rawValue:))
  }
}
#endif
