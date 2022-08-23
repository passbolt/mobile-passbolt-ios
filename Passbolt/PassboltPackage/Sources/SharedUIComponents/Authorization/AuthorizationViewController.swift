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
import CommonModels
import Crypto
import Foundation
import Network
import UIComponents

public final class AuthorizationViewController: PlainViewController, UIComponent {

  public typealias ContentView = AuthorizationView
  public typealias Controller = AuthorizationController

  public static func instance(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self {
    Self(
      using: controller,
      with: components,
      cancellables: cancellables
    )
  }

  public private(set) lazy var contentView: AuthorizationView = .init()
  public var components: UIComponentFactory

  private let controller: Controller
  // sign in can be made only if it is nil
  private var signInCancellable: AnyCancellable?
  private let autoLoginPromptSubject: PassthroughSubject<Never, Never> = .init()

  public init(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.controller = controller
    self.components = components
    super.init(
      cancellables: cancellables
    )
  }

  public func setup() {
    self.title =
      DisplayableString
      .localized(key: "authorization.title")
      .string()

    mut(navigationItem) {
      .rightBarButtonItem(
        Mutation<UIBarButtonItem>
          .combined(
            .image(named: .help, from: .uiCommons),
            .action { [weak self] in
              self?.cancellables.executeOnMainActor { [weak self] in
                await self?.presentSheetMenu(HelpMenuViewController.self, in: [])
              }
            }
          )
          .instantiate()
      )
    }
  }

  public func setupView() {
    mut(contentView) {
      .backgroundColor(dynamic: .background)
    }

    setupSubscriptions()
  }

  public func activate() {
    autoLoginPromptSubject
      .delay(for: 0.05, scheduler: RunLoop.main)
      .sink(receiveCompletion: { [unowned self] _ in
        guard signInCancellable == nil
        else { return }
        self.signInCancellable = self.handleSignInAction(
          self.controller
            .biometricSignIn
        )
      })
      .store(in: cancellables)
  }

  public func deactivate() {
    signInCancellable = nil
  }

  private func setupSubscriptions() {
    Publishers.CombineLatest(
      controller
        .accountWithProfilePublisher(),
      controller
        .biometricStatePublisher()
    )
    .receive(on: RunLoop.main)
    .sink { [weak self] accountWithProfile, biometricsState in
      self?.contentView.applyOn(name: .text("\(accountWithProfile.label)"))
      self?.contentView.applyOn(email: .text(accountWithProfile.username))
      self?.contentView.applyOn(url: .text(accountWithProfile.domain.rawValue))
      switch biometricsState {
      case .unavailable:
        self?.contentView.applyOn(
          biometricButtonContainer: .hidden(true)
        )
      case .faceID:
        self?.contentView.applyOn(
          biometricButton: .image(named: .faceID, from: .uiCommons)
        )
        self?.contentView.applyOn(
          biometricButtonContainer: .hidden(false)
        )
        self?.autoLoginPromptSubject.send(completion: .finished)
      case .touchID:
        self?.contentView.applyOn(
          biometricButton: .image(named: .touchID, from: .uiCommons)
        )
        self?.contentView.applyOn(
          biometricButtonContainer: .hidden(false)
        )
        self?.autoLoginPromptSubject.send(completion: .finished)
      }
    }
    .store(in: cancellables)

    controller
      .accountAvatarPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] data in
        guard
          let imageData = data,
          let image: UIImage = .init(data: imageData)
        else { return }

        self?.contentView.applyOn(image: .image(image))
      }
      .store(in: cancellables)

