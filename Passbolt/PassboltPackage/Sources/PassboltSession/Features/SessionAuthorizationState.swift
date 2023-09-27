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
  /// Request new authorization if needed and
  /// wait for completion of pending authorization.
  /// Returns immediately if authorization
  /// is not required.
  /// Throws if there is no matching session or
  /// authorization becomes canceled or fails.
  internal var waitForAuthorizationIfNeeded: @SessionActor (SessionAuthorizationRequest) async throws -> Void
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
    @SessionActor (
      _ account: Account,
      _ authorization: @escaping @Sendable () async throws -> Void
    ) async throws -> Void
  /// Cancel any ongoing or pending authorization.
  /// This method is not an equivalent of closing session,
  /// use Session.close for proper session closing.
  internal var cancelAuthorization: @SessionActor () -> Void
}

extension SessionAuthorizationState: LoadableFeature {


  #if DEBUG
  nonisolated static var placeholder: Self {
    Self(
      waitForAuthorizationIfNeeded: unimplemented1(),
      performAuthorization: unimplemented2(),
      cancelAuthorization: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension SessionAuthorizationState {

  @TaskLocal private static var authorizationIID: IID? = .none

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let sessionState: SessionState = try features.instance()

    struct OngoingAuthorization {

      let iid: IID
      let account: Account
      let task: Task<Void, Error>
    }

    // always access using SessionActor
    var ongoingAuthorization: OngoingAuthorization? = .none

    let passphraseAuthorizationAwaiterGroup: AwaiterGroup<Void> = .init()
    let mfaAuthorizationAwaiterGroup: AwaiterGroup<Void> = .init()

    @SessionActor func waitForAuthorizationIfNeeded(
      _ request: SessionAuthorizationRequest
    ) async throws {
      if let ongoingAuthorization: OngoingAuthorization = ongoingAuthorization {
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

          if  // check conditions only for MFA
          case .passphrase = request,
            case .none = sessionState.passphrase(),
            case .mfa = sessionState.pendingAuthorization()
          {
            // request authorization if passphrase missing
            try sessionState.authorizationRequested(request)
          }
          else {
            return  // no need to request or wait
          }
        }
        else {
          // wait for ongoing authorization to finish ignoring the error
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

      switch sessionState.pendingAuthorization() {
      // no pending request
      case .none:
        switch request {
        case .passphrase:
          if case .none = sessionState.passphrase() {
            // request authorization if passphrase missing
            try sessionState.authorizationRequested(request)
            // wait for authorization
            try await passphraseAuthorizationAwaiterGroup.awaiter()
          }
          else {
            return  // no need to request or wait
          }

        case .mfa:
          if case .none = sessionState.mfaToken() {
            // request authorization if mfa token missing
            try sessionState.authorizationRequested(request)
            // wait for authorization
            try await mfaAuthorizationAwaiterGroup.awaiter()
          }
          else {
            return  // no need to request or wait
          }
        }

      // already requested passphrase and mfa
      case .passphraseWithMFA:
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
            try sessionState.authorizationRequested(request)
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
            try sessionState.authorizationRequested(request)
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

    @SessionActor func completeAuthorization(
      for account: Account,
      withError error: Error? = .none
    ) {
      switch error {
      case is CancellationError, is Cancelled:
        // don't clear ongoing authorization on cancel
        // there can be another authorization ongoing
        return  // nothing more to do, make sure no updates apply

      case let mfaRequired as SessionMFAAuthorizationRequired:
        do {
          try sessionState.authorizationRequested(
            .mfa(
              mfaRequired.account,
              providers: mfaRequired.mfaProviders
            )
          )
        }
        catch {
          // ignore error, account should always match
          error
            .asTheError()
            .asAssertionFailure()
        }
        break  // continue execution

      case .some, .none:
        break  // continue execution
      }

      ongoingAuthorization = .none

      switch sessionState.pendingAuthorization() {
      case .none:  // nothing pending -> resume all
        mfaAuthorizationAwaiterGroup.resumeAll()
        passphraseAuthorizationAwaiterGroup.resumeAll()

      case .passphrase:  // mfa not pending -> resume mfa
        mfaAuthorizationAwaiterGroup.resumeAll()

      case .mfa:  // passphrase not pending -> resume passphrase
        passphraseAuthorizationAwaiterGroup.resumeAll()

      case .passphraseWithMFA:  // all pending -> resume none
        break  // NOP - ignore
      }
    }

    @SessionActor func performAuthorization(
      _ account: Account,
      _ authorization: @escaping @Sendable () async throws -> Void
    ) async throws {
      guard case .none = Self.authorizationIID
      else { throw CancellationError() }

      let authorizationIID: IID = .init()

      try await Self.$authorizationIID
        .withValue(authorizationIID) {
          if let currentAuthorization: OngoingAuthorization = ongoingAuthorization {
            if currentAuthorization.account == account {
              // wait for ongoing completion ignoring error and continue
              await currentAuthorization.task.waitForCompletion()
            }
            else {
              // cancel ongoing and continue
              currentAuthorization.task.cancel()
            }
          }  // else NOP

          let authorizationTask: Task<Void, Error> = .init { @SessionActor in
            try Task.checkCancellation()
            try await authorization()
          }

          ongoingAuthorization = .init(
            iid: authorizationIID,
            account: account,
            task: authorizationTask
          )

          do {
            try await authorizationTask.value
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
    }

    @SessionActor func cancelAuthorization() {
      // current account is not changing here
      // updates sequence is not sending updates here
      // this method is not an equivalent of closing session
      // use Session.close for proper closing session
      if let currentAuthorization: OngoingAuthorization = ongoingAuthorization {
        currentAuthorization.task.cancel()
        ongoingAuthorization = .none
      }  // else NOP

      passphraseAuthorizationAwaiterGroup.cancelAll()
      mfaAuthorizationAwaiterGroup.cancelAll()
    }

    return Self(
      waitForAuthorizationIfNeeded: waitForAuthorizationIfNeeded(_:),
      performAuthorization: performAuthorization(_:_:),
      cancelAuthorization: cancelAuthorization
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionAuthorizationState() {
    self.use(
      .lazyLoaded(
        SessionAuthorizationState.self,
        load: SessionAuthorizationState
          .load(features:)
      )
    )
  }
}
