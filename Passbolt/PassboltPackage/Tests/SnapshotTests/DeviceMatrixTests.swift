//
// Passbolt - Open source password manager for teams
// Copyright (c) 2026 Passbolt SA
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

import SnapshotTesting
import SnapshotTestsSupport
import UIKit
import XCTest

/// Guards what makes reference images portable: no canvas may leave its rasterisation scale to
/// the host. A config omitting `displayScale` renders at the running simulator's scale, so every
/// affected baseline then fails on image dimensions on any other machine — and that is invisible
/// on the machine that recorded them, hence a test.
final class DeviceMatrixTests: XCTestCase {

  func test_everyDeviceInMatrix_pinsDisplayScale() {
    for device: ViewImageConfig in SnapshotMatrix.devices {
      let size: String = device.size.map { "\(Int($0.width))x\(Int($0.height))" } ?? "unsized"
      XCTAssertGreaterThan(
        device.traits.displayScale,
        0,
        """
        Device config \(size) does not pin `displayScale`, so its reference images will \
        rasterise at the host simulator's scale. Add `.init(displayScale:)` to its \
        UITraitCollection — see ViewImageConfig+Missing.swift.
        """
      )
    }
  }

  func test_fittedCanvas_pinsDisplayScale() {
    XCTAssertGreaterThan(SnapshotMatrix.fittedDisplayScale, 0)
  }
}
