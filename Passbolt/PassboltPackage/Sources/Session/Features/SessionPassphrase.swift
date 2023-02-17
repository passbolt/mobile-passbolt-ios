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

import CommonModels
import Features

// MARK: - Interface

/// SessionPassphrase provides access
/// to session passphrase related methods.
public struct SessionPassphrase {
  /// Control session passphrase storage.
  /// When called with `true` current session
  /// passphrase will be stored using biometry.
  /// When called with `false` current session
  /// passphrese will be removed from storage.
  /// Waits for session authorization if needed.
  /// Throws if there is no session or passphrase is missing.
  public var storeWithBiometry: @SessionActor @Sendable (Bool) async throws -> Void

  public init(
    storeWithBiometry: @escaping @SessionActor @Sendable (Bool) async throws -> Void
  ) {
    self.storeWithBiometry = storeWithBiometry
  }
}

extension SessionPassphrase: LoadableFeature {

  public struct Context: LoadableFeatureContext {

    public var identifier: AnyHashable { self.account }

    public var account: Account

    public init(
      account: Account
    ) {
      self.account = account
    }
  }

  #if DEBUG
  public nonisolated static var placeholder: Self {
    Self(
      storeWithBiometry: unimplemented1()
    )
  }
  #endif
}
