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
import SharedUIComponents

internal struct HomeView: ControlledView {

  internal let controller: HomeViewController
  @StateObject private var navigationState = NavigationState()

  internal init(
    controller: HomeViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    NavigationContainer(navigationState: navigationState) {
      WithViewState(from: self.controller) { state in
        self.bodyView(with: state)
      }
    }
    .onAppear {
      controller.setActiveNavigationState(navigationState)
    }
  }

  @ViewBuilder private func bodyView(
    with state: ViewState
  ) -> some View {
    Group {
      if #unavailable(iOS 17) {
        HomeContentHost(presentation: state.currentPresentation, controller: controller)
      }
      else {
        switch state.currentPresentation {
        case .plainResourcesList, .favoriteResourcesList, .modifiedResourcesList,
          .sharedResourcesList, .ownedResourcesList, .expiredResourcesList:
          ResourcesListView(
            controller: controller.prepareResourcesList(for: state.currentPresentation)
          )

        case .foldersExplorer:
          ResourceFolderContentView(
            controller: controller.prepareController(context: .init(folderDetails: .none))
          )

        case .tagsExplorer:
          ResourceTagsListView(
            controller: controller.prepareController(
              context: .init(
                title: state.currentPresentation.title,
                titleIconName: state.currentPresentation.iconName
              )
            )
          )

        case .resourceUserGroupsExplorer:
          ResourceUserGroupsListView(
            controller: controller.prepareController(
              context: .init(
                title: state.currentPresentation.title,
                titleIconName: state.currentPresentation.iconName
              )
            )
          )
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        IconButton(
          iconName: .close,
          action: { self.controller.closeExtension() }
        )
        .tint(Color.passboltPrimaryText)
      }
    }
  }
}

private struct HomeContentHost: UIViewControllerRepresentable {

  let presentation: HomePresentationMode
  let controller: HomeViewController

  func makeUIViewController(context: Context) -> HomeContainerController {
    let container: HomeContainerController = HomeContainerController()
    container.updateContent(presentation: presentation, controller: controller)
    return container
  }

  func updateUIViewController(_ container: HomeContainerController, context: Context) {
    container.updateContent(presentation: presentation, controller: controller)
  }
}

private final class HomeContainerController: UIViewController {

  private var currentPresentation: HomePresentationMode?

  func updateContent(
    presentation: HomePresentationMode,
    controller: HomeViewController
  ) {
    guard presentation != currentPresentation else { return }
    currentPresentation = presentation

    for child in children {
      child.willMove(toParent: nil)
      child.view.removeFromSuperview()
      child.removeFromParent()
    }

    let contentView: AnyView
    switch presentation {
    case .plainResourcesList, .favoriteResourcesList, .modifiedResourcesList,
      .sharedResourcesList, .ownedResourcesList, .expiredResourcesList:
      contentView = AnyView(
        ResourcesListView(controller: controller.prepareResourcesList(for: presentation))
      )

    case .foldersExplorer:
      contentView = AnyView(
        ResourceFolderContentView(
          controller: controller.prepareController(context: .init(folderDetails: .none))
        )
      )

    case .tagsExplorer:
      contentView = AnyView(
        ResourceTagsListView(
          controller: controller.prepareController(
            context: .init(
              title: presentation.title,
              titleIconName: presentation.iconName
            )
          )
        )
      )

    case .resourceUserGroupsExplorer:
      contentView = AnyView(
        ResourceUserGroupsListView(
          controller: controller.prepareController(
            context: .init(
              title: presentation.title,
              titleIconName: presentation.iconName
            )
          )
        )
      )
    }

    let hostingController: UIHostingController<AnyView> = UIHostingController(rootView: contentView)
    hostingController.view.backgroundColor = .clear
    addChild(hostingController)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hostingController.view)
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    hostingController.didMove(toParent: self)
  }
}
