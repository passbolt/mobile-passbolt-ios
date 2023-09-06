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
    let timeTicks: AnyUpdatable<Void> = features.instance(of: OSTime.self).timeVariable(Seconds(rawValue: 1))

    // this variable holds last requested resource ID
    let lastRequestedResourceID: Variable<Resource.ID?> = .init(initial: .none)
    // this variable holds currently revealed resource ID
    let revealedResourceID: ComputedVariable<Resource.ID?> = .init(
      combined: sessionData.lastUpdate,
      with: lastRequestedResourceID
    ) { (dataUpdate: Update<Timestamp>, revealedUpdate: Update<Resource.ID?>) throws -> Resource.ID? in
      // check if session was updated after last reveal request
      if dataUpdate.generation > revealedUpdate.generation {
        // clear on session data updates
        return .none
      }
      else {
        // use requested after session data update
        return try revealedUpdate.value
      }
    }

    // this variable holds OTP generator
    // for currently revealed resource ID
    let otpGenerator: ComputedVariable<() -> OTPValue> = .init(
      transformed: revealedResourceID
    ) { (revealed: Update<Resource.ID?>) async throws -> () -> OTPValue in
      guard let resourceID: Resource.ID = try revealed.value
      else { throw Cancelled.error() }

      // load resource controller to access its details
      let resourceController: ResourceController = try await
        features
        .branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )
        .instance()

      // load resource secret
      try await resourceController.fetchSecretIfNeeded()

      // look for the OTP secret
      guard let totpSecret: TOTPSecret = try await resourceController.state.value.firstTOTPSecret
      else {
        throw Cancelled.error()
      }

      // prepare otp generator
      let otpGenerator: TOTPCodeGenerator = try await features
				.instance()
			let generate: () -> TOTPValue = otpGenerator.prepare(
				.init(
					resourceID: resourceID,
					secret: totpSecret
				)
			)

      return { .totp(generate()) }
    }

    // combine time ticks with current OTP generator
    let currentOTP: ComputedVariable<OTPValue> = .init(
      combined: timeTicks,
      with: otpGenerator
    ) { (_: Update<Void>, generator: Update<() -> OTPValue>) in
      try generator.value()
    }

    @Sendable nonisolated func revealOTP(
      _ resourceID: Resource.ID
    ) async throws -> OTPValue {
      lastRequestedResourceID.value = resourceID
      return try await currentOTP.value
    }

    @Sendable nonisolated func hideOTP() {
      lastRequestedResourceID.value = .none
    }

    return Self(
      currentOTP: currentOTP.asAnyUpdatable(),
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
      in: ResourceScope.self
    )
  }
}
