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
import Users

internal final class ResourceDetailsViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var name: String
    internal var favorite: Bool
    internal var containsUndefinedFields: Bool
    internal var fields: Array<ResourceDetailsFieldViewModel>
    internal var locationAvailable: Bool
    internal var location: Array<String>
    internal var expirationDate: Date?
    internal var tagsAvailable: Bool
    internal var tags: Array<String>
    internal var permissionsListVisible: Bool
    internal var permissions: Array<OverlappingAvatarStackView.Item>

    internal var isExpired: Bool? {
      guard let expirationDate else { return nil }
      return expirationDate.timeIntervalSinceNow < 0
    }
    internal var expiryRelativeFormattedDate: RelativeDateDisplayableFormat? {
      guard let expirationDate else { return nil }
      let interval = expirationDate.timeIntervalSinceNow
      let relativeFormattedString = RelativeDateTimeFormatter().localizedString(fromTimeInterval: interval)

      var expiryParts = relativeFormattedString.split(separator: " ")
      let numberIndex = expiryParts.firstIndex { Int($0) != nil }

      guard let numberIndex else { return nil }
      let numberString = String(expiryParts[numberIndex])
      expiryParts.remove(at: numberIndex)
      //We just keep the time string "month", "day"
      let expiryTimeFormat = expiryParts.joined(separator: " ").replacingOccurrences(of: "in", with: "")
      return .init(
        number: numberString,
        localizedRelativeString: expiryTimeFormat)
    }

  }

  internal let viewState: ViewStateSource<ViewState>

  internal struct LocalState: Equatable {

    fileprivate var revealedFields: Set<ResourceType.FieldPath>
  }

  private let localState: Variable<LocalState>

  private let resourceController: ResourceController

  private let navigationToSelf: NavigationToResourceDetails
  private let navigationToResourceContextualMenu: NavigationToResourceContextualMenu
  private let navigationToResourceLocationDetails: NavigationToResourceLocationDetails
  private let navigationToResourceTagsDetails: NavigationToResourceTagsDetails
  private let navigationToResourcePermissionsDetails: NavigationToResourcePermissionsDetails
  private let pasteboard: OSPasteboard

  private let resourceID: Resource.ID
  private let sessionConfiguration: SessionConfiguration

  private let features: Features

  internal init(
    context: Resource.ID,
    features: Features
  ) throws {
    let features: Features = try features.branch(
      scope: ResourceScope.self,
      context: context
    )
    self.sessionConfiguration = try features.sessionConfiguration()

    self.resourceID = context

    self.features = features

    self.pasteboard = features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToResourceContextualMenu = try features.instance()
    self.navigationToResourceLocationDetails = try features.instance()
    self.navigationToResourceTagsDetails = try features.instance()
    self.navigationToResourcePermissionsDetails = try features.instance()

    self.resourceController = try features.instance()
    let users: Users = try features.instance()

    self.localState = .init(
      initial: .init(
        revealedFields: .init()
      )
    )
    self.viewState = .init(
      initial: .init(
        name: .init(),
        favorite: false,
        containsUndefinedFields: false,
        fields: .init(),
        locationAvailable: self.sessionConfiguration.folders.enabled,
        location: .init(),
        tagsAvailable: self.sessionConfiguration.tags.enabled,
        tags: .init(),
        permissionsListVisible: self.sessionConfiguration.share.showMembersList,
        permissions: .init()
      ),
      updateFrom: ComputedVariable(
        combined: self.resourceController.state,
        with: self.localState
      ),
      update: { [navigationToSelf, sessionConfiguration] (updateView, update: Update<(Resource, LocalState)>) in
        do {
          let (resource, localState): (Resource, LocalState) = try update.value
          let resourcePermissions: Array<OverlappingAvatarStackView.Item> = try await resource.permissions.asyncMap {
            (permission: ResourcePermission) in
            switch permission {
            case .user(let id, _, _):
              return await .user(
                id,
                avatarImage: users.avatarImage(for: id),
                isSuspended: try users.userDetails(id).isSuspended
              )

            case .userGroup(let id, _, _):
              return .userGroup(id)
            }
          }
          updateView { (viewState: inout ViewState) in
            viewState.name = resource.name
            viewState.favorite = resource.favorite
            viewState.containsUndefinedFields = resource.containsUndefinedFields
            viewState.fields = fields(
              for: resource,
              using: features,
              revealedFields: resource.secretAvailable
                ? localState.revealedFields
                : .init(),
              sessionConfiguration: sessionConfiguration
            )
            viewState.location = resource.path.map(\.name)
            viewState.tags = resource.tags.map(\.slug.rawValue)
            viewState.expirationDate = resource.expired?.asDate
            viewState.permissions = resourcePermissions
          }
        }
        catch {
          let message = error.asTheError().displayableMessage.string()
          //When deletion happen it display the error message instead of the correct message. We skip this error message to avoid confusion
          if(message != DisplayableString.localized(key: "error.database.result.empty").string()) {
            SnackBarMessageEvent.send(.error(error))
          }
          await navigationToSelf.revertCatching()
        }
      }
    )
  }
}

