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

import Commons
import Crypto
import Display
import FeatureScopes
import OSFeatures
import Resources

import struct OrderedCollections.OrderedDictionary

public final class ResourceEditViewController: ViewController {

  public struct Context {

    public var editingContext: ResourceEditingContext
    public var success: @Sendable (Resource) async -> Void
    public var customOnSuccessNavigation: (() async throws -> Void)?

    public init(
      editingContext: ResourceEditingContext,
      success: @escaping @Sendable (Resource) async -> Void = { _ in },
      customOnSuccessNavigation: (() async throws -> Void)? = nil
    ) {
      self.editingContext = editingContext
      self.success = success
      self.customOnSuccessNavigation = customOnSuccessNavigation
    }
  }

  public struct ViewState: Equatable {
    // Name field - can be edited outside of the form sections
    internal var nameField: ResourceEditFieldViewModel?
    // All form fields except name field
    internal var mainForm: MainFormViewModel
    // Flag indicating that there are undefined fields in the resource - i.e definied with new version of API
    internal var containsUndefinedFields: Bool
    // Flag indicating that the resource has been edited
    internal var edited: Bool
    internal var showPasswordSection: Bool
    // Flag indicating that advanced settings button can be shown
    internal var canShowAdvancedSettings: Bool
    // Flag indicating that advanced settings are shown
    internal var showsAdvancedSettings: Bool
    // Flag indicating if additional secrets can be added
    internal var canAddAdditionalSecrets: Bool
    // Current resource type slug
    internal var resourceTypeSlug: ResourceSpecification.Slug
    // Flag indicating that the resource is a standalone TOTP
    internal var isStandaloneTOTP: Bool {
      self.resourceTypeSlug.isStandaloneTOTPType
    }
  }

  public nonisolated let viewState: ViewStateSource<ViewState>

  internal let editsExisting: Bool

  private struct LocalState: Equatable {

    fileprivate var editedFields: Set<ResourceType.FieldPath>
  }

  private let localState: Variable<LocalState>

  private let allFields: Set<ResourceType.FieldPath>

  private let resourceEditForm: ResourceEditForm

  private let navigationToSelf: NavigationToResourceEdit
  private let navigationToOTPEdit: NavigationToOTPEditForm
  private let navigationToOTPAdvanced: NavigationToOTPEditAdvancedForm
  private let navigationToOTPScanning: NavigationToOTPScanning
  private let navigationToPasswordEdit: NavigationToResourcePasswordEdit
  private let navigationToTextEdit: NavigationToResourceTextEdit
  private let navigationToURIEdit: NavigationToResourceURIEdit
  private let navigationToInvalidMetadataKey: NavigationToMetadataPinnedKeyValidationDialog

  private let randomGenerator: RandomStringGenerator

  private let success: @Sendable (Resource) async -> Void
  private let customOnSuccessNavigation: (() async throws -> Void)?

  private let features: Features

