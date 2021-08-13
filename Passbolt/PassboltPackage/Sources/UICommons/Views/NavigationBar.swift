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

import UIKit

public final class NavigationBar: UINavigationBar {

  public lazy var dynamicBackgroundColor: DynamicColor = .always(self.backgroundColor) {
    didSet {
      self.backgroundColor = dynamicBackgroundColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicTintColor: DynamicColor = .always(self.tintColor) {
    didSet {
      self.tintColor = dynamicTintColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicBarTintColor: DynamicColor = .always(self.barTintColor) {
    didSet {
      self.barTintColor = dynamicBarTintColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicTitleColor: DynamicColor = .always(.black) {
    didSet {
      self.titleTextAttributes = [
        .foregroundColor: dynamicTitleColor(in: traitCollection.userInterfaceStyle),
        .font: titleFont,
      ]
    }
  }

  public lazy var titleFont: UIFont = .systemFont(ofSize: 14) {
    didSet {
      self.titleTextAttributes = [
        .foregroundColor: dynamicTitleColor(in: traitCollection.userInterfaceStyle),
        .font: titleFont,
      ]
    }
  }

  override public func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?
  ) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard traitCollection != previousTraitCollection
    else { return }
    updateColors()
  }

  private func updateColors() {
    let interfaceStyle: UIUserInterfaceStyle = traitCollection.userInterfaceStyle
    self.backgroundColor = dynamicBackgroundColor(in: interfaceStyle)
    self.tintColor = dynamicTintColor(in: interfaceStyle)
    self.barTintColor = dynamicBarTintColor(in: interfaceStyle)
    self.titleTextAttributes = [
      .foregroundColor: dynamicTitleColor(in: interfaceStyle),
      .font: titleFont,
    ]
  }
}
