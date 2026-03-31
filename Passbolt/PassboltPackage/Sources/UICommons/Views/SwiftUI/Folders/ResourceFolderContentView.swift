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

import CommonModels
import SwiftUI

// MARK: - Row Data Model
public enum FolderContentRowData: DynamicListItem {

  case addResource
  case sectionHeader(id: String, title: String)
  case divider(id: String)
  case folder(ResourceFolderListItemDSV)
  case resource(ResourceListItemDSV)
  case loadingIndicator
  case emptyState

  public var id: String {
    switch self {
    case .addResource:
      return "add_resource"
    case .sectionHeader(let id, _):
      return "header_\(id)"
    case .divider(let id):
      return "divider_\(id)"
    case .folder(let folder):
      return "folder_\(folder.id.rawValue.rawValue.uuidString)"
    case .resource(let resource):
      return "resource_\(resource.id.rawValue.rawValue.uuidString)"
    case .loadingIndicator:
      return "loading"
    case .emptyState:
      return "empty"
    }
  }

  public var estimatedHeight: CGFloat {
    switch self {
    case .addResource, .folder, .resource:
      return 64
    case .sectionHeader:
      return 24
    case .divider:
      return 16
    case .loadingIndicator:
      return 44
    case .emptyState:
      return 200
    }
  }
}

extension FolderContentRowData: Hashable {

