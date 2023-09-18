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
import FeatureScopes

public struct OperationResultConfiguration: Sendable {

	public var image: ImageNameConstant
	public var title: DisplayableString
	public var message: DisplayableString?
	public var actionLabel: DisplayableString
	public var confirmation: @Sendable () async throws -> Void

	public init(
		image: ImageNameConstant,
		title: DisplayableString,
		message: DisplayableString? = .none,
		actionLabel: DisplayableString,
		confirmation: @escaping @Sendable () async throws -> Void
	) {
		self.image = image
		self.title = title
		self.message = message
		self.actionLabel = actionLabel
		self.confirmation = confirmation
	}

	public init(
		for error: TheError,
		confirmation: @escaping @Sendable () async throws -> Void
	) {
		self.image = .failureMark
		self.title = "generic.error"
		self.message = error.displayableMessage
		self.actionLabel = "generic.try.again"
		self.confirmation = confirmation
	}
}

public enum OperationResultNavigationDestination: NavigationDestination {

	public typealias TransitionContext = OperationResultConfiguration
}

public typealias NavigationToOperationResult = NavigationTo<OperationResultNavigationDestination>

extension NavigationToOperationResult {

	fileprivate static var live: FeatureLoader {
		legacyPushTransition(
			to: OperationResultControlledView.self
		)
	}
}

extension FeaturesRegistry {

	public mutating func useLiveNavigationToOperationResult() {
		self.use(
			NavigationToOperationResult.live
		)
	}
}
