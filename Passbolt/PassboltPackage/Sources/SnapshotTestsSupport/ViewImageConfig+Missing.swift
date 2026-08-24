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

// Missing device config from https://github.com/pointfreeco/swift-snapshot-testing/pull/1046/changes
import SnapshotTesting
import UIKit

/// The iPhone 17 family — 17, 17 Pro, 17 Pro Max, Air — is 3x throughout.
///
/// Must be stated somewhere: `UIGraphicsImageRendererFormat(for:)` falls back to the render
/// environment when traits leave `displayScale` unspecified, so an unpinned canvas rasterises at
/// the host simulator's scale and its images fail elsewhere on size rather than on content.
///
/// Stating it on the config is not by itself enough — see `assertSnapshots`, which reads it back
/// out and renders with it.
private let iPhone17FamilyDisplayScale: CGFloat = 3

extension ViewImageConfig {

  /// Copy with `scale` pinned, unless the config already states one of its own.
  ///
  /// This records a device's scale; it does not apply it. `snapshotView` builds the renderer from
  /// the traits passed to `.image(traits:)`, so a config's own traits never reach the format —
  /// `assertSnapshots` reads the scale from here and passes it there.
  internal func pinningDisplayScaleIfUnspecified(_ scale: CGFloat) -> ViewImageConfig {
    // Unspecified reads back as 0, not nil.
    guard self.traits.displayScale == 0
    else {
      return self
    }
    var pinned: ViewImageConfig = self
    pinned.traits = UITraitCollection(
      traitsFrom: [
        self.traits,
        UITraitCollection(displayScale: scale),
      ]
    )
    return pinned
  }
}

extension ViewImageConfig {

  public static let iPhone17 = ViewImageConfig.iPhone17(.portrait)

  public static func iPhone17(_ orientation: Orientation) -> ViewImageConfig {
    let safeArea: UIEdgeInsets
    let size: CGSize
    switch orientation {
    case .landscape:
      safeArea = .init(top: 20, left: 62, bottom: 20, right: 62)
      size = .init(width: 874, height: 402)
    case .portrait:
      safeArea = .init(top: 62, left: 0, bottom: 34, right: 0)
      size = .init(width: 402, height: 874)
    }

    return .init(safeArea: safeArea, size: size, traits: .iPhone17(orientation))
  }

  public static let iPhone17Pro = ViewImageConfig.iPhone17Pro(.portrait)

  public static func iPhone17Pro(_ orientation: Orientation) -> ViewImageConfig {
    let safeArea: UIEdgeInsets
    let size: CGSize
    switch orientation {
    case .landscape:
      safeArea = .init(top: 20, left: 62, bottom: 20, right: 62)
      size = .init(width: 874, height: 402)
    case .portrait:
      safeArea = .init(top: 62, left: 0, bottom: 34, right: 0)
      size = .init(width: 402, height: 874)
    }

    return .init(safeArea: safeArea, size: size, traits: .iPhone17Pro(orientation))
  }

  public static let iPhone17ProMax = ViewImageConfig.iPhone17ProMax(.portrait)

  public static func iPhone17ProMax(_ orientation: Orientation) -> ViewImageConfig {
    let safeArea: UIEdgeInsets
    let size: CGSize
    switch orientation {
    case .landscape:
      safeArea = .init(top: 20, left: 62, bottom: 20, right: 62)
      size = .init(width: 956, height: 440)
    case .portrait:
      safeArea = .init(top: 62, left: 0, bottom: 34, right: 0)
      size = .init(width: 440, height: 956)
    }

    return .init(safeArea: safeArea, size: size, traits: .iPhone17ProMax(orientation))
  }

  public static let iPhoneAir = ViewImageConfig.iPhoneAir(.portrait)

  public static func iPhoneAir(_ orientation: Orientation) -> ViewImageConfig {
    let safeArea: UIEdgeInsets
    let size: CGSize
    switch orientation {
    case .landscape:
      safeArea = .init(top: 20, left: 68, bottom: 29, right: 68)
      size = .init(width: 912, height: 420)
    case .portrait:
      safeArea = .init(top: 68, left: 0, bottom: 34, right: 0)
      size = .init(width: 420, height: 912)
    }

    return .init(safeArea: safeArea, size: size, traits: .iPhoneAir(orientation))
  }
}

extension UITraitCollection {
  public static func iPhone17(
    _ orientation: ViewImageConfig.Orientation
  )
    -> UITraitCollection
  {
    let base: Array<UITraitCollection> = [
      .init(displayScale: iPhone17FamilyDisplayScale),
      .init(forceTouchCapability: .available),
      .init(layoutDirection: .leftToRight),
      .init(preferredContentSizeCategory: .medium),
      .init(userInterfaceIdiom: .phone),
    ]
    switch orientation {
    case .landscape:
      return .init(
        traitsFrom: base + [
          .init(horizontalSizeClass: .compact),
          .init(verticalSizeClass: .compact),
        ]
      )
    case .portrait:
      return .init(
        traitsFrom: base + [
          .init(horizontalSizeClass: .compact),
          .init(verticalSizeClass: .regular),
        ]
      )
    }
  }

  public static func iPhone17Pro(
    _ orientation: ViewImageConfig.Orientation
  )
    -> UITraitCollection
  {
    let base: Array<UITraitCollection> = [
      .init(displayScale: iPhone17FamilyDisplayScale),
      .init(forceTouchCapability: .available),
      .init(layoutDirection: .leftToRight),
      .init(preferredContentSizeCategory: .medium),
      .init(userInterfaceIdiom: .phone),
    ]
    switch orientation {
    case .landscape:
      return .init(
        traitsFrom: base + [
          .init(horizontalSizeClass: .compact),
          .init(verticalSizeClass: .compact),
        ]
      )
    case .portrait:
      return .init(
        traitsFrom: base + [
          .init(horizontalSizeClass: .compact),
          .init(verticalSizeClass: .regular),
        ]
      )
    }
  }

  public static func iPhone17ProMax(
    _ orientation: ViewImageConfig.Orientation
  )
    -> UITraitCollection
  {
    let base: Array<UITraitCollection> = [
      .init(displayScale: iPhone17FamilyDisplayScale),
      .init(forceTouchCapability: .available),
      .init(layoutDirection: .leftToRight),
      .init(preferredContentSizeCategory: .medium),
      .init(userInterfaceIdiom: .phone),
    ]
    switch orientation {
    case .landscape:
      return .init(
        traitsFrom: base + [
          .init(horizontalSizeClass: .regular),
          .init(verticalSizeClass: .compact),
        ]
      )
    case .portrait:
      return .init(
        traitsFrom: base + [
          .init(horizontalSizeClass: .compact),
          .init(verticalSizeClass: .regular),
        ]
      )
    }
  }

  public static func iPhoneAir(
    _ orientation: ViewImageConfig.Orientation
  )
    -> UITraitCollection
  {
    let base: Array<UITraitCollection> = [
      .init(displayScale: iPhone17FamilyDisplayScale),
      .init(forceTouchCapability: .available),
      .init(layoutDirection: .leftToRight),
      .init(preferredContentSizeCategory: .medium),
      .init(userInterfaceIdiom: .phone),
    ]
    switch orientation {
    case .landscape:
      return .init(
        traitsFrom: base + [
          .init(horizontalSizeClass: .regular),
          .init(verticalSizeClass: .compact),
        ]
      )
    case .portrait:
      return .init(
        traitsFrom: base + [
          .init(horizontalSizeClass: .compact),
          .init(verticalSizeClass: .regular),
        ]
      )
    }
  }
}