  public static func == (lhs: FolderContentRowData, rhs: FolderContentRowData) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public struct ResourceFolderContentView: View {

  @State var id: IID = .init()
  private let folderName: DisplayableString
  private let isSearchResult: Bool
  private let directFolders: Array<ResourceFolderListItemDSV>
  private let nestedFolders: Array<ResourceFolderListItemDSV>
  private let suggestedResources: Array<ResourceListItemDSV>?
  private let directResources: Array<ResourceListItemDSV>
  private let nestedResources: Array<ResourceListItemDSV>
  private let contentEmpty: Bool
  private let suggestedContentEmpty: Bool
  private let directContentEmpty: Bool
  private let nestedContentEmpty: Bool
  private let hasMoreData: Bool
  private let isLoadingMore: Bool
  private let contentResetToken: Int
  private let refreshAction: @Sendable () async -> Void
  private let loadMoreAction: @Sendable () async -> Void
  private let createAction: (() async throws -> Void)?
  private let folderTapAction: (ResourceFolder.ID) async throws -> Void
  private let resourceTapAction: (Resource.ID) async throws -> Void
  private let resourceMenuAction: ((Resource.ID) async throws -> Void)?

  public init(
    folderName: DisplayableString,
    isSearchResult: Bool,
    directFolders: Array<ResourceFolderListItemDSV>,
    nestedFolders: Array<ResourceFolderListItemDSV>,
    suggestedResources: Array<ResourceListItemDSV>?,
    directResources: Array<ResourceListItemDSV>,
    nestedResources: Array<ResourceListItemDSV>,
    hasMoreData: Bool,
    isLoadingMore: Bool,
    contentResetToken: Int = 0,
    refreshAction: @escaping @Sendable () async -> Void,
    loadMoreAction: @escaping @Sendable () async -> Void,
    createAction: (() async throws -> Void)?,
    folderTapAction: @escaping (ResourceFolder.ID) async throws -> Void,
    resourceTapAction: @escaping (Resource.ID) async throws -> Void,
    resourceMenuAction: ((Resource.ID) async throws -> Void)?
  ) {
    self.folderName = folderName
    self.isSearchResult = isSearchResult
    self.directFolders = directFolders
    self.nestedFolders = nestedFolders
    self.suggestedResources = suggestedResources
    self.directResources = directResources
    self.nestedResources = nestedResources
    self.contentEmpty =
      directFolders.isEmpty
      && directResources.isEmpty
      && (suggestedResources?.isEmpty ?? true)
      && nestedFolders.isEmpty
      && nestedResources.isEmpty
    self.suggestedContentEmpty = (suggestedResources?.isEmpty ?? true)
    self.directContentEmpty =
      directFolders.isEmpty
      && directResources.isEmpty
    self.nestedContentEmpty =
      nestedFolders.isEmpty
      && nestedResources.isEmpty
    self.hasMoreData = hasMoreData
    self.isLoadingMore = isLoadingMore
    self.contentResetToken = contentResetToken
    self.refreshAction = refreshAction
    self.loadMoreAction = loadMoreAction
    self.createAction = createAction
    self.folderTapAction = folderTapAction
    self.resourceTapAction = resourceTapAction
    self.resourceMenuAction = resourceMenuAction
  }

  public var body: some View {
    if self.contentEmpty {
      ScrollView {
        if let createAction: () async throws -> Void = self.createAction {
          ResourceListAddView(action: createAction)
        }
        EmptyListView()
      }
      .refreshable {
        await self.refreshAction()
      }
    }
    else {
      DynamicList(
        items: rowData,
        hasMoreData: hasMoreData,
        isLoadingMore: isLoadingMore,
        onLoadMore: loadMoreAction,
        refreshAction: refreshAction,
        contentResetToken: contentResetToken,
        content: { viewForRow($0) }
      )
    }
  }

  private var rowData: Array<FolderContentRowData> {
    var rows: Array<FolderContentRowData> = []

    if self.createAction != nil {
      rows.append(.addResource)
    }

    if self.isSearchResult {
      // suggested section
      if let suggestedResources: Array<ResourceListItemDSV> = self.suggestedResources, !suggestedResources.isEmpty {
        rows.append(
          .sectionHeader(
            id: "suggested",
            title: DisplayableString.localized("autofill.extension.resource.list.section.suggested.title").string()
          )
        )
        for resource in suggestedResources {
          rows.append(.resource(resource))
        }
      }

      // direct section
      if !self.directContentEmpty {
        if !self.suggestedContentEmpty {
          rows.append(.divider(id: "suggested_direct"))
        }

        rows.append(
          .sectionHeader(
            id: "direct",
            title:
              DisplayableString.localized(
                key: "home.presentation.mode.folders.explorer.search.direct.results",
                arguments: [self.folderName.string()]
              )
              .string()
          )
        )

        for folder in self.directFolders {
          rows.append(.folder(folder))
        }
        for resource in self.directResources {
          rows.append(.resource(resource))
        }
      }

      // nested section
      if !self.nestedContentEmpty {
        if !self.directContentEmpty {
          rows.append(.divider(id: "direct_nested"))
        }

        rows.append(
          .sectionHeader(
            id: "nested",
            title: DisplayableString.localized("home.presentation.mode.folders.explorer.search.nested.results")
              .string()
          )
        )

        for folder in self.nestedFolders {
          rows.append(.folder(folder))
        }
        for resource in self.nestedResources {
          rows.append(.resource(resource))
        }
      }
    }
    else if let suggestedResources: Array<ResourceListItemDSV> = self.suggestedResources,
      !suggestedResources.isEmpty
    {
      // non-search with suggestions (autofill extension)
      rows.append(
        .sectionHeader(
          id: "suggested",
          title: DisplayableString.localized("autofill.extension.resource.list.section.suggested.title").string()
        )
      )
      for resource in suggestedResources {
        rows.append(.resource(resource))
      }

      rows.append(
        .sectionHeader(
          id: "all",
          title: DisplayableString.localized("autofill.extension.resource.list.section.all.title").string()
        )
      )
      for folder in self.directFolders {
        rows.append(.folder(folder))
      }
      for resource in self.directResources {
        rows.append(.resource(resource))
      }
    }
    else {
      // default: direct content only
      for folder in self.directFolders {
        rows.append(.folder(folder))
      }
      for resource in self.directResources {
        rows.append(.resource(resource))
      }
    }

    if self.isLoadingMore {
      rows.append(.loadingIndicator)
    }

    return rows
  }

  @ViewBuilder
  private func viewForRow(_ row: FolderContentRowData) -> some View {
    switch row {
    case .addResource:
      if let createAction: () async throws -> Void = self.createAction {
        ResourceListAddView(action: createAction)
          .frame(height: row.estimatedHeight)
      }

    case .sectionHeader(_, let title):
      Text(title)
        .text(
          font: .inter(ofSize: 14, weight: .semibold),
          color: .passboltPrimaryText
        )
        .padding(leading: 16, trailing: 16)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: row.estimatedHeight)
        .backgroundColor(.passboltBackground)

    case .divider:
      ListDividerView()
        .padding(leading: 16, trailing: 16)
        .frame(height: row.estimatedHeight)

    case .folder(let folder):
      ResourceFolderListItemView(
        name: folder.name,
        shared: folder.shared,
        contentCount: folder.contentCount,
        locationString: folder.location,
        action: {
          try await self.folderTapAction(folder.id)
        }
      )
      .frame(height: row.estimatedHeight)

    case .resource(let resource):
      ResourceListItemView(
        name: resource.name,
        username: resource.username,
        isExpired: resource.isExpired,
        icon: resource.icon,
        resourceTypeSlug: resource.typeInfo.typeSlug,
        contentAction: {
          try await self.resourceTapAction(resource.id)
        },
        rightAction: self.resourceMenuAction.map { action in
          { try await action(resource.id) }
        },
        rightAccessory: {
          if case .none = self.resourceMenuAction {
            EmptyView()
          }
          else {
            Image(named: .more)
              .resizable()
              .aspectRatio(1, contentMode: .fit)
              .foregroundColor(Color.passboltIcon)
              .frame(width: 44)
              .padding(8)
          }
        }
      )
      .frame(height: row.estimatedHeight)

    case .loadingIndicator:
      HStack {
        Spacer()
        SwiftUI.ProgressView()
        Spacer()
      }
      .frame(height: row.estimatedHeight)
      .padding()

    case .emptyState:
      EmptyListView()
        .frame(height: row.estimatedHeight)
    }
  }
}
