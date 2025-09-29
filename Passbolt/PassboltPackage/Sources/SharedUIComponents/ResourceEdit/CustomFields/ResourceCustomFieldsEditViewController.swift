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
public final class ResourceCustomFieldsEditViewController: ViewController {

  public struct ViewState: Equatable {

    internal var customFields: Array<CustomFieldModel> = .init()
  }

  public nonisolated let viewState: ViewStateSource<ViewState>
  internal let editsExisting: Bool

  private let resourceEditForm: ResourceEditForm
  private let navigationToSelf: NavigationToResourceCustomFieldsEdit

  public init(
    context _: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.navigationToSelf = try features.instance()
    self.resourceEditForm = try features.instance()
    let editingContext: ResourceEditingContext = try features.context(of: ResourceEditScope.self)
    self.editsExisting = !editingContext.editedResource.isLocal

    self.viewState = .init(
      initial: .init(
        customFields: .init()
      ),
      updateFrom: self.resourceEditForm.state,
      update: { (updateState, update: Update<Resource>) async in
        do {
          let resource: Resource = try update.value

          updateState { (viewState: inout ViewState) in
            let metaCustmoFields: Array<ResourceCustomFieldDTO> = resource.meta.custom_fields.customFieldDTOs ?? .init()
            let secretCustomFields: Array<ResourceCustomFieldDTO> =
              resource.secret.custom_fields.customFieldDTOs ?? .init()
            let combinedCustomFields: Array<ResourceCustomFieldDTO> =
              metaCustmoFields.combined(with: secretCustomFields)
            var customFieldModels: Array<CustomFieldModel> = .init()
            for customField in combinedCustomFields {
              guard let key = customField.key else {
                continue
              }
              let value: CustomFieldModel.Value = customField.value.flatMap { .valid($0) } ?? .invalid
              let model: CustomFieldModel = .init(
                id: customField.id,
                name: key,
                value: value
              )
              customFieldModels.append(model)
            }
            viewState.customFields = customFieldModels
          }
        }
        catch {
          SnackBarMessageEvent.send(.error(error))
        }
      }
    )
  }

  internal func discardForm() async {
    await consumingErrors {
      try await navigationToSelf.revert()
    }
  }
}

internal struct CustomFieldModel: Equatable, Identifiable {
  internal let id: ResourceCustomFieldDTO.ID
  internal let name: String
  internal let value: Value

  internal init(id: ResourceCustomFieldDTO.ID, name: String, value: Value) {
    self.id = id
    self.name = name
    self.value = value
  }

  internal enum Value: Equatable {
    case valid(String)
    case invalid
  }
}
