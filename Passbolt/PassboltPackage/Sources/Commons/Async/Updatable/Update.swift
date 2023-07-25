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

public struct Update<Value>: Sendable
where Value: Sendable {

  @usableFromInline internal enum Content: Sendable {

    case value(Value)
    case issue(Error)
  }

  @inline(__always) public let generation: UpdateGeneration
  @usableFromInline @inline(__always) internal let content: Content

  @_transparent @usableFromInline internal init(
    generation: UpdateGeneration,
    _ content: Content
  ) {
    self.generation = generation
    self.content = content
  }

  @_transparent public init(
		generation: @autoclosure () -> UpdateGeneration,
    _ value: Value
  ) {
		self.init(
			generation: generation(),
			.value(value)
		)
  }

  @_transparent public init(
		generation: @autoclosure () -> UpdateGeneration,
    _ error: Error
  ) {
		self.init(
			generation: generation(),
			.issue(error)
		)
  }

	@_transparent @usableFromInline internal init(
		generation: @autoclosure () -> UpdateGeneration,
		_ resolve: () throws -> Value
	) {
		do {
			self.content = try .value(resolve())
		}
		catch {
			self.content = .issue(error)
		}
		self.generation = generation()
	}

	@_transparent @usableFromInline internal init(
		generation: @autoclosure () -> UpdateGeneration,
		_ resolve: () async throws -> Value
	) async {
		do {
			self.content = try await .value(resolve())
		}
		catch {
			self.content = .issue(error)
		}
		self.generation = generation()
	}

  @_transparent public init(
		generation: @autoclosure () -> UpdateGeneration
  ) where Value == Void {
		self.init(
			generation: generation(),
			.value(Void())
		)
  }
}

extension Update {

  @_transparent @usableFromInline internal static func uninitialized() -> Self {
    .init(
      generation: .uninitialized,
      .issue(Unavailable.error("Uninitialized variable"))
    )
  }

  @_transparent public static func cancelled() -> Self {
    .init(
      generation: .uninitialized,
      .issue(CancellationError())
    )
  }

  public var value: Value {
    @_transparent get throws {
      switch self.content {
      case .value(let value):
        return value

      case .issue(let error):
        throw error
      }
    }
  }
}
