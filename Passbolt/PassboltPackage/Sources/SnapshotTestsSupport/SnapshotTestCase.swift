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

import Foundation
import SnapshotTesting
import SwiftUI
import XCTest

/// Base test case for the registry-driven snapshot tests. Scopes the snapshot-testing record
/// mode via `withSnapshotTesting` (replaces the deprecated global `SnapshotTesting.isRecording`
/// flag from pre-1.18). Locale (`LANG=en_US.UTF-8`) and time zone (`TZ=UTC`) are pinned for
/// deterministic rendering via the `SnapshotTestPlan.xctestplan` environment, so they apply
/// before Foundation caches `Locale.current` / `TimeZone.current`.
@MainActor
open class SnapshotTestCase: XCTestCase {

  override open func invokeTest() {
    let recordMode: SnapshotTestingConfiguration.Record =
      ProcessInfo.processInfo.environment["SNAPSHOT_TESTING_RECORD"] == "true"
      ? .all
      : .missing
    withSnapshotTesting(record: recordMode) {
      super.invokeTest()
    }
  }

  /// Renders every registered preview across the full `SnapshotMatrix`.
  ///
  /// Every combination is attempted even after one fails: `assertSnapshots` reports through
  /// `XCTFail` rather than throwing, so a single UI change that moves twenty baselines reports
  /// all twenty rather than stopping at the first. Each failure names its own reference image
  /// path — `<scheme>/<size>/<module>/preview.<name>.png` — which is what identifies it.
  public func assertMatrix(
    of previews: Array<SnapshotPreview>,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    for preview: SnapshotPreview in previews {
      // A fitted preview renders identically whatever screen it would have sat on, so the
      // device dimension collapses to a single pass. Recording it per device would only
      // duplicate the same image under two directory names.
      let devices: Array<ViewImageConfig?>
      switch preview.layout {
      case .fitted:
        devices = [.none]
      case .device:
        devices = SnapshotMatrix.devices.map { .some($0) }
      }

      for colorScheme: ColorScheme in SnapshotMatrix.colorSchemes {
        for device: ViewImageConfig? in devices {
          assertSnapshots(
            of: preview.view(),
            named: preview.name,
            module: preview.module,
            colorScheme: colorScheme,
            device: device,
            file: file,
            // swift-snapshot-testing composes the file name as `<testName>.<named>`. Every
            // preview in a module shares one test method, so `#function` would stamp the same
            // method name onto all of them — and rename every baseline if that method were ever
            // renamed. A constant keeps reference image names tied to the preview alone.
            testName: Self.snapshotFileNamePrefix,
            line: line
          )
        }
      }
    }
  }

  private static let snapshotFileNamePrefix: String = "preview"
}
