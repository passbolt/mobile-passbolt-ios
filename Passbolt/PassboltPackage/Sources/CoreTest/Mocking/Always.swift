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

@Sendable public func always<V>(
  _ value: @autoclosure @escaping () -> V
) -> @Sendable () -> V {
  { value() }
}

@Sendable public func alwaysThrow<V>(
  _ error: @autoclosure @escaping () -> Error
) -> @Sendable () throws -> V {
  { throw error() }
}

@Sendable public func always<A1, V>(
  _ value: @autoclosure @escaping () -> V
) -> @Sendable (A1) -> V {
  { _ in value() }
}

@Sendable public func alwaysThrow<A1, V>(
  _ error: @autoclosure @escaping () -> Error
) -> @Sendable (A1) throws -> V {
  { _ in throw error() }
}

@Sendable public func always<A1, A2, V>(
  _ value: @autoclosure @escaping () -> V
) -> @Sendable (A1, A2) -> V {
  { _, _ in value() }
}

@Sendable public func alwaysThrow<A1, A2, V>(
  _ error: @autoclosure @escaping () -> Error
) -> @Sendable (A1, A2) throws -> V {
  { _, _ in throw error() }
}

@Sendable public func always<A1, A2, A3, V>(
  _ value: @autoclosure @escaping () -> V
) -> @Sendable (A1, A2, A3) -> V {
  { _, _, _ in value() }
}

@Sendable public func alwaysThrow<A1, A2, A3, V>(
  _ error: @autoclosure @escaping () -> Error
) -> @Sendable (A1, A2, A3) throws -> V {
  { _, _, _ in throw error() }
}

@Sendable public func always<A1, A2, A3, A4, V>(
  _ value: @autoclosure @escaping () -> V
) -> @Sendable (A1, A2, A3, A4) -> V {
  { _, _, _, _ in value() }
}

@Sendable public func always<A1, A2, A3, A4, A5, V>(
  _ value: @autoclosure @escaping () -> V
) -> @Sendable (A1, A2, A3, A4, A5) -> V {
  { _, _, _, _, _ in value() }
}

@Sendable public func always<A1, A2, A3, A4, A5, A6, V>(
  _ value: @autoclosure @escaping () -> V
) -> @Sendable (A1, A2, A3, A4, A5, A6) -> V {
  { _, _, _, _, _, _ in value() }
}

@Sendable public func always<A1, A2, A3, A4, A5, A6, A7, V>(
  _ value: @autoclosure @escaping () -> V
) -> @Sendable (A1, A2, A3, A4, A5, A6, A7) -> V {
  { _, _, _, _, _, _, _ in value() }
}

@Sendable public func always<A1, A2, A3, A4, A5, A6, A7, A8, V>(
  _ value: @autoclosure @escaping () -> V
) -> @Sendable (A1, A2, A3, A4, A5, A6, A7, A8) -> V {
  { _, _, _, _, _, _, _, _ in value() }
}
