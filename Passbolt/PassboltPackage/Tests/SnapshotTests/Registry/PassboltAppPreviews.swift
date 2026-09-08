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

import SnapshotTestsSupport
import SwiftUI

@testable import PassboltApp

/// Previews from `PassboltApp` enrolled in snapshot testing.
///
/// Coverage is opt-in: a preview is covered only once named here, and naming the type means
/// renaming or deleting one is a compile error rather than a vanishing test.
///
/// Main-actor isolated because `SnapshotPreview` stores a non-`Sendable` `@MainActor` view builder.
@MainActor
internal enum PassboltAppPreviews {

  private static let module: String = "PassboltApp"

  /// Screen-level previews, four images each: views that fill a screen, roots that are a
  /// `List`/`ScrollView` (no ideal height), and layouts built from `Spacer()`s (ideal length zero).
  ///
  /// Every screen here is DI-bound and loads its content through `ViewStateSource`'s reactive
  /// pipeline, so each is built directly from its own `async` `makeSnapshotPreview()` rather than
  /// through `.of(_:)` — see `SnapshotPreview.view`'s doc for why a `.task`-based load isn't safe
  /// to snapshot otherwise. Naming the method here still makes renaming or deleting it a compile
  /// error, the same protection `.of(_:)` gets from naming the type.
  internal static var all: Array<SnapshotPreview> {
    [
      .init(
        module: module,
        name: "Authorization",
        layout: .device,
        view: { AnyView(await AuthorizationView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "ResourcesList",
        layout: .device,
        view: { AnyView(await ResourcesListView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "ResourceDetails",
        layout: .device,
        view: { AnyView(await ResourceDetailsView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "MainSettings",
        layout: .device,
        view: { AnyView(await MainSettingsView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "ApplicationSettings",
        layout: .device,
        view: { AnyView(await ApplicationSettingsView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "ExpertSettings",
        layout: .device,
        view: { AnyView(await ExpertSettingsView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "AccountsSettings",
        layout: .device,
        view: { AnyView(await AccountsSettingsView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "TermsAndLicenses",
        layout: .device,
        view: { AnyView(await TermsAndLicensesView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "TroubleshootingSettings",
        layout: .device,
        view: { AnyView(await TroubleshootingSettingsView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "DefaultPresentationModeSettings",
        layout: .device,
        view: { AnyView(await DefaultPresentationModeSettingsView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "AccountKeyInspector",
        layout: .device,
        view: { AnyView(await AccountKeyInspectorView_Previews.makeSnapshotPreview()) }
      ),
      .init(
        module: module,
        name: "AccountKeyExportMenu",
        layout: .device,
        view: { AnyView(await AccountKeyExportMenuView_Previews.makeSnapshotPreview()) }
      ),
    ]
  }
}
