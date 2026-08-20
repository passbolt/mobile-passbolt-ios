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

@testable import UICommons

/// Previews from `UICommons` enrolled in snapshot testing.
///
/// Snapshot coverage is opt-in. Add a line to cover a preview; leave it out to skip one. Because
/// each entry names the `PreviewProvider` type, renaming or deleting a preview breaks this file at
/// compile time rather than silently dropping a test.
///
/// Every `PreviewProvider` in `UICommons` is currently enrolled. Adding a preview does *not* add
/// coverage on its own — a line has to be added here too.
///
/// Main-actor isolated because `SnapshotPreview` stores a `@MainActor` view builder, which is not
/// `Sendable`; under Swift 6 a non-isolated static of that type would be rejected.
@MainActor
internal enum UICommonsPreviews {

  private static let module: String = "UICommons"

  internal static var all: Array<SnapshotPreview> {
    previews.map { .of($0, module: module) }
  }

  private static let previews: Array<any PreviewProvider.Type> = [
    IconButton_Previews.self
  ]
}
