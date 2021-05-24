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

extension Mutation where Subject: Button {
  
  public static func backgroundColor(dynamic color: DynamicColor) -> Self {
    .custom { (subject: Subject) in subject.dynamicBackgroundColor = color }
  }
  
  public static func pressedBackgroundColor(dynamic color: DynamicColor) -> Self {
    .custom { (subject: Subject) in subject.dynamicPressedBackgroundColor = color }
  }
  
  public static func disabledBackgroundColor(dynamic color: DynamicColor) -> Self {
    .custom { (subject: Subject) in subject.dynamicDisabledBackgroundColor = color }
  }
  
  public static func tintColor(dynamic color: DynamicColor) -> Self {
    .custom { (subject: Subject) in subject.dynamicTintColor = color }
  }
  
  public static func pressedBackgroundColor(_ color: UIColor?) -> Self {
    .custom { (subject: Subject) in subject.pressedBackgroundColor = color }
  }
  
  public static func disabledBackgroundColor(_ color: UIColor?) -> Self {
    .custom { (subject: Subject) in subject.disabledBackgroundColor = color }
  }
  
  public static func border(dynamic color: DynamicColor, width: CGFloat = 1) -> Self {
    .custom { (subject: Subject) in
      subject.dynamicBorderColor = color
      subject.layer.borderWidth = width
    }
  }
  
  public static func enabled() -> Self {
    .custom { (subject: Subject) in subject.isEnabled = true }
  }
  
  public static func disabled() -> Self {
    .custom { (subject: Subject) in subject.isEnabled = false }
  }
}
