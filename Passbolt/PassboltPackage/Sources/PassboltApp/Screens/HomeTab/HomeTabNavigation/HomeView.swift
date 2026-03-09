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

internal struct HomeView: ControlledView {

  internal let controller: HomeViewController

  internal init(controller: HomeViewController) {
    self.controller = controller
  }

  internal var body: some View {
    with(\.currentPresentation) { presentation in
      if #unavailable(iOS 17) {
        // iOS 16 fails to handle switch statement with views, so we need to use workaround
        HomeContentHost(presentation: presentation, controller: controller)
      }
      else {
        switch presentation {
        case .plainResourcesList,
          .favoriteResourcesList,
          .modifiedResourcesList,
          .sharedResourcesList,
          .ownedResourcesList,
          .expiredResourcesList:
          ResourcesListView(controller: controller.prepareResourcesList(for: presentation))

        case .foldersExplorer:
          FoldersExplorerView(controller: controller.prepareController(context: .none))

        case .tagsExplorer:
          TagsExplorerView(controller: controller.prepareController(context: .none))

        case .resourceUserGroupsExplorer:
          ResourceUserGroupsExplorerView(controller: controller.prepareController(context: .none))
        }
      }
    }
    .task(self.controller.activate)
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

    // Create appropriate SwiftUI view based on presentation mode
    let contentView: AnyView
    switch presentation {
    case .plainResourcesList, .favoriteResourcesList, .modifiedResourcesList,
      .sharedResourcesList, .ownedResourcesList, .expiredResourcesList:
      contentView = AnyView(
        ResourcesListView(controller: controller.prepareResourcesList(for: presentation))
      )

    case .foldersExplorer:
      contentView = AnyView(
        FoldersExplorerView(controller: controller.prepareController(context: .none))
      )

    case .tagsExplorer:
      contentView = AnyView(
        TagsExplorerView(controller: controller.prepareController(context: .none))
      )

    case .resourceUserGroupsExplorer:
      contentView = AnyView(
        ResourceUserGroupsExplorerView(controller: controller.prepareController(context: .none))
      )
    }

    // Add new child UIHostingController
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
