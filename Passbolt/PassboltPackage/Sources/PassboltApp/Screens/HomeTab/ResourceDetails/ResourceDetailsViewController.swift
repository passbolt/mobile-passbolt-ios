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
    internal var sections: Array<ResourceDetailsSectionViewModel>
    internal var canShowMembersList: Bool
    internal var permissions: Array<OverlappingAvatarStackView.Item>
    internal var expirationDate: Date?

    internal var isExpired: Bool? {
      guard let expirationDate else { return nil }
      return expirationDate.timeIntervalSinceNow < 0
    }

  }

  nonisolated internal let viewState: ViewStateSource<ViewState>

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
        sections: .init(),
        canShowMembersList: false,
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
            viewState.sections = sections(
              for: resource,
              using: features,
              revealedFields: resource.secretAvailable
                ? localState.revealedFields
                : .init(),
              sessionConfiguration: sessionConfiguration
            )
            viewState.expirationDate = resource.expired?.asDate
            viewState.canShowMembersList = sessionConfiguration.share.showMembersList
            if sessionConfiguration.share.showMembersList {
              viewState.permissions = resourcePermissions
            }
          }
        }
        catch {
          let message = error.asTheError().displayableMessage.string()
          //When deletion happen it display the error message instead of the correct message. We skip this error message to avoid confusion
          if message != DisplayableString.localized(key: "error.database.result.empty").string() {
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

/// Prepare sections/groupped fields for display in UI
@MainActor private func sections(
  for resource: Resource,
  using features: Features,
  revealedFields: Set<Resource.FieldPath>,
  sessionConfiguration: SessionConfiguration
) -> Array<ResourceDetailsSectionViewModel> {
  guard resource.type.specification.slug != .placeholder else {
    return .init()  // show no sections for placeholder type
  }

  var passwordSection: ResourceDetailsSectionViewModel = .init(
    title: "resource.edit.section.password.title",
    fields: .init()
  )

  var totpSection: ResourceDetailsSectionViewModel = .init(
    title: "resource.edit.section.totp.title",
    fields: .init()
  )

  var metadataSection: ResourceDetailsSectionViewModel = .init(
    title: "resource.edit.section.metadata.title",
    fields: .init()
  )

  var notesSection: ResourceDetailsSectionViewModel = .init(title: "resource.edit.section.note.title", fields: .init())

  var fieldModelsByName: OrderedDictionary<ResourceFieldName, ResourceDetailsFieldViewModel> = resource
    .fields
    .compactMap {
      (
        field: ResourceFieldSpecification
      ) -> (
        key: ResourceFieldName,
        value: ResourceDetailsFieldViewModel
      )? in
      // remove name from fields, we already have it displayed
      if field.isNameField {
        return .none
      }
      else {
        guard
          let spec: ResourceDetailsFieldViewModel = .init(
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
        else { return .none }
        return (key: field.name, value: spec)
      }
    }
    .reduce(into: OrderedDictionary<ResourceFieldName, ResourceDetailsFieldViewModel>()) { $0[$1.key] = $1.value }

  for fieldName: ResourceFieldName in ResourceDetailsSectionViewModel.passwordSectionFields {
    if let fieldModel: ResourceDetailsFieldViewModel = fieldModelsByName[fieldName] {
      passwordSection.fields.append(fieldModel)
      fieldModelsByName.removeValue(forKey: fieldName)
    }
  }

  for (fieldName, fieldModel) in fieldModelsByName {
    if ResourceDetailsSectionViewModel.totpSectionFields.contains(fieldName) {
      totpSection.fields.append(fieldModel)
    }
    else if fieldName == .note {
      notesSection.fields.append(fieldModel)
    }
    else {
      metadataSection.fields.append(fieldModel)
    }
  }

  if sessionConfiguration.folders.enabled {
    metadataSection.virtualFields.append(
      .location(resource.path.map(\.name))
    )
  }
  if sessionConfiguration.tags.enabled {
    metadataSection.virtualFields.append(
      .tags(resource.tags.map(\.slug.rawValue))
    )
  }

  if let expirationDate = resource.expired?.asDate {
    let isExpired: Bool = expirationDate.timeIntervalSinceNow < 0
    let interval = expirationDate.timeIntervalSinceNow
    let relativeFormattedString: String = RelativeDateTimeFormatter().localizedString(fromTimeInterval: interval)

    var expiryParts = relativeFormattedString.split(separator: " ")
    let numberIndex = expiryParts.firstIndex { Int($0) != nil }

    if let numberIndex {
      let numberString = String(expiryParts[numberIndex])
      expiryParts.remove(at: numberIndex)
      //We just keep the time string "month", "day"
      let expiryTimeFormat = expiryParts.joined(separator: " ").replacingOccurrences(of: "in", with: "")
      let dateFormat: RelativeDateDisplayableFormat = .init(
        number: numberString,
        localizedRelativeString: expiryTimeFormat
      )
      metadataSection.virtualFields.append(
        .expiration(isExpired, dateFormat)
      )
    }
  }

  // remove empty sections
  return [passwordSection, totpSection, notesSection, metadataSection]
    .filter {
      $0.fields.isEmpty == false || $0.virtualFields.isEmpty == false
    }
}

/// View model for a section/fields group of resource details
internal struct ResourceDetailsSectionViewModel: Equatable, Identifiable {

  internal var id: String { self.title.string() }
  internal var title: DisplayableString
  internal var fields: Array<ResourceDetailsFieldViewModel>
  internal var virtualFields: Array<VirtualField> = .init()

  /// Properties that are not fields but are displayed as part of the section - navigating to other screens
  internal enum VirtualField: Equatable, Identifiable {

    internal typealias ID = Tagged<String, Self>
    case location(Array<String>)
    case tags(Array<String>)
    case expiration(Bool, RelativeDateDisplayableFormat)

    internal var id: ID {
      switch self {
      case .location:
        return "location"
      case .tags:
        return "tags"
      case .expiration:
        return "expiration"
      }
    }
  }

  /// Password/main section fields
  static fileprivate var passwordSectionFields: Array<ResourceFieldName> {
    [
      .username,
      .password,
      .secret,
      .uri,
    ]
  }

  /// TOTP section fields
  static fileprivate var totpSectionFields: Array<ResourceFieldName> {
    [
      .totp
    ]
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
      if let values = resource[keyPath: field.path].arrayValue, let value = values.first?.stringValue, !value.isEmpty {
        // at the moment, we support only one-item list on UI
        self.value = .plain(value)
        self.mainAction = .copy
        self.accessoryAction = .copy
      }
      else {
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
        if field.path == \.meta.description {
          return nil  // do not display empty description field
        }
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
