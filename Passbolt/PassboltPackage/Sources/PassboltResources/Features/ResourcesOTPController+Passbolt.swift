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
import DatabaseOperations
import FeatureScopes
import NetworkOperations
import OSFeatures
import Resources
import SessionData

// MARK: - Implementation

extension ResourcesOTPController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let sessionData: SessionData = try features.instance()
		let timeTicks: TimeVariable = features.instance(of: OSTime.self).timeVariable(Seconds(rawValue: 1))

		let revealedResourceID: PatchableVariable<Resource.ID?> = .init(
			updatingFrom: sessionData.lastUpdate
		) { (_: Update<Resource.ID?>, _: Update<Timestamp>) async throws  -> Resource.ID? in
			.none // clear each time session data refreshes
		}

		let currentOTP: FlattenedVariable<OTPValue> = .init(
			transformed: revealedResourceID
		) { (revealedResourceID: Update<Resource.ID?>) async throws -> ComputedVariable<OTPValue> in
			// load resource details
			guard
				let resourceID: Resource.ID = try? revealedResourceID.value,
				let resourceController: ResourceController = try? await (features
					.branchIfNeeded(
						scope: ResourceDetailsScope.self,
						context: resourceID
					)
					?? features)
					.instance()
			else {
				throw Cancelled.error()
			}

			// load secret
			try await resourceController.fetchSecretIfNeeded()

			guard let totpSecret: TOTPSecret = try await resourceController.state.value.firstTOTPSecret
			else {
				throw Cancelled.error()
			}

			// prepare otp generator
			let otpGenerator: TOTPCodeGenerator = try await features.instance(
				context: .init(
					resourceID: resourceID,
					totpSecret: totpSecret
				)
			)

			// combine generator with time ticks
			return ComputedVariable<OTPValue>(
				transformed: timeTicks
			) { (_: Update<Void>) async throws -> OTPValue in
				.totp(otpGenerator.generate())
			}
		}

		@Sendable nonisolated func revealOTP(
			_ resourceID: Resource.ID
		) async throws -> OTPValue {
			await revealedResourceID.patch { (_: Update<Resource.ID?>) -> Resource.ID? in
				resourceID // set revealed resource ID
			}
			return try await currentOTP.value
		}

		@Sendable nonisolated func hideOTP() async {
			await revealedResourceID.patch { (_: Update<Resource.ID?>) -> Resource.ID?? in
				Optional<Optional<Resource.ID>>.some(.none) // clear revealed resource ID
			}
		}

    return Self(
     currentOTP: currentOTP,
		 revealOTP: revealOTP(_:),
		 hideOTP: hideOTP
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourcesOTPController() {
    self.use(
      .disposable(
				ResourcesOTPController.self,
        load: ResourcesOTPController.load(features:)
      ),
      in: OTPResourcesTabScope.self
    )
		self.use(
			.disposable(
				ResourcesOTPController.self,
				load: ResourcesOTPController.load(features:)
			),
			in: ResourceDetailsScope.self
		)
  }
}
