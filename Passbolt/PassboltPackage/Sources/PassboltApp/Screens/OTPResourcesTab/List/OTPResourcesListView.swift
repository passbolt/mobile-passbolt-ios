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

import Commons
import Display
import SharedUIComponents
import UICommons

internal struct OTPResourcesListView: ControlledView {

  internal let controller: OTPResourcesListViewController

  internal init(
    controller: OTPResourcesListViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(from: self.controller) { state in
      self.bodyView(with: state)
    }
  }

  @MainActor @ViewBuilder private func bodyView(
    with state: ViewState
  ) -> some View {
    ScreenView(
      titleIcon: .otp,
      title: "otp.resources.list.title",
      titleExtensionView: {
        self.searchView(with: state)
      },
      titleLeadingItem: EmptyView.init,
      titleTrailingItem: EmptyView.init,
      contentView: {
        self.contentView(with: state)
      }
    )
    .backgroundColor(.passboltBackground)
    .foregroundColor(.passboltPrimaryText)
    .onDisappear(perform: self.controller.hideOTPCodes)
    .environment(\.hideLeadingItem, true)
  }

  @MainActor @ViewBuilder private func contentView(
    with state: ViewState
  ) -> some View {
    OTPResourcesList(
      resources: binding(to: \.otpResources),
      hasMoreData: state.hasMoreData,
      isLoadingMore: state.isLoadingMore,
      contentResetToken: state.contentResetToken,
      refreshAction: self.controller.refreshList,
      refreshIndicatorSource: self.controller.refreshIndicatorSource,
      loadMoreAction: self.controller.loadMore,
      createAction: self.controller.createOTPAction,
      resourceTapAction: self.controller.revealAndCopyOTP(for:),
      resourceMenuAction: self.controller.showContextualMenu(for:)
    )
    .accessibilityIdentifier("totp.collection.view")
    .shadowTopEdgeOverlay()
  }

  @MainActor @ViewBuilder private func searchView(
    with state: ViewState
  ) -> some View {
    ResourceSearchDisplayView(
      controller: self.controller.searchController
    )
    .padding(.horizontal, 8)
  }
}

private enum OTPResourcesListData: DynamicListItem {
  case addResource
  case resource(TOTPResourceViewModel)
  case loadingIndicator

  var estimatedHeight: CGFloat {
    switch self {
    case .addResource:
      return 64
    case .resource:
      return 64
    case .loadingIndicator:
      return 44
    }
  }

  var id: String {
    switch self {
    case .addResource:
      return "addResource"
    case .resource(let resource):
      return resource.id.rawValue.rawValue.uuidString
    case .loadingIndicator:
      return "loadingIndicator"
    }
  }

  var isResource: Bool {
    switch self {
    case .resource:
      return true
    default:
      return false
    }
  }
}

extension OTPResourcesListData: Hashable {

  public static func == (lhs: OTPResourcesListData, rhs: OTPResourcesListData) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

private struct OTPResourcesList: View {

  @Binding private var resources: Array<TOTPResourceViewModel>
  private let hasMoreData: Bool
  private let isLoadingMore: Bool
  private let contentResetToken: Int
  private let refreshAction: @Sendable () async -> Void
  private let refreshIndicatorSource: AnyUpdatable<Bool>?
  private let loadMoreAction: @Sendable () async -> Void
  private let createAction: (@Sendable () async -> Void)?
  private let resourceTapAction: (Resource.ID) async -> Void
  private let resourceMenuAction: ((Resource.ID) async -> Void)?

  fileprivate init(
    resources: Binding<Array<TOTPResourceViewModel>>,
    hasMoreData: Bool,
    isLoadingMore: Bool,
    contentResetToken: Int,
    refreshAction: @Sendable @escaping () async -> Void,
    refreshIndicatorSource: AnyUpdatable<Bool>? = nil,
    loadMoreAction: @Sendable @escaping () async -> Void,
    createAction: (@Sendable () async -> Void)?,
    resourceTapAction: @escaping (Resource.ID) async -> Void,
    resourceMenuAction: ((Resource.ID) async -> Void)?
  ) {
    self._resources = resources
    self.hasMoreData = hasMoreData
    self.isLoadingMore = isLoadingMore
    self.contentResetToken = contentResetToken
    self.refreshAction = refreshAction
    self.refreshIndicatorSource = refreshIndicatorSource
    self.loadMoreAction = loadMoreAction
    self.createAction = createAction
    self.resourceTapAction = resourceTapAction
    self.resourceMenuAction = resourceMenuAction
  }

  fileprivate var body: some View {
    DynamicList(
      items: rowData,
      hasMoreData: hasMoreData,
      isLoadingMore: isLoadingMore,
      onLoadMore: loadMoreAction,
      refreshAction: refreshAction,
      refreshIndicatorSource: refreshIndicatorSource,
      content: { viewForRow($0) }
    )
    .id(contentResetToken)
    .background {
      if rowData.hasResources == false {
        EmptyListView(message: "otp.resources.list.empty.message")
      }
    }
  }

  private var rowData: Array<OTPResourcesListData> {
    var rows: Array<OTPResourcesListData> = .init()
    if self.createAction != nil {
      rows.append(.addResource)
    }

    for resource: TOTPResourceViewModel in self.resources {
      rows.append(.resource(resource))
    }

    if self.isLoadingMore {
      rows.append(.loadingIndicator)
    }

    return rows
  }

  @ViewBuilder
  private func viewForRow(_ row: OTPResourcesListData) -> some View {
    switch row {
    case .addResource:
      if let createAction: @Sendable () async -> Void = self.createAction {
        ResourceListAddView(action: createAction)
          .frame(height: row.estimatedHeight)
          .accessibilityIdentifier("totp.create.button")
      }

    case .resource(let item):
      CommonListResourceOTPView(
        name: item.name,
        isExpired: item.isExpired,
        icon: item.icon,
        resourceTypeSlug: item.resourceTypeSlug,
        otpGenerator: item.generateOTP,
        contentAction: { (otp: OTPValue?) in
          await self.resourceTapAction(item.id)
        },
        accessoryAction: {
          await self.resourceMenuAction?(item.id)
        },
        accessory: {
          Image(named: .more)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .foregroundColor(Color.passboltIcon)
            .frame(width: 44)
            .padding(8)
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

extension Array where Element == OTPResourcesListData {

  // isEmpty is not sufficient, as the list can contain the "add resource" item even when there are no resources.
  fileprivate var hasResources: Bool {
    if self.isEmpty {
      return false
    }

    return self.contains { $0.isResource }
  }
}