extension ResourceDetailsViewController {

  internal func showMenu() async {
    await consumingErrors(
      errorDiagnostics: "Failed to present resource menu!"
    ) {
      let revealOTPAction: (@MainActor () async -> Void)?
      let resource: Resource = try await self.resourceController.state.value
      if let totpPath: ResourceType.FieldPath = resource.firstTOTPPath {
        revealOTPAction = { [weak self] in
          await self?.revealFieldValue(path: totpPath)
        }
      }
      else {
        revealOTPAction = .none
      }

      try await self.navigationToResourceContextualMenu
        .perform(
          context: .init(
            revealOTP: revealOTPAction
          )
        )
    }
  }

  internal func showLocationDetails() async {
    await self.navigationToResourceLocationDetails.performCatching()
  }

  internal func showTagsDetails() async {
    await self.navigationToResourceTagsDetails.performCatching()
  }

  internal func showPermissionsDetails() async {
    await self.navigationToResourcePermissionsDetails.performCatching()
  }

  internal func copyFieldValue(
    path: Resource.FieldPath
  ) async {
    await consumingErrors(
      errorDiagnostics: "Failed to copy resource field value!"
    ) {
      var resource: Resource = try await self.resourceController.state.value

      // ensure having secret if field is part of it
      if resource.isEncrypted(path) {
        try await self.resourceController.fetchSecretIfNeeded()
        resource = try await self.resourceController.state.value
      }  // else NOP
      let fieldValue: JSON = resource[keyPath: path]
      if let totpSecret: TOTPSecret = fieldValue.totpSecretValue {
        let totpValue: TOTPValue =
          try self.features
          .instance(of: TOTPCodeGenerator.self)
          .prepare(
            .init(
              resourceID: resourceID,
              secret: totpSecret
            )
          )()
        self.pasteboard.put(totpValue.otp.rawValue)
      }
      else {
        self.pasteboard.put(fieldValue.stringValue ?? "")
      }

      SnackBarMessageEvent.send(
        .info(
          .localized(
            key: "resource.value.copied",
            arguments: [
              resource
                .displayableName(forField: path)?
                .string()
                ?? DisplayableString
                .localized("resource.field.name.unknown")
                .string()
            ]
          )
        )
      )
    }
  }

  internal func revealFieldValue(
    path: ResourceType.FieldPath
  ) async {
    await consumingErrors(
      errorDiagnostics: "Failed to reveal resource field value!"
    ) {
      let resource: Resource = try await self.resourceController.state.value

      // ensure having secret if field is part of it
      if resource.isEncrypted(path) {
        try await self.resourceController.fetchSecretIfNeeded()
      }  // else NOP

      self.localState.mutate { (state: inout LocalState) in
        state.revealedFields.insert(path)
      }
    }
  }

  internal func coverFieldValue(
    path: ResourceType.FieldPath
  ) {
    self.localState.mutate { (state: inout LocalState) in
      state.revealedFields.remove(path)
    }
  }

  internal func coverAllFields() {
    self.localState.mutate { (state: inout LocalState) in
      state.revealedFields.removeAll()
    }
  }
}

@MainActor private func fields(
  for resource: Resource,
  using features: Features,
  revealedFields: Set<Resource.FieldPath>,
  sessionConfiguration: SessionConfiguration
) -> Array<ResourceDetailsFieldViewModel> {
  if resource.type.specification.slug == .placeholder {
    return .init()  // show no fields for placeholder type
  }
  else {
    return resource
      .fields
      .compactMap { (field: ResourceFieldSpecification) -> ResourceDetailsFieldViewModel? in
        // remove name from fields, we already have it displayed
        if field.isNameField {
          return .none
        }
        else {
          return .init(
            field,
            in: resource,
            revealedFields: revealedFields,
            configuration: sessionConfiguration.resources,
            prepareTOTPGenerator: { [features] totpSecret in
              let generateOTP: @Sendable () -> TOTPValue =
                try features
                .instance(of: TOTPCodeGenerator.self)
                .prepare(
                  .init(
                    resourceID: resource.id,
                    secret: totpSecret
                  )
                )
              return generateOTP
            }
          )
        }
      }
  }
}

internal struct ResourceDetailsFieldViewModel {

  internal enum Action {

    case copy
    case reveal
    case hide
  }

  internal enum Value: Equatable {

    internal static func == (
      _ lhs: ResourceDetailsFieldViewModel.Value,
      _ rhs: ResourceDetailsFieldViewModel.Value
    ) -> Bool {
      switch (lhs, rhs) {
      case (.plain(let lString), .plain(let rString)):
        return lString == rString

      case (.encrypted, .encrypted):
        return true

      case (.password(let lString), .password(let rString)):
        return lString == rString

      case (.encryptedTOTP, .encryptedTOTP):
        return true

      case (.totp(let lHash, _), .totp(let rHash, _)):
        return lHash == rHash

      case _:
        return false
      }
    }

