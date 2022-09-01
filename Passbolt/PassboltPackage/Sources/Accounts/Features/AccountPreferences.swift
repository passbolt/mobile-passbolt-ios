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

import Features

// MARK: - Interface

/// Access to preferences associated with a stored account.
public struct AccountPreferences {

  /// Updates in the context account preferences.
  public var updates: UpdatesSequence
  /// Assign local label for the context account.
  public var setLocalAccountLabel: @Sendable (_ label: String) throws -> Void
  /// Check if account passphrase is stored
  /// for the context account.
  public var isPassphraseStored: @Sendable () -> Bool
  /// Control if account should use biometry
  /// protected storage for the context account passphrase.
  public var storePassphrase: @Sendable (_ store: Bool) async throws -> Void
  /// Control if default ``HomePresentationMode``
  /// should be last used for the context account.
  public var useLastHomePresentationAsDefault: StateBinding<Bool>
  /// Access default ``HomePresentationMode``
  /// for the context account.
  public var defaultHomePresentation: StateBinding<HomePresentationMode>

  public init(
    updates: UpdatesSequence,
    setLocalAccountLabel: @escaping @Sendable (_ label: String) throws -> Void,
    isPassphraseStored: @escaping @Sendable () -> Bool,
    storePassphrase: @escaping @Sendable (_ store: Bool) async throws -> Void,
    useLastHomePresentationAsDefault: StateBinding<Bool>,
    defaultHomePresentation: StateBinding<HomePresentationMode>
  ) {
    self.updates = updates
    self.setLocalAccountLabel = setLocalAccountLabel
    self.isPassphraseStored = isPassphraseStored
    self.storePassphrase = storePassphrase
    self.useLastHomePresentationAsDefault = useLastHomePresentationAsDefault
    self.defaultHomePresentation = defaultHomePresentation
  }
}

extension AccountPreferences: LoadableFeature {

  public typealias Context = Account

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      updates: .placeholder,
      setLocalAccountLabel: unimplemented(),
      isPassphraseStored: unimplemented(),
      storePassphrase: unimplemented(),
      useLastHomePresentationAsDefault: .placeholder,
      defaultHomePresentation: .placeholder
    )
  }
  #endif
}
