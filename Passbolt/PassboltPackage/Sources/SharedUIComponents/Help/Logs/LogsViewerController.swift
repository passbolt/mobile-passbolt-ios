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
import UIComponents

public struct LogsViewerController {

  public var refreshLogs: @MainActor () -> Void
  public var logsPublisher: @MainActor () -> AnyPublisher<Array<String>?, Never>
  public var presentShareMenu: @MainActor () -> Void
  public var shareMenuPresentationPublisher: @MainActor () -> AnyPublisher<String?, Never>
}

extension LogsViewerController: UIController {

  public typealias Context = Void

  public static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let logsFetchExecutor: AsyncExecutor = try await features.instance(of: Executors.self).newBackgroundExecutor()

    let logsCacheSubject: CurrentValueSubject<Array<String>?, Never> = .init(nil)
    let shareMenuPresentationSubject: PassthroughSubject<String?, Never> = .init()

    func refreshLogs() {
      logsFetchExecutor {
        logsCacheSubject.send(diagnostics.collectedLogs())
      }
    }

    func logsPublisher() -> AnyPublisher<Array<String>?, Never> {
      logsCacheSubject
        .map { $0.map { [diagnostics.deviceInfo()] + $0 } }
        .eraseToAnyPublisher()
    }

    func presentShareMenu() {
      shareMenuPresentationSubject
        .send(
          "Passbolt:\n"
            + (logsCacheSubject
              .value?
              .joined(separator: "\n")
              ?? "N/A")
        )
    }

    func shareMenuPresentationPublisher() -> AnyPublisher<String?, Never> {
      shareMenuPresentationSubject
        .eraseToAnyPublisher()
    }

    return Self(
      refreshLogs: refreshLogs,
      logsPublisher: logsPublisher,
      presentShareMenu: presentShareMenu,
      shareMenuPresentationPublisher: shareMenuPresentationPublisher
    )
  }
}
