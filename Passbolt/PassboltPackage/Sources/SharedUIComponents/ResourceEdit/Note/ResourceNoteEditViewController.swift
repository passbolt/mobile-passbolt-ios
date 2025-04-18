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
public final class ResourceNoteEditViewController: ViewController {
  public struct Context {
    internal var onFormDiscarded: @Sendable () async throws -> Void

    public init(
      onFormDiscarded: @escaping @Sendable () async throws -> Void
    ) {
      self.onFormDiscarded = onFormDiscarded
    }
  }

  public struct ViewState: Equatable {
    internal var note: Validated<String>
  }

  private let resourceEditForm: ResourceEditForm

  private let navigationToSelf: NavigationToResourceNoteEdit

  public nonisolated let viewState: ViewStateSource<ViewState>
  private let context: Context
  private let editingContext: ResourceEditingContext

  public init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.context = context

    self.navigationToSelf = try features.instance()
    self.resourceEditForm = try features.instance()
    self.editingContext = try features.context(of: ResourceEditScope.self)
    self.viewState = .init(
      initial: .init(
        note: .valid(editingContext.editedResource.secret.description.stringValue ?? "")
      )
    )
  }

  internal func update(_ note: String) {
    viewState.update(\.note, to: .valid(note))
  }

  internal func apply() async {
    await consumingErrors {
      await self.resourceEditForm.update(
        \.secret.description,
        to: viewState.current.note.value
      )
      try await navigationToSelf.revert()
    }
  }

  internal func discardForm() async {
    await consumingErrors {
      try await navigationToSelf.revert()
      try await context.onFormDiscarded()
    }
  }

  internal func removeNote() async {
    await consumingErrors {
      let currentType = self.editingContext.editedResource.type
      guard
        let newResourceTypeSlug = currentType.slugByRemovingNote(),
        let newResourceType = self.editingContext.availableTypes.first(
          where: {
            $0.specification.slug == newResourceTypeSlug
          })
      else {
        return SnackBarMessageEvent.send(.error("resource.edit.invalid.configuration"))
      }
      try self.resourceEditForm.updateType(newResourceType)
      self.resourceEditForm.update(
        \.secret.description,
        to: .null
      )
      try await navigationToSelf.revert()
    }
  }
}
