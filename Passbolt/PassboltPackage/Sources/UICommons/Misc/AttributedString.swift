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

public enum AttributedString {

  indirect case string(String, attributes: Attributes, tail: AttributedString)
  case terminator
}

extension AttributedString {

  public static func localized(
    _ localizationKey: LocalizationKeyConstant,
    fromTable tableName: String? = nil,
    inBundle bundle: Bundle = Bundle.main,
    arguments: CVarArg...,
    font: UIFont,
    color: DynamicColor
  ) -> Self {
    let localized: String = .init(
      format: NSLocalizedString(
        localizationKey.rawValue,
        tableName: tableName,
        bundle: bundle,
        comment: ""
      ),
      arguments: arguments
    )

    return .string(
      localized,
      attributes: Attributes(
        font: font,
        color: color
      ),
      tail: .terminator
    )
  }

  public static func localized(
    _ localizationKey: LocalizationKeyConstant,
    withBoldSubstringLocalized boldLocalizationKey: LocalizationKeyConstant,
    fromTable tableName: String? = nil,
    inBundle bundle: Bundle = Bundle.main,
    fontSize: CGFloat,
    color: DynamicColor
  ) -> Self {
    let string: String = NSLocalizedString(
      localizationKey.rawValue,
      tableName: tableName,
      bundle: bundle,
      comment: ""
    )

    let boldSubstring: String = NSLocalizedString(
      boldLocalizationKey.rawValue,
      tableName: tableName,
      bundle: bundle,
      comment: ""
    )
    guard let substringRange = string.range(of: boldSubstring)
    else {
      assertionFailure("Invalid localized substring: \(boldLocalizationKey) for: \(localizationKey)")
      return .string(
        string,
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
      splitedStringHead,
      attributes: Attributes(
        font: .inter(ofSize: fontSize, weight: .regular),
        color: color
      ),
      tail: .string(
        boldSubstring,
        attributes: Attributes(
          font: .inter(ofSize: fontSize, weight: .bold),
          color: color
        ),
        tail: .string(
          splitedStringTail,
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
    case let .string(string, attributes: attributes, tail: tail):
      let mutableString: NSMutableAttributedString = .init(
        string: string,
        attributes: [
          .font: attributes.font,
          .foregroundColor: attributes.color(in: interfaceStyle),
        ]
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
      return string + tail.description
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
  }
}

extension AttributedString.Attributes: CustomStringConvertible {

  public var description: String {
    "[font: [name:\(font.familyName), size:\(font.pointSize)], color: \(color)]"
  }
}
