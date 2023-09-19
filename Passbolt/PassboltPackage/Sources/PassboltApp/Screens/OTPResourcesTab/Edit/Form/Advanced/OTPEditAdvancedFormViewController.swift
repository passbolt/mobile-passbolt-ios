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
import OSFeatures
import Resources

internal final class OTPEditAdvancedFormViewController: ViewController {

  public struct Context {

    public var totpPath: Resource.FieldPath

    public init(
      totpPath: Resource.FieldPath
    ) {
      self.totpPath = totpPath
    }
  }

  internal struct ViewState: Equatable {

    internal var algorithm: Validated<HOTPAlgorithm?>
    internal var period: Validated<String>
    internal var digits: Validated<String>
  }

  internal let viewState: ViewStateSource<ViewState>

  private let asyncExecutor: AsyncExecutor
  private let resourceEditForm: ResourceEditForm

  private let navigationToSelf: NavigationToOTPEditAdvancedForm

  private let totpPath: Resource.FieldPath

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.totpPath = context.totpPath

    self.navigationToSelf = try features.instance()

    self.asyncExecutor = try features.instance()
    self.resourceEditForm = try features.instance()

    self.viewState = .init(
      initial: .init(
        algorithm: .valid(.none),
        period: .valid(""),
        digits: .valid("")
      ),
      updateFrom: self.resourceEditForm.state,
      update: { (updateState, update: Update<Resource>) async in
        do {
          let resource: Resource = try update.value
          guard resource.contains(context.totpPath)
          else {
            throw
              InvalidResourceType
              .error(message: "Resource without TOTP, can't edit it.")
          }
          await updateState { (viewState: inout ViewState) in
            viewState.algorithm = resource.validated(context.totpPath.appending(path: \.algorithm))
              .map { $0.stringValue.flatMap(HOTPAlgorithm.init(rawValue:)) }
            viewState.digits = resource.validated(context.totpPath.appending(path: \.digits))
              .map { $0.stringValue ?? "" }
            viewState.period = resource.validated(context.totpPath.appending(path: \.period))
              .map { $0.stringValue ?? "" }
          }
        }
        catch {
					SnackBarMessageEvent.send(.error(error))
        }
      }
    )
  }
}

extension OTPEditAdvancedFormViewController {

  internal final func setAlgorithm(
    _ algorithm: HOTPAlgorithm
  ) {
    self.resourceEditForm
      .update(
        self.totpPath.appending(path: \.algorithm),
        to: algorithm
      )
  }

  @Sendable nonisolated internal final func setPeriod(
    _ period: String
  ) {
    self.resourceEditForm
      .update(
        self.totpPath.appending(path: \.period),
        to: period
      )
  }

  @Sendable nonisolated internal final func setDigits(
    _ digits: String
  ) {
    self.resourceEditForm
      .update(
        self.totpPath.appending(path: \.digits),
        to: digits
      )
  }
}
