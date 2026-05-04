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
  private let context: Context

  internal let totpController: TOTPViewController?
  internal let duoController: DUOAuthorizationViewController?
  internal let yubiKeyController: YubiKeyViewController?

  public init(context: Context, features: Features) throws {
    guard let initialProvider: SessionMFAProvider = context.first else {
      throw InternalInconsistency.error("MFAViewController initialized with empty context")
    }
    self.features = features
    self.context = context
    let viewState: ViewStateSource<ViewState> = .init(
      initial: .init(
        currentProvider: initialProvider
      )
    )
    self.viewState = viewState

    self.totpController =
      context.contains(.totp)
      ? Self.makeTOTPController(features: features, viewState: viewState)
      : nil
    self.duoController =
      context.contains(.duo)
      ? Self.makeDUOController(features: features)
      : nil
    self.yubiKeyController =
      context.contains(.yubiKey)
      ? Self.makeYubiKeyController(features: features)
      : nil
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

  internal func nextProvider() async {
    let currentProvider: SessionMFAProvider = await viewState.current.currentProvider
    guard let currentIndex: Array.Index = context.firstIndex(of: currentProvider)
    else { return }

    let nextIndex: Array.Index =
      currentIndex.advanced(by: 1) < context.count ? currentIndex.advanced(by: 1) : context.startIndex

    let nextProvider: SessionMFAProvider = context[nextIndex]
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
