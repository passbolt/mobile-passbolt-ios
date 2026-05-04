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
import FeatureScopes
import Metadata
import OSFeatures
import Resources
import SessionData
import SharedUIComponents

internal final class OTPResourcesListViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var otpResources: Array<TOTPResourceViewModel> = .init()
    internal var isLoadingMore: Bool = false
    internal var hasMoreData: Bool = true
    internal var contentResetToken: Int = 0
    internal var lastFilterText: String = .init()
  }

  internal struct Context {

    internal let pageSize: Int

    internal init(pageSize: Int) {
      self.pageSize = pageSize
    }
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  internal let createAvailable: Bool

  private let pasteboard: OSPasteboard

  private let resourcesOTPController: ResourcesOTPController
  private let resourceEditPreparation: ResourceEditPreparation
  private let resources: ResourcesController
  private let sessionData: SessionData
  internal let searchController: ResourceSearchDisplayController

  private let features: Features
  private let context: Context

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.features = features
    self.context = context
    self.resources = try features.instance()
    self.sessionData = try features.instance()

    self.createAvailable = try features.sessionConfiguration().resources.totpEnabled
    let otpController: ResourcesOTPController = try features.instance()
    self.resourcesOTPController = otpController
    self.pasteboard = features.instance()

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: "otp.resources.search.placeholder",
        onPresentationMenuTap: .none,
        onAvatarTap: { [otpController] in
          otpController.hideOTP()
          try await navigationToAccountMenu.perform()
        }
      )
    )

    self.resourceEditPreparation = try features.instance()

    self.viewState = .init(
      initial: .init(),
      updateFrom: ComputedVariable(
        combined: searchController.searchText.asAnyUpdatable(),
        with: sessionData.lastUpdate,
        combine: { (update: (Update<String>, Update<Timestamp>)) in
          try update.0.value
        }
      ),
      update: { [resources, resourcesOTPController] (updateState, update: Update<String>) in
        do {
          var filter: ResourcesFilter = .init(sorting: .nameAlphabetically, otpOnly: true)
          filter.text = try update.value
          filter.limit = context.pageSize
          filter.offset = 0
          let otpResources: Array<TOTPResourceViewModel> =
            try await resources
            .filteredResourcesList(filter)
            .toTOTPResourceViewModels(using: resourcesOTPController)

          updateState { (viewState: inout ViewState) in
            viewState.otpResources = otpResources
            viewState.hasMoreData = otpResources.count >= context.pageSize
            viewState.isLoadingMore = false
            if viewState.lastFilterText != filter.text {
              viewState.contentResetToken += 1
            }
            viewState.lastFilterText = filter.text
          }
        }
        catch {
          error.consume()
        }
      }
    )
  }

  @MainActor @Sendable internal final func loadMore() async {

    let currentState: ViewState = await viewState.current
    let hasMore: Bool = currentState.hasMoreData
    let isLoading: Bool = currentState.isLoadingMore

    guard hasMore, !isLoading else { return }

    self.viewState.update { (state: inout ViewState) in
      state.isLoadingMore = true
    }

    do {
      let pageSize: Int = context.pageSize
      let filterText: String = self.searchController.searchText.value
      let expectedOffset: Int = currentState.otpResources.count
      var filter: ResourcesFilter = .init(sorting: .nameAlphabetically, otpOnly: true)
      filter.text = filterText
      filter.limit = pageSize
      filter.offset = expectedOffset

      let nextPageResources: Array<ResourceListItemDSV> = try await self.resources.filteredResourcesList(filter)

      self.viewState.update { (state: inout ViewState) in
        // Discard the page if a filter update or refresh reset the list mid-flight.
        guard state.lastFilterText == filterText, state.otpResources.count == expectedOffset
        else {
          state.isLoadingMore = false
          return
        }
        state.otpResources.append(contentsOf: nextPageResources.toTOTPResourceViewModels(using: resourcesOTPController))
        state.hasMoreData = nextPageResources.count >= pageSize
        state.isLoadingMore = false
      }
    }
    catch {
      error.consume(context: "Failed to load more resources.")
      self.viewState.update { (state: inout ViewState) in
        state.isLoadingMore = false
      }
    }
  }
}

extension OTPResourcesListViewController {

  @Sendable internal func refreshList() async {
    await consumingErrors {
      try await self.sessionData.refreshIfNeeded()
    }
  }

  internal var createOTPAction: (@Sendable () async -> Void)? {
    self.createAvailable ? self.createOTP : .none
  }

