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
import Resources

@MainActor
public final class ResourcePasswordEditViewController: ViewController {
  public struct Context {
    internal var onFormDiscarded: @Sendable () async throws -> Void

    public init(
      onFormDiscarded: @escaping @Sendable () async throws -> Void
    ) {
      self.onFormDiscarded = onFormDiscarded
    }
  }

  public struct ViewState: Equatable {
    internal var fields: IdentifiedArray<ResourceEditFieldViewModel>
  }

  private struct LocalState: Equatable {

    fileprivate var editedFields: Set<ResourceType.FieldPath>
  }

  private let resourceEditForm: ResourceEditForm
  private let randomGenerator: RandomStringGenerator
  private let navigationToSelf: NavigationToResourcePasswordEdit

  public nonisolated let viewState: ViewStateSource<ViewState>
  private let context: Context
  private let editingContext: ResourceEditingContext
  private let localState: Variable<LocalState>

  public init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.context = context

    let randomGenerator: RandomStringGenerator = try features.instance()
    self.randomGenerator = randomGenerator

    self.navigationToSelf = try features.instance()
    self.resourceEditForm = try features.instance()
    self.editingContext = try features.context(of: ResourceEditScope.self)
    self.localState = .init(initial: .init(editedFields: .init()))
    self.viewState = .init(
      initial: .init(
        fields: .init()
      ),
      updateFrom: ComputedVariable(
        combined: self.resourceEditForm.state,
        with: self.localState
      ),
      update: {
        @MainActor (updateState, update: Update<(Resource, LocalState)>) async throws -> Void in
        let update: (resource: Resource, localState: LocalState) = try update.value
        assert(update.resource.secretAvailable, "Can't edit resource without secret!")

        let countEntropy: (String) -> Entropy = { [randomGenerator] (input: String) -> Entropy in
          randomGenerator.entropy(input, CharacterSets.all)
        }

        let fields: IdentifiedArray<ResourceEditFieldViewModel> = fields(
          for: update.resource,
          edited: update.localState.editedFields,
          countEntropy: countEntropy
        )
        updateState { (viewState: inout ViewState) in
          viewState.fields = fields
        }
      }
    )
  }

  internal func apply() async {
    await consumingErrors {
      try await navigationToSelf.revert()
    }
  }

  internal func discardForm() async {
    await consumingErrors {
      try await navigationToSelf.revert()
      try await context.onFormDiscarded()
    }
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
}
@MainActor private func fields(
  for resource: Resource,
  edited: Set<ResourceType.FieldPath>,
  countEntropy: (String) -> Entropy
) -> IdentifiedArray<ResourceEditFieldViewModel> {
  if resource.type.specification.slug == .placeholder {
    return .init()  // show no fields for placeholder type
  }
  else {
    let excludedFields: Set<ResourceFieldName> = [
      .name,
      .description,
      .customFields,
      .allURIs,
    ]
    let fields: Array<ResourceEditFieldViewModel> =
      resource
      .fields
      .filter { excludedFields.contains($0.name) == false }
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
