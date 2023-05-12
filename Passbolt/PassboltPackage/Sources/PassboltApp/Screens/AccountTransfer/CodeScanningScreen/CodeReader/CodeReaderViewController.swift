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

import AVFoundation
import CommonModels
import SharedUIComponents
import UIComponents

internal final class CodeReaderViewController: PlainViewController, UIComponent {

  internal typealias ContentView = CodeReaderView
  internal typealias Controller = CodeReaderController

  internal static func instance(
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

  internal private(set) lazy var contentView: ContentView = .init(session: cameraSession)
  internal let components: UIComponentFactory

  private let captureMetadataQueue: DispatchQueue = .init(label: "com.passbolt.reader.metadata")
  private lazy var metadataOutput: AVCaptureMetadataOutput = {
    let output: AVCaptureMetadataOutput = .init()
    output.setMetadataObjectsDelegate(self, queue: captureMetadataQueue)
    return output
  }()
  private lazy var cameraSession: AVCaptureSession? = {
    let session: AVCaptureSession = .init()
    guard
      let device: AVCaptureDevice = .default(for: .video),
      let input: AVCaptureDeviceInput = try? .init(device: device),
      session.canAddInput(input),
      session.canAddOutput(metadataOutput)
    else { return nil }
    session.addInput(input)
    session.addOutput(metadataOutput)

    metadataOutput.metadataObjectTypes = [.qr]
    return session
  }()

  private let controller: Controller
  private var payloadProcessingCancellable: AnyCancellable?

  internal init(
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

  internal func setupView() {
    setupSubscriptions()
  }

  private func setupSubscriptions() {}

  internal func activate() {
    self.cancellables.executeOnMainActor { [weak self] in
      if let cameraSession: AVCaptureSession = self?.cameraSession {
        cameraSession.startRunning()
        self?
          .present(
            snackbar: Mutation<UICommons.PlainView>
              .snackBarMessage(
                .localized("code.scanning.begin"),
                backgroundColor: .background,
                textColor: .primaryText
              )
              .instantiate(),
            hideAfter: 2
          )
      }
      else {
        await self?
          .present(
            CodeScanningCameraInaccessibleViewController.self
          )
      }
    }
  }

  internal func deactivate() {
    payloadProcessingCancellable = nil
    cameraSession?.stopRunning()
  }
}

extension CodeReaderViewController: AVCaptureMetadataOutputObjectsDelegate {

  internal func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: Array<AVMetadataObject>,
    from connection: AVCaptureConnection
  ) {
    dispatchPrecondition(condition: .onQueue(captureMetadataQueue))
    guard
      payloadProcessingCancellable == nil,  // prevent multiple processing at the same time
      let metadata: AVMetadataMachineReadableCodeObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
      let payload: String = metadata.stringValue
    else { return }
    // we are ignoring QRCodes which payload is not representable by String (utf8)
    // due to public api limitations, CIQRCodeDescriptor contains raw data but with
    // error correction bytes applied which can't be easily removed (Reed-Solomon encoding)
    payloadProcessingCancellable =
      controller
      .processPayload(payload)
      .subscribe(on: RunLoop.main)
      .handleEvents(receiveSubscription: { [weak self] _ in
        self?
          .present(
            snackbar: Mutation<UICommons.PlainView>
              .snackBarMessage(
                .localized("code.scanning.processing.in.progress"),
                backgroundColor: .background,
                textColor: .primaryText
              )
              .instantiate(),
            hideAfter: 2,
            replaceCurrent: false
          )
      })
      .receive(on: RunLoop.main)
      .handleErrors { [weak self] error in
        switch error {
        case is Cancelled:
          return /* NOP */

        case let serverError as ServerConnectionIssue:
          Task {
            await self?
              .present(
                ServerNotReachableAlertViewController.self,
                in: serverError.serverURL
              )
          }

        case let serverError as ServerResponseTimeout:
          Task {
            await self?
              .present(
                ServerNotReachableAlertViewController.self,
                in: serverError.serverURL
              )
          }

        case _:
          self?.presentErrorSnackbar(error.displayableMessage)
        }
      }
      .handleEnd { [weak self] ending in
        if case let .failed(error) = ending, !(error is Cancelled) {
          // Delay unlocking QRCode processing until error message becomes visible for some time.
          // It will blink rapidly otherwise if camera is still pointing into invalid QRCode.
          self?.captureMetadataQueue
            .asyncAfter(deadline: .now() + 1.5) { [weak self] in
              self?.payloadProcessingCancellable = nil
            }
        }
        else {
          self?.captureMetadataQueue
            .async { [weak self] in
              self?.payloadProcessingCancellable = nil
            }
        }
      }
      .sinkDrop()
  }
}