    contentView
      .secureTextPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] passphrase in
        self?.controller.updatePassphrase(passphrase)
      }
      .store(in: cancellables)

    controller
      .validatedPassphrasePublisher()
      .first()  // skipping error just to update intial value
      .map { Validated.valid($0.value) }
      .merge(
        with:
          controller
          .validatedPassphrasePublisher()
          .dropFirst()
      )
      .receive(on: RunLoop.main)
      .sink { [weak self] validatedPassphrase in
        self?.contentView.update(from: validatedPassphrase)
        self?.contentView.applyOn(
          signInButton: .when(
            validatedPassphrase.isValid,
            then: .enabled(),
            else: .disabled()
          )
        )
      }
      .store(in: cancellables)

    controller
      .validatedPassphrasePublisher()
      .map(\.isValid)
      .receive(on: RunLoop.main)
      .sink { [weak self] isValid in
        self?.contentView.applyOn(
          signInButton: .when(
            isValid,
            then: .enabled(),
            else: .disabled()
          )
        )
      }
      .store(in: cancellables)

    contentView
      .signInTapPublisher
      .sink { [unowned self] in
        guard signInCancellable == nil
        else { return }
        self.signInCancellable = self.handleSignInAction(
          self.controller
            .signIn
        )
      }
      .store(in: cancellables)

    contentView
      .biometricTapPublisher
      .sink { [unowned self] in
        guard signInCancellable == nil
        else { return }
        self.signInCancellable = self.handleSignInAction(
          self.controller
            .biometricSignIn
        )
      }
      .store(in: cancellables)

    contentView
      .forgotTapPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.controller
          .presentForgotPassphraseAlert()
      }
      .store(in: cancellables)

    controller
      .presentForgotPassphraseAlertPublisher()
      .sink { [weak self] presented in
        self?.cancellables.executeOnMainActor { [weak self] in
          guard let self = self else { return }

          if presented {
            await self.present(ForgotPassphraseAlertViewController.self)
          }
          else {
            await self.dismiss(ForgotPassphraseAlertViewController.self)
          }
        }
      }
      .store(in: cancellables)

    controller
      .accountNotFoundScreenPresentationPublisher()
      .sink { [weak self] account in
        self?.cancellables.executeOnMainActor { [weak self] in
          await self?.replaceLast(
            Self.self,
            with: AccountNotFoundViewController.self,
            in: account
          )
        }
      }
      .store(in: cancellables)
  }

  private func navigateToInvalidServerFingerprint(
    accountID: Account.LocalID,
    fingerprint: Fingerprint
  ) {
    self.cancellables.executeOnMainActor { [weak self] in
      guard let self = self else { return }
      await self.push(
        ServerFingerprintViewController.self,
        in: (accountID: accountID, fingerprint: fingerprint)
      )
    }
  }

  private func handleSignInAction(
    _ signInAction: () -> AnyPublisher<Bool, Error>
  ) -> AnyCancellable {
    signInAction()
      .receive(on: RunLoop.main)
      .handleEvents(receiveCompletion: { [weak self] completion in
        guard case let .failure(error) = completion
        else { return }
        guard let theError = error.asLegacy.legacyBridge as? ServerPGPFingeprintInvalid
        else {
          return
        }
        let accountID: Account.LocalID = theError.account.localID
        let fingerprint: Fingerprint = theError.fingerprint ?? "N/A"

        self?.signInCancellable = nil
        self?.navigateToInvalidServerFingerprint(
          accountID: accountID,
          fingerprint: fingerprint
        )
      })
      .handleStart { [weak self] in
        self?.present(
          overlay: LoaderOverlayView(
            longLoadingMessage: (
              message: .localized(
                key: .loadingLong
              ),
              delay: 5
            )
          )
        )
      }
      .handleErrors(
        (
          [.canceled],
          handler: { _ in true /* NOP */ }
        ),
        (
          [.invalidPassphraseError],
          handler: { [weak self] _ in
            self?.presentErrorSnackbar(
              .localized(
                key: "sign.in.error.passphrase.invalid.message"
              ),
              hideAfter: 5
            )
            return true
          }
        ),
        defaultHandler: { [weak self] error in
          self?.cancellables.executeOnMainActor { [weak self] in
            if let theError: TheError = error.asLegacy.legacyBridge {
              if let serverError: ServerConnectionIssue = theError as? ServerConnectionIssue {
                await self?.present(
                  ServerNotReachableAlertViewController.self,
                  in: serverError.serverURL
                )
              }
              else if let serverError: ServerConnectionIssue = theError as? ServerConnectionIssue {
                await self?.present(
                  ServerNotReachableAlertViewController.self,
                  in: serverError.serverURL
                )
              }
              else if let serverError: ServerResponseTimeout = theError as? ServerResponseTimeout {
                await self?.present(
                  ServerNotReachableAlertViewController.self,
                  in: serverError.serverURL
                )
              }
              else if theError is AccountBiometryDataChanged {
                await self?.presentErrorSnackbar(
                  .localized(
                    key: "sign.in.error.biometrics.changed.message"
                  ),
                  hideAfter: 5
                )
              }
              else {
                await self?.presentErrorSnackbar(theError.displayableMessage)
              }
            }
            else {
              await self?.presentErrorSnackbar(error.displayableMessage)
            }
          }
        }
      )
      .handleEnd { [weak self] ending in
        if case .canceled = ending {
          /* NOP */
        }
        else {
          self?.signInCancellable = nil
        }
        self?.dismissOverlay()
      }
      .sinkDrop()
  }

  public override func willMove(
    toParent parent: UIViewController?
  ) {
    super.willMove(toParent: parent)
    guard parent == .none else { return }
    self.dismissOverlay()
  }
}
