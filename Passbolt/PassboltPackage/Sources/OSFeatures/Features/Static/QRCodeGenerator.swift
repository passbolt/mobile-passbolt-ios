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

import CoreImage.CIFilterBuiltins
import Features

import class UIKit.UIImage

// MARK: - Interface

public struct QRCodeGenerator {

  public var generateQRCode: @MainActor (Data) throws -> Data
}

extension QRCodeGenerator: StaticFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      generateQRCode: unimplemented1()
    )
  }
  #endif
}

// MARK: - Implementation

extension QRCodeGenerator {

  fileprivate static var live: Self {

    @MainActor func generateQRCode(
      _ content: Data
    ) throws -> Data {
      let context: CIContext = .init()
      let filter: CIFilter & CIQRCodeGenerator = CIFilter.qrCodeGenerator()
      filter.message = content

      if let colorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB),
        let outputImage: CIImage = filter.outputImage,
        let imageData: Data = context.pngRepresentation(
          of: outputImage,
          format: .RGBA8,
          colorSpace: colorSpace
        )
      {
        return imageData
      }
      else {
        throw
          QRCodeGenerationFailure
          .error(
            "Cannot create QR code out of provided message."
          )
      }
    }

    return .init(
      generateQRCode: generateQRCode(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useQRCodeGenerator() {
    self.use(
      QRCodeGenerator.live
    )
  }
}
