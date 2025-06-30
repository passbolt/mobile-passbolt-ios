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

import SwiftUI

public struct FolderLocationTreeView: View {

  private let node: Node
  @State private var expanded: Bool = true

  public init(
    location locationNode: Node
  ) {
    self.node = locationNode
  }

  public var body: some View {
    DisclosureGroup(
      isExpanded: self.$expanded,
      content: {
        if let child: Node = self.node.child {
          if case .some = child.child {
            FolderLocationTreeView(location: child)
              .padding(leading: 8)  // indent next level
          }
          else {  // leaf can't be expanded
            self.labelView(for: child)
              .padding(
                top: 8,
                leading: 8,  // indent next level
                bottom: 8
              )
          }
        }  // else nothing
      },
      label: {
        self.labelView(for: self.node)
          .padding(
            top: 8,
            bottom: 8
          )
      }
    )

  }

  @ViewBuilder private func labelView(
    for node: Node
  ) -> some View {
    HStack(spacing: 4) {
      if case .leaf(_, _, let icon, let slug) = node {
        ResourceIconView(resourceIcon: icon, resourceTypeSlug: slug)
          .frame(width: 40)
      }
      else {
        Image(
          named: node.shared
            ? .sharedFolderIcon
            : .folderIcon
        )
        .resizable()
        .aspectRatio(1, contentMode: .fit)
        .frame(width: 40)
      }

      Text(
        node.name
          ?? DisplayableString
          .localized(key: "folder.root.name")
          .string()
      )
      .font(
        .inter(
          ofSize: 14,
          weight: .semibold
        )
      )
      .foregroundColor(.passboltPrimaryText)
      .multilineTextAlignment(.leading)
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
      .padding(leading: 8)
    }
  }
}

extension FolderLocationTreeView {

  public indirect enum Node: Hashable, Identifiable {

    case root(child: Node? = .none)
    case node(
      id: ResourceFolder.ID,
      name: String,
      shared: Bool,
      child: Node? = .none
    )
    case leaf(
      id: Resource.ID?,
      name: String,
      icon: ResourceIcon,
      resourceTypeSlug: ResourceSpecification.Slug?
    )

    public var id: AnyHashable {
      switch self {
      case .root:
        return Optional<ResourceFolder.ID>.none

      case .node(let id, _, _, _):
        return id

      case .leaf(let id, _, _, _):
        return id
      }
    }

    public var name: String? {
      switch self {
      case .root:
        return .none

      case .node(_, let name, _, _):
        return name

      case .leaf(_, let name, _, _):
        return name
      }
    }

    public var shared: Bool {
      switch self {
      case .root:
        return false

      case .node(_, _, let shared, _):
        return shared

      case .leaf:
        return false  // ??
      }
    }

    public var child: Node? {
      switch self {
      case .root(let child):
        return child

      case .node(_, _, _, let child):
        return child

      case .leaf:
        return .none
      }
    }

    public mutating func append(
      child newValue: Node
    ) {
      switch self {
      case .root(.none):
        self = .root(child: newValue)

      case .root(.some(var child)):
        child.append(child: newValue)
        self = .root(child: child)

      case .node(let id, let name, let shared, .none):
        self = .node(
          id: id,
          name: name,
          shared: shared,
          child: newValue
        )

      case .node(let id, let name, let shared, .some(var child)):
        child.append(child: newValue)
        self = .node(
          id: id,
          name: name,
          shared: shared,
          child: child
        )

      case .leaf:
        assertionFailure("Can't add child to the leaf!")
      }
    }
  }
}
