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


import TestExtensions

@testable import PassboltAccounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountPreferencesTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    set(
      AccountScope.self,
      context: .mock_ada
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    register(
      { $0.usePassboltAccountPreferences() },
      for: AccountPreferences.self
    )
  }

  /// Patches both backing stores of the passphrase wipe setting.
  ///
  /// `register(_:for:)` only keeps the loader of the requested feature, so the stored
  /// properties have to be provided here - otherwise they resolve to placeholders.
  private func patchMigrationProperties(
    legacyValue: Bool?,
    keychainRead: @escaping @Sendable () throws -> Bool?,
    keychainWrite: @escaping @Sendable (Bool?) throws -> Void,
    clearedLegacyValue: CriticalState<Bool>
  ) {
    patch(
      \PassphraseWipeOnBackgroundStoredProperty.variable,
      with: .init(
        fetch: { legacyValue },
        store: { (value: Bool?) -> Void in
          if case .none = value {
            clearedLegacyValue.set(\.self, true)
          }  // else - not the migration write
        }
      )
    )
    patch(
      \PassphraseWipeOnBackgroundKeychainProperty.variable,
      with: .init(
        fetch: { try? keychainRead() },
        store: { (_: Bool?) -> Void in /* NOP */ }
      )
    )
    patch(
      \PassphraseWipeOnBackgroundKeychainProperty.read,
      with: keychainRead
    )
    patch(
      \PassphraseWipeOnBackgroundKeychainProperty.write,
      with: keychainWrite
    )
  }

  /// Records every value handed to the keychain, failing the write when `failing` is set.
  private func recordingKeychainWrite(
    into writes: CriticalState<Array<Bool?>>,
    failing: Bool = false
  ) -> @Sendable (Bool?) throws -> Void {
    { (value: Bool?) throws -> Void in
      writes.access { (recorded: inout Array<Bool?>) -> Void in
        recorded.append(value)
      }
      if failing {
        throw MockIssue.error()
      }  // else - write succeeded
    }
  }

  func test_load_migratesLegacyValueToKeychain_andClearsIt_whenKeychainWriteSucceeds() async throws {
    let clearedLegacyValue: CriticalState<Bool> = .init(false)
    let keychainWrites: CriticalState<Array<Bool?>> = .init(Array<Bool?>())
    patchMigrationProperties(
      legacyValue: true,
      keychainRead: { .none },
      keychainWrite: recordingKeychainWrite(into: keychainWrites),
      clearedLegacyValue: clearedLegacyValue
    )

    await withInstance { (_: AccountPreferences) in
      let expectedWrites: Array<Bool?> = [true]
      XCTAssertEqual(
        keychainWrites.get(\.self),
        expectedWrites,
        "Legacy value should be written to the keychain"
      )
      XCTAssertTrue(
        clearedLegacyValue.get(\.self),
        "Legacy value should be cleared after a successful write"
      )
    }
  }

  func test_load_keepsLegacyValue_whenKeychainWriteFails() async throws {
    let clearedLegacyValue: CriticalState<Bool> = .init(false)
    let keychainWrites: CriticalState<Array<Bool?>> = .init(Array<Bool?>())
    patchMigrationProperties(
      legacyValue: true,
      keychainRead: { .none },
      keychainWrite: recordingKeychainWrite(
        into: keychainWrites,
        failing: true
      ),
      clearedLegacyValue: clearedLegacyValue
    )

    await withInstance { (_: AccountPreferences) in
      XCTAssertFalse(
        clearedLegacyValue.get(\.self),
        "Legacy value must survive a migration which did not reach the keychain"
      )
    }
  }

  func test_load_keepsLegacyValue_andDoesNotWrite_whenKeychainReadFails() async throws {
    let clearedLegacyValue: CriticalState<Bool> = .init(false)
    let keychainWrites: CriticalState<Array<Bool?>> = .init(Array<Bool?>())
    patchMigrationProperties(
      legacyValue: true,
      keychainRead: { throw MockIssue.error() },
      keychainWrite: recordingKeychainWrite(into: keychainWrites),
      clearedLegacyValue: clearedLegacyValue
    )

    await withInstance { (_: AccountPreferences) in
      XCTAssertTrue(
        keychainWrites.get(\.self).isEmpty,
        "An unreadable keychain must not be treated as a missing value and overwritten"
      )
      XCTAssertFalse(
        clearedLegacyValue.get(\.self),
        "Legacy value must survive a migration which could not read the keychain"
      )
    }
  }

  func test_load_clearsLegacyValue_withoutWriting_whenAlreadyMigrated() async throws {
    let clearedLegacyValue: CriticalState<Bool> = .init(false)
    let keychainWrites: CriticalState<Array<Bool?>> = .init(Array<Bool?>())
    patchMigrationProperties(
      legacyValue: false,
      keychainRead: { true },
      keychainWrite: recordingKeychainWrite(into: keychainWrites),
      clearedLegacyValue: clearedLegacyValue
    )

    await withInstance { (_: AccountPreferences) in
      XCTAssertTrue(
        keychainWrites.get(\.self).isEmpty,
        "Already stored keychain value must not be overwritten by the legacy one"
      )
      XCTAssertTrue(
        clearedLegacyValue.get(\.self),
        "Legacy value should be cleared once the keychain holds a value"
      )
    }
  }

  func test_load_doesNotTouchKeychain_whenThereIsNothingToMigrate() async throws {
    let clearedLegacyValue: CriticalState<Bool> = .init(false)
    let keychainWrites: CriticalState<Array<Bool?>> = .init(Array<Bool?>())
    patchMigrationProperties(
      legacyValue: .none,
      keychainRead: { .none },
      keychainWrite: recordingKeychainWrite(into: keychainWrites),
      clearedLegacyValue: clearedLegacyValue
    )

    await withInstance { (_: AccountPreferences) in
      XCTAssertTrue(keychainWrites.get(\.self).isEmpty)
      XCTAssertFalse(clearedLegacyValue.get(\.self))
    }
  }
}