  public init(
    context: Context,
    features: Features
  ) throws {
    let features: Features =
      try features
      .branch(
        scope: ResourceEditScope.self,
        context: context.editingContext
      )
    self.features = features  // keep the branch alive

    self.success = context.success
    self.customOnSuccessNavigation = context.customOnSuccessNavigation

    let randomGenerator: RandomStringGenerator = try features.instance()
    self.randomGenerator = randomGenerator

    if isInExtensionContext {
      // TODO: unify navigation between app and extnsion
      self.navigationToSelf = .placeholder
      self.navigationToOTPEdit = .placeholder
      self.navigationToOTPAdvanced = .placeholder
      self.navigationToPasswordEdit = .placeholder
      self.navigationToTextEdit = .placeholder
      self.navigationToOTPScanning = .placeholder
      self.navigationToURIEdit = .placeholder
    }
    else {
      self.navigationToSelf = try features.instance()
      self.navigationToOTPEdit = try features.instance()
      self.navigationToOTPAdvanced = try features.instance()
      self.navigationToPasswordEdit = try features.instance()
      self.navigationToTextEdit = try features.instance()
      self.navigationToOTPScanning = try features.instance()
      self.navigationToURIEdit = try features.instance()
    }

    self.navigationToInvalidMetadataKey = try features.instance()

    self.resourceEditForm = try features.instance()

    self.editsExisting = !context.editingContext.editedResource.isLocal
    self.allFields = Set(context.editingContext.editedResource.fields.map(\.path))

    self.localState = .init(
      initial: .init(
        editedFields: .init()
      )
    )
    let editedResource: Resource = context.editingContext.editedResource

    self.viewState = .init(
      initial: .init(
        nameField: nil,
        mainForm: .empty,
        containsUndefinedFields: false,
        edited: false,
        showPasswordSection: editedResource.isStandaloneTOTPResource == false,
        canShowAdvancedSettings: isInExtensionContext == false,
        showsAdvancedSettings: false,
        canAddAdditionalSecrets: editedResource.isSimplePasswordResource == false,
        resourceTypeSlug: editedResource.type.specification.slug
      ),
      updateFrom: ComputedVariable(
        combined: self.resourceEditForm.state,
        with: self.localState
      ),
      update: {
        @MainActor (updateState, update: Update<(Resource, LocalState)>) async throws -> Void in
        let update: (resource: Resource, localState: LocalState) = try update.value
        assert(update.resource.secretAvailable, "Can't edit resource without secret!")
        guard
          let nameFieldSpecification: ResourceFieldSpecification = update.resource.fields.first(where: {
            $0.name == .name
          })
        else {
          return
        }
        let countEntropy: (String) -> Entropy = { [randomGenerator] (input: String) -> Entropy in
          randomGenerator.entropy(input, CharacterSets.all)
        }
        let nameField: ResourceEditFieldViewModel? = .init(
          nameFieldSpecification,
          in: update.resource,
          edited: update.localState.editedFields.contains(nameFieldSpecification.path),
          countEntropy: countEntropy
        )
        let mainForm: MainFormViewModel = prepareMainFormViewModel(
          for: update.resource,
          edited: update.localState.editedFields,
          countEntropy: countEntropy
        )
        updateState { (viewState: inout ViewState) in
          viewState.nameField = nameField
          viewState.mainForm = mainForm
          viewState.containsUndefinedFields = update.resource.containsUndefinedFields
          viewState.edited = !update.localState.editedFields.isEmpty
        }
      }
    )
  }

  @MainActor internal func set(
    _ value: String,
    for field: ResourceType.FieldPath
  ) {
    self.resourceEditForm.update(field, to: value)
    self.localState.mutate { (state: inout LocalState) in
      state.editedFields.insert(field)
    }
  }

  @MainActor internal func generatePassword(
    for field: ResourceType.FieldPath
  ) {
    let generated: String = self.randomGenerator.generate(
      CharacterSets.all,
      18,
      Entropy.veryStrongPassword
    )
    self.resourceEditForm.update(field, to: generated)
    self.localState.mutate { (state: inout LocalState) in
      state.editedFields.insert(field)
    }
  }

  @MainActor internal func sendForm() async throws {
    do {
      let resource: Resource = try await self.resourceEditForm.sendForm()
      if !isInExtensionContext {
        // TODO: unify navigation between app and extension
        if let customOnSuccessNavigation {
          try await customOnSuccessNavigation()
        }
        else {
          try await self.navigationToSelf.revert()
        }
      }  // else NOP

      SnackBarMessageEvent.send(
        self.editsExisting
          ? "resource.menu.action.edited"
          : "resource.form.new.password.created"
      )
      await self.success(resource)
    }
    catch let error as InvalidForm {
      self.localState.mutate { (state: inout LocalState) in
        state.editedFields = self.allFields
      }
      throw error
    }
    catch let error as MetadataPinnedKeyValidationError {
      await self.navigationToInvalidMetadataKey.performCatching(
        context: .init(
          reason: error.reason,
          onTrustedKey: { [weak self] in try await self?.sendForm() }
        )
      )
    }
    catch {
      throw error
    }
  }

  @MainActor internal func discardForm() async {
    await consumingErrors(
      errorDiagnostics: "Failed to discard resource edit form!"
    ) {
      if isInExtensionContext {
        // TODO: unify navigation between app and extnsion
        self.features.instance(of: NavigationTree.self)
          .dismiss(self.viewNodeID)
      }
      else {
        try await self.navigationToSelf.revert()
      }
    }
  }

  @MainActor internal func scanTOTP() async {
    await consumingErrors {
      let currentState: Resource = try await self.resourceEditForm.state.value
      guard let totpPath: ResourceType.FieldPath = currentState.type.fieldSpecification(for: \.firstTOTP)?.path
      else {
        return
      }

      await self.navigationToOTPScanning.performCatching(
        context: .init(
          totpPath: totpPath
        )
      )
    }
  }

  /// Show advanced settings
  @MainActor internal func showAdvancedSettings() {
    viewState.update(\.showsAdvancedSettings, to: true)
    viewState.update(\.canShowAdvancedSettings, to: false)
  }

