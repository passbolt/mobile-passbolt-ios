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

import Combine
import CommonModels
import CoreNFC
import Foundation

public final class NFCReader: NSObject {

  internal let queue: DispatchQueue
  internal var session: NFCNDEFReaderSession?

  private let instructionMessage: String
  private let successMessage: String
  private var callback: ((Result<Array<NFCNDEFMessage>, Error>) -> Void)? = nil

  public static func readOTP(
    instructionMessage: String,
    successMessage: String,
    parser: NDEFParser = .yubiKeyOTPParser(),
    callback: @escaping (Result<String, Error>) -> Void
  ) {
    let reader: NFCReader = .init(
      instructionMessage: instructionMessage,
      successMessage: successMessage,
      resultCallback: callback
    )

    reader.start()
  }

  private init(
    queue: DispatchQueue = .init(label: "NFCQueue"),
    instructionMessage: String,
    successMessage: String,
    parser: NDEFParser = .yubiKeyOTPParser(),
    resultCallback: @escaping (Result<String, Error>) -> Void
  ) {
    self.queue = queue
    self.instructionMessage = instructionMessage
    self.successMessage = successMessage
    super.init()
    self.callback = { (result: Result<Array<NFCNDEFMessage>, Error>) -> Void in
      // capturing self to extend its lifetime & setting callback to nil
      self.callback = nil
      resultCallback(result.flatMap(parser.parse))
    }
  }

  public func start() {
    guard NFCNDEFReaderSession.readingAvailable
    else {
      return callback?(
        .failure(
          NFCIssue.error(
            underlyingError:
              NFCNotSupported.error()
          )
        )
      ) ?? Void()
    }

    self.session = .init(
      delegate: self,
      queue: queue,
      invalidateAfterFirstRead: true
    )

    session?.alertMessage = instructionMessage
    session?.begin()
  }

  public func invalidate() {
    session?.invalidate()
  }

  public func restart() {
    session?.restartPolling()
  }
}

extension NFCReader: NFCNDEFReaderSessionDelegate {

  public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    /* NOP */
  }

  public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
    callback?(
      .failure(
        NFCIssue.error(
          underlyingError:
            Unidentified
            .error(underlyingError: error)
        )
      )
    )
  }

  public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
    session.alertMessage = successMessage

    callback?(.success(messages))
  }
}
