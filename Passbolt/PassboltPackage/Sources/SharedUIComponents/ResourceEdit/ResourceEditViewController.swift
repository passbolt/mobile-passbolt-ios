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

    public init(
      editingContext: ResourceEditingContext,
      success: @escaping @Sendable (Resource) async -> Void = { _ in }
    ) {
      self.editingContext = editingContext
      self.success = success
    }
  }

  public struct ViewState: Equatable {

    internal var fields: IdentifiedArray<ResourceEditFieldViewModel>
    internal var containsUndefinedFields: Bool
    internal var edited: Bool
  }

  public let viewState: ViewStateSource<ViewState>

  internal let editsExisting: Bool

  private struct LocalState: Equatable {

    fileprivate var editedFields: Set<ResourceType.FieldPath>
  }

  private let localState: Variable<LocalState>

  private let allFields: Set<ResourceType.FieldPath>

  private let resourceEditForm: ResourceEditForm

  private let navigationToSelf: NavigationToResourceEdit

  private let randomGenerator: RandomStringGenerator

  private let success: @Sendable (Resource) async -> Void

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

    let randomGenerator: RandomStringGenerator = try features.instance()
    self.randomGenerator = randomGenerator

    if isInExtensionContext {
      // TODO: unify navigation between app and extnsion
      self.navigationToSelf = .placeholder
    }
    else {
      self.navigationToSelf = try features.instance()
    }

    self.resourceEditForm = try features.instance()

    self.editsExisting = !context.editingContext.editedResource.isLocal
    self.allFields = Set(context.editingContext.editedResource.fields.map(\.path))

    self.localState = .init(
      initial: .init(
        editedFields: .init()
      )
    )
    self.viewState = .init(
      initial: .init(
        fields: .init(),
        containsUndefinedFields: false,
        edited: false
      ),
      updateFrom: ComputedVariable(
        combined: self.resourceEditForm.state,
        with: self.localState
      ),
      update: { @MainActor (updateState, update: Update<(Resource, LocalState)>) async throws -> Void in
        let update: (resource: Resource, localState: LocalState) = try update.value
        assert(update.resource.secretAvailable, "Can't edit resource without secret!")
        let fields = fields(
          for: update.resource,
          using: features,
          edited: update.localState.editedFields,
          countEntropy: { [randomGenerator] (input: String) -> Entropy in
            randomGenerator.entropy(input, CharacterSets.all)
          }
        )
        updateState { (viewState: inout ViewState) in
          viewState.fields = fields
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
        // TODO: unify navigation between app and extnsion
        try await self.navigationToSelf.revert()
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
}

@MainActor private func fields(
  for resource: Resource,
  using features: Features,
  edited: Set<ResourceType.FieldPath>,
  countEntropy: (String) -> Entropy
) -> IdentifiedArray<ResourceEditFieldViewModel> {
  if resource.type.specification.slug == .placeholder {
    return .init()  // show no fields for placeholder type
  }
  else {
    let fields: Array<ResourceEditFieldViewModel> =
      resource
      .fields
      .compactMap { (field: ResourceFieldSpecification) -> ResourceEditFieldViewModel? in
        .init(
          field,
          in: resource,
          edited: edited.contains(field.path),
          countEntropy: countEntropy
        )
      }

    var result: IdentifiedArray<ResourceEditFieldViewModel> = .init()
    for field: ResourceEditFieldViewModel in fields {
      result[field.path] = field
    }
    return result
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

      self.value = .plainShort(validated)

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
      let currentValue = resource
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
      }
    }
  }
}

extension ResourceEditFieldViewModel: Equatable {}

extension ResourceEditFieldViewModel: Identifiable {

  internal var id: ResourceType.FieldPath { self.path }
}
