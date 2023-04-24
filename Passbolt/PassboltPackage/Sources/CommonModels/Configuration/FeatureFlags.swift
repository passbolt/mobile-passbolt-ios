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

import struct Foundation.URL

public enum FeatureFlags {}

extension FeatureFlags {

  public enum Legal {

    case none
    case terms(URL)
    case privacyPolicy(URL)
    case both(termsURL: URL, privacyPolicyURL: URL)
  }
}

extension FeatureFlags {

  public enum Folders {

    case disabled
    case enabled(version: String)
  }

  public enum PreviewPassword {

    case disabled
    case enabled
  }

  public enum Tags {

    case disabled
    case enabled
  }

  public enum TOTP {

    case disabled
    case enabled
  }
}

extension FeatureFlags.Legal: FeatureConfigItem {

  public static var `default`: FeatureFlags.Legal {
    .none
  }
}

extension FeatureFlags.Folders: FeatureConfigItem {

  public static var `default`: FeatureFlags.Folders {
    .disabled
  }
}

extension FeatureFlags.PreviewPassword: FeatureConfigItem {

  public static var `default`: FeatureFlags.PreviewPassword {
    .enabled
  }
}

extension FeatureFlags.Tags: FeatureConfigItem {

  public static var `default`: FeatureFlags.Tags {
    .disabled
  }
}

extension FeatureFlags.TOTP: FeatureConfigItem {

  public static var `default`: FeatureFlags.TOTP {
    .disabled
  }
}

extension FeatureFlags.Legal: Equatable {}
extension FeatureFlags.Folders: Equatable {}
extension FeatureFlags.PreviewPassword: Equatable {}
extension FeatureFlags.Tags: Equatable {}
extension FeatureFlags.TOTP: Equatable {}
