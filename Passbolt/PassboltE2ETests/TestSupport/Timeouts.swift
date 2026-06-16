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

import Foundation

/// Semantic timeout values shared across E2E tests. Prefer these over literal numbers
/// so the intent of each wait is visible at the call site and so timings can be tuned
/// in one place.
extension TimeInterval {

  /// Standard UI element appearance: tabs, sheets, alerts, page transitions, animations.
  internal static let standardUI: TimeInterval = 5.0

  /// A single network round-trip: search results, on-demand reveal, list reload.
  internal static let networkCall: TimeInterval = 10.0

  /// Slower server-backed operations: post-edit refreshes, forms initializing with server data.
  internal static let slowNetworkCall: TimeInterval = 20.0

  /// Long operations that involve full session data refresh or background sync.
  internal static let longNetworkCall: TimeInterval = 30.0
}
