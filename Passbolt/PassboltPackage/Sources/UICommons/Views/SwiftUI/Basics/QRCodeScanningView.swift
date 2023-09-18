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
import SwiftUI
import UIKit

public struct QRCodeScanningView: UIViewControllerRepresentable {

  private let process: @Sendable (String) -> Void

  public init(
    process: @escaping @Sendable (String) -> Void
  ) {
    self.process = process
  }

  public func makeUIViewController(
    context: Context
  ) -> some UIViewController {
    QRCodeScanningViewController(
      process: self.process
    )
  }

  public func updateUIViewController(
    _ uiViewController: UIViewControllerType,
    context: Context
  ) {
    // no updates
  }
}

internal final class QRCodeScanningViewController: UIViewController {

  private let captureMetadataQueue: DispatchQueue = .init(label: "com.passbolt.qr.reader")
  private lazy var metadataOutput: AVCaptureMetadataOutput = {
    let output: AVCaptureMetadataOutput = .init()
    output.setMetadataObjectsDelegate(
      self,
      queue: self.captureMetadataQueue
    )
    return output
  }()
  private lazy var cameraSession: AVCaptureSession? = {
    let session: AVCaptureSession = .init()
    guard
      let device: AVCaptureDevice = .default(for: .video),
      let input: AVCaptureDeviceInput = try? .init(device: device),
      session.canAddInput(input),
      session.canAddOutput(self.metadataOutput)
    else { return nil }

    session.addInput(input)
    session.addOutput(self.metadataOutput)

    self.metadataOutput.metadataObjectTypes = [.qr]
    return session
  }()

  private let process: @Sendable (String) -> Void

  public init(
    process: @escaping @Sendable (String) -> Void
  ) {
    self.process = process
    super
      .init(
        nibName: .none,
        bundle: .none
      )
  }

  @available(*, unavailable)
  internal required init?(coder: NSCoder) {
    unreachable(#function)
  }

  deinit {
    self.cameraSession?.stopRunning()
  }

  override func loadView() {
    self.view = CodeReaderView(
      session: self.cameraSession
    )
    self.captureMetadataQueue.async {
      self.cameraSession?.startRunning()
    }
  }
}

extension QRCodeScanningViewController: AVCaptureMetadataOutputObjectsDelegate {

  internal func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: Array<AVMetadataObject>,
    from connection: AVCaptureConnection
  ) {
    dispatchPrecondition(condition: .onQueue(captureMetadataQueue))

    guard
      let metadata: AVMetadataMachineReadableCodeObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
      let payload: String = metadata.stringValue
    else { return }

    self.process(payload)
  }
}

internal final class CodeReaderView: PlainView {

  private let cameraPreview: AVCaptureVideoPreviewLayer?

  internal init(
    session captureSession: AVCaptureSession?
  ) {
    self.cameraPreview = captureSession.map(AVCaptureVideoPreviewLayer.init(session:))
    super.init()
  }

  @available(*, unavailable)
  internal required init() {
    unreachable(#function)
  }

  override internal func setup() {
    if let cameraPreview: AVCaptureVideoPreviewLayer = self.cameraPreview {
      cameraPreview.videoGravity = .resizeAspectFill
      self.layer.addSublayer(cameraPreview)
    }
    else {
      self.backgroundColor = .passboltBackground
      let label: UILabel = .init()
      label.text =
        DisplayableString
        .localized(
          key: "code.scanning.camera.unavailable"
        )
        .string()
      label.numberOfLines = 0
      label.textAlignment = .center
      label.textColor = .passboltPrimaryText
      label.font = .inter(
        ofSize: 16,
        weight: .bold
      )
      label.translatesAutoresizingMaskIntoConstraints = false
      self.addSubview(label)
      NSLayoutConstraint
        .activate([
          label.centerXAnchor
            .constraint(equalTo: self.centerXAnchor),
          label.centerYAnchor
            .constraint(equalTo: self.centerYAnchor),
          label.leadingAnchor
            .constraint(greaterThanOrEqualTo: self.leadingAnchor),
          label.trailingAnchor
            .constraint(lessThanOrEqualTo: self.trailingAnchor),
        ])
    }
  }

  override internal func layoutSubviews() {
    super.layoutSubviews()
    self.cameraPreview?.frame = self.bounds
  }
}
