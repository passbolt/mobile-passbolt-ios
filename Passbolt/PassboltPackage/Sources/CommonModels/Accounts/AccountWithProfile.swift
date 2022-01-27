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

// Read only composite of Account and AccountProfile for displaying authorization and account list.
public struct AccountWithProfile {

  public let localID: Account.LocalID
  public let userID: Account.UserID
  public let domain: URLString
  public var label: String
  public var username: String
  public var firstName: String
  public var lastName: String
  public var avatarImageURL: String
  public let fingerprint: Fingerprint
  public var biometricsEnabled: Bool

  public init(
    localID: Account.LocalID,
    userID: Account.UserID,
    domain: URLString,
    label: String,
    username: String,
    firstName: String,
    lastName: String,
    avatarImageURL: String,
    fingerprint: Fingerprint,
    biometricsEnabled: Bool
  ) {
    self.localID = localID
    self.userID = userID
    self.domain = domain
    self.label = label
    self.username = username
    self.firstName = firstName
    self.lastName = lastName
    self.avatarImageURL = avatarImageURL
    self.fingerprint = fingerprint
    self.biometricsEnabled = biometricsEnabled
  }
}

extension AccountWithProfile {

  public init(
    account: Account,
    profile: AccountProfile
  ) {
    assert(account.localID == profile.accountID)
    self.init(
      localID: account.localID,
      userID: account.userID,
      domain: account.domain,
      label: profile.label,
      username: profile.username,
      firstName: profile.firstName,
      lastName: profile.lastName,
      avatarImageURL: profile.avatarImageURL,
      fingerprint: account.fingerprint,
      biometricsEnabled: profile.biometricsEnabled
    )
  }

  public var account: Account {
    Account(
      localID: localID,
      domain: domain,
      userID: userID,
      fingerprint: fingerprint
    )
  }

  public var profile: AccountProfile {
    AccountProfile(
      accountID: localID,
      label: label,
      username: username,
      firstName: firstName,
      lastName: lastName,
      avatarImageURL: avatarImageURL,
      biometricsEnabled: biometricsEnabled,
      settings: .init()  // not used yet
    )
  }
}

extension AccountWithProfile: Equatable {}
