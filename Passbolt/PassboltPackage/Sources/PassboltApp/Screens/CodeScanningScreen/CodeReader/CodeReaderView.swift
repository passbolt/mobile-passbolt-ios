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

import AVFoundation
import Commons
import UICommons

internal final class CodeReaderView: View {

  private let cameraPreview: AVCaptureVideoPreviewLayer?

  internal init(session captureSession: AVCaptureSession?) {
    self.cameraPreview = captureSession.map(AVCaptureVideoPreviewLayer.init(session:))
    super.init()
  }

  @available(*, unavailable)
  internal required init() {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  override internal func setup() {
    if let cameraPreview: AVCaptureVideoPreviewLayer = cameraPreview {
      cameraPreview.videoGravity = .resizeAspectFill
      layer.addSublayer(cameraPreview)
    }
    else {
      mut(self) {
        .combined(
          .backgroundColor(dynamic: .background)
        )
      }
      Mutation<Label>
        .combined(
          .text(displayable: .localized(key: "code.scanning.camera.unavailable")),
          .numberOfLines(0),
          .textColor(dynamic: .primaryText),
          .font(.inter(ofSize: 16, weight: .bold)),
          .textAlignment(.center),
          .subview(of: self),
          .centerYAnchor(.equalTo, centerYAnchor),
          .centerXAnchor(.equalTo, centerXAnchor),
          .leadingAnchor(.greaterThanOrEqualTo, leadingAnchor),
          .trailingAnchor(.greaterThanOrEqualTo, trailingAnchor)
        )
        .instantiate()
    }
  }

  override internal func layoutSubviews() {
    super.layoutSubviews()
    cameraPreview?.frame = self.bounds
  }
}
