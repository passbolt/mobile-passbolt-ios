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
public final class ResourceURIEditViewController: ViewController {
  /// This limit is limited by the server. Subject to change.
  private nonisolated static let additionalURIsLimit: Int = 20

  public struct ViewState: Equatable {
    internal var mainURI: Validated<String>
    internal var additionalURIs: IdentifiedArray<IdentifiedURI> = .init()

    struct IdentifiedURI: Identifiable, Equatable {
      let id: UUID = .init()
      var uri: Validated<String>

      mutating func updateURI(_ uri: String) {
        self.uri = .valid(uri)
      }
    }
  }

  public nonisolated let viewState: ViewStateSource<ViewState>
  internal let editsExisting: Bool

  private let resourceEditForm: ResourceEditForm
  private let navigationToSelf: NavigationToResourceURIEdit

  public init(
    context _: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.navigationToSelf = try features.instance()
    self.resourceEditForm = try features.instance()
    let editingContext: ResourceEditingContext = try features.context(of: ResourceEditScope.self)
    self.editsExisting = editingContext.editedResource.isLocal

    self.viewState = .init(
      initial: .init(
        mainURI: .valid(""),
        additionalURIs: .init()
      ),
      updateFrom: self.resourceEditForm.state,
      update: { (updateState, update: Update<Resource>) async in
        do {
          let resource: Resource = try update.value

          updateState { (viewState: inout ViewState) in
            guard let uris: [JSON] = resource.meta.uris.arrayValue
            else {
              return
            }
            viewState.mainURI = .valid(uris.first?.stringValue ?? "")
            viewState.additionalURIs = .init()
            for uri in uris.dropFirst() {
              let identifiedURI: ViewState.IdentifiedURI = .init(
                uri: .valid(uri.stringValue ?? "")
              )
              viewState.additionalURIs[identifiedURI.id] = identifiedURI
            }

          }
        }
        catch {
          SnackBarMessageEvent.send(.error(error))
        }
      }
    )
  }

  internal func addURI() async {
    let limit: Int = Self.additionalURIsLimit
    let currentState: ViewState = await self.viewState.current
    if currentState.additionalURIs.count >= limit {
      SnackBarMessageEvent.send(
        .error(
          .localized(
            key: "resource.edit.uris.additional.uris.error.limit",
            arguments: [limit]
          )
        )
      )
      return
    }
    self.viewState.update { (viewState: inout ViewState) in
      let newURI: ViewState.IdentifiedURI = .init(
        uri: .valid("")
      )
      viewState.additionalURIs[newURI.id] = newURI
    }
  }

  internal func removeURI(withId: ViewState.IdentifiedURI.ID) {
    self.viewState.update { (viewState: inout ViewState) in
      viewState.additionalURIs[withId] = nil
    }
  }

  internal func setMainURI(_ uri: String) {
    self.viewState.update { (viewState: inout ViewState) in
      viewState.mainURI = .valid(uri)
    }
  }

  internal func set(_ uri: String, for id: ViewState.IdentifiedURI.ID) {
    self.viewState.update { (viewState: inout ViewState) in
      viewState.additionalURIs[id]?.updateURI(uri)
    }
  }

  internal func apply() async {
    await consumingErrors {
      let viewState: ViewState = await self.viewState.current
      let uris: Array<String> =
        [
          viewState.mainURI.value
        ] + viewState.additionalURIs.map { $0.uri.value }

      self.resourceEditForm.update(
        \.meta.uris,
        to: .array(uris.map { .string($0) })
      )

      try await navigationToSelf.revert()
    }
  }

  internal func discardForm() async {
    await consumingErrors {
      try await navigationToSelf.revert()
    }
  }
}
