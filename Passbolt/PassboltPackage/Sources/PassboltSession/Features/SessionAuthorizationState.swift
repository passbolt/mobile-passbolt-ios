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
import Features
import Session

// MARK: - Interface

/// In-memory storage for current session authorization state.
/// For internal use only.
internal struct SessionAuthorizationState {
  /// Current pending authorization if any.
  internal var pendingAuthorization: @SessionActor @Sendable () -> SessionAuthorizationRequest?
  /// Request new authorization. It has no effect
  /// if there is already the same authorization requested.
  /// Passphrase request has priority over
  /// mfa request and will replace it
  /// for the same account.
  /// Requesting authorization for different
  /// account than currently pending is threated
  /// as an error.
  internal var requestAuthorization: @SessionActor @Sendable (SessionAuthorizationRequest) throws -> Void
  /// Request new authorization if needed and
  /// wait for completion of pending authorization.
  /// Returns immediately if authorization
  /// is not required.
  /// Throws if there is no matching session or
  /// authorization becomes canceled or fails.
  internal var waitForAuthorizationIfNeeded: @SessionActor @Sendable (SessionAuthorizationRequest) async throws -> Void
  /// Execute task that is treated as authorization.
  /// If it succeeds any pending authorization
  /// will be treated as succeeded or will fail
  /// if it throws.
  /// This function call will throw immediately
  /// if there is ongoing authorization for the
  /// same account. Use `waitForAuthorization`
  /// in orded to wait for its completion.
  /// If this function is called while there is
  /// pending authorization for different account
  /// it will first cancel pending authorization.
  internal var performAuthorization:
    @SessionActor @Sendable (
      _ account: Account,
      _ authorization: @escaping @Sendable () async throws -> Void
    ) async throws -> Void
  /// Cancel any ongoing or pending authorization.
  /// This method is not an equivalent of closing session,
  /// use Session.close for proper session closing.
  internal var cancelAuthorization: @SessionActor @Sendable () -> Void
}

extension SessionAuthorizationState: LoadableContextlessFeature {

