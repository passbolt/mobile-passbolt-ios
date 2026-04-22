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

import Crypto
import Display
import Features
import PassboltExtension

import class AuthenticationServices.ASCredentialProviderViewController
import class AuthenticationServices.ASCredentialServiceIdentifier
import struct AuthenticationServices.ASExtensionError

@MainActor
internal final class ApplicationExtension {

  internal static let shared: ApplicationExtension = .init()

  private let ui: UI
  private let features: Features
  private let requestedServiceIdentifiers:
    CriticalState<[AutofillExtensionContext.ServiceIdentifier]>
  private let rootViewControllerRef: WeakRef<ASCredentialProviderViewController>
  private var isInitialized: Bool = false

  @MainActor private init() {
    let requestedServiceIdentifiers:
      CriticalState<[AutofillExtensionContext.ServiceIdentifier]> = .init(
        .init()
      )
    let rootViewControllerRef: WeakRef<ASCredentialProviderViewController> = .init()
    let features: Features = FeaturesFactory {
      (registry: inout FeaturesRegistry) in
      registry.useExtensionRootAnchorProvider()
      registry.usePassboltFeatures()
      registry.usePassboltInitialization()
      registry.use(
        ConfigurationExtensionContext(
          completeExtensionConfiguration: {
            rootViewControllerRef.value?
              .extensionContext
              .completeExtensionConfigurationRequest()
          }
        )
      )
      registry.use(
        AutofillExtensionContext(
          completeWithCredential: { credential in
            rootViewControllerRef.value?
              .extensionContext
              .completeRequest(
                withSelectedCredential: .init(
                  user: credential.user,
                  password: credential.password
                ),
                completionHandler: nil
              )
          },
          completeWithError: { error in
            rootViewControllerRef.value?
              .extensionContext
              .cancelRequest(withError: error)
          },
          cancelAndCloseExtension: {
            rootViewControllerRef.value?
              .extensionContext
              .cancelRequest(withError: ASExtensionError(.userCanceled))
          },
          requestedServiceIdentifiers: {
            requestedServiceIdentifiers.get(\.self)
          }
        )
      )
      registry.useLiveDisplay()
      registry.useResourceEditNavigation()
      registry.useLiveNavigationToOTPEditForm()
      registry.useLiveNavigationToOTPScanning()
      registry.useLiveNavigationToOTPScanningSuccess()
      registry.useLiveNavigationToOTPEditForm()
      registry.useLiveNavigationToOTPEditAdvancedForm()
      registry.useLiveNavigationToOTPAttachSelectionList()
    }
    self.ui = UI(
      features: features
    )
    self.features = features
    self.requestedServiceIdentifiers = requestedServiceIdentifiers
    self.rootViewControllerRef = rootViewControllerRef
  }
}

extension ApplicationExtension {

  @MainActor internal func updateRootViewController(
    _ rootViewController: ASCredentialProviderViewController
  ) {
    self.rootViewControllerRef.value = rootViewController
    self.requestedServiceIdentifiers.access { identifiers in
      identifiers = .init()
    }
    setupSnackBarMessages(within: rootViewController.view)
  }

  @MainActor internal func initialize() {
    guard !self.isInitialized else { return }
    self.isInitialized = true
    do {
      try self.features
        .instance(of: Initialization.self)
        .initialize()
    } catch {
      error
        .asTheError()
        .asFatalError()
    }
  }

  internal func requestSuggestions(
    for identifiers: [ASCredentialServiceIdentifier]
  ) {
    self.requestedServiceIdentifiers.access { requestedIdentifiers in
      requestedIdentifiers =
        identifiers
        .map { identifier in
          AutofillExtensionContext.ServiceIdentifier(
            rawValue: identifier.identifier
          )
        }
    }
  }

  internal func prepareCredentialList() {
    self.ui.prepareCredentialList()
  }

  internal func prepareInterfaceForExtensionConfiguration() {
    self.ui.prepareInterfaceForExtensionConfiguration()
  }
}

/// Mutable weak reference wrapper used to allow closures
/// to read the current root view controller without
/// capturing a specific instance.
@MainActor
private final class WeakRef<T: AnyObject> {

  fileprivate weak var value: T?

  fileprivate init() {
    self.value = .none
  }
}
