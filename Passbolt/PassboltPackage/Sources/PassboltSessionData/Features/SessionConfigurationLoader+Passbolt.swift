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

import Features
import NetworkOperations
import OSFeatures
import Session
import SessionData

import struct Foundation.URL

extension SessionConfigurationLoader {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let session: Session = try features.instance()
    let serverConfigurationFetchNetworkOperation: ServerConfigurationFetchNetworkOperation = try features.instance()
    let featureAccessControlConfigurationFetchNetworkOperation: FeatureAccessControlConfigurationFetchNetworkOperation =
      try features.instance()

    let configuration: ComputedVariable<SessionConfiguration> = .init(
      // TODO: we should update only on account changes
      // not on all session changes...
      // ...hovever this is an Updatable and it will
      // recompute its value only if asked for new one.
      // Since we typically access configuration
      // from the session scope context it might not be an issue
      transformed: session.updates
    ) { _ in
      try await fetchConfiguration()
    }

    @Sendable nonisolated func fetchConfiguration() async throws -> SessionConfiguration {
      Diagnostics.logger.info("Fetching server configuration...")
      guard case .some = try? await session.currentAccount()
      else {
        Diagnostics.logger.info("...server configuration fetching skipped!")
        return .default
      }

      let serverConfiguration: ServerConfiguration
      do {
        serverConfiguration = try await serverConfigurationFetchNetworkOperation()
      }
      catch {
        Diagnostics.logger.info("...server configuration fetching failed!")
        throw error
      }

      Diagnostics.logger.info("...server configuration fetched!")

      var resources: ResourcesFeatureConfiguration = .init(
        passwordRevealEnabled: serverConfiguration.plugins.passwordPreview?.enabled ?? true,
        passwordCopyEnabled: true,
        totpEnabled: serverConfiguration.plugins.totpResources?.enabled ?? false
      )

      var folders: FoldersFeatureConfiguration = .init(
        enabled: serverConfiguration.plugins.folders?.enabled ?? false
      )

      var tags: TagsFeatureConfiguration = .init(
        enabled: serverConfiguration.plugins.tags?.enabled ?? false
      )

      var share: ShareFeatureConfiguration = .init(
        showMembersList: true
      )

      var passwordPolicies: PasswordPoliciesFeatureConfiguration = .init(
        passwordPoliciesEnabled: serverConfiguration.plugins.passwordPolicies?.enabled ?? false,
        passwordPoliciesUpdateEnabled: serverConfiguration.plugins.passwordPoliciesUpdate?.enabled ?? false
      )

      var configuration: SessionConfiguration = .init(
        termsURL: serverConfiguration.legal.terms,
        privacyPolicyURL: serverConfiguration.legal.privacyPolicy,
        resources: resources,
        folders: folders,
        tags: tags,
        share: share,
        passwordPolicies: passwordPolicies
      )

      if serverConfiguration.plugins.rbacs?.enabled ?? false {
        Diagnostics.logger.info("Fetching rbacs configuration...")
        let accessConfiguration: FeatureAccessControlConfiguration
        do {
          accessConfiguration = try await featureAccessControlConfigurationFetchNetworkOperation()
        }
        catch {
          Diagnostics.logger.info("...rbacs configuration fetching failed!")
          throw error
        }

        Diagnostics.logger.info("...rbacs configuration fetched!")

        switch accessConfiguration.folders {
        case .allow:
          break  // keep the state from plugins

        case .deny:
          configuration.folders.enabled = false
        }

        switch accessConfiguration.tags {
        case .allow:
          break  // keep the state from plugins

        case .deny:
          configuration.tags.enabled = false
        }

        switch accessConfiguration.copySecrets {
        case .allow:
          break  // keep the state from plugins

        case .deny:
          configuration.resources.passwordCopyEnabled = false
        }

        switch accessConfiguration.previewSecrets {
        case .allow:
          break  // keep the state from plugins

        case .deny:
          configuration.resources.passwordRevealEnabled = false
        }

        switch accessConfiguration.viewShareList {
        case .allow:
          break  // keep the state from plugins

        case .deny:
          configuration.share.showMembersList = false
        }
      }  // else no RBAC

      return configuration
    }

    @Sendable nonisolated func sessionConfiguration() async throws -> SessionConfiguration {
      do {
        return try await configuration.value
      }
      catch {
        // allow retrying on error
        configuration.invalidateCache()
        throw error
      }
    }

    return Self(
      sessionConfiguration: sessionConfiguration
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionConfigurationLoader() {
    self.use(
      .lazyLoaded(
        SessionConfigurationLoader.self,
        load: SessionConfigurationLoader.load(features:)
      )
    )
  }
}
