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

import Crypto
import Display
import FeatureScopes
import OSFeatures
import Resources

import struct OrderedCollections.OrderedDictionary

public final class ResourceEditViewController: ViewController {

  public struct Context {

    public var editingContext: ResourceEditingContext
    public var success: @Sendable (Resource) -> Void

    public init(
      editingContext: ResourceEditingContext,
      success: @escaping @Sendable (Resource) -> Void
    ) {
      self.editingContext = editingContext
      self.success = success
    }
  }

  public struct ViewState: Equatable {

    internal var fields: OrderedDictionary<Resource.FieldPath, ResourceEditFieldViewModel>
    internal var containsUndefinedFields: Bool
  }

  public let viewState: ComputedViewState<ViewState>
  internal let discardFormAlertVisible: ViewStateVariable<Bool>
  internal let snackBarMessage: ViewStateVariable<SnackBarMessage?>
  internal let editsExisting: Bool

  private let resourceEditForm: ResourceEditForm

  private let navigationToSelf: NavigationToResourceEdit

  private let randomGenerator: RandomStringGenerator
  private let asyncExecutor: AsyncExecutor
  private let diagnostics: OSDiagnostics

  private let success: @Sendable (Resource) -> Void

  private let features: Features

  public init(
    context: Context,
    features: Features
  ) throws {
    let features: Features = features.branch(
      scope: ResourceEditScope.self,
      context: context.editingContext
    )
    self.features = features  // keep the branch alive

    self.success = context.success

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
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

    self.editsExisting = context.editingContext.editedResource.isLocal

    self.viewState = .init(
      initial: .init(
        fields: .init(),
        containsUndefinedFields: false
      ),
      from: self.resourceEditForm.state,
      transform: { (resource: Resource) in
        assert(resource.secretAvailable, "Can't edit resource without secret!")

        return .init(
          fields: fields(
            for: resource,
            using: features,
            countEntropy: { [randomGenerator] (input: String) -> Entropy in
              randomGenerator.entropy(input, CharacterSets.all)
            }
          ),
          containsUndefinedFields: resource.containsUndefinedFields
        )
      }
    )

    self.discardFormAlertVisible = .init(initial: false)
    self.snackBarMessage = .init(initial: .none)
  }

  @MainActor internal func set(
    _ value: String,
    for field: Resource.FieldPath
  ) {
    self.resourceEditForm.update(field, to: value)
  }

  @MainActor internal func generatePassword(
    for field: Resource.FieldPath
  ) {
    let generated: String = self.randomGenerator.generate(
      CharacterSets.all,
      18,
      Entropy.veryStrongPassword
    )
    self.resourceEditForm.update(field, to: generated)
  }

  @MainActor internal func sendForm() async {
    await self.diagnostics.withLogCatch(
      info: .message("Failed to send resource edit form!"),
      fallback: { [snackBarMessage] error in
        snackBarMessage.update(\.self, to: .error(error))
      }
    ) {
      self.discardFormAlertVisible.update(\.self, to: false)
      let resource: Resource = try await self.resourceEditForm.sendForm()
      if !isInExtensionContext {
        // TODO: unify navigation between app and extnsion
        try await self.navigationToSelf.revert()
      }  // else NOP
      self.success(resource)
    }
  }

  @MainActor internal func showDiscardFormAlert() {
    self.discardFormAlertVisible.update(\.self, to: true)
  }

  @MainActor internal func discardForm() async {
    await self.diagnostics.withLogCatch(
      info: .message("Failed to discard resource edit form!"),
      fallback: { [snackBarMessage] error in
        snackBarMessage.update(\.self, to: .error(error))
      }
    ) {
      self.discardFormAlertVisible.update(\.self, to: false)
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
  countEntropy: (String) -> Entropy
) -> OrderedDictionary<Resource.FieldPath, ResourceEditFieldViewModel> {
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
          countEntropy: countEntropy
        )
      }

    var result: OrderedDictionary<Resource.FieldPath, ResourceEditFieldViewModel> = .init()
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
  }

  internal var path: Resource.FieldPath
  internal var name: DisplayableString
  internal var requiredMark: Bool
  internal var encryptedMark: Bool?
  internal var value: Value
  internal var placeholder: DisplayableString

  internal init?(
    _ field: ResourceFieldSpecification,
    in resource: Resource,
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
        resource
        .validated(field.path)
        .map { $0.stringValue ?? "" }

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
        resource
        .validated(field.path)
        .map { $0.stringValue ?? "" }

      self.value = .plainLong(validated)

    case .password(let name, _, let placeholder):
      self.name = name
      self.encryptedMark = .none  // we are not showing those for passwords
      self.placeholder = placeholder

      let validated: Validated<String> =
        resource
        .validated(field.path)
        .map { $0.stringValue ?? "" }

      self.value = .password(
        validated,
        entropy: countEntropy(validated.value)
      )

    case .selection(let name, let values, _, let placeholder):
      self.name = name
      self.encryptedMark = .none  // we are not showing those currently
      self.placeholder = placeholder

      let validated: Validated<String> =
        resource
        .validated(field.path)
        .map { $0.stringValue ?? "" }

      self.value = .selection(
        validated,
        values: values
      )

    case .totp:
      return nil  // we are not allowing editing totp here unfortunately

    case .undefined:
      return nil
    }
  }
}

extension ResourceEditFieldViewModel: Equatable {}

extension ResourceEditFieldViewModel: Identifiable {

  internal var id: some Hashable { self.path }
}