  /// Navigate to TOTP create/edit form.
  /// Note: Adding TOTP might require changing resource type to one that supports TOTP.  That might require revering if TOTP addition is cancelled.
  @MainActor internal func createOrEditTOTP() async {
    await consumingErrors {
      let editingContext = try features.context(of: ResourceEditScope.self)

      let currentState = try await self.resourceEditForm.state.value
      guard
        let attachedOTPSlug: ResourceSpecification.Slug = currentState.attachedOTPSlug,
        let attachedOTPType: ResourceType = editingContext.availableTypes.first(where: {
          $0.specification.slug == attachedOTPSlug
        }),
        let totpPath: ResourceType.FieldPath = attachedOTPType.fieldSpecification(for: \.firstTOTP)?.path
      else {
        let displayableString: DisplayableString =
          editingContext.editedResource.isLocal
          ? "resource.create.invalid.configuration"
          : "resource.edit.invalid.configuration"
        return SnackBarMessageEvent.send(.error(displayableString))
      }

      if attachedOTPSlug != currentState.type.specification.slug {
        try self.resourceEditForm.updateType(attachedOTPType)
      }

      await self.navigationToOTPEdit.performCatching(
        context: .init(
          totpPath: totpPath
        )
      )
    }
  }

  @MainActor internal func addPassword() async {
    await consumingErrors {
      let editingContext = try features.context(of: ResourceEditScope.self)
      let isV5Type = editingContext.editedResource.type.specification.slug.isV5Type
      let newResourceSlug: ResourceSpecification.Slug = isV5Type ? .v5DefaultWithTOTP : .passwordWithTOTP
      guard
        editingContext.editedResource.type.specification.slug.isStandaloneTOTPType,
        let newType: ResourceType = editingContext.availableTypes.first(
          where: {
            $0.specification.slug == newResourceSlug
          })
      else {
        let displayableString: DisplayableString =
          editingContext.editedResource.isLocal
          ? "resource.create.invalid.configuration"
          : "resource.edit.invalid.configuration"
        return SnackBarMessageEvent.send(.error(displayableString))
      }

      let onFormDiscarded: @Sendable () async throws -> Void = { [resourceEditForm] in
        try resourceEditForm.updateType(editingContext.editedResource.type)
      }
      try self.resourceEditForm.updateType(newType)

      await self.navigationToPasswordEdit.performCatching(
        context: .init(
          onFormDiscarded: onFormDiscarded
        )
      )
    }
  }

  @MainActor internal func editMetadataDescription() async {
    await consumingErrors {
      await self.navigationToTextEdit.performCatching(
        context: .init(
          textPath: \.meta.description,
          title: "resource.edit.section.metadata.description",
          fieldName: "resource.edit.section.metadata.description.name",
          description: "resource.edit.section.metadata.description.description",
          action: nil
        )
      )
    }
  }

  @MainActor internal func editAdditionalURIs() async {
    await consumingErrors {
      await self.navigationToURIEdit.performCatching()
    }
  }

  @MainActor internal func editNote() async {
    await consumingErrors {
      let currentState = try await self.resourceEditForm.state.value
      let editingContext = try features.context(of: ResourceEditScope.self)
      let newResourceSlug = editingContext.editedResource.type.slugByAttachingNote()

      if newResourceSlug != currentState.type.specification.slug {
        guard
          let newType: ResourceType = editingContext.availableTypes.first(
            where: {
              $0.specification.slug == newResourceSlug
            })
        else {
          let displayableString: DisplayableString =
            editingContext.editedResource.isLocal
            ? "resource.create.invalid.configuration"
            : "resource.edit.invalid.configuration"
          return SnackBarMessageEvent.send(.error(displayableString))
        }
        try self.resourceEditForm.updateType(newType)
      }

      await self.navigationToTextEdit.performCatching(
        context: .init(
          textPath: \.secret.description,
          title: "resource.edit.field.add.note",
          fieldName: "resource.edit.note.content.title",
          description: "resource.edit.note.content.disclaimer",
          action: .init(
            title: "resource.edit.note.remove.button.title",
            icon: .trash,
            action: removeNote
          )
        )
      )
    }
  }

  private func removeNote() async throws {
    let editingContext: ResourceEditingContext = try features.context(of: ResourceEditScope.self)
    let resource: Resource = try await self.resourceEditForm.state.value

    if let newResourceTypeSlug = resource.type.slugByRemovingNote(),
      resource.firstTOTP.secret_key.stringValue?.isEmpty == true,
      let newResourceType = editingContext.availableTypes.first(
        where: {
          $0.specification.slug == newResourceTypeSlug
        })
    {
      try self.resourceEditForm.updateType(newResourceType)
    }

    self.resourceEditForm.update(
      \.secret.description,
      to: .null
    )
    try await navigationToTextEdit.revert()
  }

