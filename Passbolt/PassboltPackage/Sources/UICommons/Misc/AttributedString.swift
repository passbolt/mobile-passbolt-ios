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

import AegithalosCocoa
import CommonModels

public enum AttributedString {

  indirect case string(DisplayableString, attributes: Attributes, tail: AttributedString)
  case terminator
}

extension AttributedString {

  public static func displayable(
    _ displayableString: DisplayableString,
    font: UIFont,
    color: DynamicColor,
    isLink: Bool = false
  ) -> Self {
    .string(
      displayableString,
      attributes: Attributes(
        font: font,
        color: color,
        isLink: isLink
      ),
      tail: .terminator
    )
  }

  public static func displayable(
    _ displayableString: DisplayableString,
    withBoldSubstring boldDisplayableString: DisplayableString,
    fontSize: CGFloat,
    color: DynamicColor
  ) -> Self {
    let string: String = displayableString.string()
    let boldSubstring: String = boldDisplayableString
      .string()

    guard let substringRange = string.range(of: boldSubstring, options: .caseInsensitive, locale: .autoupdatingCurrent)
    else {
      assertionFailure("Invalid localized substring: \(boldDisplayableString) for: \(displayableString)")
      return .string(
        .raw(string),
        attributes: Attributes(
          font: .inter(ofSize: fontSize, weight: .regular),
          color: color
        ),
        tail: .terminator
      )
    }

    let splitedStringHead: String = .init(string[string.startIndex..<substringRange.lowerBound])
    let splitedStringTail: String = .init(string[substringRange.upperBound..<string.endIndex])

    return .string(
      .raw(splitedStringHead),
      attributes: Attributes(
        font: .inter(ofSize: fontSize, weight: .regular),
        color: color
      ),
      tail: .string(
        .raw(boldSubstring),
        attributes: Attributes(
          font: .inter(ofSize: fontSize, weight: .bold),
          color: color
        ),
        tail: .string(
          .raw(splitedStringTail),
          attributes: Attributes(
            font: .inter(ofSize: fontSize, weight: .regular),
            color: color
          ),
          tail: .terminator
        )
      )
    )
  }
}

extension AttributedString {

  public func nsAttributedString(
    in interfaceStyle: UIUserInterfaceStyle
  ) -> NSAttributedString {
    switch self {
    case .terminator:
      return NSAttributedString()
    case let .string(displayableString, attributes: attributes, tail: tail):
      let string: String = displayableString.string()
      var stringAttributes: Dictionary<NSAttributedString.Key, Any>? = [
        .font: attributes.font,
        .foregroundColor: attributes.color(in: interfaceStyle),
      ]

      if attributes.isLink {
        stringAttributes?[.link] = string
      }
      else {
        /* NOP */
      }

      let mutableString: NSMutableAttributedString = .init(
        string: string,
        attributes: stringAttributes
      )
      mutableString.append(tail.nsAttributedString(in: interfaceStyle))
      return mutableString
    }
  }
}

extension AttributedString: CustomStringConvertible {

  public var description: String {
    switch self {
    case .terminator:
      return ""
    case let .string(string, attributes: _, tail: tail):
      return string.string() + tail.description
    }
  }
}

extension AttributedString: CustomDebugStringConvertible {

  public var debugDescription: String {
    switch self {
    case .terminator:
      return ""
    case let .string(string, attributes: attributes, tail: tail):
      return "^[\(attributes)]\(string)" + tail.debugDescription
    }
  }
}

extension AttributedString {

  public struct Attributes {

    public var font: UIFont
    public var color: DynamicColor
    public var isLink: Bool

    public init(
      font: UIFont,
      color: DynamicColor,
      isLink: Bool = false
    ) {
      self.font = font
      self.color = color
      self.isLink = isLink
    }
  }
}

extension AttributedString.Attributes: CustomStringConvertible {

  public var description: String {
    "[font: [name:\(font.familyName), size:\(font.pointSize)], color: \(color)]"
  }
}
