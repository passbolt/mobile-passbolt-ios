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
import UniformTypeIdentifiers

internal struct AccountKitPickerView: ControlledView {

  internal let controller: AccountKitPickerViewController

  internal init(controller: AccountKitPickerViewController) {
    self.controller = controller
  }

  internal var body: some View {
    DocumentPicker(
      onDocumentSelected: self.controller.onAccountKitSelected(_:)
    )
  }
}

private struct DocumentPicker: UIViewControllerRepresentable {

  private let onDocumentSelected: (URL?) -> Void

  fileprivate init(onDocumentSelected: @escaping (URL?) -> Void) {
    self.onDocumentSelected = onDocumentSelected
  }

  fileprivate func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
    picker.delegate = context.coordinator
    picker.modalPresentationStyle = .fullScreen
    return picker
  }

  fileprivate func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    // no-op
  }

  fileprivate func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  fileprivate class Coordinator: NSObject, UIDocumentPickerDelegate {
    private let parent: DocumentPicker

    fileprivate init(_ parent: DocumentPicker) {
      self.parent = parent
    }

    fileprivate func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: Array<URL>) {
      parent.onDocumentSelected(urls.first)
    }

    fileprivate func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
      parent.onDocumentSelected(.none)
    }
  }
}
