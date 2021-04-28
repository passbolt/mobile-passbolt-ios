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

extension Mutation where Subject: TextButton {
  
  public static func textColor(dynamic color: DynamicColor) -> Self {
    .custom { (subject: Subject) in subject.dynamicTextColor = color }
  }
  
  public static func pressedTextColor(dynamic color: DynamicColor) -> Self {
    .custom { (subject: Subject) in subject.dynamicPressedTextColor = color }
  }
  
  public static func disabledTextColor(dynamic color: DynamicColor) -> Self {
    .custom { (subject: Subject) in subject.dynamicDisabledTextColor = color }
  }
  
  public static func text(_ text: String) -> Self {
    .custom { (subject: Subject) in subject.text = text }
  }
  
  public static func text(
    localized key: LocalizationKeyConstant,
    fromTable tableName: String? = nil,
    inBundle bundle: Bundle = Bundle.main,
    arguments: CVarArg...
  ) -> Self {
    Self { (subject: Subject) in
      let localized: String = NSLocalizedString(
        key.rawValue,
        tableName: tableName,
        bundle: bundle,
        comment: ""
      )
      if arguments.isEmpty {
        subject.text = localized
      } else {
        subject.text = String(
          format: localized,
          arguments: arguments
        )
      }
    }
  }
  
  public static func textColor(_ textColor: UIColor) -> Self {
    .custom { (subject: Subject) in subject.textColor = textColor }
  }
  
  public static func pressedTextColor(_ pressedTextColor: UIColor) -> Self {
    .custom { (subject: Subject) in subject.pressedTextColor = pressedTextColor }
  }
  
  public static func disabledTextColor(_ pressedTextColor: UIColor) -> Self {
    .custom { (subject: Subject) in subject.disabledTextColor = pressedTextColor }
  }
  
  public static func font(_ font: UIFont) -> Self {
    .custom { (subject: Subject) in subject.font = font }
  }
  
  public static func textAlignment(_ textAlignment: NSTextAlignment) -> Self {
    .custom { (subject: Subject) in subject.textAlignment = textAlignment }
  }
  
  public static func textInsets(_ textInsets: NSDirectionalEdgeInsets) -> Self {
    .custom { (subject: Subject) in subject.textInsets = textInsets }
  }
  
  public static func textLineBreakMode(_ lineBreakMode: NSLineBreakMode) -> Self {
    .custom { (subject: Subject) in subject.textLineBreakMode = lineBreakMode }
  }
  
  public static func textNumberOfLines(_ numberOfLines: Int) -> Self {
    .custom { (subject: Subject) in subject.textNumberOfLines = numberOfLines }
  }
}
