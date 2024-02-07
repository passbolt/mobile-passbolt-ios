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

import CoreTest
import TestExtensions

@testable import PassboltSessionData

final class SessionConfigurationLoaderTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    patch(
      \Session.updates,
      with: Variable(initial: Void()).asAnyUpdatable()
    )
    register(
      { $0.usePassboltSessionConfigurationLoader() },
      for: SessionConfigurationLoader.self
    )
  }

  func test_sessionConfiguration_isDefault_whenAccessingCurrentAccountFails() async throws {
    patch(
      \Session.currentAccount,
      with: alwaysThrow(MockIssue.error())
    )
    let feature: SessionConfigurationLoader = try self.testedInstance()

    await verifyIf(
      try await feature.sessionConfiguration(),
      isEqual: .default
    )
  }

  func test_sessionConfiguration_throws_whenFetchingServerConfigurationFails() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \ServerConfigurationFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    let feature: SessionConfigurationLoader = try self.testedInstance()

    await verifyIf(
      try await feature.sessionConfiguration(),
      throws: MockIssue.self
    )
  }

  func test_sessionConfiguration_isDefault_whenNoLegalOrPluginsAvailable() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \ServerConfigurationFetchNetworkOperation.execute,
      with: always(
        .init(
          legal: .init(
            privacyPolicy: .none,
            terms: .none
          ),
          plugins: .init(
            passwordPreview: .none,
            folders: .none,
            tags: .none,
            totpResources: .none,
            rbacs: .none
          )
        )
      )
    )

    let feature: SessionConfigurationLoader = try self.testedInstance()

    await verifyIf(
      try await feature.sessionConfiguration(),
      isEqual: .default
    )
  }

  func test_sessionConfiguration_matchesLegal_whenLegalAvailable() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \ServerConfigurationFetchNetworkOperation.execute,
      with: always(
        .init(
          legal: .init(
            privacyPolicy: "https://passbolt.com/privacyPolicy",
            terms: "https://passbolt.com/terms"
          ),
          plugins: .init(
            passwordPreview: .init(
              enabled: false
            ),
            folders: .init(
              enabled: true
            ),
            tags: .init(
              enabled: true
            ),
            totpResources: .init(
              enabled: true
            ),
            rbacs: .init(
              enabled: false
            )
          )
        )
      )
    )

    let feature: SessionConfigurationLoader = try self.testedInstance()

    await verifyIf(
      try await feature.sessionConfiguration(),
      isEqual: .init(
        termsURL: "https://passbolt.com/terms",
        privacyPolicyURL: "https://passbolt.com/privacyPolicy",
        resources: .init(
          passwordRevealEnabled: false,
          passwordCopyEnabled: true,
          totpEnabled: true
        ),
        folders: .init(
          enabled: true
        ),
        tags: .init(
          enabled: true
        ),
        share: .init(
          showMembersList: true
        )
      )
    )
  }

  func test_sessionConfiguration_matchesPlugins_whenPluginsAvailable() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \ServerConfigurationFetchNetworkOperation.execute,
      with: always(
        .init(
          legal: .init(
            privacyPolicy: .none,
            terms: .none
          ),
          plugins: .init(
            passwordPreview: .init(
              enabled: false
            ),
            folders: .init(
              enabled: true
            ),
            tags: .init(
              enabled: true
            ),
            totpResources: .init(
              enabled: true
            ),
            rbacs: .init(
              enabled: false
            )
          )
        )
      )
    )

    let feature: SessionConfigurationLoader = try self.testedInstance()

    await verifyIf(
      try await feature.sessionConfiguration(),
      isEqual: .init(
        termsURL: .none,
        privacyPolicyURL: .none,
        resources: .init(
          passwordRevealEnabled: false,
          passwordCopyEnabled: true,
          totpEnabled: true
        ),
        folders: .init(
          enabled: true
        ),
        tags: .init(
          enabled: true
        ),
        share: .init(
          showMembersList: true
        )
      )
    )
  }

  func test_sessionConfiguration_throws_whenFetchingRBACSFails() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \ServerConfigurationFetchNetworkOperation.execute,
      with: always(
        .init(
          legal: .init(
            privacyPolicy: .none,
            terms: .none
          ),
          plugins: .init(
            passwordPreview: .none,
            folders: .none,
            tags: .none,
            totpResources: .none,
            rbacs: .init(
              enabled: true
            )
          )
        )
      )
    )
    patch(
      \FeatureAccessControlConfigurationFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: SessionConfigurationLoader = try self.testedInstance()

    await verifyIf(
      try await feature.sessionConfiguration(),
      throws: MockIssue.self
    )
  }

  func test_sessionConfiguration_respectsRBACS_whenFetchingRBACSSucceeds() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \ServerConfigurationFetchNetworkOperation.execute,
      with: always(
        .init(
          legal: .init(
            privacyPolicy: .none,
            terms: .none
          ),
          plugins: .init(
            passwordPreview: .init(
              enabled: true
            ),
            folders: .init(
              enabled: true
            ),
            tags: .init(
              enabled: true
            ),
            totpResources: .init(
              enabled: true
            ),
            rbacs: .init(
              enabled: true
            )
          )
        )
      )
    )
    patch(
      \FeatureAccessControlConfigurationFetchNetworkOperation.execute,
      with: always(
        .init(
          folders: .deny,
          tags: .deny,
          copySecrets: .deny,
          previewSecrets: .deny,
          viewShareList: .deny
        )
      )
    )

    let feature: SessionConfigurationLoader = try self.testedInstance()

    await verifyIf(
      try await feature.sessionConfiguration(),
      isEqual: .init(
        termsURL: .none,
        privacyPolicyURL: .none,
        resources: .init(
          passwordRevealEnabled: false,
          passwordCopyEnabled: false,
          totpEnabled: true
        ),
        folders: .init(
          enabled: false
        ),
        tags: .init(
          enabled: false
        ),
        share: .init(
          showMembersList: false
        )
      )
    )
  }

  func test_sessionConfiguration_retriesFetchingAfterFailure() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \ServerConfigurationFetchNetworkOperation.execute,
      with: {
        self.mockExecuted()
        return
          try self.loadOrDefine(
            \.serverConfigurationNetworkOperationResult,
            of: Result<ServerConfiguration, Error>.self,
            defaultValue: .failure(MockIssue.error())
          )
          .get()
      }
    )

    let feature: SessionConfigurationLoader = try self.testedInstance()

    await verifyIf(
      try await feature.sessionConfiguration(),
      throws: MockIssue.self
    )

    self.serverConfigurationNetworkOperationResult = Result<ServerConfiguration, Error>
      .success(
        .init(
          legal: .init(
            privacyPolicy: .none,
            terms: .none
          ),
          plugins: .init(
            passwordPreview: .none,
            folders: .none,
            tags: .none,
            totpResources: .none,
            rbacs: .none
          )
        )
      )

    await verifyIf(
      try await feature.sessionConfiguration(),
      isEqual: .default
    )

    await verifyIf(
      self.mockExecutedCount,
      isEqual: 2
    )
  }
}