  #if DEBUG
  nonisolated static var placeholder: Self {
    Self(
      pendingAuthorization: unimplemented(),
      requestAuthorization: unimplemented(),
      waitForAuthorizationIfNeeded: unimplemented(),
      performAuthorization: unimplemented(),
      cancelAuthorization: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension SessionAuthorizationState {

  @TaskLocal private static var authorizationIID: IID? = .none

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionState: SessionState = try await features.instance()

    enum PendingAuthorization {

      case passphrase(Account)
      case mfa(Account, Array<SessionMFAProvider>)
      case passphraseAndMFA(Account, Array<SessionMFAProvider>)
    }

    struct OngoingAuthorization {

      let iid: IID
      let account: Account
      let task: Task<Void, Error>
    }

    struct State {

      var pendingAuthorization: PendingAuthorization?
      var ongoingAuthorization: OngoingAuthorization?
    }

    let state: CriticalState<State> = .init(
      .init(
        pendingAuthorization: .none,
        ongoingAuthorization: .none
      )
    )

    let passphraseAuthorizationAwaiterGroup: AwaiterGroup<Void> = .init()
    let mfaAuthorizationAwaiterGroup: AwaiterGroup<Void> = .init()

    @SessionActor @Sendable func pendingAuthorization() -> SessionAuthorizationRequest? {
      switch state.get(\.pendingAuthorization) {
      case .none:
        return .none

      case let .passphrase(account),
        let .passphraseAndMFA(account, _):
        return .passphrase(account)

      case let .mfa(account, mfaProviders):
        return .mfa(account, providers: mfaProviders)
      }
    }

    @SessionActor @Sendable func requestAuthorization(
      _ request: SessionAuthorizationRequest
    ) throws {
      guard request.account == sessionState.account()
      else {
        throw
          SessionClosed
          .error(account: request.account)
      }

      switch state.get(\.pendingAuthorization) {
      // new request when there is none
      case .none:
        switch request {
        case let .passphrase(account):
          state.set(
            \.pendingAuthorization,
            .passphrase(account)
          )

        case let .mfa(account, mfaProviders):
          state.set(
            \.pendingAuthorization,
            .mfa(account, mfaProviders)
          )
        }
        sessionState.updatesSequenceSource.sendUpdate()

      // alerady requested passphrase and MFA
      case .passphraseAndMFA:
        return  // NOP - ignore

      // alerady requested passphrase
      case .passphrase:
        switch request {
        // passphrase already requested
        case .passphrase:
          return  // NOP - ignore

        // promote to passphrase and mfa request
        case let .mfa(account, mfaProviders):
          state.set(
            \.pendingAuthorization,
            .passphraseAndMFA(account, mfaProviders)
          )
          sessionState.updatesSequenceSource.sendUpdate()
        }

      // alerady requested mfa
      case let .mfa(_, mfaProviders):
        switch request {
        // promote to passphrase and mfa request
        case let .passphrase(account):
          state.set(
            \.pendingAuthorization,
            .passphraseAndMFA(account, mfaProviders)
          )
          sessionState.updatesSequenceSource.sendUpdate()

        // mfa already requested
        case .mfa:
          return  // NOP - ignore
        }
      }
    }

    @SessionActor @Sendable func waitForAuthorizationIfNeeded(
      _ request: SessionAuthorizationRequest
    ) async throws {
      if let ongoingAuthorization: OngoingAuthorization = state.get(\.ongoingAuthorization) {
        // MFA authorization requires a valid session token
        // which forces it to go through this function.
        // In order to prevent infinite waiting we are skipping
        // wait in that case and allow it to exit early but
        // we have to request passphrase if that is actually needed.
        if ongoingAuthorization.iid == Self.authorizationIID {
          guard request.account == sessionState.account()
          else {
            throw
              SessionClosed
              .error(account: request.account)
          }

          if // check conditions only for MFA
            case .passphrase = request,
            case .none = sessionState.passphrase(),
            case .mfa = state.get(\.pendingAuthorization)
          {
            // request authorization if passphrase missing
            try requestAuthorization(request)
          }
          else {
            return  // no need to request or wait
          }
        }
        else {
          // wait for ongoing authorization to finish
          await ongoingAuthorization.task
            .waitForCompletion()
        }
      }  // else continue

      guard request.account == sessionState.account()
      else {
        throw
          SessionClosed
          .error(account: request.account)
      }

      switch state.get(\.pendingAuthorization) {
      // no pending request
      case .none:
        switch request {
        case .passphrase:
          if case .none = sessionState.passphrase() {
            // request authorization if passphrase missing
            try requestAuthorization(request)
            // wait for authorization
            try await passphraseAuthorizationAwaiterGroup.awaiter()
          }
          else {
            return  // no need to request or wait
          }

        case .mfa:
          if case .none = sessionState.mfaToken() {
            // request authorization if mfa token missing
            try requestAuthorization(request)
            // wait for authorization
            try await mfaAuthorizationAwaiterGroup.awaiter()
          }
          else {
            return  // no need to request or wait
          }
        }

      // already requested passphrase and mfa
      case .passphraseAndMFA:
        switch request {
        case .passphrase:
          // wait for authorization
          try await passphraseAuthorizationAwaiterGroup.awaiter()
        case .mfa:
          // wait for authorization
          try await mfaAuthorizationAwaiterGroup.awaiter()
        }

      // already requested passphrase
      case .passphrase:
        switch request {
        case .passphrase:
          // wait for authorization
          try await passphraseAuthorizationAwaiterGroup.awaiter()
        case .mfa:
          if case .none = sessionState.mfaToken() {
            // request authorization if mfa token missing
            try requestAuthorization(request)
            // wait for authorization
            try await mfaAuthorizationAwaiterGroup.awaiter()
          }
          else {
            return  // no need to request or wait
          }
        }

      // already requested mfa
      case .mfa:
        switch request {
        case .passphrase:
          if case .none = sessionState.passphrase() {
            // request authorization if passphrase missing
            try requestAuthorization(request)
            // wait for authorization
            try await passphraseAuthorizationAwaiterGroup.awaiter()
          }
          else {
            return  // no need to request or wait
          }

        case .mfa:
          // wait for authorization
          try await mfaAuthorizationAwaiterGroup.awaiter()
        }
      }
    }

    @SessionActor @Sendable func updatePendingRequest() {
      guard let currentAccount: Account = sessionState.account()
      else {
        if case .some = state.get(\.pendingAuthorization) {
          state.set(\.pendingAuthorization, .none)
          sessionState.updatesSequenceSource.sendUpdate()
        }  // else NOP
        passphraseAuthorizationAwaiterGroup.cancelAll()
        mfaAuthorizationAwaiterGroup.cancelAll()
        return  // nothing more to do...
      }

      switch state.get(\.pendingAuthorization) {
      case .none:
        if case .some = sessionState.passphrase() {
          passphraseAuthorizationAwaiterGroup.resumeAll()
        }
        else {
          passphraseAuthorizationAwaiterGroup.cancelAll()
        }
        if case .some = sessionState.mfaToken() {
          mfaAuthorizationAwaiterGroup.resumeAll()
        }
        else {
          mfaAuthorizationAwaiterGroup.cancelAll()
        }

      case .passphrase(currentAccount):
        if case .some = sessionState.passphrase() {
          state.set(\.pendingAuthorization, .none)
          sessionState.updatesSequenceSource.sendUpdate()
          passphraseAuthorizationAwaiterGroup.resumeAll()
        }  // else NOP

      case .passphraseAndMFA(currentAccount, let mfaProviders):
        if case .some = sessionState.passphrase() {
          if sessionState.mfaToken() != .none {
            state.set(\.pendingAuthorization, .none)
            sessionState.updatesSequenceSource.sendUpdate()
            passphraseAuthorizationAwaiterGroup.resumeAll()
            mfaAuthorizationAwaiterGroup.resumeAll()
          }
          else {
            state.set(\.pendingAuthorization, .mfa(currentAccount, mfaProviders))
            sessionState.updatesSequenceSource.sendUpdate()
            passphraseAuthorizationAwaiterGroup.resumeAll()
          }
        }  // else NOP

      case .mfa(currentAccount, _):
        if case .some = sessionState.mfaToken() {
          state.set(\.pendingAuthorization, .none)
          sessionState.updatesSequenceSource.sendUpdate()
          mfaAuthorizationAwaiterGroup.resumeAll()
        }  // else NOP

      // all requests for non current accout
      case _:
        state.set(\.pendingAuthorization, .none)
        sessionState.updatesSequenceSource.sendUpdate()
        passphraseAuthorizationAwaiterGroup.cancelAll()
        mfaAuthorizationAwaiterGroup.cancelAll()
      }
    }

    @SessionActor @Sendable func completeAuthorization(
      for account: Account,
      withError error: Error? = .none
    ) {
      switch error {
      case .none:
        state.set(\.ongoingAuthorization, .none)
        updatePendingRequest()

      case let mfaRequired as SessionMFAAuthorizationRequired:
        state.set(\.ongoingAuthorization, .none)
        // ignore error, account should always match
        try? requestAuthorization(
          .mfa(
            mfaRequired.account,
            providers: mfaRequired.mfaProviders
          )
        )
        updatePendingRequest()

      case is CancellationError, is Cancelled:
        // don't clear ongoing authorization on cancel
        // there can be another authorization
        break

      case .some:
        state.set(\.ongoingAuthorization, .none)
      }
    }

    @SessionActor @Sendable func performAuthorization(
      _ account: Account,
      _ authorization: @escaping @Sendable () async throws -> Void
    ) async throws {
      let authorizationIID: IID = .init()

      try await Self.$authorizationIID
        .withValue(authorizationIID) {
          if let ongoingAuthorization: OngoingAuthorization = state.get(\.ongoingAuthorization) {
            if ongoingAuthorization.account == account {
              // wait for ongoing completion and continue
              await ongoingAuthorization.task.waitForCompletion()
            }
            else {
              // cancel ongoing and continue
              ongoingAuthorization.task.cancel()
            }
          }  // else NOP

          let authorizationTask: Task<Void, Error> = .init { @SessionActor in
            do {
              try Task.checkCancellation()
              try await authorization()
              completeAuthorization(for: account)
            }
            catch {
              completeAuthorization(
                for: account,
                withError: error
              )
              throw error
            }
          }
          state.set(
            \.ongoingAuthorization,
            .init(
              iid: authorizationIID,
              account: account,
              task: authorizationTask
            )
          )

          try await authorizationTask.value
        }
    }

    @SessionActor @Sendable func cancelAuthorization() {
      // current account is not changing here
      // updates sequence is not sending updates here
      // this method is not an equivalent of closing session
      // use Session.close for proper closing session
      if let ongoingAuthorization: OngoingAuthorization = state.get(\.ongoingAuthorization) {
        ongoingAuthorization.task.cancel()
        state.set(\.ongoingAuthorization, .none)
      }  // else NOP

      state.set(\.pendingAuthorization, .none)
      if case .some = state.get(\.pendingAuthorization) {
        state.set(\.pendingAuthorization, .none)
        sessionState.updatesSequenceSource.sendUpdate()
      }  // else NOP

      passphraseAuthorizationAwaiterGroup.cancelAll()
      mfaAuthorizationAwaiterGroup.cancelAll()
    }

    return Self(
      pendingAuthorization: pendingAuthorization,
      requestAuthorization: requestAuthorization(_:),
      waitForAuthorizationIfNeeded: waitForAuthorizationIfNeeded(_:),
      performAuthorization: performAuthorization(_:_:),
      cancelAuthorization: cancelAuthorization
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionAuthorizationState() {
    self.use(
      .lazyLoaded(
        SessionAuthorizationState.self,
        load: SessionAuthorizationState
          .load(features:cancellables:)
      )
    )
  }
}
