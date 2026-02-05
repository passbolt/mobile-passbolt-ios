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

import AVFoundation
import AccountSetup
import Display
import FeatureScopes

internal struct CodeScanningView: ControlledView {

  internal let controller: CodeScanningViewController

  internal init(controller: Controller) {
    self.controller = controller
  }

  internal var body: some View {
    withAlert(
      \.alert,
      content: { content }
    )
  }

  private var content: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        BackButton(action: self.controller.backButtonTapped)
        progressView
          .padding(.trailing, 8)
          .frame(height: 24)
        IconButton(iconName: .help, action: self.controller.showHelp)

      }
      .padding(.horizontal, 16)
      CodeScannerView(
        processPayload: self.controller.processPayload(_:),
        alertHandler: self.controller.handleCodeScannerAlert(_:),
        cancelScanning: self.controller.cancelImport
      )
      .ignoresSafeArea()
    }
    .toolbar(.hidden)
  }

  private var progressView: some View {
    with(\.progress) { progress in
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4)
            .foregroundStyle(Color.passboltDivider)
            .frame(height: 8)
            .frame(maxWidth: .infinity)
          RoundedRectangle(cornerRadius: 4)
            .foregroundStyle(Color.passboltSecondaryRed)
            .frame(width: geometry.size.width * progress, height: 8)
        }
        .frame(maxHeight: .infinity)
      }
    }
  }
}

#if DEBUG
extension CodeScanningViewController {

  static func previewDependencies(_ features: inout PreviewFeaturesContainer) {
    features
      .patch(
        \AccountImport.progress,
        with: { .scanningProgress(0.3) }
      )
    features
      .patch(
        \AccountImport.updates,
        with: PlaceholderUpdatable().asAnyUpdatable()
      )
  }
}

#Preview {

  createPreview(
    CodeScanningView.self
  )
  .wrapInNavigationStack()
}
#endif

private struct CodeScannerView: UIViewRepresentable {

  private let processPayload: (String) async throws -> Void
  private let alertHandler: (AlertViewModel) -> Void
  private let cancelScanning: () async -> Void

  fileprivate init(
    processPayload: @escaping (String) async throws -> Void,
    alertHandler: @escaping (AlertViewModel) -> Void,
    cancelScanning: @escaping () async -> Void
  ) {
    self.processPayload = processPayload
    self.alertHandler = alertHandler
    self.cancelScanning = cancelScanning
  }

  fileprivate func updateUIView(_ uiView: UIView, context: Context) {
    /** no-op */
  }

  fileprivate func makeCoordinator() -> Coordinator {
    Coordinator(
      processPayload: processPayload,
      alertHandler: alertHandler,
      cancelScanning: cancelScanning
    )
  }

  fileprivate func makeUIView(context: Context) -> UIView {
    let view = PreviewView()
    context.coordinator.setupSession(previewView: view)
    return view
  }

  fileprivate class PreviewView: UIView {
    override class var layerClass: AnyClass {
      AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
      // swift-format-ignore: NeverForceUnwrap
      layer as! AVCaptureVideoPreviewLayer
    }
  }

  fileprivate class Coordinator: NSObject {

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

    private var processingTask: Task<Void, Never>?

    private let processPayload: (String) async throws -> Void
    private let alertHandler: (AlertViewModel) -> Void
    private let cancelScanning: () async -> Void

    fileprivate init(
      processPayload: @escaping (String) async throws -> Void,
      alertHandler: @escaping (AlertViewModel) -> Void,
      cancelScanning: @escaping () async -> Void
    ) {
      self.processPayload = processPayload
      self.alertHandler = alertHandler
      self.cancelScanning = cancelScanning
    }

    fileprivate func setupSession(previewView: PreviewView) {
      if let cameraSession: AVCaptureSession = self.cameraSession {

        SnackBarMessageEvent.send("code.scanning.begin")

        previewView.videoPreviewLayer.session = cameraSession
        previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
        cameraSession.startRunning()
      }
      else {
        alertHandler(
          .init(
            title: "code.scanning.camera.unavailable",
            message: "",
            actions: [
              .regular(
                id: .init(),
                title: .localized(key: .gotIt),
                perform: { await self.cancelScanning() }
              )
            ]
          )
        )
      }
    }
  }
}

extension CodeScannerView.Coordinator: AVCaptureMetadataOutputObjectsDelegate {

  internal func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: Array<AVMetadataObject>,
    from connection: AVCaptureConnection
  ) {
    dispatchPrecondition(condition: .onQueue(captureMetadataQueue))
    guard
      processingTask == nil,  // prevent multiple processing at the same time
      let metadata: AVMetadataMachineReadableCodeObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
      let payload: String = metadata.stringValue
    else { return }
    // we are ignoring QRCodes which payload is not representable by String (utf8)
    // due to public api limitations, CIQRCodeDescriptor contains raw data but with
    // error correction bytes applied which can't be easily removed (Reed-Solomon encoding)

    SnackBarMessageEvent.send("code.scanning.processing.in.progress")

    processingTask = Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        try await self.processPayload(payload)
      }
      catch {
        switch error {
        case is Cancelled:
          break  // NOP

        case let serverError as ServerConnectionIssue:
          self.alertHandler(.serverErrorAlert(with: serverError.serverURL))

        case let serverError as ServerResponseTimeout:
          self.alertHandler(.serverErrorAlert(with: serverError.serverURL))

        case _:
          SnackBarMessageEvent.send(.error(error))
        }
      }

      // Delay unlocking QRCode processing until error message becomes visible for some time.
      // It will blink rapidly otherwise if camera is still pointing into invalid QRCode.
      try? await Task.sleep(for: .seconds(1.5))

      self.processingTask = nil
    }
  }
}
