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

import SwiftUI

public struct UserAvatarView: View {

  private let imageLoad: (() async -> Data?)?
  @State var loadedImage: Image?
  private let image: Image

  public init(
    imageLoad: @escaping () async -> Data?
  ) {
    self.imageLoad = imageLoad
    self.image = Image(named: .person)
  }

  public init(
    imageData: Data?
  ) {
    self.imageLoad = .none
    self.image =
      imageData.flatMap(Image.init(data:))
      ?? Image(named: .person)
  }

  public var body: some View {
    AvatarView {
      if case .some = imageLoad, let loadedImage: Image = self.loadedImage {
        loadedImage
          .resizable()
          .task {
            if case .none = self.loadedImage {
              self.loadedImage =
                await self.imageLoad?().flatMap(Image.init(data:))
                ?? self.image
            }  // else NOP
          }
      }
      else {
        self.image
          .resizable()
      }
    }
  }
}

#if DEBUG

internal struct UserAvatarView_Previews: PreviewProvider {

  internal static var previews: some View {
    UserAvatarView(imageData: .none)
  }
}
#endif
