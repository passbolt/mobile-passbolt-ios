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
import Resources

@MainActor
public final class ResourceTextEditViewController: ViewController {

  public struct Context {
    public let textPath: Resource.FieldPath
    public let title: DisplayableString
    public let fieldName: DisplayableString
    public let description: DisplayableString
    public let action: Action?

    public struct Action {
      public let title: DisplayableString
      public let icon: ImageNameConstant
      public let action: () async throws -> Void
    }
  }
  private struct LocalState: Equatable {

    fileprivate var editedFields: Set<Resource.FieldPath>
  }

  public struct ViewState: Equatable {
    internal var text: Validated<String>
    internal var title: DisplayableString
    internal var fieldName: DisplayableString
    internal var description: DisplayableString
    internal var showAction: Bool {
      action != nil
    }
    internal var action: Action?
    fileprivate var initialText: JSON

    struct Action: Equatable {
      let title: DisplayableString
      let icon: ImageNameConstant
    }
  }

  private let resourceEditForm: ResourceEditForm

  private let navigationToSelf: NavigationToResourceTextEdit

  public nonisolated let viewState: ViewStateSource<ViewState>

  private let editingContext: ResourceEditingContext
  private let localState: Variable<LocalState>
  private let context: Context

  public init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.navigationToSelf = try features.instance()
    self.resourceEditForm = try features.instance()
    self.editingContext = try features.context(of: ResourceEditScope.self)
    self.context = context
    self.localState = .init(
      initial: .init(
        editedFields: .init()
      )
    )
    self.viewState = .init(
      initial: .init(
        text: .valid(""),
        title: context.title,
        fieldName: context.fieldName,
        description: context.description,
        action: context.action.map {
          .init(
            title: $0.title,
            icon: $0.icon
          )
        },
        initialText: .null
      ),
      updateFrom: ComputedVariable(
        combined: self.resourceEditForm.state,
        with: self.localState
      ),
      update: { [context] (updateState, update: Update<(Resource, LocalState)>) async in
        do {
          let resource: Resource = try update.value.0
          let localState: LocalState = try update.value.1

          updateState { (viewState: inout ViewState) in
            if localState.editedFields.contains(context.textPath) {
              viewState.text =
                resource
                .validated(context.textPath)
                .map { $0.stringValue ?? "" }
            }
            else {
              viewState.text =
                .valid(resource[keyPath: context.textPath].stringValue ?? "")
              viewState.initialText = resource[keyPath: context.textPath]
            }
          }
        }
        catch {
          SnackBarMessageEvent.send(.error(error))
        }
      }
    )
  }

  internal func update(_ text: String) {
    self.resourceEditForm
      .update(context.textPath, to: text)
    self.localState.mutate { (state: inout LocalState) in
      state.editedFields.insert(context.textPath)
    }
  }

  internal func apply() async {
    await self.resourceEditForm.update(
      context.textPath,
      to: viewState.current.text.value
    )
    do {
      try await self.resourceEditForm.validateField(context.textPath)
      try await navigationToSelf.revert()
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
    }
  }

  internal func discardForm() async {
    await consumingErrors {
      try await navigationToSelf.revert()
      await resourceEditForm.update(context.textPath, to: self.viewState.current.initialText)
    }
  }

  internal func executeAction() async {
    await consumingErrors {
      try await self.context.action?.action()
    }
  }
}
