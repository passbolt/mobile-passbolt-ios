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
import Commons
import SwiftUI

// MARK: - Row Data Model
public enum ResourcesListRowData: DynamicListItem {

  public typealias Section = Tagged<String, Self>

  case sectionHeader(title: String)
  case addResource
  case resource(ResourceListItemDSV, Section)
  case loadingIndicator

  public var id: String {
    switch self {
    case .sectionHeader(let title):
      return "header_\(title)"
    case .addResource:
      return "add_resource"
    case .resource(let resource, let section):
      return "resource_\(resource.id.rawValue.rawValue.uuidString)_\(section.rawValue)"
    case .loadingIndicator:
      return "loading"
    }
  }

  public var estimatedHeight: CGFloat {
    switch self {
    case .sectionHeader:
      return 24
    case .addResource, .resource:
      return 64
    case .loadingIndicator:
      return 44
    }
  }
}

extension ResourcesListRowData.Section {

  static let suggested: Self = "suggested"
  static let all: Self = "all"
}

extension ResourcesListRowData: Hashable {

  public static func == (lhs: ResourcesListRowData, rhs: ResourcesListRowData) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public struct ResourcesListView: View {

  @State private var id: IID = .init()
  private let suggestedResources: Array<ResourceListItemDSV>?
  @Binding private var resources: Array<ResourceListItemDSV>
  private let contentEmpty: Bool
  private let hasMoreData: Bool
  private let isLoadingMore: Bool
  private let contentResetToken: Int
  private let refreshAction: @Sendable () async -> Void
  private let refreshIndicatorSource: AnyUpdatable<Bool>?
  private let loadMoreAction: @Sendable () async -> Void
  private let createAction: (@Sendable () async throws -> Void)?
  private let resourceTapAction: @Sendable (Resource.ID) async throws -> Void
  private let resourceMenuAction: (@Sendable (Resource.ID) async throws -> Void)?

  public init(
    suggestedResources: Array<ResourceListItemDSV>?,
    resources: Binding<Array<ResourceListItemDSV>>,
    hasMoreData: Bool,
    isLoadingMore: Bool,
    contentResetToken: Int = 0,
    refreshAction: @escaping @Sendable () async -> Void,
    refreshIndicatorSource: AnyUpdatable<Bool>? = nil,
    loadMoreAction: @escaping @Sendable () async -> Void,
    createAction: (@Sendable () async throws -> Void)?,
    resourceTapAction: @escaping @Sendable (Resource.ID) async throws -> Void,
    resourceMenuAction: (@Sendable (Resource.ID) async throws -> Void)?
  ) {
    self.suggestedResources = suggestedResources
    self._resources = resources
    self.hasMoreData = hasMoreData
    self.isLoadingMore = isLoadingMore
    self.contentResetToken = contentResetToken
    self.contentEmpty =
      suggestedResources?.isEmpty ?? true
      && resources.isEmpty
    self.refreshAction = refreshAction
    self.refreshIndicatorSource = refreshIndicatorSource
    self.loadMoreAction = loadMoreAction
    self.createAction = createAction
    self.resourceTapAction = resourceTapAction
    self.resourceMenuAction = resourceMenuAction
  }

  public var body: some View {
    let rowData: Array<ResourcesListRowData> = self.rowData
    DynamicList(
      items: rowData,
      hasMoreData: hasMoreData,
      isLoadingMore: isLoadingMore,
      onLoadMore: loadMoreAction,
      refreshAction: refreshAction,
      refreshIndicatorSource: refreshIndicatorSource,
      contentResetToken: contentResetToken,
      content: { viewForRow($0) }
    )
    .background {
      if rowData.hasResources == false {
        EmptyListView()
      }
    }
  }

  private var rowData: Array<ResourcesListRowData> {
    var rows: Array<ResourcesListRowData> = []

    // Add create button if available
    if self.createAction != nil {
      rows.append(.addResource)
    }

    // Add suggested section if available
    if let suggested: Array<ResourceListItemDSV> = self.suggestedResources, !suggested.isEmpty {
      rows.append(
        .sectionHeader(
          title: DisplayableString.localized("autofill.extension.resource.list.section.suggested.title").string()
        )
      )
      for resource in suggested {
        rows.append(.resource(resource, .suggested))
      }

      // Add "All" section header if we have both suggested and regular resources
      if !self.resources.isEmpty {
        rows.append(
          .sectionHeader(
            title: DisplayableString.localized("autofill.extension.resource.list.section.all.title").string()
          )
        )
      }
    }

    // Add all resources
    for resource in self.resources {
      rows.append(.resource(resource, .all))
    }

    // Add loading indicator if loading more
    if self.isLoadingMore {
      rows.append(.loadingIndicator)
    }

    return rows
  }

  @ViewBuilder
  private func viewForRow(_ row: ResourcesListRowData) -> some View {
    switch row {
    case .sectionHeader(let title):
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

    case .addResource:
      if let createAction: @Sendable () async throws -> Void = self.createAction {
        ResourceListAddView(action: createAction)
          .frame(height: row.estimatedHeight)
      }

    case .resource(let resource, _):
      ResourceListItemView(
        name: resource.name,
        username: resource.username,
        isExpired: resource.isExpired,
        icon: resource.icon,
        resourceTypeSlug: resource.typeInfo.typeSlug,
        contentAction: {
          try await self.resourceTapAction(resource.id)
        },
        rightAction: self.resourceMenuAction.flatMap { action in
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
    }
  }
}

extension Array where Element == ResourcesListRowData {

  fileprivate var hasResources: Bool {
    self.contains { row in
      if case .resource = row {
        return true
      }
      else {
        return false
      }
    }
  }
}
