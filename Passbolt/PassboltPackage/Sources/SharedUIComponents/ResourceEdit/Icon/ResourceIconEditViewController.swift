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
public final class ResourceIconEditViewController: ViewController {

  public struct ViewState: Equatable {
    internal var selectedColorHex: Color.Hex?
    internal var defaultColorSelected: Bool { selectedColorHex == nil }

    internal var availableColors: [Color.Hex] {
      [
        "#00000000",
        "#DFDFDF",
        "#888888",
        "#575757",
        "#9C6A55",
        "#E64626",
        "#F07438",
        "#F5AA48",
        "#FFE144",
        "#B1D86A",
        "#3D9B5E",
        "#A0DAE3",
        "#4A75DF",
        "#AC8CFB",
        "#E88BA8",
      ]
    }

    internal var selectedIcon: ResourceIcon.IconIdentifier?
    internal var defautlIconSelected: Bool { selectedIcon == nil }
    internal var availableIcons: [ResourceIcon.IconIdentifier] {
      ResourceIcon.IconType.keepassIconSet.availableIdentifiers
    }
  }

  public nonisolated let viewState: ViewStateSource<ViewState>
  internal let editsExisting: Bool
  internal var currentIconURL: URL? {
    nil
  }

  private let resourceEditForm: ResourceEditForm
  private let navigationToSelf: NavigationToResourceIconEdit

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
        selectedColorHex: nil,
        selectedIcon: nil
      ),
      updateFrom: self.resourceEditForm.state,
      update: { (updateState, update: Update<Resource>) async in
        do {
          let resource: Resource = try update.value

          updateState { (viewState: inout ViewState) in
            viewState.selectedColorHex = resource.icon.backgroundColor.flatMap { Color.Hex(rawValue: $0) }
            viewState.selectedIcon = resource.icon.value
          }
        }
        catch {
          SnackBarMessageEvent.send(.error(error))
        }
      }
    )
  }

  internal func update(color: Color.Hex?) {
    self.viewState.update { (viewState: inout ViewState) in
      viewState.selectedColorHex = color
    }
  }

  internal func update(icon: ResourceIcon.IconIdentifier?) {
    self.viewState.update { (viewState: inout ViewState) in
      viewState.selectedIcon = icon
    }
  }

  internal func apply() async {
    await consumingErrors {
      let viewState: ViewState = await self.viewState.current
      let icon: ResourceIcon = .init(
        type: .keepassIconSet,
        value: viewState.selectedIcon,
        backgroundColor: viewState.selectedColorHex?.rawValue
      )
      self.resourceEditForm.update(
        \.meta.icon,
        to: icon.json
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
