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

import Accounts
import CommonDataModels
import Crypto
import UIComponents

public struct ServerFingerprintController {

  public var formattedFingerprint: () -> Fingerprint
  public var saveFingerprintPublisher: () -> AnyPublisher<Void, TheErrorLegacy>
  public var toggleFingerprintMarkedAsChecked: () -> Void
  public var fingerprintMarkedAsCheckedPublisher: () -> AnyPublisher<Bool, Never>
}

extension ServerFingerprintController: UIController {

  public typealias Context = (
    accountID: Account.LocalID,
    fingerprint: Fingerprint
  )

  public static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> ServerFingerprintController {

    let fingerprintStorage: FingerprintStorage = features.instance()

    let fingerprintMarkedAsCheckedSubject: CurrentValueSubject<Bool, Never> = .init(false)

    func formattedFingerprint() -> Fingerprint {
      .init(rawValue: context.fingerprint.rawValue.splitIntoGroups(of: 4).joined(separator: " "))
    }

    func saveFingerprintPublisher() -> AnyPublisher<Void, TheErrorLegacy> {
      guard fingerprintMarkedAsCheckedSubject.value
      else {
        assertionFailure("Invalid state. Save fingerprint should be enabled")
        return Fail(error: .internalInconsistency())
          .eraseToAnyPublisher()
      }

      return fingerprintStorage.storeServerFingerprint(
        context.accountID,
        context.fingerprint
      )
      .asPublisher
    }

    func toggleFingerprintChecked() {
      fingerprintMarkedAsCheckedSubject.value.toggle()
    }

    func fingerPrintCheckedPublisher() -> AnyPublisher<Bool, Never> {
      fingerprintMarkedAsCheckedSubject.eraseToAnyPublisher()
    }

    return Self(
      formattedFingerprint: formattedFingerprint,
      saveFingerprintPublisher: saveFingerprintPublisher,
      toggleFingerprintMarkedAsChecked: toggleFingerprintChecked,
      fingerprintMarkedAsCheckedPublisher: fingerPrintCheckedPublisher
    )
  }
}

extension String {

  fileprivate func splitIntoGroups(of length: IndexDistance) -> Array<String> {
    var result: Array<String> = .init()
    var currentIndex: Index = startIndex

    while let nextIndex = self.index(currentIndex, offsetBy: length, limitedBy: endIndex) {
      result.append(.init(self[currentIndex..<nextIndex]))
      currentIndex = nextIndex
    }

    return result
  }
}
