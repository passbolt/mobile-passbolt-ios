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

import SwiftUI

/// One SwiftUI preview enrolled in snapshot testing.
///
/// Snapshot coverage is **opt-in**: a preview is covered when, and only when, a registry under
/// `Tests/SnapshotTests/Registry` names it. Enrolling costs one line; declining costs nothing.
/// Because each entry names a `PreviewProvider` type rather than copying its body, renaming or
/// deleting a preview is a compile error rather than a silently vanishing test.
///
/// Note that this reaches previews through `PreviewProvider.previews`, which is ordinary public
/// SwiftUI API. Previews declared with the `#Preview` macro are deliberately **not** supported —
/// the macro expands to a type whose view cannot be recovered at runtime, so covering one would
/// mean copying its source text into the test target. Use `PreviewProvider` for anything meant to
/// be snapshot-tested; `#Preview` remains fine for previews nobody wants pinned.
public struct SnapshotPreview {

  /// How much canvas a preview is rendered onto.
  public enum Layout {

    /// Render at the view's ideal size. Only for views with a size of their own — `.sizeThatFits`
    /// proposes nothing, so a view that takes its width from its parent needs `fittedWidth`.
    case fitted

    /// Render at `SnapshotMatrix.fittedContentWidth`, height fitted. The default for components:
    /// given no width, a `GeometryReader` or `TextField` reports zero, and others render squashed.
    case fittedWidth

    /// Render onto the full device canvas, once per device in `SnapshotMatrix.devices`.
    /// Use for screen-level previews, where safe-area insets and available width are part of
    /// what is being pinned.
    case device
  }

  /// Module the preview belongs to. Becomes a path component of the reference image directory,
  /// which keeps `PassboltApp.AuthorizationView` and `PassboltExtension.AuthorizationView` apart.
  public let module: String
  /// Reference image base name, unique within `module`.
  public let name: String
  /// Canvas the preview is rendered onto. See `Layout`.
  public let layout: Layout
  /// Builds the view. Deferred rather than eager so that a provider whose body is expensive — or
  /// which resolves feature dependencies through `createPreview` — does no work until the test
  /// that needs it runs.
  public let view: @MainActor () -> AnyView

  public init(
    module: String,
    name: String,
    layout: Layout = .fitted,
    view: @escaping @MainActor () -> AnyView
  ) {
    self.module = module
    self.name = name
    self.layout = layout
    self.view = view
  }

  /// Enrols a `PreviewProvider`.
  ///
  /// `name` defaults to the type name with a trailing `_Previews` removed, so
  /// `AvatarView_Previews` records as `AvatarView`. Pass `named:` only when a provider's type name
  /// would produce a confusing or colliding reference image name.
  ///
  /// `layout` defaults to `.fitted`, which suits only components with a size of their own — pass
  /// `.fittedWidth` for anything that spans its width, and `.device` for screen-level previews.
  public static func of<Provider>(
    _ type: Provider.Type,
    module: String,
    layout: Layout = .fitted,
    named name: String? = nil
  ) -> SnapshotPreview
  where Provider: PreviewProvider {
    let typeName: String = String(describing: type)
    let suffix: String = "_Previews"
    let derivedName: String =
      typeName.hasSuffix(suffix)
      ? String(typeName.dropLast(suffix.count))
      : typeName
    return SnapshotPreview(
      module: module,
      name: name ?? derivedName,
      layout: layout,
      view: { AnyView(Provider.previews) }
    )
  }
}
