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

import Features
import UICommons
import UIComponents
import UniformTypeIdentifiers

public final class HelpMenuViewController: PlainViewController, UIComponent, UIDocumentPickerDelegate {

  public typealias ContentView = HelpMenuView
  public typealias Controller = HelpMenuController

  public private(set) lazy var contentView: ContentView = .init()

  public let components: UIComponentFactory
  private let controller: Controller
  public static let navigationToPassphraseValidationSubject: PassthroughSubject<Void, Never> = .init()

  public static func instance(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self {
    Self(
      using: controller,
      with: components,
      cancellables: cancellables
    )
  }

  public init(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.controller = controller
    self.components = components
    super
      .init(
        cancellables: cancellables
      )
  }

  public func setupView() {
    title =
      DisplayableString
      .localized(
        key: "help.menu.title"
      )
      .string()

    contentView.setActions(controller.actions())

    setupSubscriptions()
  }

  // Navigation to account transfer (callback)
  public var navigateToAccountTransfer: (() -> Void)?

  /**
   * Sets up subscriptions to various publishers from the controller.
   * @returns {void}
   */
  private func setupSubscriptions() {
    controller
      .logsPresentationPublisher()
      .sink { [weak self] in
        self?.cancellables
          .executeOnMainActor { [weak self] in
            if let parent: AnyUIComponent = self?.presentingViewController as? AnyUIComponent {
              await self?.dismiss(Self.self)
              await parent.present(PlainNavigationViewController<LogsViewerViewController>.self)
            }
            else {
              await self?.present(PlainNavigationViewController<LogsViewerViewController>.self)
            }
          }
      }
      .store(in: cancellables)

    controller
      .websiteHelpPresentationPublisher()
      .sink { [weak self] in
        self?.cancellables
          .executeOnMainActor { [weak self] in
            await self?.dismiss(Self.self)
          }
      }
      .store(in: cancellables)

    controller
      .importAccountKitPresentationPublisher()
      .sink { [weak self] in
        self?.cancellables
          .executeOnMainActor { [weak self] in
            self?.presentDocumentPicker()
          }
      }
      .store(in: cancellables)
  }

  /**
   * Presents a document picker to the user.
   *
   * The document picker is configured to allow the user to select any type of document, and it's presented in full-screen mode.
   * @returns {void}
   */
  private func presentDocumentPicker() {
    let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
    documentPicker.delegate = self
    documentPicker.modalPresentationStyle = .fullScreen
    present(documentPicker, animated: true, completion: nil)
  }

  /**
   * Handles the selection of a document in the document picker.
   *
   * This delegate function is called when a user picks a document using the document picker.
   *
   * @param {UIDocumentPickerViewController} controller - The document picker view controller.
   * @param {URL[]} urls - An array of URLs pointing to the selected documents.
   * @returns {void}
   */
  public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    //Do not continue if the user does not select any file
    guard let selectedFileURL = urls.first else {
      return
    }
    // Retrieve the file content and launch
    do {
      let fileContents = try String(contentsOf: selectedFileURL, encoding: .utf8)
      //Send file content to controller
      self.handleAccountKitImportation(fileContents)
    }
    catch {
      error.logged()
    }
  }

  /**
   * Handles the importation of an account kit.
   *
   * This function initiates the account kit importation process
   *
   * @param {string} payload - The payload for the account kit importation.
   * @returns {void}
   */
  private func handleAccountKitImportation(_ payload: String) {
    controller.proceedAccountKitImportationPublisher(payload)
      .sink(
        receiveCompletion: { [weak self] completion in
          self?.cancellables
            .executeOnMainActor { [weak self] in
              guard let self else { return }
              switch completion {
              case .finished:
                break
              case .failure(let error):
                //Send error to parent
                NotificationCenter.default.post(name: .helpMenuActionAccountKitNotification, object: error)
                break
              }
              await self.dismiss(Self.self)
            }

        },
        receiveValue: { [weak self] accountTransferData in
          // Handle the AccountTransferData and send it to parent
          NotificationCenter.default.post(name: .helpMenuActionAccountKitNotification, object: accountTransferData)
        }
      )
      .store(in: self.cancellables)
  }

}
