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

public struct SessionConfiguration {

  public var termsURL: URLString?
  public var privacyPolicyURL: URLString?

  public var resources: ResourcesFeatureConfiguration
  public var folders: FoldersFeatureConfiguration
  public var tags: TagsFeatureConfiguration
  public var share: ShareFeatureConfiguration
  public var passwordPolicies: PasswordPoliciesFeatureConfiguration
  public var metadata: MetadataFeatureConfiguration

  public init(
    termsURL: URLString?,
    privacyPolicyURL: URLString?,
    resources: ResourcesFeatureConfiguration,
    folders: FoldersFeatureConfiguration,
    tags: TagsFeatureConfiguration,
    share: ShareFeatureConfiguration,
    passwordPolicies: PasswordPoliciesFeatureConfiguration,
    metadata: MetadataFeatureConfiguration
  ) {
    self.termsURL = termsURL
    self.privacyPolicyURL = privacyPolicyURL
    self.resources = resources
    self.folders = folders
    self.tags = tags
    self.share = share
    self.passwordPolicies = passwordPolicies
    self.metadata = metadata
  }
}

extension SessionConfiguration: Equatable {}

extension SessionConfiguration {

  public static var `default`: Self {
    .init(
      termsURL: .none,
      privacyPolicyURL: .none,
      resources: .init(
        passwordRevealEnabled: true,
        passwordCopyEnabled: true,
        totpEnabled: false
      ),
      folders: .init(
        enabled: false
      ),
      tags: .init(
        enabled: false
      ),
      share: .init(
        showMembersList: true
      ),
      passwordPolicies: .init(
        passwordPoliciesEnabled: false,
        passwordPoliciesUpdateEnabled: false
      ),
      metadata: .init(enabled: false)
    )
  }
}