  private func createOTP() async {
    await consumingErrors {
      let metadataTypeSettings: MetadataSettingsService = try await self.features.instance()
      let totpType: ResourceSpecification.Slug =
        metadataTypeSettings.typesSettings().defaultResourceTypes == .v5
        ? .v5StandaloneTOTP
        : .totp
      let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(totpType, .none, .none)
      guard
        let resourceType: ResourceType = editingContext.availableTypes.first(where: {
          $0.specification.slug == totpType
        }),
        let totpPath: ResourceType.FieldPath = resourceType.fieldSpecification(for: \.firstTOTP)?.path
      else {
        return
      }
      let features: Features = try await self.features.branchIfNeeded(
        scope: ResourceEditScope.self,
        context: editingContext
      )
      let navigationToOTPScanning: NavigationToOTPScanning = try await features.instance()
      await navigationToOTPScanning.performCatching(
        context: .init(
          totpPath: totpPath
        )
      )
    }
  }

  @discardableResult
  private func revealOTP(
    for resourceID: Resource.ID
  ) async throws -> OTPValue {
    try await self.resourcesOTPController.revealOTP(resourceID)
  }

  private func copyOTP(
    _ value: OTPValue
  ) async throws {
    pasteboard.putWithAutoExpiration(value.otp.rawValue)
    SnackBarMessageEvent.send("otp.value.copied.message")
  }

  internal func revealAndCopyOTP(
    for resourceID: Resource.ID
  ) async {
    await consumingErrors(
      errorDiagnostics: "Failed to reveal or copy OTP."
    ) {
      try await self.copyOTP(self.revealOTP(for: resourceID))
    }
  }

  internal func showContextualMenu(
    for resourceID: Resource.ID
  ) async {
    await consumingErrors(
      errorDiagnostics: "Failed to navigate to OTP contextual menu."
    ) {
      await self.hideOTPCodes()
      let features: Features =
        try await features.branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )
      let navigationToContextualMenu: NavigationToResourceOTPContextualMenu = try await features.instance()
      try await navigationToContextualMenu.perform(
        context: .init(
          revealOTP: { [self] in
            await consumingErrors(
              errorDiagnostics: "Failed to reveal OTP."
            ) {
              try await self.revealOTP(for: resourceID)
            }
          }
        )
      )
    }
  }

  internal func hideOTPCodes() {
    self.resourcesOTPController.hideOTP()
  }
}

internal struct TOTPResourceViewModel {

  internal var id: Resource.ID
  internal var name: String
  internal var isExpired: Bool
  internal var icon: ResourceIcon
  internal var resourceTypeSlug: ResourceSpecification.Slug?
  internal var generateOTP: @Sendable () async -> OTPValue?

  internal init(
    id: Resource.ID,
    name: String,
    isExpired: Bool,
    icon: ResourceIcon,
    resourceTypeSlug: ResourceSpecification.Slug?,
    generateOTP: @Sendable @escaping () async -> OTPValue?
  ) {
    self.id = id
    self.name = name
    self.isExpired = isExpired
    self.icon = icon
    self.resourceTypeSlug = resourceTypeSlug
    self.generateOTP = generateOTP
  }
}

extension TOTPResourceViewModel: Equatable {

  internal static func == (
    _ lhs: TOTPResourceViewModel,
    _ rhs: TOTPResourceViewModel
  ) -> Bool {
    lhs.id == rhs.id
      && lhs.name == rhs.name
  }
}

extension TOTPResourceViewModel: Identifiable {}

extension Array where Element == ResourceListItemDSV {

  fileprivate func toTOTPResourceViewModels(
    using resourcesOTPController: ResourcesOTPController
  ) -> Array<TOTPResourceViewModel> {
    var list: Array<TOTPResourceViewModel> = .init()

    for item in self {
      let otpIterator: UncheckedSendableBox<AnyAsyncIterator<OTPValue?>> = .init(
        resourcesOTPController
          .currentOTP
          .asAnyAsyncSequence()
          .map { (update: Update<OTPValue>) -> OTPValue? in
            if let otp: OTPValue = try? update.value, otp.resourceID == item.id {
              return otp
            }
            else {
              return .none
            }
          }
          .removeDuplicates()
          .makeAsyncIterator()
          .asAnyAsyncIterator()
      )
      list.append(
        .init(
          id: item.id,
          name: item.name,
          isExpired: item.isExpired,
          icon: item.icon,
          resourceTypeSlug: item.typeInfo.typeSlug,
          generateOTP: { () async -> OTPValue? in
            (try? await otpIterator.value.next())?.flatMap { $0 }
          }
        )
      )
    }

    return list
  }
}
