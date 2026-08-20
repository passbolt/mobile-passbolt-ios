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
import UIKit
import XCTest

/// Routes snapshot reference images to the `Snapshots/` resource directory bundled with
/// `SnapshotTestsSupport` and applies the {color scheme} × {device} matrix.
/// `device` is `nil` for `SnapshotPreview.Layout.fitted` — the view is then rendered at its ideal
/// size rather than onto a screen, and the reference image lands in a `fitted` directory instead
/// of a per-size one.
@MainActor
public func assertSnapshots(
  of view: AnyView,
  named: String,
  module: String,
  colorScheme: ColorScheme,
  device: ViewImageConfig?,
  file: StaticString = #filePath,
  testName: String = #function,
  line: UInt = #line
) {
  let directory: String = SnapshotMatrix.referenceDirectory(
    colorScheme: colorScheme,
    device: device,
    module: module
  )
  // Wrap the view with an adaptive system background so transparent regions in
  // the view (e.g. `.clear`-background IconButtons in MFAView) show the host
  // window's adaptive background instead of the UIHostingController's default
  // hardcoded white.
  let configuredView: AnyView = AnyView(
    view
      .environment(\.colorScheme, colorScheme)
      .background(Color(uiColor: UIColor.systemBackground))
  )

  let traits: UITraitCollection = UITraitCollection(
    userInterfaceStyle: colorScheme == .dark ? .dark : .light
  )

  let imageLayout: SwiftUISnapshotLayout
  if let device: ViewImageConfig = device {
    imageLayout = .device(config: device)
  }
  else {
    imageLayout = .sizeThatFits
  }

  // KNOWN LIMITATION: UICommons/Colors.swift resolves named UIColors EAGERLY
  // via `UIColor(named:in:compatibleWith: .current)`, collapsing them to a
  // single static variant at access time. SwiftUI can't switch those at render
  // time because they've already lost their dark-mode resolver. We scope
  // `UITraitCollection.current` here so any `.current` lookups that happen on
  // the main thread during the render see the intended traits — most named
  // colors will then come out correct. The proper fix is to change Colors.swift
  // to return `UIColor { traits in … }` dynamic providers (out of POC scope).
  var failure: String? = nil
  traits.performAsCurrent {
    failure = verifySnapshot(
      of: configuredView,
      as: .wait(
        for: 0.3,
        on: .image(
          // `precision` is the fraction of pixels allowed to differ; `perceptualPrecision`
          // is how far any single pixel may drift before it counts as different.
          //
          // These do NOT do the same job, and confusing them makes the whole suite
          // decorative. A pixel *budget* scales with canvas area, not with the component
          // under test: at `precision: 0.99` a full-device image grants roughly 22k–38k
          // free pixels, while two 24pt icons occupy about 10k. Deleting both icons
          // outright changed 0.27% of the image and passed comfortably.
          //
          // So: no pixel budget at all, and absorb rendering noise per-pixel instead.
          // `perceptualPrecision: 0.98` still tolerates the antialiasing and colour-space
          // jitter that varies between machines and OS versions — which is the actual
          // problem a loosened `precision` was reaching for.
          //
          // If this starts flaking, tighten what is being rendered rather than reinstating
          // a pixel budget; a budget large enough to hide noise is large enough to hide a
          // deleted control.
          precision: 1.0,
          perceptualPrecision: 0.98,
          layout: imageLayout,
          traits: traits
        )
      ),
      named: named,
      snapshotDirectory: directory,
      file: file,
      testName: testName,
      line: line
    )
  }
  if let failure: String = failure {
    XCTFail(failure, file: file, line: line)
  }
}

public enum SnapshotMatrix {

  public static let colorSchemes: Array<ColorScheme> = [
    .light,
    .dark,
  ]

  public static let devices: Array<ViewImageConfig> = [
    .iPhone8(.portrait),
    .iPhone17ProMax(.portrait),
  ]

  /// Reference images are laid out `<color scheme>/<width>x<height>/<module>/`, or
  /// `<color scheme>/fitted/<module>/` for previews rendered at their ideal size.
  ///
  /// The module level is not cosmetic: `PassboltApp` and `PassboltExtension` both declare
  /// `AuthorizationView` and `AccountSelectionView`, so without it their reference images would
  /// overwrite each other. It also keeps the tree browsable.
  public static func referenceDirectory(
    colorScheme: ColorScheme,
    device: ViewImageConfig?,
    module: String
  ) -> String {
    let schemeFolder: String
    switch colorScheme {
    case .dark: schemeFolder = "dark"
    default: schemeFolder = "light"
    }
    let sizeFolder: String
    if let device: ViewImageConfig = device {
      guard let size: CGSize = device.size
      else {
        fatalError("ViewImageConfig.size is required for snapshot routing")
      }
      sizeFolder = "\(Int(size.width))x\(Int(size.height))"
    }
    else {
      sizeFolder = "fitted"
    }
    let directory: URL =
      snapshotsRoot()
      .appendingPathComponent(schemeFolder, isDirectory: true)
      .appendingPathComponent(sizeFolder, isDirectory: true)
      .appendingPathComponent(module, isDirectory: true)
    return directory.path
  }

  /// Resolves the on-disk `Snapshots/` directory for reads/writes.
  ///
  /// `Sources/SnapshotTestsSupport/Snapshots/` is a Git submodule pointing at the
  /// passbolt-ios-screenshot-testing repository — the source of truth for every reference
  /// image. It is mounted at that exact path so the `.copy("Snapshots")` resource declared on
  /// this target keeps working unchanged.
  ///
  /// Local builds use the package source path so `record_snapshots` writes back into the
  /// submodule working tree (commit and push there, then record the new commit in this repo).
  /// On CI the simulator's test sandbox cannot reach `/Volumes/workspace/repository/...`, so we
  /// fall back to the bundled resource copy at `Bundle.module/Snapshots/`, which lives inside
  /// the test bundle and is therefore sandbox-accessible.
  private static func snapshotsRoot(file: StaticString = #filePath) -> URL {
    let sourceDir: URL = URL(fileURLWithPath: "\(file)")
      .deletingLastPathComponent()
      .appendingPathComponent("Snapshots", isDirectory: true)
    if FileManager.default.fileExists(atPath: sourceDir.path) {
      return sourceDir
    }
    if let resourceURL: URL = Bundle.module.resourceURL?
      .appendingPathComponent("Snapshots", isDirectory: true),
      FileManager.default.fileExists(atPath: resourceURL.path)
    {
      return resourceURL
    }
    fatalError(
      """
      Could not locate Snapshots/ — checked \(sourceDir.path) and Bundle.module resources.
      The reference images are a Git submodule; populate it with `make snapshots_init`.
      """
    )
  }
}
