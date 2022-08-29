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
import Commons
import SwiftUI

// Since SwiftUI requires concrete types but not always
// operate on concrete ones we had to create intermediate view
// for images with padding since applying padding changes
// type of View to `some View` which is more or less unspecified.
public struct ImageWithPadding: View {

  private let padding: EdgeInsets
  private let imageName: ImageNameConstant

  public init(
    _ padding: EdgeInsets,
    named imageName: ImageNameConstant
  ) {
    self.padding = padding
    self.imageName = imageName
  }

  public init(
    _ padding: CGFloat = 0,
    named imageName: ImageNameConstant
  ) {
    self.init(
      .init(
        top: padding,
        leading: padding,
        bottom: padding,
        trailing: padding
      ),
      named: imageName
    )
  }

  public var body: some View {
    Image(named: self.imageName)
      .resizable()
      .aspectRatio(1, contentMode: .fit)
      .padding(self.padding)
  }
}
