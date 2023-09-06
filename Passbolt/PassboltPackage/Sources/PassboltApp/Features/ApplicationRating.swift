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
import Foundation
import OSFeatures
import FeatureScopes

internal struct ApplicationRating {

	internal var showApplicationRatingIfRequired: @MainActor () -> Void
}

extension ApplicationRating {

	@MainActor fileprivate static func load(
		features: Features,
		cancellables _: Cancellables
	) throws -> Self {
		var lastAppRateCheckTimestamp: LastAppRateCheckTimestampStoredProperty = try features.instance()
		let loginCount: LoginCountStoredProperty = try features.instance()
		let timeProvider: OSTime = features.instance()
		let rateAppFeature: OSApplicationRating = features.instance()

		nonisolated func incrementLoginCounter() {
			loginCount.set(to: loginCount.get(withDefault: 0) + 1)
		}

		nonisolated func fiveDaysHasPassedSinceInstall() -> Bool {
			guard let timestamp = lastAppRateCheckTimestamp.value else {
				lastAppRateCheckTimestamp.value = timeProvider.timestamp()
				return false
			}

			let now = timeProvider.timestamp()
			return now > timestamp + (5 * 24 * 60 * 60 as Timestamp)  // 5 days in seconds
		}

		nonisolated func fiveLoginsHasPassed() -> Bool {
			return loginCount.value ?? 0 >= 5
		}

		@MainActor func showRateApp() {
			incrementLoginCounter()
			guard fiveDaysHasPassedSinceInstall(),
				fiveLoginsHasPassed()
			else {
				return /* NOOP */
			}
			rateAppFeature.requestApplicationRating()
		}
		return .init(
			showApplicationRatingIfRequired: showRateApp
		)
	}
}

extension ApplicationRating: LoadableFeature {


	#if DEBUG
	nonisolated public static var placeholder: Self {
		Self(
			showApplicationRatingIfRequired: unimplemented0()
		)
	}
	#endif
}

extension FeaturesRegistry {

	internal mutating func usePassboltApplicationRatingFeature() {
		self.use(
			.lazyLoaded(
				ApplicationRating.self,
				load: ApplicationRating.load(features:cancellables:)
			),
			in: RootFeaturesScope.self
		)
		self.usePassboltStoredProperty(
			LoginCountStoredPropertyDescription.self,
			in: RootFeaturesScope.self
		)
		self.usePassboltStoredRawProperty(
			LastAppRateCheckTimestampStoredPropertyDescription.self,
			in: RootFeaturesScope.self
		)
	}
}

internal typealias LoginCountStoredProperty = StoredProperty<LoginCountStoredPropertyDescription>

internal enum LoginCountStoredPropertyDescription: StoredPropertyDescription {

	public typealias Value = Int

	static var shared: Bool { true }
	public static var key: OSStoredPropertyKey { "loginCount" }
}


internal typealias LastAppRateCheckTimestampStoredProperty = StoredProperty<LastAppRateCheckTimestampStoredPropertyDescription>

internal enum LastAppRateCheckTimestampStoredPropertyDescription: StoredPropertyDescription {

	public typealias Value = Timestamp

	static var shared: Bool { true }
	public static var key: OSStoredPropertyKey { "lastAppRateCheckTimestamp" }
}
