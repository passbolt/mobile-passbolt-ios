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

import AccountSetup
import Accounts
import Display
import FeatureScopes
import OSFeatures
import SharedUIComponents

internal final class AccountKeyInspectorViewController: ViewController {

  internal struct State: Equatable {

    internal var avatarImage: Data?
    internal var name: String
    internal var userID: String
    internal var fingerprint: String
    internal var crationDate: String
    internal var expirationDate: String?
    internal var keySize: String
    internal var algorithm: String
  }

  internal let viewState: ViewStateSource<State>

  private let navigationToAccountKeyExportMenu: NavigationToAccountKeyExportMenu

  private let accountDetails: AccountDetails
  private let pasteboard: OSPasteboard
  private let calendar: OSCalendar

  private let features: Features

  internal init(
    context: Void,
    features: Features
  ) throws {
    self.features = features

    self.pasteboard = features.instance()
    self.calendar = features.instance()
    self.accountDetails = try features.instance()

    self.navigationToAccountKeyExportMenu = try features.instance()

    self.viewState = .init(
      initial: .init(
        avatarImage: .none,
        name: "",
        userID: "",
        fingerprint: "",
        crationDate: "",
        expirationDate: "",
        keySize: "",
        algorithm: ""
      ),
      updateFrom: self.accountDetails.updates,
      update: { [accountDetails, calendar] (updateView, _) in
        do {
          let accountWithProfile: AccountWithProfile = try accountDetails.profile()
          await updateView { (viewState: inout State) in
            viewState.name = "\(accountWithProfile.firstName) \(accountWithProfile.lastName)"
          }
          let keyDetails: PGPKeyDetails = try await accountDetails.keyDetails()
          await updateView { (viewState: inout State) in
            viewState.userID = keyDetails.userID
            viewState.fingerprint = formatFingerprint(keyDetails.fingerprint)
            viewState.crationDate = calendar.format(.medium, keyDetails.created)
            viewState.expirationDate = keyDetails.expires
              .map { calendar.format(.medium, $0) }
            viewState.keySize = "\(keyDetails.length)"
            viewState.algorithm = keyDetails.algorithm.rawValue
          }
          let accountAvatarImage: Data? = try await accountDetails.avatarImage()
          await updateView { (viewState: inout State) in
            viewState.avatarImage = accountAvatarImage
          }
        }
        catch {
          error.consume(
            context: "Failed to update account key details!"
          )
        }
      }
    )
  }

  internal func copyUserID() async {
    await self.pasteboard.put(self.viewState.current.userID)
    SnackBarMessageEvent.send(
      "account.key.inspector.uid.copied.message"
    )
  }

  internal func copyFingerprint() async {
    await self.pasteboard.put(self.viewState.current.fingerprint)
    SnackBarMessageEvent.send(
      "account.key.inspector.fingerprint.copied.message"
    )
  }

  internal func showExportMenu() async {
    await self.navigationToAccountKeyExportMenu.performCatching()
  }
}

private func formatFingerprint(
  _ fingerprint: Fingerprint
) -> String {
  var formattedString: String = fingerprint.rawValue
  var currentIndex: String.Index = formattedString.startIndex
  while let nextIndex: String.Index =
    formattedString
    .index(
      currentIndex,
      offsetBy: 4,
      limitedBy: formattedString.endIndex
    )
  {
    guard nextIndex != formattedString.endIndex else { break }
    formattedString.insert(" ", at: nextIndex)
    currentIndex =
      formattedString
      .index(
        nextIndex,
        offsetBy: 1,
        limitedBy: formattedString.endIndex
      ) ?? nextIndex
  }

  return formattedString
}
