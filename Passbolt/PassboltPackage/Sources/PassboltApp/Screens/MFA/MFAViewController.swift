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

internal final class MFAViewController: ViewController {
  internal typealias Context = Array<SessionMFAProvider>

  internal struct ViewState: Equatable {
    internal var currentProvider: SessionMFAProvider
    internal var isLoading: Bool = false
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let features: Features
  private let context: Context
  private let navigationToSelf: NavigationToMFA

  internal init(context: Context, features: Features) throws {
    guard let initialProvider = context.first else {
      throw InternalInconsistency.error("MFAViewController initialized with empty context")
    }
    self.features = features
    self.context = context
    self.navigationToSelf = try features.instance()
    self.viewState = .init(
      initial: .init(
        currentProvider: initialProvider
      )
    )
  }

  internal func prepareTOTP() -> TOTPViewController? {
    do {
      return try features.instance(
        context: .init(
          loadingCallback: { [weak self] in
            self?.viewState.update(\.isLoading, to: $0)
          }
        )
      )
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
    }
    return nil
  }

  internal func prepareDUO() -> DUOAuthorizationViewController? {
    do {
      return try features.instance()
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
    }
    return nil
  }

  internal func prepareYubiKey() -> YubiKeyViewController? {
    do {
      return try features.instance()
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
    }
    return nil
  }

  internal func nextProvider() async {
    let currentProvider = await viewState.current.currentProvider
    guard let currentIndex: Array.Index = context.firstIndex(of: currentProvider)
    else { return }

    let nextIndex: Array.Index =
      currentIndex.advanced(by: 1) < context.count ? currentIndex.advanced(by: 1) : context.startIndex

    let nextProvider: SessionMFAProvider = context[nextIndex]
    viewState.update(\.currentProvider, to: nextProvider)
  }

  @Sendable internal func close() async {
    await consumingErrors {
      let session: Session = try features.instance()
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
