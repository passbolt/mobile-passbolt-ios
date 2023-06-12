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
import OSFeatures
import Resources
import SharedUIComponents

internal enum ResourceContextualMenuAccessAction: Hashable, Identifiable {

  case openURI
  case copyURI
  case copyUsername
  case revealOTP
  case copyOTP
  case copyPassword
  case copyDescription

  internal var id: Self { self }
}

internal enum ResourceContextualMenuModifyAction: Hashable, Identifiable {

  case toggle(favorite: Bool)

  case share
  case edit
  case delete

  internal var id: Self { self }
}

internal final class ResourceContextualMenuViewController: ViewController {

  internal struct Context {

    internal var revealOTP: (@MainActor () -> Void)?
    internal var showMessage: @MainActor (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Equatable {

    internal var title: String
    internal var accessActions: Array<ResourceContextualMenuAccessAction>
    internal var modifyActions: Array<ResourceContextualMenuModifyAction>
  }

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let resourceController: ResourceController
  private let otpCodesController: OTPCodesController

  private let navigationToSelf: NavigationToResourceContextualMenu
  private let navigationToDeleteAlert: NavigationToResourceDeleteAlert
  private let navigationToShare: NavigationToResourceShare
  private let navigationToEdit: NavigationToResourceEdit

  private let linkOpener: OSLinkOpener
  private let pasteboard: OSPasteboard
  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor

  private let revealOTP: (@MainActor () -> Void)?
  private let showMessage: @MainActor (SnackBarMessage?) -> Void
  private let resourceID: Resource.ID

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(ResourceDetailsScope.self)
    self.resourceID = try features.context(of: ResourceDetailsScope.self)

    self.features = features.takeOwned()

    self.revealOTP = context.revealOTP
    self.showMessage = context.showMessage

    self.linkOpener = features.instance()
    self.pasteboard = features.instance()
    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToDeleteAlert = try features.instance()
    self.navigationToShare = try features.instance()
    self.navigationToEdit = try features.instance()

    self.resourceController = try features.instance()
    self.otpCodesController = try features.instance()

    self.viewState = .init(
      initial: .init(
        title: "",
        accessActions: .init(),
        modifyActions: .init()
      )
    )
  }
}

extension ResourceContextualMenuViewController {