    case encrypted
    case placeholder(String)
    case plain(String)
    case password(String)
    case totp(hash: Int, generate: @Sendable () -> TOTPValue)
    case encryptedTOTP
    case invalid(TheError)
  }

  internal var path: ResourceType.FieldPath
  internal var name: DisplayableString
  internal var value: Value
  internal var mainAction: Action?
  internal var accessoryAction: Action?

  internal init?(
    _ field: ResourceFieldSpecification,
    in resource: Resource,
    revealedFields: Set<Resource.FieldPath>,
    configuration: ResourcesFeatureConfiguration,
    prepareTOTPGenerator: (TOTPSecret) throws -> @Sendable () -> TOTPValue
  ) {
    assert(
      resource.type.specification.slug != .placeholder,
      "Can't prepare fields for placeholder resources"
    )
    self.path = field.path
    switch field.semantics {
    case .list(let name, let placeholder, _):
      self.name = name
      if let values = resource[keyPath: field.path].arrayValue, let value = values.first?.stringValue {
        // at the moment, we support only one-item list on UI
        self.value = .placeholder(value)
        self.mainAction = .copy
        self.accessoryAction = .copy
      } else {
        self.value = .placeholder(placeholder.string())
        self.mainAction = .none
        self.accessoryAction = .none
      }
      
    case  // unencrypted
      .text(let name, let placeholder, _) where !field.encrypted,
      .longText(let name, let placeholder, _) where !field.encrypted,
      .selection(let name, values: _, let placeholder, _) where !field.encrypted,
      .intValue(let name, let placeholder, _) where !field.encrypted,
      .floatValue(let name, let placeholder, _) where !field.encrypted:
      self.name = name
      if let stringValue = resource[keyPath: field.path].stringValue, !stringValue.isEmpty {
        self.value = .plain(stringValue)
        self.mainAction = .copy
        self.accessoryAction = .copy
      }
      else {
        self.value = .placeholder(placeholder.string())
        self.mainAction = .none
        self.accessoryAction = .none
      }

    case  // encrypted
    .text(let name, let placeholder, _),
      .longText(let name, let placeholder, _),
      .selection(let name, values: _, let placeholder, _),
      .intValue(let name, let placeholder, _),
      .floatValue(let name, let placeholder, _):
      self.name = name
      let revealed: Bool = revealedFields.contains(field.path)
      if revealed {
        if let stringValue = resource[keyPath: field.path].stringValue, !stringValue.isEmpty {
          self.value = .plain(stringValue)
        }
        else {
          self.value = .placeholder(placeholder.string())
        }
        self.mainAction = .copy
        self.accessoryAction = .hide
      }
      else {
        self.value = .encrypted
        self.mainAction = .copy
        self.accessoryAction = .reveal
      }

    case .password(let name, let placeholder, _):
      self.name = name
      let revealed: Bool = revealedFields.contains(field.path)
      if revealed && configuration.passwordRevealEnabled {
        if let stringValue = resource[keyPath: field.path].stringValue, !stringValue.isEmpty {
          self.value = .password(stringValue)
        }
        else {
          self.value = .placeholder(placeholder.string())
        }

        self.mainAction =
          configuration.passwordCopyEnabled
          ? .copy
          : .none
        self.accessoryAction = .hide
      }
      else {
        self.value = .encrypted
        self.mainAction =
          configuration.passwordCopyEnabled
          ? .copy
          : .none
        self.accessoryAction =
          configuration.passwordRevealEnabled
          ? .reveal
          : configuration.passwordCopyEnabled
            ? .copy  // if not allowed to reveal use copy
            : .none
      }

    case .totp(let name):
      let revealed: Bool = revealedFields.contains(field.path)
      self.name = name
      if revealed {
        if let totpSecret: TOTPSecret = resource[keyPath: field.path].totpSecretValue {
          do {
            self.value = .totp(
              hash: totpSecret.hashValue,
              generate: try prepareTOTPGenerator(totpSecret)
            )
          }
          catch {
            self.value = .invalid(error.asTheError())
          }
        }
        else {
          self.value = .invalid(
            InvalidResourceField
              .error(
                "Invalid or missing TOTP field",
                specification: field,
                path: field.path,
                value: nil,
                displayable: "error.otp.configuration.invalid"
              )
          )
        }
        self.mainAction = .copy
        self.accessoryAction = .hide
      }
      else {
        self.value = .encryptedTOTP
        self.mainAction = .copy
        self.accessoryAction = .reveal
      }

    case .undefined:
      return nil  // do not display undefined fields, unfortunately even a placeholder
    }
  }
}

extension ResourceDetailsFieldViewModel: Equatable {}

extension ResourceDetailsFieldViewModel: Identifiable {

  internal var id: some Hashable { self.path }
}

internal struct RelativeDateDisplayableFormat: Equatable {
  public let number: String
  public let localizedRelativeString: String
}
