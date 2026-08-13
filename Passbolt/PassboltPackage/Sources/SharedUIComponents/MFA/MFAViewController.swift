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

import Display
import Session

public final class MFAViewController: ViewController {
  public typealias Context = Array<SessionMFAProvider>

  public struct ViewState: Equatable, Sendable {
    public var currentProvider: SessionMFAProvider
    public var isLoading: Bool = false
  }

  public nonisolated let viewState: ViewStateSource<ViewState>

  private let features: Features
  /// Providers which have a controller and can actually be shown to the user.
  private let presentableProviders: Context

  internal let totpController: TOTPViewController?
  internal let duoController: DUOAuthorizationViewController?
  internal let yubiKeyController: YubiKeyViewController?

  public init(context: Context, features: Features) throws {
    // unsupported providers can't be presented, drop them upfront
    let supportedProviders: Context = context.supportedProviders
    guard let firstSupportedProvider: SessionMFAProvider = supportedProviders.first else {
      throw InternalInconsistency.error("MFAViewController initialized with empty context")
    }
    self.features = features
    let viewState: ViewStateSource<ViewState> = .init(
      initial: .init(
        currentProvider: firstSupportedProvider
      )
    )
    self.viewState = viewState

    let totpController: TOTPViewController? =
      supportedProviders.contains(.totp)
      ? Self.makeTOTPController(features: features, viewState: viewState)
      : nil
    let duoController: DUOAuthorizationViewController? =
      supportedProviders.contains(.duo)
      ? Self.makeDUOController(features: features)
      : nil
    let yubiKeyController: YubiKeyViewController? =
      supportedProviders.contains(.yubiKey)
      ? Self.makeYubiKeyController(features: features)
      : nil
    self.totpController = totpController
    self.duoController = duoController
    self.yubiKeyController = yubiKeyController

    // a supported provider whose controller failed to load has nothing
    // to display, drop it as well to avoid switching to an empty screen
    let presentableProviders: Context = supportedProviders.filter { (provider: SessionMFAProvider) -> Bool in
      switch provider {
      case .totp:
        return totpController != nil

      case .duo:
        return duoController != nil

      case .yubiKey:
        return yubiKeyController != nil

      case .unknown:
        return false
      }
    }
    self.presentableProviders = presentableProviders

    // without any presentable provider there is nothing but an empty
    // screen to display, fail instead of stranding the user on it,
    // the failures are already displayed by the controller factories above
    guard let initialProvider: SessionMFAProvider = presentableProviders.first
    else {
      throw InternalInconsistency.error("MFAViewController has no presentable provider")
    }
    // the initial provider differs from the first supported one
    // when the controller of that one has failed to load
    viewState.update(\.currentProvider, to: initialProvider)
  }

  private static func makeTOTPController(
    features: Features,
    viewState: ViewStateSource<ViewState>
  ) -> TOTPViewController? {
    do {
      return try features.instance(
        context: .init(
          loadingCallback: { [weak viewState] (isLoading: Bool) in
            viewState?.update(\.isLoading, to: isLoading)
          }
        )
      )
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
      return nil
    }
  }

  private static func makeDUOController(features: Features) -> DUOAuthorizationViewController? {
    do {
      return try features.instance()
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
      return nil
    }
  }

  private static func makeYubiKeyController(features: Features) -> YubiKeyViewController? {
    do {
      return try features.instance()
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
      return nil
    }
  }

  /// Whether switching to another provider can lead to a different screen.
  /// Constant after initialization, the providers are not mutated.
  internal var hasMultipleProviders: Bool { self.presentableProviders.count > 1 }

  internal func nextProvider() async {
    let currentProvider: SessionMFAProvider = await viewState.current.currentProvider
    guard let currentIndex: Array.Index = presentableProviders.firstIndex(of: currentProvider)
    else { return }

    let nextIndex: Array.Index =
      currentIndex.advanced(by: 1) < presentableProviders.count
      ? currentIndex.advanced(by: 1)
      : presentableProviders.startIndex

    let nextProvider: SessionMFAProvider = presentableProviders[nextIndex]
    viewState.update(\.currentProvider, to: nextProvider)
  }

  @Sendable internal func close() async {
    await consumingErrors {
      let session: Session = try await features.instance()
      await session.close(.none)
    }
  }
}

#if DEBUG
#Preview {
  createPreview(
    MFAView.self,
    with: [.yubiKey, .totp, .duo]
  )
  .wrapInNavigationStack()
}
#endif