  @Sendable internal func activate() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Resource contextual menu updates broken!"),
        fallback: { _ in
          try? await self.navigationToSelf.revert()
        }
      ) {
        for try await resource in self.resourceController.state {
          self.update(resource)
        }
      }
  }

  internal func update(
    _ resource: Resource
  ) {
    var accessActions: Array<ResourceContextualMenuAccessAction> = .init()
    if resource.contains(\.meta.uri) {
      accessActions.append(.openURI)
      accessActions.append(.copyURI)
    }  // else NOP

    if resource.contains(\.meta.username) {
      accessActions.append(.copyUsername)
    }  // else NOP

    if resource.contains(\.secret.password) || resource.contains(\.secret) {
      accessActions.append(.copyPassword)
    }  // else NOP

    if resource.contains(\.secret.description) || resource.contains(\.meta.description) {
      accessActions.append(.copyDescription)
    }  // else NOP

    if case .some = self.revealOTP {
      accessActions.append(.revealOTP)
    }  // else NOP

    // TODO: currently can't identify otp fields other way than by name
    if resource.contains(\.secret.totp) {
      accessActions.append(.copyOTP)
    }  // else NOP

    var modifyActions: Array<ResourceContextualMenuModifyAction> = [
      .toggle(favorite: resource.favorite)
    ]

    if resource.permission.canShare {
      modifyActions.append(.share)
    }  // else NOP
    if resource.permission.canEdit {
      modifyActions.append(.edit)
      modifyActions.append(.delete)
    }  // else NOP

    self.viewState.update { (state: inout ViewState) in
      state.title = resource.meta.name.stringValue ?? ""
      state.accessActions = accessActions
      state.modifyActions = modifyActions
    }
  }

  internal func handle(
    _ action: ResourceContextualMenuAccessAction
  ) async {
    switch action {
    case .openURI:
      await self.openURL(field: \.meta.uri)

    case .copyURI:
			await self.copy(field: \.meta.uri)

    case .copyUsername:
			await self.copy(field: \.meta.username)

    case .revealOTP:
			await self.revealOTPCode()

    case .copyOTP:
			await self.copyOTPCode()

    case .copyPassword:
      // it can be \.secret as well!!!
			await self.copy(field: \.secret.password)

    case .copyDescription:
      // it can be \.meta.description as well!!!
			await self.copy(field: \.secret.description)
    }
  }

  internal func handle(
    _ action: ResourceContextualMenuModifyAction
  ) async {
    switch action {
    case .toggle(favorite: _):
			await self.toggleFavorite()

    case .share:
			await self.share()

    case .edit:
			await self.edit()

    case .delete:
			await self.delete()
    }
  }

  internal func openURL(
    field path: Resource.FieldPath
  ) async {
		await self.diagnostics
			.withLogCatch(
				info: .message("Opening resource field url failed!"),
				fallback: { @MainActor (error: Error) async -> Void in
					self.showMessage(.error(error))
				}
			) { () async throws -> Void in
				var resource: Resource = try await self.resourceController.state.value

				let fieldPath: Resource.FieldPath
				// password can be legacy unstructured
				if path == \.secret.password {
					if resource.contains(\.secret.password) {
						fieldPath = \.secret.password
					}
					else if resource.contains(\.secret) {
						fieldPath = \.secret
					}
					else {
						throw
						UnknownResourceField
							.error(
								"Attempting to access not existing resource field value!",
								path: path,
								value: .null
							)
					}
				}
				// edscription can be encrypted or not
				else if path == \.secret.description {
					if resource.contains(\.secret.description) {
						fieldPath = \.secret.description
					}
					else if resource.contains(\.meta.description) {
						fieldPath = \.meta.description
					}
					else {
						throw
						UnknownResourceField
							.error(
								"Attempting to access not existing resource field value!",
								path: path,
								value: .null
							)
					}
				}
				else {
					fieldPath = path
				}

				guard let field: ResourceFieldSpecification = resource.allFields.first(where: { $0.path == fieldPath })
				else {
					throw
					UnknownResourceField
						.error(
							"Attempting to access not existing resource field value!",
							path: path,
							value: .null
						)
				}

				if field.encrypted {
					_ = try await self.resourceController.fetchSecretIfNeeded()
					resource = try await self.resourceController.state.value
				}  // else continue

				try await self.linkOpener.openURL(.init(rawValue: resource[keyPath: fieldPath].stringValue ?? ""))

				try await self.navigationToSelf.revert()
			}
  }

  internal func copy(
    field path: Resource.FieldPath
  ) async {
		await self.diagnostics
			.withLogCatch(
				info: .message("Copying resource field value failed!"),
				fallback: { @MainActor (error: Error) async -> Void in
					self.showMessage(.error(error))
				}
			) { () async throws -> Void in
				var resource: Resource = try await self.resourceController.state.value

				let fieldPath: Resource.FieldPath
				// password can be legacy unstructured
				if path == \.secret.password {
					if resource.contains(\.secret.password) {
						fieldPath = \.secret.password
					}
					else if resource.contains(\.secret) {
						fieldPath = \.secret
					}
					else {
						throw
						UnknownResourceField
							.error(
								"Attempting to access not existing resource field value!",
								path: path,
								value: .null
							)
					}
				}
				// edscription can be encrypted or not
				else if path == \.secret.description {
					if resource.contains(\.secret.description) {
						fieldPath = \.secret.description
					}
					else if resource.contains(\.meta.description) {
						fieldPath = \.meta.description
					}
					else {
						throw
						UnknownResourceField
							.error(
								"Attempting to access not existing resource field value!",
								path: path,
								value: .null
							)
					}
				}
				else {
					fieldPath = path
				}

				guard let field: ResourceFieldSpecification = resource.allFields.first(where: { $0.path == fieldPath })
				else {
					throw
					UnknownResourceField
						.error(
							"Attempting to access not existing resource field value!",
							path: path,
							value: .null
						)
				}

				if field.encrypted {
					_ = try await self.resourceController.fetchSecretIfNeeded()
					resource = try await self.resourceController.state.value
				}  // else continue

				self.pasteboard.put(resource[keyPath: fieldPath].stringValue ?? "")

				try await self.navigationToSelf.revert()

				self.showMessage(
					.info(
						.localized(
							key: "resource.menu.item.field.copied",
							arguments: [
								field.name.displayable.string()
							]
						)
					)
				)
			}
  }

  internal final func revealOTPCode() async {
		await self.diagnostics
			.withLogCatch(
				info: .message("Revealing resource OTP failed!"),
				fallback: { @MainActor (error: Error) async -> Void in
					self.showMessage(.error(error))
				}
			) { @MainActor in
				guard let revealOTP = self.revealOTP
				else {
					throw
					InvalidResourceData
						.error(message: "Invalid or missing TOTP reveal action!")
				}
				try await self.navigationToSelf.revert(animated: true)
				revealOTP()
			}
  }

  internal final func copyOTPCode() async {
		await self.diagnostics
			.withLogCatch(
				info: .message("Copying resource OTP failed!"),
				fallback: { @MainActor (error: Error) async -> Void in
					self.showMessage(.error(error))
				}
			) {
				let resourceSecret: JSON = try await self.resourceController.fetchSecretIfNeeded()

				// searching only for "totp" field, can't identify totp otherwise now
				guard let totpSecret: TOTPSecret = resourceSecret.totp.totpSecretValue
				else {
					throw
					InvalidResourceData
						.error(message: "Invalid or missing TOTP in secret")
				}

				let totpCodeGenerator: TOTPCodeGenerator = try self.features.instance(
					context: .init(
						resourceID: resourceID,
						sharedSecret: totpSecret.sharedSecret,
						algorithm: totpSecret.algorithm,
						digits: totpSecret.digits,
						period: totpSecret.period
					)
				)

				let totp: TOTPValue = totpCodeGenerator.generate()
				self.pasteboard.put(totp.otp.rawValue)
				try await self.navigationToSelf.revert(animated: true)
				self.showMessage(.info("otp.copied.message"))
			}
  }

  internal final func toggleFavorite() async {
		await self.diagnostics
			.withLogCatch(
				info: .message("Toggling resource favorite failed!"),
				fallback: { @MainActor (error: Error) async -> Void in
					self.showMessage(.error(error))
				}
			) {
				try await self.resourceController.toggleFavorite()
				let resource: Resource = try await self.resourceController.state.value
				try await self.navigationToSelf.revert()
				if resource.favorite {
					self.showMessage(
						.info(
							.localized(
								key: "resource.menu.action.favorite.added",
								arguments: [
									resource.meta.name.stringValue
									?? DisplayableString
										.localized("resource")
										.string()
								]
							)
						)
					)
				}
				else {
					self.showMessage(
						.info(
							.localized(
								key: "resource.menu.action.favorite.removed",
								arguments: [
									resource.meta.name.stringValue
									?? DisplayableString
										.localized("resource")
										.string()
								]
							)
						)
					)
				}
			}
  }

  internal final func share() async {
		await self.diagnostics
			.withLogCatch(
				info: .message("Navigation to resource share failed!"),
				fallback: { @MainActor (error: Error) async -> Void in
					self.showMessage(.error(error))
				}
			) {
				try await self.navigationToSelf.revert()
				try await self.navigationToShare.perform(context: resourceID)
    }
  }

  internal final func edit() async {
		await self.diagnostics
			.withLogCatch(
				info: .message("Navigation to resource edit failed!"),
				fallback: { @MainActor (error: Error) async -> Void in
					self.showMessage(.error(error))
				}
			) {
				try await self.navigationToSelf.revert()
				try await self.navigationToEdit.perform(
        context: (
          editing: .edit(resourceID),
          completion: { _ in }
        )
      )
    }
  }

  internal final func delete() async {
		await self.diagnostics
			.withLogCatch(
				info: .message("Navigation to resource delete failed!"),
				fallback: { @MainActor (error: Error) async -> Void in
					self.showMessage(.error(error))
				}
			) {
				try await self.navigationToSelf.revert(animated: true)
				try await self.navigationToDeleteAlert.perform(
        context: (
					resourceID: self.resourceID,
					containsOTP: self.resourceController.state.value.containsOTP,
					showMessage: self.showMessage
        )
      )
    }
  }

  internal final func dismiss() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Dismissing resource contextual menu failed!",
      behavior: .reuse
    ) { [navigationToSelf] in
      try await navigationToSelf.revert()
    }
  }
}