  @MainActor internal func navigateToOTPAdvancedSettings() async {
    await consumingErrors {
      let editingContext: ResourceEditingContext = try features.context(of: ResourceEditScope.self)
      let resourceType: ResourceType = editingContext.editedResource.type
      guard resourceType.specification.slug.isStandaloneTOTPType,
        let totpPath: ResourceType.FieldPath = resourceType.fieldSpecification(for: \.firstTOTP)?.path
      else {
        return
      }

      try await self.navigationToOTPAdvanced.perform(context: .init(totpPath: totpPath))
    }
  }
}

@MainActor internal func prepareMainFormViewModel(
  for resource: Resource,
  edited: Set<ResourceType.FieldPath>,
  countEntropy: (String) -> Entropy
) -> MainFormViewModel {
  guard resource.type.specification.slug != .placeholder
  else {
    return .empty
  }
  let isStandaloneTOTP: Bool = resource.isStandaloneTOTPResource

  var fields: Array<ResourceEditFieldViewModel> =
    resource
    .fields
    .filter { $0.name != .name && $0.name != .description && $0.name != .note }
    .compactMap { (field: ResourceFieldSpecification) -> ResourceEditFieldViewModel? in
      .init(
        field,
        in: resource,
        edited: edited.contains(field.path),
        countEntropy: countEntropy
      )
    }

  if isStandaloneTOTP,
    let secretFieldSpec = resource.type.fieldSpecification(for: \.secret.totp.secret_key)
  {
    let secretField: ResourceEditFieldViewModel? = .init(
      secretFieldSpec,
      in: resource,
      edited: edited.contains(secretFieldSpec.path),
      countEntropy: countEntropy
    )
    if let secretField {
      fields.append(secretField)
    }
  }

  var result: IdentifiedArray<ResourceEditFieldViewModel> = .init()
  for field: ResourceEditFieldViewModel in fields {
    result[field.path] = field
  }

  let title: DisplayableString =
    isStandaloneTOTP
    ? "resource.edit.section.totp.title"
    : "resource.edit.section.password.title"

  let additionalOptions: Array<MainFormViewModel.AdditionalOption> =
    isStandaloneTOTP
    ? [.addPassword, .addNote]
    : [.addTOTP, .addNote]

  return .init(
    title: title,
    fields: result,
    additionalOptions: additionalOptions
  )
}

internal struct MainFormViewModel: Equatable {

  internal static let empty: MainFormViewModel = .init(
    title: "",
    fields: .init(),
    additionalOptions: .init()
  )

  internal var title: DisplayableString
  internal var fields: IdentifiedArray<ResourceEditFieldViewModel>
  internal var additionalOptions: Array<AdditionalOption>
  internal var metadataOptions: Array<MetadataOption> {
    [
      .editDescription,
      .addtionalURIs,
    ]
  }

  fileprivate init(
    title: DisplayableString,
    fields: IdentifiedArray<ResourceEditFieldViewModel>,
    additionalOptions: Array<AdditionalOption>
  ) {
    self.title = title
    self.fields = fields
    self.additionalOptions = additionalOptions
  }

  internal enum AdditionalOption: Identifiable, Equatable {
    internal var id: Self { self }

    case addTOTP
    case addNote
    case addPassword

    internal var title: DisplayableString {
      switch self {
      case .addTOTP:
        return "resource.edit.field.add.totp"
      case .addNote:
        return "resource.edit.field.add.note"
      case .addPassword:
        return "resource.edit.field.add.password"
      }
    }
  }

  internal enum MetadataOption: Identifiable, Equatable {
    internal var id: Self { self }

    case editDescription
    case addtionalURIs

    internal var title: DisplayableString {
      switch self {
      case .editDescription:
        return "resource.edit.section.metadata.description"
      case .addtionalURIs:
        return "resource.edit.section.metadata.additional.uris"
      }
    }
  }
}

internal struct ResourceEditFieldViewModel {

  internal enum Value: Equatable {

    internal static func == (
      _ lhs: ResourceEditFieldViewModel.Value,
      _ rhs: ResourceEditFieldViewModel.Value
    ) -> Bool {
      switch (lhs, rhs) {
      case (.plainShort(let lString), .plainShort(let rString)):
        return lString == rString

      case (.plainLong(let lString), .plainLong(let rString)):
        return lString == rString

      case (.selection(let lString, let lValues), .selection(let rString, let rValues)):
        return lString == rString
          && lValues == rValues

      case (.password(let lString, _), .password(let rString, _)):
        // skipping entropy, it is derived from string
        return lString == rString

      case _:
        return false
      }
    }

