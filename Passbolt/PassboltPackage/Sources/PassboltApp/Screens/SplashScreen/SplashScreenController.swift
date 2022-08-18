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

import Accounts
import CommonModels
import Session
import SessionData
import UIComponents

internal struct SplashScreenController {

  internal var navigationDestinationPublisher: @MainActor () -> AnyPublisher<Destination, Never>
  internal var retryFetchConfiguration: @MainActor () async throws -> Void
  internal var shouldDisplayUpdateAlert: @MainActor () async -> Bool
}

extension SplashScreenController {

  internal enum Destination: Equatable {

    case accountSetup
    case accountSelection(Account?, message: DisplayableString?)
    case diagnostics
    case home
    case mfaAuthorization(Array<SessionMFAProvider>)
    case featureConfigFetchError
  }
}

extension SplashScreenController: UIController {

  internal typealias Context = Account?

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let accounts: Accounts = try await features.instance()
    let session: Session = try await features.instance()
    let sessionConfiguration: SessionConfiguration = try await features.instance()
    let updateCheck: UpdateCheck = try await features.instance()

    let destinationSubject: CurrentValueSubject<Destination?, Never> = .init(nil)

    cancellables.executeAsync { () -> Void in
      do {
        try accounts.verifyDataIntegrity()
      }
      catch {
        return
          destinationSubject
          .send(.diagnostics)
      }

      do {
        try await fetchConfiguration()
      }
      catch {
        return destinationSubject.send(.featureConfigFetchError)
      }

      let storedAccounts: Array<Account> = accounts.storedAccounts()

      if storedAccounts.isEmpty {
        return
          destinationSubject
          .send(.accountSetup)
      }
      else if let currentAccount: Account =
        try? await session.currentAccount(),
        currentAccount == context || context == .none
      {
        switch await session.pendingAuthorization() {
        case .none:
          return
            destinationSubject
            .send(.home)

        case let .mfa(_, mfaProviders):
          return
            destinationSubject
            .send(.mfaAuthorization(mfaProviders))

        case let .passphrase(account):
          return
            destinationSubject
            .send(
              .accountSelection(
                account,
                message: .localized("authorization.prompt.refresh.session.reason")
              )
            )
        }
      }
      else {
        return
          destinationSubject
          .send(
            .accountSelection(
              context,
              message: nil
            )
          )
      }
    }

    @Sendable nonisolated func fetchConfiguration() async throws {
      try await sessionConfiguration.fetchIfNeeded()
    }

    @Sendable nonisolated func retryFetchConfiguration() async throws {
      try await fetchConfiguration()
      destinationSubject.send(.home)
    }

    func destinationPublisher() -> AnyPublisher<Destination, Never> {
      destinationSubject
        .filterMapOptional()
        .eraseToAnyPublisher()
    }

    func shouldDisplayUpdateAlert() async -> Bool {
      guard await updateCheck.checkRequired()
      else { return false }

      do {
        return try await updateCheck.updateAvailable()
      }
      catch {
        return false
      }
    }

    return Self(
      navigationDestinationPublisher: destinationPublisher,
      retryFetchConfiguration: retryFetchConfiguration,
      shouldDisplayUpdateAlert: shouldDisplayUpdateAlert
    )
  }
}
