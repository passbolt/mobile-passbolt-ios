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

public final class AnyUpdatable<Value>
where Value: Sendable {

  @usableFromInline internal let sourceGeneration: @Sendable () -> UpdateGeneration
  @usableFromInline internal let notifyAfter:
    @Sendable (@escaping @Sendable (Update<Value>) -> Void, UpdateGeneration) -> Void

  fileprivate init<Source>(
    erasing source: Source
  ) where Source: Updatable, Source.Value == Value {
    self.sourceGeneration = { source.generation }
    self.notifyAfter = source.notify(_:after:)
  }
}

extension Updatable {

  public func asAnyUpdatable() -> AnyUpdatable<Value> {
    self as? AnyUpdatable<Value> ?? AnyUpdatable<Value>(erasing: self)
  }
}

extension AnyUpdatable: Updatable {

  public nonisolated var generation: UpdateGeneration {
    @_transparent _read {
      yield self.sourceGeneration()
    }
  }

  @_transparent public func notify(
    _ awaiter: @escaping @Sendable (Update<Value>) -> Void,
    after generation: UpdateGeneration
  ) {
    self.notifyAfter(awaiter, generation)
  }
}
