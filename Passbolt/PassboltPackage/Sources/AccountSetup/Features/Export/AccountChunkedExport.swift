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

import struct Foundation.Data

// MARK: - Interface

/// Exporting current session account using QR codes.
public struct AccountChunkedExport {

  /// Updates in account export process.
  public var updates: AnyUpdatable<Void>
  /// Current status of exporting.
  public var status: @Sendable () -> Status
  /// Initialize export by authorizing, it will prolong
  /// current session.
  /// It will start the process on the backend as well.
  /// It will throw if transfer is already in progress.
  public var authorize: @Sendable (AccountExportAuthorizationMethod) async throws -> Void
  /// Cancel current export if any.
  /// Cancelled process result in error status with CancellationError.
  public var cancel: @Sendable () -> Void

  public init(
    updates: AnyUpdatable<Void>,
    status: @escaping @Sendable () -> Status,
    authorize: @escaping @Sendable (AccountExportAuthorizationMethod) async throws -> Void,
    cancel: @escaping @Sendable () -> Void
  ) {
    self.updates = updates
    self.status = status
    self.authorize = authorize
    self.cancel = cancel
  }
}

extension AccountChunkedExport {

  public enum Status: Equatable {

    case uninitialized
    case part(Int, content: Data)
    case error(TheError)
    case finished

    public static func == (
      _ lhs: Status,
      _ rhs: Status
    ) -> Bool {
      switch (lhs, rhs) {
      case (.uninitialized, .uninitialized), (.finished, .finished):
        return true

      case (.part(let lNum, let lData), .part(let rNum, let rData)):
        return lNum == rNum && lData == rData

      case (.error(let lErr), .error(let rErr)):
        return type(of: lErr) == type(of: rErr)

      case _:
        return false
      }
    }
  }
}

extension AccountChunkedExport: LoadableFeature {


  #if DEBUG
  public static var placeholder: Self {
    .init(
      updates: PlaceholderUpdatable().asAnyUpdatable(),
      status: unimplemented0(),
      authorize: unimplemented1(),
      cancel: unimplemented0()
    )
  }
  #endif
}
