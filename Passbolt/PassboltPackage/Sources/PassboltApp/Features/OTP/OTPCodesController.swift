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

import OSFeatures
import Resources

// MARK: - Interface

internal struct OTPCodesController {

  /// Updates when current OTP value changes.
  internal var updates: UpdatesSequence
  /// Returns currently active OTP resource value if any.
  internal var current: @Sendable () async -> OTPValue?
  /// Changes currently active OTP resource to the next OTP
  /// for that resource if able and returns current value.
  /// Disposes previously active if not matching the same ID.
  /// - Note: TOTP updates are made automatically every second
  /// and can be accessed using `current` when `updates`
  /// generates new values.
  internal var requestNextFor: @Sendable (Resource.ID) async throws -> OTPValue
  /// Copy OTP value for requested resource.
  /// Reuses current if able or requests next for the resource,
  /// while disposing active if not matching ID.
  /// - Note: Copy does not set new active OTP resource and does
  /// not trigger updates (except update on disposing current).
  internal var copyFor: @Sendable (Resource.ID) async throws -> Void
  /// Clear current OTP resource and cancel any pending updates.
  internal var dispose: @Sendable () async -> Void
}

extension OTPCodesController: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG
  internal nonisolated static var placeholder: Self {
    .init(
      updates: .placeholder,
      current: unimplemented0(),
      requestNextFor: unimplemented1(),
      copyFor: unimplemented1(),
      dispose: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension OTPCodesController {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let time: OSTime = features.instance()
    let pasteboard: OSPasteboard = features.instance()

    let otpResources: OTPResources = try features.instance()

    @Sendable nonisolated func requestOTPCodeGenerator(
      for resourceID: Resource.ID
    ) async throws -> OTPCodesGenerator {
      let totp: TOTPSecret = try await otpResources.secretFor(resourceID)
      let totpCodeGenerator: TOTPCodeGenerator = try await features.instance(
        context: .init(
          resourceID: resourceID,
          sharedSecret: totp.sharedSecret,
          algorithm: totp.algorithm,
          digits: totp.digits,
          period: totp.period
        )
      )
      return {
        .totp(totpCodeGenerator.generate())
      }
    }

    let controller: OTPController = .init(
      timerSequence: time.timerSequence(1),
      requestGenerator: requestOTPCodeGenerator(for:)
    )

    @Sendable nonisolated func current() async -> OTPValue? {
      await controller.currentOTPValue
    }

    @Sendable nonisolated func requestNext(
      for resourceID: Resource.ID
    ) async throws -> OTPValue {
      try await controller.requestOTP(
        for: resourceID,
        disposable: false
      )
    }

    @Sendable nonisolated func copy(
      for resourceID: Resource.ID
    ) async throws {
      let otp: OTP =
        try await controller.requestOTP(
          for: resourceID,
          disposable: true
        )
        .otp

      pasteboard.put(otp.rawValue)
    }

    @Sendable nonisolated func dispose() async {
      await controller.disposeCurrent()
    }

    return .init(
      updates: controller.updates,
      current: current,
      requestNextFor: requestNext(for:),
      copyFor: copy(for:),
      dispose: dispose
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltOTPCodesController() {
    // primary use of this instance is OTP list on tab
    self.use(
      .lazyLoaded(
        OTPCodesController.self,
        load: OTPCodesController.load(features:cancellables:)
      ),
      in: SessionScope.self
    )
    // resource details owns separate instance
    // to avoid interacting with OTP list
    self.use(
      .lazyLoaded(
        OTPCodesController.self,
        load: OTPCodesController.load(features:cancellables:)
      ),
      in: ResourceDetailsScope.self
    )
  }
}

private typealias OTPCodesGenerator = @Sendable () -> OTPValue

private enum OTPControllerState {

  case idle
  case requested(
    Resource.ID,
    task: Task<OTPCodesGenerator, Error>
  )
  case active(
    Resource.ID,
    generator: OTPCodesGenerator,
    updatesTask: Task<Void, Never>
  )
}

extension OTPControllerState {

  fileprivate var resourceID: Resource.ID? {
    switch self {
    case .idle:
      return .none

    case .active(let resourceID, _, _):
      return resourceID

    case .requested(let resourceID, _):
      return resourceID
    }
  }

  fileprivate var generator: OTPCodesGenerator? {
    switch self {
    case .idle:
      return .none

    case .active(_, let generator, _):
      return generator

    case .requested:
      return .none
    }
  }
}

private final actor OTPController {

  private var state: OTPControllerState
  private let updatesSource: UpdatesSequenceSource
  private let timerSequence: AnyAsyncSequence<Void>
  private let requestGenerator: @Sendable (Resource.ID) async throws -> OTPCodesGenerator

  fileprivate init(
    timerSequence: AnyAsyncSequence<Void>,
    requestGenerator: @escaping @Sendable (Resource.ID) async throws -> OTPCodesGenerator
  ) {
    self.state = .idle
    self.updatesSource = .init()
    self.timerSequence = timerSequence
    self.requestGenerator = requestGenerator
  }

  fileprivate nonisolated var updates: UpdatesSequence {
    self.updatesSource.updatesSequence
  }

  fileprivate var currentOTPValue: OTPValue? {
    self.state.generator?()
  }

  fileprivate func requestOTP(
    for resourceID: Resource.ID,
    disposable: Bool
  ) async throws -> OTPValue {
    switch self.state {
    case .active(resourceID, let generator, _):
      return generator()

    case .requested(resourceID, let task):
      let generator: OTPCodesGenerator = try await task.value
      if !disposable, case .idle = state {
        state = .active(
          resourceID,
          generator: generator,
          updatesTask: .init {
            #warning("[MOB-1096] TODO: add full support for HOTP - don't schedule updates / trigger only on counter updates")
            for await _ in timerSequence {
              updatesSource.sendUpdate()
            }
          }
        )
      }  // else NOP

      return generator()

    case .active(_, _, let task):
      task.cancel()
      self.state = .idle
      self.updatesSource.sendUpdate()
      return try await requestOTPWithGenerator(
        for: resourceID,
        keepActive: !disposable
      )

    case .idle:
      return try await requestOTPWithGenerator(
        for: resourceID,
        keepActive: !disposable
      )

    case .requested(_, let task):
      task.cancel()
      self.state = .idle
      self.updatesSource.sendUpdate()
      return try await requestOTPWithGenerator(
        for: resourceID,
        keepActive: !disposable
      )
    }
  }

  fileprivate func disposeCurrent() {
    switch self.state {
    case .active(_, _, let task):
      task.cancel()
      self.state = .idle
      self.updatesSource.sendUpdate()

    case .idle:
      break  // NOP - nothing to do

    case .requested(_, let task):
      task.cancel()
      self.state = .idle
      self.updatesSource.sendUpdate()
    }
  }

  private func requestOTPWithGenerator(
    for resourceID: Resource.ID,
    keepActive: Bool
  ) async throws -> OTPValue {
    let requestGenerator: (Resource.ID) async throws -> OTPCodesGenerator = self.requestGenerator

    let requestTask: Task<OTPCodesGenerator, Error> = .init {
      try await requestGenerator(resourceID)
    }

    // make sure current active/requested
    // were cancelled at this point
    self.state = .requested(
      resourceID,
      task: requestTask
    )
    // no updates here - no new code to get

    let generator: OTPCodesGenerator = try await requestTask.value

    if keepActive {
      let updatesSource: UpdatesSequenceSource = self.updatesSource
      let timerSequence: AnyAsyncSequence<Void> = self.timerSequence
      self.state = .active(
        resourceID,
        generator: generator,
        updatesTask: .init {
          #warning("[MOB-1096] TODO: add full support for HOTP - don't schedule updates / trigger only on counter updates")
          for await _ in timerSequence {
            updatesSource.sendUpdate()
          }
        }
      )
      self.updatesSource.sendUpdate()
    }
    else {
      // throw away generator
      self.state = .idle
    }

    return generator()
  }
}
