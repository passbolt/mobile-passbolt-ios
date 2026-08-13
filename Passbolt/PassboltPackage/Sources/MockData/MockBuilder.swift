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

/// Opts a mock type into ``with(_:)``, the copy-and-mutate builder used to derive a variant of a canned mock.
///
/// Mock fixtures are whole values (`ResourceDTO.mock_1`, `SessionConfiguration.mock_default`), so a test that needs
/// one field changed would otherwise either restate every other field or declare a `var` and mutate it across
/// several statements. Conforming lets it read as a single expression instead:
///
/// ```swift
/// let resource: ResourceDTO = .mock_1.with { $0.permissions = permissions }
/// ```
///
/// Conform any mock whose fixtures need per-test tweaks. The protocol carries no requirements - conformance is the
/// whole declaration - and its conformances belong beside the fixtures they serve, in `Mocks/<Type>+Mock.swift`.
///
/// - Important: Only value types may conform. ``with(_:)`` derives its copy by assignment, which for a reference
///   type would hand back the very same instance with the fixture itself mutated - silently leaking one test's
///   tweak into every later use of that fixture.
public protocol MockBuilder {}

extension MockBuilder where Self: Sendable {

  /// A copy of this value with `builder` applied to it. The receiver is left untouched, so a shared fixture - most
  /// are `static let` - can be derived from repeatedly without one test's tweak reaching another.
  ///
  /// - Parameter builder: Mutates the copy in place. Only the fields a test actually cares about need setting.
  /// - Returns: The mutated copy.
  public func with(_ builder: @Sendable (inout Self) -> Void) -> Self {
    var mutable: Self = self
    builder(&mutable)
    return mutable
  }
}