    case plainShort(Validated<String>)
    case plainLong(Validated<String>)
    case password(
      Validated<String>,
      entropy: Entropy
    )
    case selection(
      Validated<String>,
      values: Array<String>
    )
    case list(
      [Validated<String>]
    )
    case totpSecret(Validated<String>)
  }

  internal var path: ResourceType.FieldPath
  internal var name: DisplayableString
  internal var requiredMark: Bool
  internal var encryptedMark: Bool?
  internal var value: Value
  internal var placeholder: DisplayableString

  internal init?(
    _ field: ResourceFieldSpecification,
    in resource: Resource,
    edited: Bool,
    countEntropy: (String) -> Entropy
  ) {
    assert(
      resource.type.specification.slug != .placeholder,
      "Can't prepare fields for placeholder resources"
    )
    self.path = field.path
    self.requiredMark = field.required

    switch field.semantics {
    case .text(let name, _, let placeholder), .intValue(let name, _, let placeholder),
      .floatValue(let name, _, let placeholder):
      self.name = name
      self.encryptedMark = .none  // we are not showing those currently
      self.placeholder = placeholder

      let validated: Validated<String> =
        edited
        ? resource
          .validated(field.path)
          .map { $0.stringValue ?? "" }
        : .valid(resource[keyPath: field.path].stringValue ?? "")

      if field.name == .totpSecretKey {
        self.value = .totpSecret(validated)
      }
      else {
        self.value = .plainShort(validated)
      }

    case .longText(let name, _, let placeholder):
      self.name = name
      self.encryptedMark =
        (  // we are only showing mark for description field
          field.path == \.secret.description
          || field.path == \.meta.description)
        ? field.encrypted
        : .none
      self.placeholder = placeholder

      let validated: Validated<String> =
        edited
        ? resource
          .validated(field.path)
          .map { $0.stringValue ?? "" }
        : .valid(resource[keyPath: field.path].stringValue ?? "")

      self.value = .plainLong(validated)

    case .password(let name, _, let placeholder):
      self.name = name
      self.encryptedMark = .none  // we are not showing those for passwords
      self.placeholder = placeholder

      let validated: Validated<String> =
        edited
        ? resource
          .validated(field.path)
          .map { $0.stringValue ?? "" }
        : .valid(resource[keyPath: field.path].stringValue ?? "")

      self.value = .password(
        validated,
        entropy: countEntropy(validated.value)
      )

    case .selection(let name, let values, _, let placeholder):
      self.name = name
      self.encryptedMark = .none  // we are not showing those currently
      self.placeholder = placeholder

      let validated: Validated<String> =
        edited
        ? resource
          .validated(field.path)
          .map { $0.stringValue ?? "" }
        : .valid(resource[keyPath: field.path].stringValue ?? "")

      self.value = .selection(
        validated,
        values: values
      )
    case .list(let name, _, let placeholder):
      self.name = name
      self.encryptedMark = .none  // we are not showing those currently
      self.placeholder = placeholder
      let validated: Validated<String> =
        edited
        ? resource
          .validated(field.path)
          .map { ($0.arrayValue ?? []).first?.stringValue ?? "" }
        : .valid(resource[keyPath: field.path].arrayValue?.first?.stringValue ?? "")
      self.value = .plainShort(validated)
    case .totp:
      return nil  // we are not allowing editing totp here unfortunately

    case .undefined:
      return nil
    }
  }

  internal var validatedString: Validated<String> {
    get {
      switch self.value {
      case .plainShort(let value):
        return value

      case .plainLong(let value):
        return value

      case .password(let value, entropy: _):
        return value

      case .selection(let value, values: _):
        return value
      case .list(let values):
        return values.first ?? .valid("")
      case .totpSecret(let value):
        return value
      }
    }
    set {
      switch self.value {
      case .plainShort:
        self.value = .plainShort(newValue)

      case .plainLong:
        self.value = .plainLong(newValue)

      case .password(_, let entropy):
        self.value = .password(newValue, entropy: entropy)

      case .selection(_, let values):
        self.value = .selection(newValue, values: values)
      case .list(let values):
        self.value = .list(values)
      case .totpSecret:
        self.value = .totpSecret(newValue)
      }
    }
  }
}

extension ResourceEditFieldViewModel: Equatable {}

extension ResourceEditFieldViewModel: Identifiable {

  internal var id: ResourceType.FieldPath { self.path }
}
